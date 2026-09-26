import Foundation
import XCTest
@testable import LocalLensCore

// MARK: - Frozen scenario fixture

/// The schedule table lives in `Fixtures/fetch/schedule-scenarios.json` so that
/// the ceilings, the overlap each batch is expected to reach, and the typed
/// outcome of every target are reviewable as data rather than as scattered
/// assertions.
///
/// The table is hand-authored and synthetic. Every name is answered by a stub
/// resolver and every response comes from a stub transport, so no case resolves
/// a name, opens a socket, or reads a live page.
private struct ScheduleFixture: Decodable, Sendable {
    struct Meta: Decodable, Sendable {
        let synthetic: Bool
        let license: String
        let note: String
    }

    struct Limits: Decodable, Sendable {
        let max_in_flight: Int
        let max_in_flight_per_host: Int
        let minimum_host_delay_seconds: Double
        let attempts_per_target: Int
    }

    struct LimitsOverride: Decodable, Sendable {
        let max_in_flight: Int?
        let max_in_flight_per_host: Int?
        let minimum_host_delay_seconds: Double?
        let attempts_per_target: Int?
    }

    struct Target: Decodable, Sendable {
        let source_id: String
        let url: String
    }

    struct Response: Decodable, Sendable {
        let status: Int?
        let headers: [String: String]?
        let body: String?
        let transport_error: String?
        let yields_before_response: Int?
    }

    struct Expected: Decodable, Sendable {
        let source_id: String
        let url: String
        let kind: String
        let attempt: Int
        let attempts: Int
        let duplicate_reason: String?
        let refusal_stage: String?
        let refusal_kind: String?
    }

    struct Case: Decodable, Sendable {
        let id: String
        let why: String
        let limits_override: LimitsOverride?
        let targets: [Target]
        let robots: [String: Int]
        let robots_body: [String: String]?
        let documents: [String: [Response]]
        let expected: [Expected]
        let expected_snapshot_count: Int
        let expected_recorded_source_ids: [String]?
        let expected_recorded_urls: [String]?
        /// How many document requests this case must have had in flight at once
        /// for the case to be a test of anything. The stub transport holds
        /// requests until this many have arrived, so parallelism is measured
        /// rather than inferred from timing.
        let requires_overlap: Int
        let expected_peak_in_flight: Int
        let expected_peak_per_host: [String: Int]
        let expected_robots_requests: Int
        let expected_document_requests: Int?
        /// Set when two targets can offer the same bytes at the same time. The
        /// offer that stores the bytes is then decided by arrival order, so the
        /// per-target `stored`/`duplicate` label is not positional: the
        /// contract is the multiset of outcomes plus the stored record.
        let concurrent_offers_are_race_decided: Bool?
    }

    struct Refusal: Decodable, Sendable {
        let stage: String
        let kind: String
        let why: String
    }

    let _fixture: Meta
    let limits: Limits
    let resolver_answers: [String: [String]]
    let cases: [Case]
    let refusals: [Refusal]
}

private let fixture: ScheduleFixture = {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/fetch/schedule-scenarios.json")
    do {
        return try JSONDecoder().decode(ScheduleFixture.self, from: Data(contentsOf: url))
    } catch {
        fatalError("could not load Fixtures/fetch/schedule-scenarios.json: \(error)")
    }
}()

// MARK: - Stubs

/// The only resolver a test may use. An unlisted host throws instead of
/// answering, so a case that unexpectedly resolves a name fails loudly rather
/// than silently reaching a name server.
private actor StubHostResolver: HostResolver {
    private let answers: [String: [String]]
    private(set) var asked: [String] = []

    init(answers: [String: [String]]) {
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

/// The only HTTP implementation a test may use.
///
/// It is scripted per URL and it measures its own concurrency, because the
/// claim under test is about how many requests are in flight at once: a
/// schedule that merely *intends* to bound concurrency would still look correct
/// to an assertion about outcomes alone.
private actor ScriptedScheduleTransport: SearchTransport {
    private var remaining: [String: [ScheduleFixture.Response]]
    /// The authored length of each URL's script. A one-step script answers every
    /// request to that URL; a longer script is consumed one step per request so
    /// a retry can differ from the attempt before it, and its last step then
    /// repeats.
    private let scriptLengths: [String: Int]
    private let robotsStatus: [String: Int]
    private let robotsBody: [String: String]
    /// How many document requests must be in flight together for the case to be
    /// a test of parallelism. The transport holds a document request until this
    /// many have arrived, so overlap is forced rather than hoped for: a serial
    /// schedule cannot satisfy it and the case fails on a measured fact instead
    /// of on a timing coincidence.
    private let requiredOverlap: Int

    private var inFlight = 0
    private var inFlightPerHost: [String: Int] = [:]
    private var peakInFlight = 0
    private var peakPerHost: [String: Int] = [:]
    private var requests: [SearchRequest] = []

    private var documentsInFlight = 0
    private var overlapReached = false

    init(
        documents: [String: [ScheduleFixture.Response]],
        robotsStatus: [String: Int],
        robotsBody: [String: String],
        requiredOverlap: Int
    ) {
        self.remaining = documents
        self.scriptLengths = documents.mapValues(\.count)
        self.robotsStatus = robotsStatus
        self.robotsBody = robotsBody
        self.requiredOverlap = max(1, requiredOverlap)
    }

    func send(_ request: SearchRequest) async throws -> SearchResponse {
        requests.append(request)

        let host = (request.url.host ?? "").lowercased()
        inFlight += 1
        inFlightPerHost[host, default: 0] += 1
        peakInFlight = max(peakInFlight, inFlight)
        peakPerHost[host] = max(peakPerHost[host] ?? 0, inFlightPerHost[host] ?? 0)

        if request.url.path == "/robots.txt" {
            defer { leave(host: host) }
            return SearchResponse(
                statusCode: robotsStatus[host] ?? 404,
                body: Data((robotsBody[host] ?? "").utf8),
                headers: ["Content-Type": "text/plain"]
            )
        }

        documentsInFlight += 1
        await holdUntilOverlap()
        defer {
            documentsInFlight -= 1
            leave(host: host)
        }

        let key = request.url.absoluteString
        guard let script = remaining[key], !script.isEmpty else {
            throw TransportFailure("scripted transport has no response for \(key)")
        }
        let step = script[0]
        if scriptLengths[key, default: 1] > 1, script.count > 1 {
            remaining[key] = Array(script.dropFirst())
        }

        if let count = step.yields_before_response, count > 0 {
            for _ in 0..<count {
                await Task.yield()
            }
        }

        if let error = step.transport_error {
            switch error {
            case "timeout_urlerror":
                throw URLError(.timedOut)
            case "timeout_wrapped":
                throw TransportFailure("URLError timedOut (-1001)")
            default:
                throw TransportFailure(error)
            }
        }

        return SearchResponse(
            statusCode: step.status ?? 200,
            body: Data((step.body ?? "").utf8),
            headers: step.headers ?? [:]
        )
    }

    // MARK: Barrier

    /// Holds a document request until `requiredOverlap` of them are in flight.
    ///
    /// The wait is a bounded yield loop rather than a suspended continuation,
    /// so a schedule that turns out to be serial fails on a measurement instead
    /// of hanging the suite, and no wall clock is involved.
    private func holdUntilOverlap() async {
        guard requiredOverlap > 1 else { return }
        for _ in 0..<Self.overlapYieldBudget {
            if documentsInFlight >= requiredOverlap {
                overlapReached = true
                return
            }
            await Task.yield()
        }
        if documentsInFlight >= requiredOverlap {
            overlapReached = true
        }
    }

    private static let overlapYieldBudget = 10_000

    private func leave(host: String) {
        inFlight -= 1
        let remainingForHost = (inFlightPerHost[host] ?? 1) - 1
        if remainingForHost <= 0 {
            inFlightPerHost[host] = nil
        } else {
            inFlightPerHost[host] = remainingForHost
        }
    }

    // MARK: Observations

    func observedPeakInFlight() -> Int { peakInFlight }
    func observedPeakPerHost() -> [String: Int] { peakPerHost }
    func didReachRequiredOverlap() -> Bool { overlapReached }
    func robotsRequestCount() -> Int { requests.filter { $0.url.path == "/robots.txt" }.count }
    func documentRequestCount() -> Int { requests.filter { $0.url.path != "/robots.txt" }.count }
    func requestedHosts() -> [String] { requests.map { ($0.url.host ?? "").lowercased() } }
}

/// A clock that never waits, so politeness is exercised without real time.
private struct ImmediatePolitenessClock: PolitenessClock {
    func now() async -> Double { 0 }
    func sleep(seconds: Double) async throws {}
}

// MARK: - Harness

private struct BatchOutcome {
    let results: [FetchResult]
    let snapshotCount: Int
    /// The store's own records, read after the batch finished. A result's
    /// captured record is a copy of the store at the moment that result was
    /// produced, so a later duplicate that merges into the same record is only
    /// visible here.
    let storedRecords: [SnapshotRecord]
    let peakInFlight: Int
    let overlapReached: Bool
    let peakPerHost: [String: Int]
    let robotsRequests: Int
    let documentRequests: Int
    let requestedHosts: Set<String>

    var kinds: [String] { results.map(\.kind) }
}

/// Runs one frozen case through the scheduler and gathers everything the
/// assertions need, so no assertion has to `await` inside its own autoclosure.
private func runBatch(_ testCase: ScheduleFixture.Case) async throws -> BatchOutcome {
    let base = fixture.limits
    let override = testCase.limits_override
    let limits = try FetchLimits(
        maxInFlight: override?.max_in_flight ?? base.max_in_flight,
        maxInFlightPerHost: override?.max_in_flight_per_host ?? base.max_in_flight_per_host,
        minimumHostDelaySeconds: override?.minimum_host_delay_seconds ?? base.minimum_host_delay_seconds,
        attemptsPerTarget: override?.attempts_per_target ?? base.attempts_per_target
    )

    let transport = ScriptedScheduleTransport(
        documents: testCase.documents,
        robotsStatus: testCase.robots,
        robotsBody: testCase.robots_body ?? [:],
        requiredOverlap: testCase.requires_overlap
    )

    let fetcher = BoundedFetcher(
        transport: transport,
        resolver: StubHostResolver(answers: fixture.resolver_answers),
        userAgent: "LocalLensTest/1.0",
        limits: limits,
        gates: HostRequestGates(clock: ImmediatePolitenessClock(), defaultMinimumDelaySeconds: 0)
    )

    let targets = testCase.targets.map { FetchTarget(sourceID: $0.source_id, url: URL(string: $0.url)!) }
    let results = try await fetcher.fetch(targets)

    return BatchOutcome(
        results: results,
        snapshotCount: await fetcher.snapshotStore.snapshotCount(),
        storedRecords: await fetcher.snapshotStore.records(),
        peakInFlight: await transport.observedPeakInFlight(),
        overlapReached: await transport.didReachRequiredOverlap(),
        peakPerHost: await transport.observedPeakPerHost(),
        robotsRequests: await transport.robotsRequestCount(),
        documentRequests: await transport.documentRequestCount(),
        requestedHosts: Set(await transport.requestedHosts())
    )
}

// MARK: - Tests

final class BoundedFetchTests: XCTestCase {
    func testFixtureIsSyntheticOfflineAndExplained() {
        XCTAssertTrue(fixture._fixture.synthetic)
        XCTAssertEqual(fixture._fixture.license, "redistributable")
        XCTAssertFalse(fixture._fixture.note.isEmpty)
        XCTAssertGreaterThanOrEqual(fixture.cases.count, 8)
        for testCase in fixture.cases {
            XCTAssertFalse(testCase.why.isEmpty, "\(testCase.id) must say why it exists")
            XCTAssertEqual(
                testCase.expected.count,
                testCase.targets.count,
                "\(testCase.id) must state one outcome per target"
            )
            XCTAssertGreaterThanOrEqual(testCase.requires_overlap, 1)
            XCTAssertLessThanOrEqual(
                testCase.requires_overlap,
                testCase.expected_peak_in_flight,
                "\(testCase.id) must require no more overlap than it claims to observe"
            )
        }
        // Every host in the table is answered by the stub resolver, so no case
        // can depend on a name server.
        let hosts = Set(fixture.cases.flatMap { $0.targets.compactMap { URL(string: $0.url)?.host } })
        for host in hosts where host != "research.invalid" {
            XCTAssertNotNil(
                fixture.resolver_answers[host],
                "\(host) must have a stub answer or be a deliberately unfetchable name"
            )
        }
    }

    func testThreeHostsAreFetchedInParallel() async throws {
        let testCase = try XCTUnwrap(fixture.cases.first { $0.id == "three-hosts-are-fetched-in-parallel" })
        let outcome = try await runBatch(testCase)

        XCTAssertEqual(outcome.kinds, testCase.expected.map(\.kind))
        // More than one fetch in flight is what makes this a parallel schedule
        // rather than a serial walk, and the transport measured it by refusing
        // to answer until three hosts were being visited at once.
        XCTAssertTrue(outcome.overlapReached, "three hosts must be visited at once")
        XCTAssertGreaterThan(outcome.peakInFlight, 1, "a batch of independent hosts must overlap")
        XCTAssertEqual(outcome.peakInFlight, testCase.expected_peak_in_flight)
        XCTAssertEqual(outcome.snapshotCount, testCase.expected_snapshot_count)
    }

    func testOneHostIsSerialisedEvenWhenTheGlobalCeilingAllowsMore() async throws {
        let testCase = try XCTUnwrap(fixture.cases.first { $0.id == "one-host-is-serialised" })
        let outcome = try await runBatch(testCase)

        XCTAssertEqual(outcome.kinds, testCase.expected.map(\.kind))
        XCTAssertEqual(outcome.peakInFlight, 1, "three targets on one host must not overlap")
        XCTAssertEqual(outcome.peakPerHost["example.com"], 1)
    }

    func testALooserPerHostCeilingDoesNotLoosenPoliteness() async throws {
        let testCase = try XCTUnwrap(
            fixture.cases.first { $0.id == "a-looser-per-host-ceiling-does-not-loosen-politeness" }
        )
        let outcome = try await runBatch(testCase)

        XCTAssertEqual(outcome.kinds, testCase.expected.map(\.kind))
        XCTAssertEqual(outcome.peakPerHost, testCase.expected_peak_per_host)
        XCTAssertEqual(outcome.peakInFlight, testCase.expected_peak_in_flight)
        // The batch-wide ceiling is reached, but never by two visits to one
        // origin: the host gate is the binding constraint, not the number.
        XCTAssertEqual(outcome.peakInFlight, 2)
        XCTAssertEqual(Set(outcome.peakPerHost.values), [1])
    }

    func testNoCaseEverObservesTwoRequestsInFlightToOneHost() async throws {
        for testCase in fixture.cases {
            let outcome = try await runBatch(testCase)
            XCTAssertEqual(
                Set(outcome.peakPerHost.values),
                [1],
                "\(testCase.id): one origin must never see two requests at once"
            )
            XCTAssertEqual(
                outcome.peakInFlight,
                testCase.expected_peak_in_flight,
                "\(testCase.id): observed batch overlap"
            )
            XCTAssertEqual(
                outcome.peakPerHost,
                testCase.expected_peak_per_host,
                "\(testCase.id): observed per-host overlap"
            )
            let ceiling = testCase.limits_override?.max_in_flight ?? fixture.limits.max_in_flight
            XCTAssertLessThanOrEqual(
                outcome.peakInFlight,
                ceiling,
                "\(testCase.id): the batch ceiling must bound observed overlap"
            )
            if testCase.requires_overlap > 1 {
                XCTAssertTrue(
                    outcome.overlapReached,
                    "\(testCase.id): the schedule never reached \(testCase.requires_overlap) concurrent fetches"
                )
            }
        }
    }

    func testIdenticalBytesFromTwoHostsAreOneSnapshot() async throws {
        let testCase = try XCTUnwrap(
            fixture.cases.first { $0.id == "identical-bytes-from-two-hosts-are-one-snapshot" }
        )
        let outcome = try await runBatch(testCase)

        // Both offers are in flight together, so which one stores the bytes is
        // decided by arrival order: the multiset of outcomes is the contract,
        // not which target holds which label.
        XCTAssertTrue(outcome.overlapReached, "the two mirrors must be fetched at once")
        XCTAssertEqual(Set(outcome.kinds), ["stored", "duplicate"])
        XCTAssertEqual(outcome.kinds.filter { $0 == "duplicate" }.count, 1)
        XCTAssertEqual(outcome.snapshotCount, 1)

        let duplicates = outcome.results.compactMap(\.outcome.duplicateReason)
        XCTAssertEqual(duplicates, [.sameBytesFromAnotherSource])
        XCTAssertEqual(outcome.results.filter { $0.outcome.isStored }.count, 1)

        // The duplicate is not new evidence, but both identities and both URLs
        // stay recorded on the one snapshot. Read through the store rather than
        // through the first result, whose record predates the merge.
        let record = try XCTUnwrap(outcome.storedRecords.first)
        XCTAssertEqual(outcome.storedRecords.count, 1)
        XCTAssertEqual(Set(record.sourceIDs), Set(try XCTUnwrap(testCase.expected_recorded_source_ids)))
        XCTAssertEqual(
            Set(record.requestedURLs.map(\.absoluteString)),
            Set(try XCTUnwrap(testCase.expected_recorded_urls))
        )
        XCTAssertEqual(record.duplicateAttempts, 1)
        XCTAssertEqual(record.attempt, 1)
        XCTAssertEqual(record.totalAttempts, 2)
    }

    func testARefusalDoesNotAbortTheRestOfTheBatch() async throws {
        let testCase = try XCTUnwrap(fixture.cases.first { $0.id == "a-refusal-does-not-abort-the-batch" })
        let outcome = try await runBatch(testCase)

        XCTAssertEqual(outcome.kinds, testCase.expected.map(\.kind))
        let refusals = outcome.results.compactMap(\.outcome.refusal)
        XCTAssertEqual(refusals.map(\.stage.rawValue), ["robots", "acquisition", "extraction"])
        // The third target declares application/pdf with a deliberately
        // unreadable body. PDF is now a supported extraction type (M005.2), so
        // the refusal is the malformed body, not the media type. The change is
        // deliberate and recorded in D038.
        XCTAssertEqual(
            refusals.map(\.kind),
            ["published_rule", "private_address", "malformed_markup"]
        )
        // The permitted target is still stored: one source failing is a result,
        // not a reason to discard the sources that succeeded.
        XCTAssertEqual(outcome.snapshotCount, 1)
    }

    func testAnUnfetchableNamespaceFailsClosedBeforeAnyRequest() async throws {
        let testCase = try XCTUnwrap(
            fixture.cases.first { $0.id == "an-unfetchable-namespace-fails-closed-before-any-request" }
        )
        let outcome = try await runBatch(testCase)

        XCTAssertEqual(outcome.kinds, ["refused", "stored"])
        let refusal = try XCTUnwrap(outcome.results.first?.outcome.refusal)
        XCTAssertEqual(refusal.stage, .robots)
        XCTAssertEqual(refusal.kind, "fail_closed")
        XCTAssertFalse(refusal.isRetryable, "a namespace that cannot be fetched must not be retried")
        // The unfetchable host was never contacted: only the permitted host
        // appears in the transport's log.
        XCTAssertEqual(outcome.requestedHosts, ["example.com"])
    }

    func testATransientTimeoutIsRetriedAndTheRetryIsVisible() async throws {
        let testCase = try XCTUnwrap(
            fixture.cases.first { $0.id == "a-transient-timeout-is-retried-and-the-retry-is-visible" }
        )
        let outcome = try await runBatch(testCase)

        let result = try XCTUnwrap(outcome.results.first)
        XCTAssertTrue(result.outcome.isStored)
        XCTAssertTrue(result.wasRetried)
        XCTAssertEqual(result.attempt, 2)
        XCTAssertEqual(result.attempts, 2)
        XCTAssertEqual(outcome.documentRequests, 2)
        // The retry produced one snapshot, not two.
        XCTAssertEqual(outcome.snapshotCount, 1)
        let record = try XCTUnwrap(result.outcome.record)
        XCTAssertEqual(record.attempt, 2, "the record keeps the attempt that produced the bytes")
    }

    func testRetriesAreBoundedByTheAttemptBudget() async throws {
        let testCase = try XCTUnwrap(
            fixture.cases.first { $0.id == "retries-are-bounded-by-the-attempt-budget" }
        )
        let outcome = try await runBatch(testCase)

        let result = try XCTUnwrap(outcome.results.first)
        let refusal = try XCTUnwrap(result.outcome.refusal)
        XCTAssertEqual(refusal.stage, .acquisition)
        XCTAssertEqual(refusal.kind, "timeout")
        XCTAssertEqual(result.attempts, 3)
        XCTAssertEqual(outcome.documentRequests, 3)
        XCTAssertEqual(outcome.snapshotCount, 0)
    }

    func testADefiniteAnswerIsNotRetried() async throws {
        let testCase = try XCTUnwrap(fixture.cases.first { $0.id == "a-definite-answer-is-not-retried" })
        let outcome = try await runBatch(testCase)

        XCTAssertEqual(outcome.kinds, ["refused", "refused"])
        for result in outcome.results {
            XCTAssertEqual(result.attempts, 1, "\(result.sourceID) must not be retried")
            XCTAssertFalse(try XCTUnwrap(result.outcome.refusal).isRetryable)
        }
        XCTAssertEqual(outcome.documentRequests, testCase.expected_document_requests)
    }

    func testResultsFollowTheTargetOrderNotTheCompletionOrder() async throws {
        let testCase = try XCTUnwrap(
            fixture.cases.first { $0.id == "results-follow-the-target-order-not-the-completion-order" }
        )
        let outcome = try await runBatch(testCase)

        XCTAssertEqual(outcome.results.map(\.sourceID), testCase.targets.map(\.source_id))
        XCTAssertEqual(outcome.results.map(\.url.absoluteString), testCase.targets.map(\.url))
        // The first target is the slowest, so a batch that reported completion
        // order would have put it last.
        XCTAssertEqual(outcome.kinds, ["stored", "stored", "stored"])
        XCTAssertEqual(outcome.snapshotCount, 3)
    }

    func testRobotsIsReadOncePerHostAndSharedAcrossTargets() async throws {
        let testCase = try XCTUnwrap(fixture.cases.first { $0.id == "one-host-is-serialised" })
        let outcome = try await runBatch(testCase)

        XCTAssertEqual(testCase.expected_robots_requests, 1)
        XCTAssertEqual(outcome.robotsRequests, 1)
    }

    func testEveryCaseMatchesItsFrozenExpectation() async throws {
        for testCase in fixture.cases {
            let outcome = try await runBatch(testCase)
            if testCase.concurrent_offers_are_race_decided == true {
                // Arrival order decides which of two identical offers stores the
                // bytes, so only the multiset of outcomes is positional-free.
                XCTAssertEqual(
                    outcome.kinds.sorted(),
                    testCase.expected.map(\.kind).sorted(),
                    "\(testCase.id): outcome kinds"
                )
            } else {
                XCTAssertEqual(outcome.kinds, testCase.expected.map(\.kind), "\(testCase.id): outcome kinds")
            }
            XCTAssertEqual(
                outcome.results.map(\.attempt),
                testCase.expected.map(\.attempt),
                "\(testCase.id): the attempt that produced the outcome"
            )
            XCTAssertEqual(
                outcome.results.map(\.attempts),
                testCase.expected.map(\.attempts),
                "\(testCase.id): attempt budget consumed"
            )
            XCTAssertEqual(
                outcome.snapshotCount,
                testCase.expected_snapshot_count,
                "\(testCase.id): stored snapshots"
            )
            XCTAssertEqual(
                outcome.robotsRequests,
                testCase.expected_robots_requests,
                "\(testCase.id): robots requests"
            )
            if let expectedDocuments = testCase.expected_document_requests {
                XCTAssertEqual(
                    outcome.documentRequests,
                    expectedDocuments,
                    "\(testCase.id): document requests"
                )
            }
            if let expectedIDs = testCase.expected_recorded_source_ids {
                XCTAssertEqual(
                    outcome.storedRecords.map { Set($0.sourceIDs) },
                    [Set(expectedIDs)],
                    "\(testCase.id): the one snapshot must carry every identity that offered the bytes"
                )
            }
            if let expectedURLs = testCase.expected_recorded_urls {
                XCTAssertEqual(
                    outcome.storedRecords.map { Set($0.requestedURLs.map(\.absoluteString)) },
                    [Set(expectedURLs)],
                    "\(testCase.id): the one snapshot must carry every URL that offered the bytes"
                )
            }
            for (result, expectation) in zip(outcome.results, testCase.expected) {
                XCTAssertEqual(result.sourceID, expectation.source_id, "\(testCase.id): source identity")
                XCTAssertEqual(result.url.absoluteString, expectation.url, "\(testCase.id): requested URL")
                if let reason = expectation.duplicate_reason {
                    if testCase.concurrent_offers_are_race_decided == true {
                        XCTAssertEqual(
                            outcome.results.compactMap(\.outcome.duplicateReason).map(\.rawValue),
                            [reason],
                            "\(testCase.id): duplicate reason"
                        )
                    } else {
                        XCTAssertEqual(
                            result.outcome.duplicateReason?.rawValue,
                            reason,
                            "\(testCase.id): duplicate reason"
                        )
                    }
                }
                if let stage = expectation.refusal_stage {
                    let refusal = try XCTUnwrap(
                        result.outcome.refusal,
                        "\(testCase.id): \(expectation.source_id) must be refused"
                    )
                    XCTAssertEqual(refusal.stage.rawValue, stage, "\(testCase.id): refusal stage")
                    XCTAssertEqual(refusal.kind, expectation.refusal_kind, "\(testCase.id): refusal kind")
                    XCTAssertFalse(refusal.reason.isEmpty, "\(testCase.id): a refusal must explain itself")
                }
            }
        }
    }

    func testEveryBatchProducesExactlyOneOutcomePerTarget() async throws {
        for testCase in fixture.cases {
            let outcome = try await runBatch(testCase)
            XCTAssertEqual(
                outcome.results.count,
                testCase.targets.count,
                "\(testCase.id): a dropped target is an invisible failure"
            )
            XCTAssertEqual(
                Set(outcome.results.map(\.sourceID)),
                Set(testCase.targets.map(\.source_id)),
                "\(testCase.id): every target must be accounted for"
            )
        }
    }

    func testRefusalFamilyIsEnumeratedAndTyped() {
        XCTAssertEqual(Set(fixture.refusals.map(\.stage)), Set(FetchStage.allCases.map(\.rawValue)))
        for refusal in fixture.refusals {
            XCTAssertFalse(refusal.kind.isEmpty, "\(refusal.stage) must name a kind")
            XCTAssertFalse(refusal.why.isEmpty, "\(refusal.stage)/\(refusal.kind) must say why")
        }
    }

    func testImpossibleLimitsAreRefusedBeforeAnyFetch() throws {
        XCTAssertThrowsError(try FetchLimits(maxInFlight: 0)) { error in
            XCTAssertEqual((error as? FetchScheduleError)?.kind, "invalid_limits")
        }
        XCTAssertThrowsError(try FetchLimits(maxInFlight: 1, maxInFlightPerHost: 0))
        XCTAssertThrowsError(try FetchLimits(maxInFlight: 1, minimumHostDelaySeconds: -1))
        XCTAssertThrowsError(try FetchLimits(maxInFlight: 1, attemptsPerTarget: 0))
        XCTAssertNoThrow(try FetchLimits(maxInFlight: 1))
    }

    func testAnEmptyBatchIsNotAFetch() async throws {
        let fetcher = BoundedFetcher(
            transport: ScriptedScheduleTransport(
                documents: [:],
                robotsStatus: [:],
                robotsBody: [:],
                requiredOverlap: 1
            ),
            resolver: StubHostResolver(answers: [:]),
            userAgent: "LocalLensTest/1.0"
        )
        let results = try await fetcher.fetch([])
        XCTAssertTrue(results.isEmpty)
    }

    func testScheduleSourceHasNoNetworkFilesystemOrClockDependency() throws {
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/LocalLensCore/BoundedFetch.swift")
        let text = try String(contentsOf: source, encoding: .utf8)

        // Built by concatenation so this guard does not itself look like a
        // network call to the repository-wide offline guards.
        for forbidden in [
            "URL" + "Session",
            "System" + "PolitenessClock",
            "File" + "Manager",
            "getaddr" + "info",
        ] {
            XCTAssertFalse(text.contains(forbidden), "BoundedFetch.swift must not use \(forbidden)")
        }
        // The scheduler must not reach a real clock either.
        XCTAssertFalse(text.contains("Task." + "sleep"))
    }
}

// MARK: - Helpers

private extension FetchOutcome {
    var duplicateReason: DuplicateReason? {
        if case let .duplicate(_, reason) = self { return reason }
        return nil
    }
}

/// `FetchStage` must stay a closed set: a new stage is a new kind of refusal,
/// and adding one without adding it to the fixture table would make the table a
/// partial description of the boundary.
private extension FetchStage {
    static var allCases: [FetchStage] { [.acquisition, .robots, .extraction, .store] }
}
