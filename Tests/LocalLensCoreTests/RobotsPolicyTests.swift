import Foundation
import XCTest
@testable import LocalLensCore

// MARK: - Frozen scenario fixture

/// The scenario table lives in `Fixtures/robots/robots-scenarios.json` so the
/// group-selection and fallback rules are reviewable as data rather than as
/// scattered assertions. It is hand-authored, synthetic, and contains no live
/// host, no captured robots.txt, and no measured response.
private struct RobotsFixture: Decodable, Sendable {
    struct Meta: Decodable, Sendable {
        let synthetic: Bool
        let license: String
        let note: String
        let shape: String
    }

    struct SelectionCase: Decodable, Sendable {
        let id: String
        let robots: String
        let expected_agents: [String]
        let expected_crawl_delay: Double?
        let expected_rule_count: Int
        let expected_sitemaps: [String]
        let why: String
    }

    struct DecisionCase: Decodable, Sendable {
        let id: String
        let robots: String
        let path: String
        let allowed: Bool
        let reason_contains: String
        let why: String
    }

    struct ParseFailureCase: Decodable, Sendable {
        let id: String
        let body: String?
        let body_base64: String?
        let expected_reason_contains: String
        let why: String
    }

    struct Response: Decodable, Sendable {
        let status: Int
        let headers: [String: String]
        let body: String
    }

    struct FetchScenario: Decodable, Sendable {
        let id: String
        let origin: String
        let resolved_addresses: [String: [String]]
        let responses: [Response]?
        let transport_error: String?
        let expected_outcome: String
        let expected_error_kind: String?
        let expected_requests: Int
        let decision_path: String
        let decision_allowed: Bool
        let reason_contains: String
        let why: String
    }

    let _fixture: Meta
    let user_agent: String
    let selection_cases: [SelectionCase]
    let decision_cases: [DecisionCase]
    let parse_failure_cases: [ParseFailureCase]
    let fetch_scenarios: [FetchScenario]
}

// MARK: - Stubs

/// The only resolver a test may use. An unlisted host throws instead of
/// answering, so a test that unexpectedly resolves something fails loudly
/// rather than silently reaching a name server.
private actor StubHostResolver: HostResolver {
    private let answers: [String: [String]]
    private(set) var asked: [String] = []

    init(answers: [String: [String]] = [:]) {
        self.answers = answers
    }

    func addresses(for host: String) async throws -> [String] {
        asked.append(host)
        guard let answer = answers[host] else {
            throw HostResolutionFailure(host: host, reason: "stub resolver has no answer for \(host)")
        }
        return answer
    }
}

/// The only HTTP implementation a test may use: a scripted list of responses.
private actor ScriptedSearchTransport: SearchTransport {
    private var pending: [RobotsFixture.Response]
    private let transportError: String?
    private(set) var requests: [SearchRequest] = []

    init(responses: [RobotsFixture.Response] = [], transportError: String? = nil) {
        self.pending = responses
        self.transportError = transportError
    }

    func send(_ request: SearchRequest) async throws -> SearchResponse {
        requests.append(request)
        if let transportError {
            switch transportError {
            case "timeout_urlerror":
                throw URLError(.timedOut)
            case "timeout_wrapped":
                throw TransportFailure("URLError timedOut (-1001)")
            case "cancellation":
                throw CancellationError()
            default:
                throw TransportFailure(transportError)
            }
        }
        guard !pending.isEmpty else {
            throw TransportFailure("scripted transport exhausted before the test expected a response")
        }
        let response = pending.removeFirst()
        return SearchResponse(
            statusCode: response.status,
            body: Data(response.body.utf8),
            headers: response.headers
        )
    }
}

/// The only clock a test may use. It never waits: `sleep` records the request
/// and advances a virtual reading, so a spacing rule is asserted exactly
/// instead of being timed.
private actor StubClock: PolitenessClock {
    private var current: Double
    private(set) var sleeps: [Double] = []

    init(start: Double = 1_000) {
        self.current = start
    }

    func now() async -> Double { current }

    func sleep(seconds: Double) async throws {
        sleeps.append(seconds)
        current += seconds
    }

    var recordedSleeps: [Double] { sleeps }
}

/// Counts overlapping bodies so a gate that admits two at once is caught.
private actor ConcurrencyProbe {
    private(set) var inFlight = 0
    private(set) var peak = 0
    private(set) var completed = 0

    func enter() {
        inFlight += 1
        peak = max(peak, inFlight)
    }

    func leave() {
        inFlight -= 1
        completed += 1
    }
}

/// Holds a gate's body open until the test releases it.
private actor Latch {
    private var opened = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if opened { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        opened = true
        let pending = waiters
        waiters = []
        for waiter in pending { waiter.resume() }
    }
}

// MARK: - Tests

final class RobotsPolicyTests: XCTestCase {

    private static let fixture: RobotsFixture = {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/robots/robots-scenarios.json")
        do {
            return try JSONDecoder().decode(RobotsFixture.self, from: Data(contentsOf: url))
        } catch {
            fatalError("the frozen robots scenario fixture must decode: \(error)")
        }
    }()

    private static let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private var userAgent: String { Self.fixture.user_agent }

    private func url(_ text: String, file: StaticString = #filePath, line: UInt = #line) throws -> URL {
        try XCTUnwrap(URL(string: text), "scenario URL must parse: \(text)", file: file, line: line)
    }

    private func policy(robots: String, origin: String = "https://example.com") throws -> RobotsPolicy {
        RobotsPolicy(
            origin: try url(origin),
            userAgent: userAgent,
            outcome: .rules(RobotsParser.parse(robots))
        )
    }

    // MARK: Fixture integrity

    func testFrozenFixtureIsSyntheticAndCannotReachTheInternet() {
        XCTAssertTrue(Self.fixture._fixture.synthetic)
        XCTAssertEqual(Self.fixture._fixture.license, "redistributable")
        XCTAssertFalse(Self.fixture.selection_cases.isEmpty)
        XCTAssertFalse(Self.fixture.decision_cases.isEmpty)
        XCTAssertFalse(Self.fixture.fetch_scenarios.isEmpty)

        // Every origin is a reserved documentation or internal-use name, or an
        // origin with no host at all (the non-HTTP case).
        let allowedNames = ["example.com", "example.invalid", "localhost"]
        let allowedSuffixes = [".invalid", ".test", ".example", ".internal", ".local", ".home.arpa"]
        var seenNames: [String] = []

        for scenario in Self.fixture.fetch_scenarios {
            let origin = URL(string: scenario.origin)
            XCTAssertNotNil(origin, "scenario origin must parse: \(scenario.origin)")
            guard let host = origin?.host, !host.isEmpty else { continue }
            seenNames.append(host)
            let allowed = allowedNames.contains(host) || allowedSuffixes.contains { host.hasSuffix($0) }
            XCTAssertTrue(allowed, "\(scenario.id) uses a non-reserved host name: \(host)")
        }
        XCTAssertFalse(seenNames.isEmpty, "the fixture must actually name an origin host")

        // The only address a permitted fixture name resolves to is the
        // documented example.com address, the same one the M002.2 acquisition
        // fixture uses. Nothing here resolves to a private or real destination.
        let permittedAnswers = ["93.184.216.34"]
        for scenario in Self.fixture.fetch_scenarios {
            for (_, answers) in scenario.resolved_addresses {
                for address in answers {
                    XCTAssertTrue(
                        permittedAnswers.contains(address),
                        "\(scenario.id) resolves to an unexpected address: \(address)"
                    )
                }
            }
        }
    }

    // MARK: Parsing and group selection

    func testUserAgentGroupSelectionMatchesTheFrozenCases() throws {
        for scenario in Self.fixture.selection_cases {
            let file = RobotsParser.parse(scenario.robots)
            let group = file.group(for: userAgent)
            XCTAssertNotNil(group, "\(scenario.id) must select a group")
            XCTAssertEqual(group?.userAgents, scenario.expected_agents, "\(scenario.id) selected the wrong group")
            XCTAssertEqual(group?.rules.count, scenario.expected_rule_count, "\(scenario.id) rule count")
            XCTAssertEqual(group?.crawlDelaySeconds, scenario.expected_crawl_delay, "\(scenario.id) crawl delay")
            XCTAssertEqual(file.sitemaps, scenario.expected_sitemaps, "\(scenario.id) sitemaps")
        }
    }

    func testGroupSelectionIsCaseInsensitiveAndPrefersTheMostSpecificToken() throws {
        let file = RobotsParser.parse(
            "User-agent: *\nDisallow: /\n\nUser-agent: LOCALLENSBOT\nDisallow: /private/\n"
        )
        let group = try XCTUnwrap(file.group(for: userAgent))
        XCTAssertEqual(group.userAgents, ["locallensbot"])
        XCTAssertEqual(group.rules.count, 1)
        // A crawler that matches nothing specific still falls back to `*`.
        let other = try XCTUnwrap(file.group(for: "OtherCrawler/2.0"))
        XCTAssertEqual(other.userAgents, ["*"])
        // An empty user agent cannot match a named group, only `*`.
        XCTAssertEqual(file.group(for: "")?.userAgents, ["*"])
    }

    func testAgentTokenIsTakenFromTheProductTokenOnly() {
        XCTAssertEqual(RobotsFile.productToken("LocalLensBot/1.0 (+https://locallens.invalid/bot)"), "locallensbot")
        XCTAssertEqual(RobotsFile.productToken("  LocalLensBot  "), "locallensbot")
        XCTAssertEqual(RobotsFile.productToken(""), "")
    }

    func testAnEmptyBodyIsAValidPolicyWithNoRules() throws {
        let file = try RobotsParser.decode(Data())
        XCTAssertEqual(file, RobotsFile.empty)
        let resolved = RobotsPolicy(origin: try url("https://example.com"), userAgent: userAgent, outcome: .rules(file))
        XCTAssertTrue(resolved.decision(for: "/anything").isAllowed)
    }

    // MARK: Decisions

    func testPathDecisionsMatchTheFrozenCases() throws {
        for scenario in Self.fixture.decision_cases {
            let resolved = try policy(robots: scenario.robots)
            let decision = resolved.decision(for: scenario.path)
            XCTAssertEqual(decision.isAllowed, scenario.allowed, "\(scenario.id): \(decision.reason)")
            XCTAssertTrue(
                decision.reason.contains(scenario.reason_contains),
                "\(scenario.id) reason must name the matched rule; got \"\(decision.reason)\""
            )
            // A refusal must also be thrown, so a caller cannot ignore it.
            if scenario.allowed {
                XCTAssertNoThrow(try resolved.requireAccess(to: try url("https://example.com\(scenario.path)")))
            } else {
                XCTAssertThrowsError(try resolved.requireAccess(to: try url("https://example.com\(scenario.path)"))) { error in
                    guard let refusal = error as? RobotsRefusal else {
                        return XCTFail("\(scenario.id) must throw a RobotsRefusal, got \(error)")
                    }
                    XCTAssertEqual(refusal.kind, "published_rule", "\(scenario.id) refusal kind")
                    XCTAssertTrue(refusal.reason.contains(scenario.reason_contains), "\(scenario.id) refusal reason")
                }
            }
        }
    }

    func testQueryStringIsMatchedAndCarriedIntoTheRefusal() throws {
        let resolved = try policy(robots: "User-agent: *\nDisallow: /*?\n")
        let refused = try url("https://example.com/search?q=coffee")
        XCTAssertThrowsError(try resolved.requireAccess(to: refused)) { error in
            guard let refusal = error as? RobotsRefusal else {
                return XCTFail("expected a RobotsRefusal, got \(error)")
            }
            XCTAssertEqual(refusal.path, "/search?q=coffee")
            XCTAssertEqual(refusal.host, "example.com")
        }
    }

    func testEveryRefusalNamesAHostAPathAndAReason() throws {
        let resolved = try policy(robots: "User-agent: *\nDisallow: /private/\n")
        do {
            try resolved.requireAccess(to: try url("https://example.com/private/x"))
            XCTFail("expected a refusal")
        } catch let refusal as RobotsRefusal {
            XCTAssertEqual(refusal.host, "example.com")
            XCTAssertEqual(refusal.path, "/private/x")
            XCTAssertEqual(refusal.kind, "published_rule")
            XCTAssertFalse(refusal.reason.isEmpty)
            XCTAssertEqual(
                refusal.errorDescription,
                "robots.txt refused example.com/private/x: \(refusal.reason)"
            )
        }
    }

    // MARK: Fallback table

    func testUnparseableBodiesAreReportedWithTheirReason() throws {
        for scenario in Self.fixture.parse_failure_cases {
            let body: Data
            if let base64 = scenario.body_base64 {
                body = try XCTUnwrap(Data(base64Encoded: base64), "\(scenario.id) must hold valid base64")
            } else {
                body = Data((scenario.body ?? "").utf8)
            }
            do {
                _ = try RobotsParser.decode(body)
                XCTFail("\(scenario.id) must not parse")
            } catch let failure as RobotsParseFailure {
                XCTAssertTrue(
                    failure.reason.contains(scenario.expected_reason_contains),
                    "\(scenario.id) reason was \"\(failure.reason)\""
                )
            }
        }
    }

    func testTheFallbackTableIsExplicitAndNeverSilentlyPermits() throws {
        let origin = try url("https://example.com")
        let failClosed: [RobotsOutcome] = [
            .serverError(statusCode: 503),
            .unreachable(reason: "connection refused"),
            .unparseable(reason: "body is not valid UTF-8"),
            .blocked(.unsupportedContentType(contentType: "application/octet-stream", url: origin)),
        ]
        for outcome in failClosed {
            let resolved = RobotsPolicy(origin: origin, userAgent: userAgent, outcome: outcome)
            let decision = resolved.decision(for: "/anything")
            XCTAssertFalse(decision.isAllowed, "\(outcome.kind) must fail closed")
            XCTAssertTrue(decision.reason.contains("failing closed"), "\(outcome.kind): \(decision.reason)")
            XCTAssertThrowsError(try resolved.requireAccess(to: origin)) { error in
                guard let refusal = error as? RobotsRefusal else {
                    return XCTFail("expected a RobotsRefusal, got \(error)")
                }
                XCTAssertEqual(refusal.kind, "fail_closed", "\(outcome.kind) refusal kind")
            }
        }

        // The one non-fail-closed outcome: an absent policy states nothing.
        let missing = RobotsPolicy(origin: origin, userAgent: userAgent, outcome: .missing(statusCode: 404))
        let decision = missing.decision(for: "/anything")
        XCTAssertTrue(decision.isAllowed)
        XCTAssertTrue(decision.reason.contains("no robots.txt published"), decision.reason)
        XCTAssertEqual(missing.crawlDelaySeconds, nil)
        XCTAssertEqual(missing.host, "example.com")
    }

    // MARK: Loading through the acquisition boundary

    func testFetchScenariosMatchTheFrozenCases() async throws {
        for scenario in Self.fixture.fetch_scenarios {
            let transport = ScriptedSearchTransport(
                responses: scenario.responses ?? [],
                transportError: scenario.transport_error
            )
            let resolver = StubHostResolver(answers: scenario.resolved_addresses)
            let resolved = try await RobotsLoader.load(
                origin: try url(scenario.origin),
                userAgent: userAgent,
                transport: transport,
                resolver: resolver
            )

            XCTAssertEqual(resolved.outcome.kind, scenario.expected_outcome, "\(scenario.id) outcome")
            let requests = await transport.requests
            XCTAssertEqual(requests.count, scenario.expected_requests, "\(scenario.id) request count")
            if let expected = scenario.expected_error_kind {
                guard case let .blocked(error) = resolved.outcome else {
                    XCTFail("\(scenario.id) must report a blocked outcome, got \(resolved.outcome.kind)")
                    continue
                }
                XCTAssertEqual(error.kind, expected, "\(scenario.id) blocked error kind")
            }

            let decision = resolved.decision(for: scenario.decision_path)
            XCTAssertEqual(decision.isAllowed, scenario.decision_allowed, "\(scenario.id): \(decision.reason)")
            XCTAssertTrue(
                decision.reason.contains(scenario.reason_contains),
                "\(scenario.id) reason was \"\(decision.reason)\""
            )
        }
    }

    func testRobotsIsFetchedThroughTheInjectedTransportAndOnlyOncePerOrigin() async throws {
        let transport = ScriptedSearchTransport(responses: [
            .init(status: 200, headers: ["Content-Type": "text/plain"], body: "User-agent: *\nDisallow: /private/\n")
        ])
        let resolver = StubHostResolver(answers: ["example.com": ["93.184.216.34"]])
        let cache = RobotsCache()
        let origin = try url("https://example.com")

        let first = try await RobotsLoader.load(
            origin: origin, userAgent: userAgent, transport: transport, resolver: resolver, cache: cache
        )
        // A second load for the same origin, and a different user agent, must
        // reuse the cached file rather than re-requesting it.
        let second = try await RobotsLoader.load(
            origin: origin, userAgent: "OtherCrawler/2.0", transport: transport, resolver: resolver, cache: cache
        )
        XCTAssertEqual(first.outcome, second.outcome)
        let cacheCount = await cache.count
        XCTAssertEqual(cacheCount, 1)

        let requests = await transport.requests
        XCTAssertEqual(requests.count, 1, "robots.txt must be requested once per origin")
        XCTAssertEqual(requests.first?.url.absoluteString, "https://example.com/robots.txt")
        XCTAssertEqual(requests.first?.method, "GET")
        XCTAssertEqual(requests.first?.headers["Accept"]?.contains("text/plain"), true)

        await cache.forget(origin)
        _ = try await RobotsLoader.load(
            origin: origin, userAgent: userAgent, transport: transport, resolver: resolver, cache: cache
        )
        let afterForget = await transport.requests
        XCTAssertEqual(afterForget.count, 2, "forgetting an entry must make the next load re-request it")
    }

    func testCachedOutcomesAreReusedWithoutTouchingTheTransport() async throws {
        let transport = ScriptedSearchTransport(
            responses: [.init(status: 404, headers: ["Content-Type": "text/plain"], body: "Not Found")]
        )
        let resolver = StubHostResolver(answers: ["example.com": ["93.184.216.34"]])
        let cache = RobotsCache()
        let origin = try url("https://example.com")

        _ = try await RobotsLoader.load(
            origin: origin, userAgent: userAgent, transport: transport, resolver: resolver, cache: cache
        )
        let second = try await RobotsLoader.load(
            origin: origin, userAgent: userAgent, transport: transport, resolver: resolver, cache: cache
        )
        XCTAssertEqual(second.outcome, .missing(statusCode: 404))
        let requestCount = await transport.requests.count
        XCTAssertEqual(requestCount, 1)
    }

    func testCancellationDuringTheRobotsFetchIsNotConvertedIntoAnOutcome() async throws {
        let transport = ScriptedSearchTransport(transportError: "cancellation")
        let resolver = StubHostResolver(answers: ["example.com": ["93.184.216.34"]])
        do {
            _ = try await RobotsLoader.load(
                origin: try url("https://example.com"),
                userAgent: userAgent,
                transport: transport,
                resolver: resolver
            )
            XCTFail("cancellation must propagate")
        } catch is CancellationError {
            // Expected: the run state machine owns the terminal transition.
        }
    }

    func testRobotsURLIsBuiltPerOriginAndKeepsAnExplicitPort() throws {
        XCTAssertEqual(
            RobotsLoader.robotsURL(for: try url("https://example.com/deep/path?q=1"))?.absoluteString,
            "https://example.com/robots.txt"
        )
        XCTAssertEqual(
            RobotsLoader.robotsURL(for: try url("http://example.com:8080/a"))?.absoluteString,
            "http://example.com:8080/robots.txt"
        )
        XCTAssertEqual(
            RobotsLoader.robotsURL(for: try url("https://EXAMPLE.com."))?.absoluteString,
            "https://example.com/robots.txt"
        )
        XCTAssertNil(RobotsLoader.robotsURL(for: try url("file:///tmp/example")))
    }

    func testCacheKeyIgnoresTheUserAgentAndSeparatesPorts() throws {
        let a = RobotsCache.key(try url("https://example.com"))
        let b = RobotsCache.key(try url("https://example.com/robots.txt"))
        let c = RobotsCache.key(try url("https://example.com:8443"))
        let d = RobotsCache.key(try url("http://example.com"))
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
        XCTAssertNotEqual(a, d)
    }

    // MARK: Politeness gate

    func testMinimumDelayIsEnforcedAgainstTheInjectedClock() async throws {
        let clock = StubClock()
        let gate = HostRequestGate(host: "example.com", clock: clock, minimumDelaySeconds: 2)

        var order: [Int] = []
        for index in 0..<3 {
            order.append(try await gate.perform { index })
        }

        XCTAssertEqual(order, [0, 1, 2])
        let sleeps = await clock.recordedSleeps
        XCTAssertEqual(sleeps, [2, 2], "one wait before every request after the first")
        let delay = await gate.minimumDelay
        XCTAssertEqual(delay, 2)
        let gateHost = await gate.host
        XCTAssertEqual(gateHost, "example.com")
    }

    func testZeroDelayNeverWaitsAndABodyFailureStillReleasesTheGate() async throws {
        let clock = StubClock()
        let gate = HostRequestGate(host: "example.com", clock: clock, minimumDelaySeconds: 0)
        _ = try await gate.perform { 1 }

        struct BodyFailure: Error {}
        do {
            _ = try await gate.perform { throw BodyFailure() }
            XCTFail("the body's error must propagate")
        } catch is BodyFailure {
            // Expected.
        }

        // The gate is usable again, so the failed body released its turn.
        let value = try await gate.perform { 3 }
        XCTAssertEqual(value, 3)
        let sleeps = await clock.recordedSleeps
        XCTAssertTrue(sleeps.isEmpty, "a zero delay must never wait")
    }

    func testOnlyOneRequestPerHostIsEverInFlight() async throws {
        let clock = StubClock()
        let gate = HostRequestGate(host: "example.com", clock: clock, minimumDelaySeconds: 1)
        let probe = ConcurrencyProbe()
        let latch = Latch()

        let held = Task {
            try await gate.perform {
                await probe.enter()
                await latch.wait()
                await probe.leave()
            }
        }
        let entered = await waitUntil { await probe.inFlight == 1 }
        XCTAssertTrue(entered, "the first request must enter its body")

        let queued = (0..<3).map { _ in
            Task {
                try await gate.perform {
                    await probe.enter()
                    await probe.leave()
                }
            }
        }
        // Give the queued requests every chance to overlap if they wrongly could.
        for _ in 0..<200 { await Task.yield() }
        let overlapping = await probe.inFlight
        let peakWhileHeld = await probe.peak
        XCTAssertEqual(overlapping, 1, "a queued request must not start while the host is busy")
        XCTAssertEqual(peakWhileHeld, 1)
        let completedWhileHeld = await probe.completed
        XCTAssertEqual(completedWhileHeld, 0)

        await latch.open()
        for task in [held] + queued {
            try await task.value
        }
        let peak = await probe.peak
        let completed = await probe.completed
        XCTAssertEqual(peak, 1, "two bodies must never overlap on one host")
        XCTAssertEqual(completed, 4)
        let sleeps = await clock.recordedSleeps
        XCTAssertEqual(sleeps, [1, 1, 1])
    }

    func testGatesAreIndependentPerHost() async throws {
        let clock = StubClock()
        let gates = HostRequestGates(clock: clock, defaultMinimumDelaySeconds: 1)
        let first = await gates.gate(forHost: "a.example.com")
        let second = await gates.gate(forHost: "b.example.com")
        let again = await gates.gate(forHost: "A.EXAMPLE.COM.")

        XCTAssertTrue(first === again, "the same host must resolve to the same gate")
        XCTAssertFalse(first === second, "different hosts must not share a gate")
        let count = await gates.hostCount
        XCTAssertEqual(count, 2)
        let byURL = await gates.gate(for: try url("https://a.example.com/x"))
        XCTAssertTrue(byURL === first)

        // While one host is held, another host's request must still complete.
        let probe = ConcurrencyProbe()
        let latch = Latch()
        let held = Task {
            try await first.perform {
                await probe.enter()
                await latch.wait()
                await probe.leave()
            }
        }
        let entered = await waitUntil { await probe.inFlight == 1 }
        XCTAssertTrue(entered)

        try await second.perform {
            await probe.enter()
            await probe.leave()
        }
        let completedWhileHeld = await probe.completed
        let stillHeld = await probe.inFlight
        XCTAssertEqual(completedWhileHeld, 1, "a second host must not be blocked by the first")
        XCTAssertEqual(stillHeld, 1, "the first host's request must still be held")

        await latch.open()
        try await held.value
        let peak = await probe.peak
        XCTAssertEqual(
            peak,
            2,
            "the peak spans two hosts: each host allows one request, and the hosts do not wait on each other"
        )
    }

    func testCrawlDelayFromRobotsIsAppliedToTheHostGate() async throws {
        let clock = StubClock()
        let gate = HostRequestGate(host: "example.com", clock: clock, minimumDelaySeconds: 0)
        let withDelay = try policy(robots: "User-agent: *\nCrawl-delay: 2.5\nDisallow: /x\n")
        XCTAssertEqual(withDelay.crawlDelaySeconds, 2.5)

        await withDelay.applyCrawlDelay(to: gate)
        let applied = await gate.minimumDelay
        XCTAssertEqual(applied, 2.5)

        _ = try await gate.perform { 1 }
        _ = try await gate.perform { 2 }
        let sleeps = await clock.recordedSleeps
        XCTAssertEqual(sleeps, [2.5])

        // A policy without a crawl-delay leaves the configured default alone.
        let withoutDelay = try policy(robots: "User-agent: *\nDisallow: /x\n")
        let configured = HostRequestGate(host: "example.com", clock: clock, minimumDelaySeconds: 3)
        await withoutDelay.applyCrawlDelay(to: configured)
        let unchanged = await configured.minimumDelay
        XCTAssertEqual(unchanged, 3)
        XCTAssertEqual(withoutDelay.crawlDelaySeconds, nil)
    }

    func testCrawlDelayIsIgnoredForOutcomesThatHaveNoRules() async throws {
        let origin = try url("https://example.com")
        for outcome: RobotsOutcome in [
            .missing(statusCode: 404),
            .serverError(statusCode: 503),
            .unreachable(reason: "connection refused"),
            .unparseable(reason: "no robots directives found in a non-empty body"),
            .blocked(.blockedPort(port: 9443, host: "example.com")),
        ] {
            let resolved = RobotsPolicy(origin: origin, userAgent: userAgent, outcome: outcome)
            XCTAssertEqual(resolved.crawlDelaySeconds, nil, "\(outcome.kind) must not invent a crawl delay")
        }
    }

    // MARK: Offline guards

    func testNoTestOrAppSourceCanReachTheNetworkTheSystemResolverOrARealClock() throws {
        // Built by concatenation so this guard does not match its own source.
        let forbidden = [
            "URL" + "Session",
            "System" + "HostResolver",
            "System" + "PolitenessClock",
            "getaddr" + "info",
            "Task" + ".sleep",
        ]
        let roots = ["Tests", "Sources/LocalLensApp"].map { Self.repositoryRoot.appendingPathComponent($0) }

        var scanned = 0
        for root in roots {
            guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
                continue
            }
            for case let file as URL in enumerator where file.pathExtension == "swift" {
                scanned += 1
                let source = try String(contentsOf: file, encoding: .utf8)
                for needle in forbidden {
                    XCTAssertFalse(
                        source.contains(needle),
                        "\(file.path) must not reference \(needle); tests use stubs only"
                    )
                }
            }
        }
        XCTAssertGreaterThan(scanned, 0, "the offline guard must actually scan test sources")
    }

    // MARK: Helpers

    /// Yields until `condition` holds. It never waits on the wall clock, so a
    /// gate that wrongly blocks still fails the test rather than hanging it.
    private func waitUntil(
        attempts: Int = 2_000,
        _ condition: @Sendable () async -> Bool
    ) async -> Bool {
        for _ in 0..<attempts {
            if await condition() { return true }
            await Task.yield()
        }
        return await condition()
    }
}
