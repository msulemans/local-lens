import Foundation

// MARK: - Request

/// One document a batch wants, named by the source identity it will be stored
/// under.
///
/// The source identity travels with the request rather than being derived from
/// the URL because a source is an attribution decision, not a property of a
/// string: two URLs can describe one source and one URL can be reached under
/// two names.
public struct FetchTarget: Equatable, Sendable {
    public let sourceID: String
    public let url: URL

    public init(sourceID: String, url: URL) {
        self.sourceID = sourceID
        self.url = url
    }
}

// MARK: - Limits

/// The shape of a fetch schedule.
///
/// Every ceiling is stated here so that politeness is a property of the
/// schedule rather than a habit of the caller. `maxInFlightPerHost` defaults to
/// one because an origin observes one connection per polite client, while
/// `maxInFlight` is what makes a batch finish sooner than a serial walk.
public struct FetchLimits: Equatable, Sendable {
    /// How many fetches may be in flight across the whole batch.
    public let maxInFlight: Int
    /// How many fetches of one host may hold a slot in the batch-wide ceiling.
    ///
    /// This cannot raise the number of requests an origin sees at once: the
    /// host gate admits exactly one visit per host, so a value above one is
    /// accepted but has no politeness effect. What it does govern is queueing —
    /// with a value of one, targets sharing a host cannot occupy the whole
    /// batch budget while they wait their turn, which would starve the other
    /// hosts in the batch.
    public let maxInFlightPerHost: Int
    /// The floor on the spacing between two requests to the same host. A
    /// published `crawl-delay` can only raise it.
    public let minimumHostDelaySeconds: Double
    /// How many times one target may be attempted before its last refusal is
    /// reported. Retries are visible in the result, never silent.
    public let attemptsPerTarget: Int

    /// The shipped schedule. Built through the unchecked initializer because a
    /// static constant cannot throw; the values are the ones the checked
    /// initializer accepts by default.
    public static let `default` = FetchLimits(
        uncheckedInFlight: 4,
        perHost: 1,
        delay: 1,
        attempts: 2
    )

    public init(
        maxInFlight: Int,
        maxInFlightPerHost: Int = 1,
        minimumHostDelaySeconds: Double = 1,
        attemptsPerTarget: Int = 1
    ) throws {
        guard maxInFlight >= 1 else {
            throw FetchScheduleError.invalidLimits(reason: "maxInFlight must be at least 1")
        }
        guard maxInFlightPerHost >= 1 else {
            throw FetchScheduleError.invalidLimits(reason: "maxInFlightPerHost must be at least 1")
        }
        guard minimumHostDelaySeconds >= 0 else {
            throw FetchScheduleError.invalidLimits(reason: "minimumHostDelaySeconds cannot be negative")
        }
        guard attemptsPerTarget >= 1 else {
            throw FetchScheduleError.invalidLimits(reason: "attemptsPerTarget must be at least 1")
        }
        self.maxInFlight = maxInFlight
        self.maxInFlightPerHost = maxInFlightPerHost
        self.minimumHostDelaySeconds = minimumHostDelaySeconds
        self.attemptsPerTarget = attemptsPerTarget
    }

    private init(uncheckedInFlight: Int, perHost: Int, delay: Double, attempts: Int) {
        self.maxInFlight = uncheckedInFlight
        self.maxInFlightPerHost = perHost
        self.minimumHostDelaySeconds = delay
        self.attemptsPerTarget = attempts
    }
}

/// A schedule that cannot be executed.
///
/// This is raised while building the schedule, so it never appears as a
/// per-URL outcome: a batch with impossible limits would otherwise look like a
/// batch in which every source failed.
public enum FetchScheduleError: Error, Equatable, LocalizedError, Sendable {
    case invalidLimits(reason: String)

    public var kind: String { "invalid_limits" }

    public var reason: String {
        switch self {
        case let .invalidLimits(reason): reason
        }
    }

    public var errorDescription: String? { "Invalid fetch schedule: \(reason)." }
}

// MARK: - Outcomes

/// Which boundary refused a fetch.
///
/// The stage is part of the outcome because "the address policy said no" and
/// "the origin's robots.txt said no" are different facts about a run, and only
/// one of them is about the document.
public enum FetchStage: String, Equatable, Sendable {
    case acquisition
    case robots
    case extraction
    case store
}

/// A refused fetch, flattened to the two strings every refusal family already
/// carries so that one batch result can report four different boundaries
/// without the caller having to switch over four error types.
public struct FetchRefusal: Error, Equatable, LocalizedError, Sendable {
    public let stage: FetchStage
    public let kind: String
    public let reason: String

    public init(stage: FetchStage, kind: String, reason: String) {
        self.stage = stage
        self.kind = kind
        self.reason = reason
    }

    /// Whether another attempt could plausibly succeed.
    ///
    /// Only transient transport faults are retried. A status code, a refused
    /// address, a robots rule, and an unreadable document are all answers from
    /// the origin or decisions of the policy, and asking again would only
    /// repeat them.
    public var isRetryable: Bool {
        stage == .acquisition && (kind == "timeout" || kind == "transport_failure")
    }

    public var errorDescription: String? {
        "\(stage.rawValue) refused the fetch: \(reason)"
    }
}

/// What one target produced.
public enum FetchOutcome: Equatable, Sendable {
    /// The bytes were new evidence.
    case stored(SnapshotRecord)
    /// The bytes were already stored, so this offer added no snapshot.
    case duplicate(SnapshotRecord, reason: DuplicateReason)
    /// A boundary refused the fetch.
    case refused(FetchRefusal)

    public var kind: String {
        switch self {
        case .stored: "stored"
        case .duplicate: "duplicate"
        case .refused: "refused"
        }
    }

    public var record: SnapshotRecord? {
        switch self {
        case let .stored(record), let .duplicate(record, _): record
        case .refused: nil
        }
    }

    public var refusal: FetchRefusal? {
        if case let .refused(refusal) = self { return refusal }
        return nil
    }

    public var isStored: Bool {
        if case .stored = self { return true }
        return false
    }

    public var isDuplicate: Bool {
        if case .duplicate = self { return true }
        return false
    }

    public var isRefused: Bool {
        if case .refused = self { return true }
        return false
    }
}

/// One target's result, including how much of the attempt budget it consumed.
///
/// `attempts` is recorded rather than hidden so that a retry is visible in the
/// run's own description: a source that needed three attempts is a fact about
/// the origin, not an implementation detail.
public struct FetchResult: Equatable, Sendable {
    public let sourceID: String
    public let url: URL
    public let outcome: FetchOutcome
    /// The 1-based attempt that produced `outcome`.
    public let attempt: Int
    /// How many attempts were made, including the one that produced `outcome`.
    public let attempts: Int

    public init(sourceID: String, url: URL, outcome: FetchOutcome, attempt: Int, attempts: Int) {
        self.sourceID = sourceID
        self.url = url
        self.outcome = outcome
        self.attempt = attempt
        self.attempts = attempts
    }

    public var kind: String { outcome.kind }

    /// Whether the last attempt was a retry of an earlier one.
    public var wasRetried: Bool { attempts > 1 }
}

// MARK: - Schedule

/// Fetches a set of targets concurrently under a bounded, per-host polite
/// schedule.
///
/// The scheduler owns no socket and no clock of its own: the transport, the
/// resolver, the politeness clock, and the store are all injected, so a batch
/// can be run end to end in a test without a network. Only cancellation is
/// thrown; every other outcome is a value, because "one source failed" is a
/// normal result of a research run rather than a fault that should discard the
/// sources that succeeded.
public struct BoundedFetcher: Sendable {
    private let transport: any SearchTransport
    private let resolver: any HostResolver
    private let policy: AcquisitionPolicy
    private let limits: FetchLimits
    private let userAgent: String
    private let gates: HostRequestGates
    private let robotsCache: RobotsCache
    private let store: SnapshotStore
    private let limiter: FetchLimiter

    public init(
        transport: any SearchTransport,
        resolver: any HostResolver,
        userAgent: String,
        policy: AcquisitionPolicy = .default,
        limits: FetchLimits = .default,
        gates: HostRequestGates = HostRequestGates(),
        robotsCache: RobotsCache = RobotsCache(),
        store: SnapshotStore = SnapshotStore()
    ) {
        self.transport = transport
        self.resolver = resolver
        self.userAgent = userAgent
        self.policy = policy
        self.limits = limits
        self.gates = gates
        self.robotsCache = robotsCache
        self.store = store
        self.limiter = FetchLimiter(
            maxInFlight: limits.maxInFlight,
            maxInFlightPerHost: limits.maxInFlightPerHost
        )
    }

    /// The store the batch fed. Exposed so a caller can cite what a run stored
    /// without the scheduler having to hand back the whole store.
    public var snapshotStore: SnapshotStore { store }

    /// Fetches every target and returns one result per target, in the order the
    /// targets were given.
    ///
    /// The returned order is the caller's order, never the completion order, so
    /// two runs over the same targets describe themselves identically even when
    /// their responses arrive in a different sequence.
    public func fetch(_ targets: [FetchTarget]) async throws -> [FetchResult] {
        guard !targets.isEmpty else { return [] }

        var collected: [(index: Int, result: FetchResult)] = []
        try await withThrowingTaskGroup(of: (Int, FetchResult).self) { group in
            for (index, target) in targets.enumerated() {
                group.addTask { (index, try await self.run(target)) }
            }
            for try await completed in group {
                collected.append(completed)
            }
        }
        return collected.sorted { $0.index < $1.index }.map(\.result)
    }

    // MARK: One target

    private func run(_ target: FetchTarget) async throws -> FetchResult {
        let host = Self.hostKey(of: target.url)
        let gate = await gates.gate(forHost: host)

        var attempt = 1
        while true {
            await limiter.acquire(host: host)
            let outcome: FetchOutcome
            do {
                outcome = try await attemptOnce(target, host: host, gate: gate, attempt: attempt)
            } catch {
                await limiter.release(host: host)
                throw error
            }
            await limiter.release(host: host)

            if
                let refusal = outcome.refusal,
                refusal.isRetryable,
                attempt < limits.attemptsPerTarget
            {
                attempt += 1
                continue
            }
            return FetchResult(
                sourceID: target.sourceID,
                url: target.url,
                outcome: outcome,
                attempt: attempt,
                attempts: attempt
            )
        }
    }

    /// One attempt: the host's turn, then robots, then the request, then
    /// extraction, then the store.
    ///
    /// The robots check and the request that follows it happen inside one turn
    /// of the host gate, because politeness has to wrap both as a single visit
    /// to the origin; a gate taken separately around each would let two
    /// requests leave back to back.
    private func attemptOnce(
        _ target: FetchTarget,
        host: String,
        gate: HostRequestGate,
        attempt: Int
    ) async throws -> FetchOutcome {
        let transport = self.transport
        let resolver = self.resolver
        let policy = self.policy
        let userAgent = self.userAgent
        let robotsCache = self.robotsCache
        let store = self.store

        return try await gate.perform {
            guard let origin = Self.origin(of: target.url) else {
                return .refused(
                    FetchRefusal(
                        stage: .acquisition,
                        kind: "invalid_url",
                        reason: "\(target.url.absoluteString) has no origin to fetch"
                    )
                )
            }

            let robots: RobotsPolicy
            do {
                robots = try await RobotsLoader.load(
                    origin: origin,
                    userAgent: userAgent,
                    transport: transport,
                    resolver: resolver,
                    policy: policy,
                    cache: robotsCache
                )
            } catch is CancellationError {
                throw CancellationError()
            }

            // A published crawl-delay can only raise the gate's spacing; the
            // schedule's floor stays in place.
            await robots.applyCrawlDelay(to: gate)

            do {
                try robots.requireAccess(to: target.url)
            } catch let refusal as RobotsRefusal {
                return .refused(
                    FetchRefusal(stage: .robots, kind: refusal.kind, reason: refusal.reason)
                )
            }

            let acquired: AcquisitionResult
            do {
                acquired = try await SafeAcquisition.fetch(
                    target.url,
                    transport: transport,
                    resolver: resolver,
                    policy: policy
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as AcquisitionError {
                return .refused(
                    FetchRefusal(
                        stage: .acquisition,
                        kind: error.kind,
                        reason: error.errorDescription ?? error.kind
                    )
                )
            } catch {
                return .refused(
                    FetchRefusal(
                        stage: .acquisition,
                        kind: "transport_failure",
                        reason: String(describing: error)
                    )
                )
            }

            let page: ExtractedPage
            do {
                page = try DocumentExtraction.extract(acquired, sourceID: target.sourceID)
            } catch let error as ExtractionError {
                return .refused(
                    FetchRefusal(stage: .extraction, kind: error.kind, reason: error.reason)
                )
            } catch {
                return .refused(
                    FetchRefusal(
                        stage: .extraction,
                        kind: "malformed_markup",
                        reason: String(describing: error)
                    )
                )
            }

            do {
                switch try await store.store(page, attempt: attempt) {
                case let .stored(record):
                    return FetchOutcome.stored(record)
                case let .duplicate(record, reason):
                    return FetchOutcome.duplicate(record, reason: reason)
                }
            } catch let error as SnapshotStoreError {
                return .refused(
                    FetchRefusal(stage: .store, kind: error.kind, reason: error.reason)
                )
            }
        }
    }

    // MARK: Keys

    /// The key a host's politeness and concurrency are shared under: the
    /// lowercased host with a trailing root dot removed, so `Example.INVALID.`
    /// and `example.invalid` are one origin.
    static func hostKey(of url: URL) -> String {
        AcquisitionPolicy.normalizedHost(url.host ?? "")
    }

    /// The origin robots.txt is read from: scheme, host, and a non-default port.
    static func origin(of url: URL) -> URL? {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return nil
        }
        let host = AcquisitionPolicy.normalizedHost(url.host ?? "")
        guard !host.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        if let port = url.port, port != AcquisitionPolicy.defaultPort(for: scheme) {
            components.port = port
        }
        return components.url
    }
}

// MARK: - Concurrency bound

/// Admits at most `maxInFlight` fetches at once, and at most
/// `maxInFlightPerHost` of them against any one host.
///
/// The bound lives here rather than in the caller's loop because a bound the
/// caller applies is a bound the caller can forget. Waiters are resumed in the
/// order they arrived, so the schedule is not just bounded but fair.
actor FetchLimiter {
    private let maxInFlight: Int
    private let maxInFlightPerHost: Int
    private var inFlight = 0
    private var inFlightPerHost: [String: Int] = [:]
    private var waiting: [(host: String, continuation: CheckedContinuation<Void, Never>)] = []

    init(maxInFlight: Int, maxInFlightPerHost: Int) {
        self.maxInFlight = max(1, maxInFlight)
        self.maxInFlightPerHost = max(1, maxInFlightPerHost)
    }

    func acquire(host: String) async {
        if admit(host: host) { return }
        await withCheckedContinuation { continuation in
            waiting.append((host, continuation))
        }
    }

    func release(host: String) {
        inFlight -= 1
        let remaining = (inFlightPerHost[host] ?? 1) - 1
        if remaining <= 0 {
            inFlightPerHost[host] = nil
        } else {
            inFlightPerHost[host] = remaining
        }
        drain()
    }

    private func admit(host: String) -> Bool {
        guard inFlight < maxInFlight, (inFlightPerHost[host] ?? 0) < maxInFlightPerHost else {
            return false
        }
        inFlight += 1
        inFlightPerHost[host, default: 0] += 1
        return true
    }

    private func drain() {
        var index = 0
        while index < waiting.count {
            if admit(host: waiting[index].host) {
                let waiter = waiting.remove(at: index)
                waiter.continuation.resume()
            } else {
                index += 1
            }
        }
    }
}
