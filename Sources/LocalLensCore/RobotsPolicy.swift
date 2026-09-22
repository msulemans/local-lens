import Foundation

// MARK: - Time and waiting boundary

/// The only source of time and of waiting inside the politeness boundary.
///
/// Waiting and measuring are injected for the same reason the transport and the
/// resolver are: a delay rule that can only be observed with a real clock
/// cannot be asserted deterministically, and a test that sleeps for real is a
/// test that is either slow or flaky.
public protocol PolitenessClock: Sendable {
    /// Monotonic seconds. Only differences between two readings are meaningful,
    /// so the origin of the scale is unspecified.
    func now() async -> Double

    /// Suspends for `seconds`. A non-positive duration returns immediately.
    func sleep(seconds: Double) async throws
}

/// The production clock. It is thin on purpose: it holds no policy, and no test
/// uses it.
public struct SystemPolitenessClock: PolitenessClock {
    public init() {}

    public func now() async -> Double {
        Double(DispatchTime.now().uptimeNanoseconds) / 1_000_000_000
    }

    public func sleep(seconds: Double) async throws {
        guard seconds > 0 else { return }
        try await Task.sleep(for: .seconds(seconds))
    }
}

// MARK: - Per-host gate

/// Serialises requests to one host and spaces them apart.
///
/// A gate is created per host, never globally: two different origins must be
/// able to proceed at the same time, and a single global gate would quietly
/// turn politeness into a global throughput ceiling. The gate admits one
/// request at a time and starts each request no sooner than
/// `minimumDelaySeconds` after the previous one started.
public actor HostRequestGate {
    public let host: String

    private let clock: any PolitenessClock
    private var minimumDelaySeconds: Double
    private var busy = false
    private var waiting: [CheckedContinuation<Void, Never>] = []
    private var nextEarliestStart: Double?

    public init(host: String, clock: any PolitenessClock, minimumDelaySeconds: Double = 0) {
        self.host = host
        self.clock = clock
        self.minimumDelaySeconds = max(0, minimumDelaySeconds)
    }

    /// The current minimum spacing. A `crawl-delay` from robots.txt is applied
    /// here through `RobotsPolicy.applyCrawlDelay(to:)`.
    public var minimumDelay: Double { minimumDelaySeconds }

    public func setMinimumDelay(seconds: Double) {
        minimumDelaySeconds = max(0, seconds)
    }

    /// Runs `body` as this host's only in-flight request.
    ///
    /// The body is never run concurrently with another body on the same gate,
    /// and it is not started until the spacing requirement is satisfied, so the
    /// caller cannot forget either rule. Cancellation of the wait, of the delay,
    /// or of the body releases the gate rather than leaking the slot.
    public func perform<T: Sendable>(_ body: @Sendable () async throws -> T) async throws -> T {
        await acquireTurn()
        do {
            let value = try await runPolitely(body)
            releaseTurn()
            return value
        } catch {
            releaseTurn()
            throw error
        }
    }

    private func runPolitely<T: Sendable>(_ body: @Sendable () async throws -> T) async throws -> T {
        let start = await clock.now()
        if let earliest = nextEarliestStart, earliest > start {
            try await clock.sleep(seconds: earliest - start)
        }
        // The spacing is measured between request starts, which is what an
        // origin observes; measuring between completions would let a slow
        // response shorten the gap the next request leaves.
        nextEarliestStart = await clock.now() + minimumDelaySeconds
        return try await body()
    }

    private func acquireTurn() async {
        while busy {
            await withCheckedContinuation { waiting.append($0) }
        }
        busy = true
    }

    private func releaseTurn() {
        busy = false
        if !waiting.isEmpty {
            waiting.removeFirst().resume()
        }
    }
}

/// Hands out one gate per host so that independent call sites share a host's
/// politeness state instead of each keeping a private copy.
public actor HostRequestGates {
    private let clock: any PolitenessClock
    private let defaultMinimumDelaySeconds: Double
    private var gates: [String: HostRequestGate] = [:]

    public init(
        clock: any PolitenessClock = SystemPolitenessClock(),
        defaultMinimumDelaySeconds: Double = 1
    ) {
        self.clock = clock
        self.defaultMinimumDelaySeconds = max(0, defaultMinimumDelaySeconds)
    }

    public func gate(forHost host: String) -> HostRequestGate {
        let key = AcquisitionPolicy.normalizedHost(host)
        if let existing = gates[key] {
            return existing
        }
        let gate = HostRequestGate(
            host: key,
            clock: clock,
            minimumDelaySeconds: defaultMinimumDelaySeconds
        )
        gates[key] = gate
        return gate
    }

    public func gate(for url: URL) -> HostRequestGate {
        gate(forHost: url.host ?? "")
    }

    public var hostCount: Int { gates.count }
}

// MARK: - robots.txt model

/// One `Allow` or `Disallow` line, kept with its source line number so a
/// refusal can name the exact rule that caused it.
public struct RobotsRule: Equatable, Sendable {
    public let allow: Bool
    public let path: String
    public let line: Int

    public init(allow: Bool, path: String, line: Int) {
        self.allow = allow
        self.path = path
        self.line = line
    }

    public var directive: String {
        "\(allow ? "Allow" : "Disallow"): \(path) (line \(line))"
    }
}

/// One user-agent group: the agent tokens it applies to, its rules, and its
/// optional crawl delay.
public struct RobotsGroup: Equatable, Sendable {
    public let userAgents: [String]
    public let rules: [RobotsRule]
    public let crawlDelaySeconds: Double?

    public init(userAgents: [String], rules: [RobotsRule], crawlDelaySeconds: Double?) {
        self.userAgents = userAgents
        self.rules = rules
        self.crawlDelaySeconds = crawlDelaySeconds
    }
}

/// A parsed robots.txt. Parsing is total: unrecognised fields and malformed
/// lines are skipped rather than fatal, because a partly valid policy is still
/// a policy and refusing to read it would lose real restrictions.
public struct RobotsFile: Equatable, Sendable {
    public let groups: [RobotsGroup]
    public let sitemaps: [String]

    public init(groups: [RobotsGroup], sitemaps: [String]) {
        self.groups = groups
        self.sitemaps = sitemaps
    }

    public static let empty = RobotsFile(groups: [], sitemaps: [])
}

/// A body that could not be read as a robots.txt at all. It carries no rules
/// and no groups, so the caller must resolve it as a fallback rather than as
/// permission.
public struct RobotsParseFailure: Error, Equatable, LocalizedError, Sendable {
    public let reason: String

    public init(reason: String) {
        self.reason = reason
    }

    public var errorDescription: String? {
        "robots.txt could not be parsed: \(reason)"
    }
}

// MARK: - Parser

public enum RobotsParser {
    /// Decodes raw bytes. UTF-8 is required rather than guessed at: a policy
    /// read through the wrong encoding could silently change which paths are
    /// disallowed, so an undecodable body is reported as unparseable and the
    /// caller fails closed.
    public static func decode(_ body: Data) throws -> RobotsFile {
        guard let text = String(data: body, encoding: .utf8) else {
            throw RobotsParseFailure(reason: "body is not valid UTF-8")
        }
        let file = parse(text)
        if file.groups.isEmpty, file.sitemaps.isEmpty,
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw RobotsParseFailure(reason: "no robots directives found in a non-empty body")
        }
        return file
    }

    public static func parse(_ text: String) -> RobotsFile {
        var groups: [RobotsGroup] = []
        var sitemaps: [String] = []
        var agents: [String] = []
        var rules: [RobotsRule] = []
        var delay: Double?
        var started = false

        func flush() {
            guard started else { return }
            groups.append(RobotsGroup(userAgents: agents, rules: rules, crawlDelaySeconds: delay))
            agents = []
            rules = []
            delay = nil
            started = false
        }

        for (offset, rawLine) in text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated()
        {
            let lineNumber = offset + 1
            let withoutComment = rawLine.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
                .first
                .map(String.init) ?? ""
            let trimmed = withoutComment.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, let colon = trimmed.firstIndex(of: ":") else { continue }

            let field = trimmed[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            let value = trimmed[trimmed.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            guard !value.isEmpty else { continue }

            switch field {
            case "user-agent":
                // Consecutive user-agent lines share one group; a user-agent
                // line that follows rules or a delay starts a new one.
                if started, !rules.isEmpty || delay != nil {
                    flush()
                }
                started = true
                agents.append(value.lowercased())

            case "allow", "disallow":
                guard started else { continue }
                rules.append(RobotsRule(allow: field == "allow", path: value, line: lineNumber))

            case "crawl-delay":
                guard started, delay == nil, let seconds = Double(value), seconds >= 0 else { continue }
                delay = seconds

            case "sitemap":
                sitemaps.append(value)

            default:
                continue
            }
        }

        flush()
        return RobotsFile(groups: groups, sitemaps: sitemaps)
    }
}

// MARK: - Group selection and rule matching

extension RobotsFile {
    /// The product token a robots.txt user-agent value is compared against:
    /// the part of the crawler's own user agent before the version.
    static func productToken(_ userAgent: String) -> String {
        let token = userAgent
            .split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map(String.init) ?? userAgent
        return token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Selects the group that applies to `userAgent`.
    ///
    /// Matching is case-insensitive and a group's token must be a prefix of the
    /// crawler's product token. The most specific match wins, so a group naming
    /// the crawler overrides `*`; `*` is only used when nothing more specific
    /// matches. Ties keep the earliest group, so the result does not depend on
    /// dictionary ordering.
    public func group(for userAgent: String) -> RobotsGroup? {
        let token = Self.productToken(userAgent)
        var best: (group: RobotsGroup, specificity: Int)?

        for group in groups {
            for agent in group.userAgents {
                let value = agent.lowercased()
                let specificity: Int
                if value == "*" {
                    specificity = 0
                } else {
                    guard !token.isEmpty, token.hasPrefix(value) else { continue }
                    specificity = value.count
                }
                if best == nil || specificity > best!.specificity {
                    best = (group, specificity)
                }
            }
        }
        return best?.group
    }

    /// The rule that decides `path`, or `nil` when no rule matches.
    ///
    /// The longest matching pattern wins; on an equal-length tie `Allow` wins,
    /// so a narrow allowance can carve a hole in a broader disallow. Patterns
    /// support `*` (any run of characters) and a trailing `$` (end of path).
    static func longestMatch(in group: RobotsGroup, path: String) -> (rule: RobotsRule, length: Int)? {
        var best: (rule: RobotsRule, length: Int)?
        for rule in group.rules {
            guard let length = matchLength(pattern: rule.path, path: path) else { continue }
            guard let current = best else {
                best = (rule, length)
                continue
            }
            if length > current.length {
                best = (rule, length)
            } else if length == current.length, rule.allow, !current.rule.allow {
                best = (rule, length)
            }
        }
        return best
    }

    /// How many characters of `path` the pattern consumes, or `nil` if it does
    /// not match at all.
    static func matchLength(pattern: String, path: String) -> Int? {
        let anchored = pattern.hasSuffix("$")
        let body = anchored ? String(pattern.dropLast()) : pattern
        let parts = body.split(separator: "*", omittingEmptySubsequences: false).map(String.init)

        if parts.count == 1 {
            guard path.hasPrefix(parts[0]) else { return nil }
            guard !anchored || path.count == parts[0].count else { return nil }
            return parts[0].count
        }

        guard path.hasPrefix(parts[0]) else { return nil }
        var index = path.index(path.startIndex, offsetBy: parts[0].count)
        var consumed = parts[0].count

        for (offset, part) in parts.enumerated().dropFirst() where !part.isEmpty {
            guard let range = path.range(of: part, range: index..<path.endIndex) else { return nil }
            if anchored, offset == parts.count - 1, range.upperBound != path.endIndex { return nil }
            consumed = path.distance(from: path.startIndex, to: range.upperBound)
            index = range.upperBound
        }

        // A trailing `*` under `$` consumes the rest of the path.
        if anchored, parts.last?.isEmpty == true {
            return path.count
        }
        return consumed
    }
}

// MARK: - Outcomes and decisions

/// What the robots.txt fetch produced. Every case is reachable from the
/// acquisition boundary alone; none of them is a thrown error, because a
/// missing or broken robots.txt is an expected outcome rather than a failure of
/// the caller's request.
public enum RobotsOutcome: Equatable, Sendable {
    case rules(RobotsFile)
    /// HTTP 4xx: the origin published no policy, which states no restriction.
    case missing(statusCode: Int)
    /// HTTP 5xx: the policy exists but cannot be read right now.
    case serverError(statusCode: Int)
    /// No HTTP response at all (DNS, connection, TLS, timeout).
    case unreachable(reason: String)
    /// A response that is not a readable policy.
    case unparseable(reason: String)
    /// The acquisition policy refused the robots.txt URL, so it was never
    /// requested.
    case blocked(AcquisitionError)

    public var kind: String {
        switch self {
        case .rules: "rules"
        case .missing: "missing"
        case .serverError: "server_error"
        case .unreachable: "unreachable"
        case .unparseable: "unparseable"
        case .blocked: "blocked"
        }
    }

    public var isRules: Bool {
        if case .rules = self { return true }
        return false
    }
}

public enum RobotsDecision: Equatable, Sendable {
    case allowed(reason: String)
    case disallowed(reason: String)

    public var isAllowed: Bool {
        if case .allowed = self { return true }
        return false
    }

    /// Always non-empty, and for a published rule it names the exact rule.
    public var reason: String {
        switch self {
        case let .allowed(reason), let .disallowed(reason): reason
        }
    }
}

/// A refused request, carrying the matched rule or the fail-closed reason.
public struct RobotsRefusal: Error, Equatable, LocalizedError, Sendable {
    /// `published_rule` when the origin's own robots.txt forbade the path, and
    /// `fail_closed` when the policy could not be read and access was denied
    /// for that reason.
    public let kind: String
    public let host: String
    public let path: String
    public let reason: String

    public init(kind: String, host: String, path: String, reason: String) {
        self.kind = kind
        self.host = host
        self.path = path
        self.reason = reason
    }

    public var errorDescription: String? {
        "robots.txt refused \(host)\(path): \(reason)"
    }
}

// MARK: - Policy

/// The resolved robots.txt policy for one origin and one user agent.
///
/// The fallback table is the substance of this type, so it is stated once here
/// and asserted against frozen fixtures:
///
/// - parsed rules: the origin's own decision, longest match, `Allow` wins ties;
/// - HTTP 4xx: no policy published, so the origin states no restriction;
/// - HTTP 5xx, unreachable, unparseable, or refused by the acquisition policy:
///   **fail closed**, because an unreadable policy is not permission.
///
/// The last group is deliberately not "allow": treating a broken robots.txt as
/// permission would let a server that answers 503 to `/robots.txt` opt out of
/// every restriction it published.
public struct RobotsPolicy: Equatable, Sendable {
    public let origin: URL
    public let userAgent: String
    public let outcome: RobotsOutcome

    public init(origin: URL, userAgent: String, outcome: RobotsOutcome) {
        self.origin = origin
        self.userAgent = userAgent
        self.outcome = outcome
    }

    public var host: String {
        AcquisitionPolicy.normalizedHost(origin.host ?? "")
    }

    /// The `crawl-delay` of the selected group, when the policy parsed and a
    /// group matched.
    public var crawlDelaySeconds: Double? {
        guard case let .rules(file) = outcome else { return nil }
        return file.group(for: userAgent)?.crawlDelaySeconds
    }

    /// Applies a published `crawl-delay` to a host's gate. A policy without a
    /// delay leaves the gate's configured default in place.
    public func applyCrawlDelay(to gate: HostRequestGate) async {
        guard let delay = crawlDelaySeconds, delay > 0 else { return }
        await gate.setMinimumDelay(seconds: delay)
    }

    public func decision(for path: String) -> RobotsDecision {
        switch outcome {
        case let .rules(file):
            guard let group = file.group(for: userAgent) else {
                return .allowed(
                    reason: "no user-agent group matches \(RobotsFile.productToken(userAgent)); no rule applies to \(path)"
                )
            }
            guard let match = RobotsFile.longestMatch(in: group, path: path) else {
                return .allowed(reason: "no rule matches \(path); access is allowed by default")
            }
            if match.rule.allow {
                return .allowed(reason: "matched \(match.rule.directive)")
            }
            return .disallowed(reason: "matched \(match.rule.directive)")

        case let .missing(statusCode):
            return .allowed(
                reason: "no robots.txt published (HTTP \(statusCode)); the origin states no restriction"
            )

        case let .serverError(statusCode):
            return .disallowed(
                reason: "robots.txt unavailable (HTTP \(statusCode)); failing closed"
            )

        case let .unreachable(reason):
            return .disallowed(reason: "robots.txt unreachable (\(reason)); failing closed")

        case let .unparseable(reason):
            return .disallowed(reason: "robots.txt unparseable (\(reason)); failing closed")

        case let .blocked(error):
            return .disallowed(
                reason: "robots.txt refused by the acquisition policy (\(error.kind)); failing closed"
            )
        }
    }

    public func decision(for url: URL) -> RobotsDecision {
        decision(for: Self.requestPath(url))
    }

    /// Throws `RobotsRefusal` unless the path is allowed. This is the form a
    /// fetch path should use, because it cannot be ignored by accident.
    public func requireAccess(to url: URL) throws {
        switch decision(for: url) {
        case .allowed:
            return
        case let .disallowed(reason):
            throw RobotsRefusal(
                kind: outcome.isRules ? "published_rule" : "fail_closed",
                host: host,
                path: Self.requestPath(url),
                reason: reason
            )
        }
    }

    /// The path an origin matches rules against: the path, plus the query when
    /// one is present, because robots.txt patterns may match query strings.
    static func requestPath(_ url: URL) -> String {
        let path = url.path.isEmpty ? "/" : url.path
        guard let query = url.query, !query.isEmpty else { return path }
        return "\(path)?\(query)"
    }
}

// MARK: - Fetch and cache

/// Reads robots.txt through the existing acquisition boundary.
///
/// It opens no socket of its own: the request travels through the injected
/// `SearchTransport` and is checked by `AcquisitionPolicy` first, so a robots
/// URL the policy refuses is reported as `.blocked` instead of being fetched
/// anyway. The gate is deliberately *not* applied here: politeness has to wrap
/// the robots check and the request that follows it as one unit, and a gate
/// taken inside this call would deadlock against a caller that already holds
/// the host's slot.
public enum RobotsLoader {
    public static func robotsURL(for origin: URL) -> URL? {
        guard
            let scheme = origin.scheme?.lowercased(),
            scheme == "http" || scheme == "https",
            let rawHost = origin.host,
            !rawHost.isEmpty
        else {
            return nil
        }
        var components = URLComponents()
        components.scheme = scheme
        components.host = AcquisitionPolicy.normalizedHost(rawHost)
        components.port = origin.port
        components.path = "/robots.txt"
        return components.url
    }

    /// Loads and resolves the policy. Only cancellation is thrown; every other
    /// failure is an outcome, because "robots.txt is broken" is a normal state
    /// that the caller must resolve rather than an error that aborts a run.
    public static func load(
        origin: URL,
        userAgent: String,
        transport: any SearchTransport,
        resolver: any HostResolver,
        policy: AcquisitionPolicy = .default,
        cache: RobotsCache? = nil
    ) async throws -> RobotsPolicy {
        if let cached = await cache?.cached(for: origin) {
            return cached
        }
        let outcome = try await outcome(
            origin: origin,
            transport: transport,
            resolver: resolver,
            policy: policy
        )
        let resolved = RobotsPolicy(origin: origin, userAgent: userAgent, outcome: outcome)
        await cache?.store(resolved, for: origin)
        return resolved
    }

    static func outcome(
        origin: URL,
        transport: any SearchTransport,
        resolver: any HostResolver,
        policy: AcquisitionPolicy
    ) async throws -> RobotsOutcome {
        guard let url = robotsURL(for: origin) else {
            return .blocked(
                AcquisitionError.invalidURL(
                    reason: "origin has no http or https robots.txt URL",
                    url: origin.absoluteString
                )
            )
        }

        let result: AcquisitionResult
        do {
            result = try await SafeAcquisition.fetch(
                url,
                transport: transport,
                resolver: resolver,
                policy: policy
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as AcquisitionError {
            switch error {
            case let .httpStatus(code, _) where (400..<500).contains(code):
                // No policy published: the origin states no restriction.
                return .missing(statusCode: code)
            case let .httpStatus(code, _) where (500..<600).contains(code):
                return .serverError(statusCode: code)
            case let .httpStatus(code, _):
                return .unreachable(reason: "unexpected HTTP status \(code)")
            case let .transportFailure(reason):
                return .unreachable(reason: reason)
            case .timeout:
                return .unreachable(reason: "the request timed out")
            default:
                // A destination, scheme, port, media-type, size, or redirect
                // refusal: the policy stopped the request before it was made.
                return .blocked(error)
            }
        } catch {
            return .unreachable(reason: String(describing: error))
        }

        do {
            return .rules(try RobotsParser.decode(result.body))
        } catch let failure as RobotsParseFailure {
            return .unparseable(reason: failure.reason)
        }
    }
}

/// One resolved policy per origin.
///
/// The user agent is not part of the key because it selects a group inside the
/// file, not the file itself. Entries are never expired: a process-lifetime
/// cache is the conservative choice for a single run, and time-based
/// revalidation is a later concern rather than something to guess at now.
public actor RobotsCache {
    private var entries: [String: RobotsPolicy] = [:]

    public init() {}

    public func cached(for origin: URL) -> RobotsPolicy? {
        entries[Self.key(origin)]
    }

    public func store(_ policy: RobotsPolicy, for origin: URL) {
        entries[Self.key(origin)] = policy
    }

    public func forget(_ origin: URL) {
        entries[Self.key(origin)] = nil
    }

    public var count: Int { entries.count }

    static func key(_ origin: URL) -> String {
        let scheme = (origin.scheme ?? "").lowercased()
        let host = AcquisitionPolicy.normalizedHost(origin.host ?? "")
        let port = origin.port ?? AcquisitionPolicy.defaultPort(for: scheme)
        return "\(scheme)://\(host):\(port.map(String.init) ?? "-")"
    }
}
