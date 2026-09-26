import Foundation
import XCTest
@testable import LocalLensCore

/// A provider that counts calls and quotes the first selected passage exactly.
private final class ModeProviderSpy: QuickAnswerProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var calls = 0

    var callCount: Int { lock.withLock { calls } }

    func answer(_ request: AnswerRequest) async throws -> AnswerProposal {
        lock.withLock { calls += 1 }
        guard let passage = request.passages.first else {
            return AnswerProposal(answer: "No passage.", claims: [])
        }
        return AnswerProposal(
            answer: "Grounded answer.",
            claims: [ProposedClaim(text: "A supported claim.", passageID: passage.id, quote: passage.text)]
        )
    }
}

/// A search transport that records the request it received and returns a fixed
/// response. It is a stub: no test reaches the network.
private final class RecordingTransport: SearchTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: SearchRequest?
    private let response: SearchResponse

    init(response: SearchResponse) {
        self.response = response
    }

    var request: SearchRequest? { lock.withLock { recorded } }

    func send(_ request: SearchRequest) async throws -> SearchResponse {
        lock.withLock { recorded = request }
        return response
    }
}

/// A one-shot gate that records whether a waiter arrived and blocks until
/// released. Used to prove the runner's pause checkpoint is real.
private final class PauseProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var entered = false
    private var released = false
    private var continuation: CheckedContinuation<Void, Never>?

    var hasEntered: Bool { lock.withLock { entered } }

    func wait() async {
        lock.withLock { entered = true }
        await withCheckedContinuation { continuation in
            let resumeNow = lock.withLock { () -> Bool in
                if released { return true }
                self.continuation = continuation
                return false
            }
            if resumeNow { continuation.resume() }
        }
    }

    func release() {
        lock.withLock {
            released = true
            continuation?.resume()
            continuation = nil
        }
    }
}

/// A counter that a search stub can bump from any executor.
private final class CallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var value: Int { lock.withLock { count } }
    func increment() { lock.withLock { count += 1 } }
}

final class ResearchModeTests: XCTestCase {

    // MARK: Frozen policies

    func testFrozenModePoliciesDoNotDrift() {
        let quick = ModePolicy.policy(for: .quick)
        XCTAssertEqual(quick.searchQueries, 2)
        XCTAssertEqual(quick.openedSources, 6)
        XCTAssertEqual(quick.synthesisPassages, 12)
        XCTAssertEqual(quick.followUpRounds, 0)
        XCTAssertEqual(quick.sourceKind, .web)

        let deep = ModePolicy.policy(for: .deep)
        XCTAssertEqual(deep.followUpRounds, 2)
        XCTAssertEqual(deep.synthesisPassages, 24)

        let academic = ModePolicy.policy(for: .academic)
        XCTAssertEqual(academic.sourceKind, .scholarly)

        let news = ModePolicy.policy(for: .news)
        XCTAssertEqual(news.timeWindowDays, 14)
        XCTAssertEqual(news.sourceKind, .news)
    }

    func testLimitsValidateAgainstTheirOwnModePolicy() {
        XCTAssertTrue(LiveQuickLimits.forMode(.quick).isWithinModeCaps)
        XCTAssertTrue(LiveQuickLimits.forMode(.deep).isWithinModeCaps)
        XCTAssertTrue(LiveQuickLimits.forMode(.academic).isWithinModeCaps)
        XCTAssertTrue(LiveQuickLimits.forMode(.news).isWithinModeCaps)
        // A Quick-shaped budget is still valid, but the same numbers are not a
        // violation of Deep's larger ceiling.
        let overQuick = LiveQuickLimits(searchQueries: 3, openedSources: 6, synthesisPassages: 12, deadlineSeconds: 60)
        XCTAssertFalse(overQuick.isWithinModeCaps)
        let fineForDeep = LiveQuickLimits(searchQueries: 3, openedSources: 6, synthesisPassages: 12, deadlineSeconds: 60, mode: .deep)
        XCTAssertTrue(fineForDeep.isWithinModeCaps)
    }

    // MARK: Planner

    func testQuickPlanUsesOneDimensionAndTheMeasuredWebQuery() {
        let plan = ResearchPlanner.plan("How does SQLite WAL mode handle readers and writers?", mode: .quick, now: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(plan.dimensions, ["Answer"])
        XCTAssertEqual(plan.searchQueries.count, 1)
        XCTAssertFalse(plan.retrievalQueries.isEmpty)
        XCTAssertEqual(plan.policy, ModePolicy.policy(for: .quick))
    }

    func testDeepPlanDerivesComparisonSides() {
        let plan = ResearchPlanner.plan("Compare Swift structured concurrency and Grand Central Dispatch for CPU-bound work", mode: .deep, now: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(plan.dimensions.first, "Swift structured concurrency")
        XCTAssertEqual(plan.dimensions.dropFirst().first, "Grand Central Dispatch for CPU-bound work")
        XCTAssertEqual(plan.dimensions.last, "Gaps")
        XCTAssertLessThanOrEqual(plan.searchQueries.count, plan.policy.searchQueries)
    }

    func testNewsPlanIsTimeStampedAndDeterministic() {
        let fixed = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11-14 UTC
        let first = ResearchPlanner.plan("what changed in the swift release", mode: .news, now: fixed)
        let second = ResearchPlanner.plan("what changed in the swift release", mode: .news, now: fixed)
        XCTAssertEqual(first, second)
        XCTAssertTrue(first.searchQueries.contains { $0.contains("Nov") || $0.contains("2023") })
        XCTAssertEqual(first.policy.timeWindowDays, 14)
    }

    func testAcademicPlanScaffoldsFindingsMethodLimitations() {
        let plan = ResearchPlanner.plan("spaced repetition for long-term recall", mode: .academic, now: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(plan.dimensions, ["Findings", "Method", "Limitations"])
        XCTAssertEqual(plan.policy.sourceKind, .scholarly)
        XCTAssertLessThanOrEqual(plan.searchQueries.count, plan.policy.searchQueries)
    }

    // MARK: Coverage and independence

    func testCoverageCountsAcceptedClaimsForSingleDimensionMode() {
        let passages = [Passage(id: "p1", snapshotID: "s1", ordinal: 0, heading: "H", text: "Alpha works.", textHash: "h")]
        let coverage = ResearchRunner.coverage(for: ["Answer"], passages: passages, claims: ["Alpha works."])
        XCTAssertEqual(coverage["Answer"], 1, "the single Answer dimension is covered by its accepted claim")
        let empty = ResearchRunner.coverage(for: ["Answer"], passages: passages, claims: [])
        XCTAssertEqual(empty["Answer"], 0)
    }

    func testNewsIndependenceClustersByDomainAndCountsDistinctSources() {
        func url(_ string: String) -> URL { URL(string: string)! }
        let record = SnapshotRecord(
            snapshot: Snapshot(id: "s1", sourceID: "src1", contentHash: "c", extractedText: "", extractorVersion: "v"),
            passages: [],
            sourceIDs: [],
            requestedURLs: [url("https://www.example.com/news/a")],
            finalURL: url("https://www.example.com/news/a"),
            attempt: 1,
            duplicateAttempts: 0
        )
        let second = SnapshotRecord(
            snapshot: Snapshot(id: "s2", sourceID: "src2", contentHash: "d", extractedText: "", extractorVersion: "v"),
            passages: [],
            sourceIDs: [],
            requestedURLs: [url("https://other.example.org/b")],
            finalURL: url("https://other.example.org/b"),
            attempt: 1,
            duplicateAttempts: 0
        )
        let passages = [
            Passage(id: "p1", snapshotID: "s1", ordinal: 0, heading: "H", text: "Alpha.", textHash: "h1"),
            Passage(id: "p2", snapshotID: "s1", ordinal: 1, heading: "H", text: "Beta.", textHash: "h2"),
            Passage(id: "p3", snapshotID: "s2", ordinal: 0, heading: "H", text: "Gamma.", textHash: "h3"),
        ]
        let clusters = NewsIndependence.clusters(passages: passages, records: [record, second])
        XCTAssertEqual(clusters.count, 2)
        XCTAssertEqual(clusters.first { $0.registrableDomain == "example.com" }?.passageIDs.count, 2)
        XCTAssertEqual(NewsIndependence.independentDomainCount(passages: passages, records: [record, second]), 2)
        XCTAssertEqual(NewsIndependence.domain(of: url("https://www.example.com/x")), "example.com")
    }

    // MARK: News time window (M006.1)

    private func datedHit(_ host: String, _ daysAgo: Double, query: String = "q") -> DatedHit {
        let url = URL(string: "https://\(host)/story")!
        return DatedHit(
            hit: SearchHit(
                id: StableIdentity.make("hit", query, url.absoluteString, host),
                query: query,
                rank: 0,
                url: url,
                title: "T",
                snippet: ""
            ),
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000).addingTimeInterval(-daysAgo * NewsRecency.secondsPerDay)
        )
    }

    func testNewsWindowKeepsRecentHitsAndExcludesStaleAndUndated() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let decision = NewsRecency.apply(
            [
                DatedHit(hit: datedHit("fresh.example", 3).hit, publishedAt: now.addingTimeInterval(-3 * NewsRecency.secondsPerDay)),
                DatedHit(hit: datedHit("edge.example", 14).hit, publishedAt: now.addingTimeInterval(-14 * NewsRecency.secondsPerDay)),
                DatedHit(hit: datedHit("stale.example", 20).hit, publishedAt: now.addingTimeInterval(-20 * NewsRecency.secondsPerDay)),
                DatedHit(hit: datedHit("undated.example", 0).hit, publishedAt: nil),
            ],
            windowDays: 14,
            now: now
        )
        XCTAssertEqual(decision.kept.map(\.url.host), ["fresh.example", "edge.example"])
        XCTAssertEqual(decision.excludedStale.count, 1)
        XCTAssertEqual(decision.excludedUndated.count, 1, "an undated page cannot be shown to honour a bounded window")
        XCTAssertFalse(decision.isStarved)
        // A publisher clock slightly ahead of the device is not a claim about
        // the future, so a report dated later today is still inside the window.
        XCTAssertTrue(NewsRecency.isWithinWindow(now.addingTimeInterval(3_600), windowDays: 14, now: now))
    }

    func testWindowedAdapterDropsStaleBeforeAnyFetchAndCountsIt() async throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let stale = DatedHit(
            hit: datedHit("old.example", 40).hit,
            publishedAt: now.addingTimeInterval(-40 * NewsRecency.secondsPerDay)
        )
        let fresh = DatedHit(
            hit: datedHit("new.example", 1).hit,
            publishedAt: now.addingTimeInterval(-1 * NewsRecency.secondsPerDay)
        )
        let adapter = WindowedSearchAdapter(
            wrapped: FixedDatedAdapter(queries: ["q": [stale, fresh]]),
            windowDays: 14,
            now: { now }
        )
        guard case let .hits(hits) = try await adapter.search("q") else {
            return XCTFail("expected the fresh result to survive the window")
        }
        XCTAssertEqual(hits.map(\.url.host), ["new.example"])
        XCTAssertEqual(adapter.ledger.excludedStaleCount, 1)
        XCTAssertEqual(adapter.ledger.queryCount, 1)
        XCTAssertEqual(adapter.ledger.summary, "1 dated results inside the window, 1 outside it")

        let starved = WindowedSearchAdapter(
            wrapped: FixedDatedAdapter(queries: ["q": [stale]]),
            windowDays: 14,
            now: { now }
        )
        let starvedOutcome = try await starved.search("q")
        XCTAssertEqual(starvedOutcome, .noResults(query: "q"))
        XCTAssertEqual(starved.ledger.starvedQueryCount, 1)
    }

    func testSyndicatedHeadlineCountsAsOneVoice() {
        func record(_ id: String, _ url: String) -> SnapshotRecord {
            SnapshotRecord(
                snapshot: Snapshot(id: id, sourceID: "src-\(id)", contentHash: "c", extractedText: "", extractorVersion: "v"),
                passages: [],
                sourceIDs: [],
                requestedURLs: [URL(string: url)!],
                finalURL: URL(string: url)!,
                attempt: 1,
                duplicateAttempts: 0
            )
        }
        let records = [
            record("s1", "https://alpha.example/news/1"),
            record("s2", "https://beta.example/news/2"),
            record("s3", "https://gamma.example/news/3"),
        ]
        let passages = [
            Passage(id: "p1", snapshotID: "s1", ordinal: 0, heading: "OpenAI raises a new funding round", text: "A", textHash: "h1"),
            Passage(id: "p2", snapshotID: "s2", ordinal: 0, heading: "OpenAI raises a new funding round", text: "B", textHash: "h2"),
            Passage(id: "p3", snapshotID: "s3", ordinal: 0, heading: "Regulators open a review into the deal", text: "C", textHash: "h3"),
        ]
        let voices = NewsIndependence.voices(passages: passages, records: records)
        XCTAssertEqual(NewsIndependence.independentDomainCount(passages: passages, records: records), 3)
        XCTAssertEqual(voices.count, 2, "two domains carrying the same headline are one voice")
        XCTAssertEqual(voices.first { $0.domains.count == 2 }?.domains, ["alpha.example", "beta.example"])
        XCTAssertEqual(NewsIndependence.independentVoiceCount(passages: passages, records: records), 2)
    }

    func testShortHeadingNeverMergesUnrelatedDomains() {
        func record(_ id: String, _ url: String) -> SnapshotRecord {
            SnapshotRecord(
                snapshot: Snapshot(id: id, sourceID: "src-\(id)", contentHash: "c", extractedText: "", extractorVersion: "v"),
                passages: [],
                sourceIDs: [],
                requestedURLs: [URL(string: url)!],
                finalURL: URL(string: url)!,
                attempt: 1,
                duplicateAttempts: 0
            )
        }
        let records = [record("s1", "https://alpha.example/a"), record("s2", "https://beta.example/b")]
        let passages = [
            Passage(id: "p1", snapshotID: "s1", ordinal: 0, heading: "Introduction", text: "A", textHash: "h1"),
            Passage(id: "p2", snapshotID: "s2", ordinal: 0, heading: "Introduction", text: "B", textHash: "h2"),
        ]
        XCTAssertNil(NewsIndependence.headlineSignature("Introduction"))
        XCTAssertEqual(NewsIndependence.voices(passages: passages, records: records).count, 2)
        XCTAssertNotNil(NewsIndependence.headlineSignature("Published time: 3 September 2026"))
    }

    func testNewsTimelineOrdersNewestFirstAndKeepsUndatedLast() {
        func record(_ id: String, _ url: String) -> SnapshotRecord {
            SnapshotRecord(
                snapshot: Snapshot(id: id, sourceID: "src-\(id)", contentHash: "c", extractedText: "", extractorVersion: "v"),
                passages: [],
                sourceIDs: [],
                requestedURLs: [URL(string: url)!],
                finalURL: URL(string: url)!,
                attempt: 1,
                duplicateAttempts: 0
            )
        }
        let records = [
            record("s1", "https://alpha.example/a"),
            record("s2", "https://beta.example/b"),
            record("s3", "https://gamma.example/c"),
        ]
        let passages = [
            Passage(id: "p1", snapshotID: "s1", ordinal: 0, heading: "Older report on the ruling", text: "A", textHash: "h1"),
            Passage(id: "p2", snapshotID: "s2", ordinal: 0, heading: "Newer report on the ruling", text: "B", textHash: "h2"),
            Passage(id: "p3", snapshotID: "s3", ordinal: 0, heading: "Undated commentary on the ruling", text: "C", textHash: "h3"),
        ]
        let old = Date(timeIntervalSince1970: 1_000_000)
        let new = Date(timeIntervalSince1970: 2_000_000)
        let timeline = NewsIndependence.timeline(
            passages: passages,
            records: records,
            publicationDates: [
                "https://alpha.example/a": old,
                "https://beta.example/b": new,
            ]
        )
        XCTAssertEqual(timeline.map(\.domains.first), ["beta.example", "alpha.example", "gamma.example"])
        XCTAssertEqual(timeline[0].publishedAt, new)
        XCTAssertNil(timeline[2].publishedAt, "an undated page is shown without a timestamp, not with a guessed one")
    }

    func testClaimSupportCountsIndependentVoicesBehindThePage() {
        func record(_ id: String, _ url: String) -> SnapshotRecord {
            SnapshotRecord(
                snapshot: Snapshot(id: id, sourceID: "src-\(id)", contentHash: "c", extractedText: "", extractorVersion: "v"),
                passages: [],
                sourceIDs: [],
                requestedURLs: [URL(string: url)!],
                finalURL: URL(string: url)!,
                attempt: 1,
                duplicateAttempts: 0
            )
        }
        let records = [
            record("s1", "https://alpha.example/a"),
            record("s2", "https://beta.example/b"),
            record("s3", "https://gamma.example/c"),
        ]
        let passages = [
            Passage(id: "p1", snapshotID: "s1", ordinal: 0, heading: "Central bank holds rates steady again", text: "A", textHash: "h1"),
            Passage(id: "p2", snapshotID: "s2", ordinal: 0, heading: "Central bank holds rates steady again", text: "B", textHash: "h2"),
            Passage(id: "p3", snapshotID: "s3", ordinal: 0, heading: "Analysts split on the next central bank move", text: "C", textHash: "h3"),
        ]
        let map = NewsIndependence.snapshotSupportMap(passages: passages, records: records)
        XCTAssertEqual(map["s1"], 1, "a syndicated copy is one voice even across two domains")
        XCTAssertEqual(map["s2"], 1)
        XCTAssertEqual(map["s3"], 1, "a report only one outlet carries is single-source")
        XCTAssertEqual(NewsIndependence.snapshotSupport(passages: passages, records: records, snapshotID: "s1"), 1)
        XCTAssertEqual(NewsIndependence.snapshotSupport(passages: passages, records: records, snapshotID: "missing"), 0)
    }

    // MARK: Edited plan and typed loop reasons (M007.1)

    func testEditedDimensionPlanIsValidatedAgainstModeCaps() throws {
        // Whitespace is collapsed but a label keeps its own case.
        XCTAssertEqual(
            try ResearchPlanner.validatedDimensions(["  Cost   ", "Speed", "  Risk "], mode: .news),
            ["Cost", "Speed", "Risk"]
        )
        // The duplicate check is case-insensitive, so "Cost" and "cost" are one
        // dimension and neither is silently dropped.
        XCTAssertThrowsError(try ResearchPlanner.validatedDimensions(["Cost", "cost"], mode: .deep)) { error in
            XCTAssertEqual(error as? ResearchPlanError, .duplicateDimension("cost"))
        }
        XCTAssertThrowsError(try ResearchPlanner.validatedDimensions([" ", "\n"], mode: .deep)) { error in
            XCTAssertEqual(error as? ResearchPlanError, .noDimensions)
        }
        XCTAssertThrowsError(
            try ResearchPlanner.validatedDimensions(["a", "b", "c", "d", "e", "f", "g"], mode: .deep)
        ) { error in
            XCTAssertEqual(error as? ResearchPlanError, .tooManyDimensions(mode: .deep, maximum: 6, given: 7))
        }
        XCTAssertThrowsError(try ResearchPlanner.validatedDimensions([String(repeating: "x", count: 61)], mode: .deep)) { error in
            guard case .dimensionTooLong = error as? ResearchPlanError else {
                return XCTFail("expected a length refusal, got \(error)")
            }
        }
        XCTAssertEqual(ResearchPlanner.maximumDimensions(for: .quick), 1)
        XCTAssertEqual(ResearchPlanner.splitDimensions("Cost, Speed\nRisk"), ["Cost", " Speed", "Risk"])
    }

    func testEditedDimensionsTakePartInThePlanAndItsQueries() throws {
        let plan = try ResearchPlanner.plan(
            "how should a small team ship offline search",
            mode: .deep,
            now: Date(timeIntervalSince1970: 0),
            dimensions: ["Cost", "Latency"]
        )
        XCTAssertEqual(plan.dimensions, ["Cost", "Latency"])
        XCTAssertEqual(plan.policy, ModePolicy.policy(for: .deep), "an edited plan still carries the frozen policy")
        XCTAssertTrue(plan.retrievalQueries.contains { $0.localizedCaseInsensitiveContains("cost") })
        XCTAssertLessThanOrEqual(plan.searchQueries.count, plan.policy.searchQueries)
        XCTAssertEqual(plan.mode, .deep)
    }

    func testLoopStopsWithEvidenceSaturatedAndRecordsTheRound() async throws {
        let base = "https://docs.example.invalid/long"
        let store = SnapshotStore()
        let plan = ResearchPlanner.plan("alpha beta", mode: .quick, now: Date(timeIntervalSince1970: 0))
        let paragraphs = (1...20).map { "Paragraph \($0) explains alpha and beta in detail." }.joined(separator: "</p><p>")
        let outcome = await ResearchRunner.run(
            plan: plan,
            deadline: Date().addingTimeInterval(30),
            search: search([plan.searchQueries[0]: [hit(base, query: plan.searchQueries[0])]]),
            store: store,
            fetch: richFetch([base: paragraphs], store: store),
            provider: ModeProviderSpy(),
            label: "hosted"
        )
        guard case let .completed(report) = outcome else {
            return XCTFail("expected completion, got \(outcome)")
        }
        XCTAssertEqual(report.stopReason, .evidenceSaturated)
        XCTAssertEqual(report.roundLog.count, 1)
        XCTAssertEqual(report.roundLog[0].reason, .evidenceSaturated)
        XCTAssertEqual(report.roundLog[0].index, 0)
        XCTAssertGreaterThan(report.roundLog[0].addedPassages, 0)
        XCTAssertTrue(report.stopReason.explanation.contains("passage ceiling"))
    }

    func testLoopStopsWhenARoundAddsNothingNewInsteadOfRepeatingQueries() async throws {
        let base = "https://docs.example.invalid/again"
        let store = SnapshotStore()
        let plan = ResearchPlanner.plan("How does alpha compare with beta for a small team", mode: .deep, now: Date(timeIntervalSince1970: 0))
        // Every query returns the same page, so a follow-up round can only
        // rediscover what is already stored.
        let searchStub: @Sendable (String) async throws -> SearchOutcome = { query in
            .hits([SearchHit(id: "\(query)-\(base)", query: query, rank: 0, url: URL(string: base)!, title: "Source", snippet: "")])
        }
        let outcome = await ResearchRunner.run(
            plan: plan,
            deadline: Date().addingTimeInterval(60),
            search: searchStub,
            store: store,
            fetch: boundedFetch([base: "Alpha and beta differ on cost."], store: store),
            provider: ModeProviderSpy(),
            label: "hosted"
        )
        guard case let .completed(report) = outcome else {
            return XCTFail("expected completion, got \(outcome)")
        }
        XCTAssertEqual(report.stopReason, .noNewEvidence)
        XCTAssertEqual(report.roundLog.last?.reason, .noNewEvidence)
        XCTAssertEqual(report.roundLog.last?.addedPassages, 0)
        XCTAssertGreaterThan(report.rounds, 1, "the runner does try one bounded follow-up before stopping")
        XCTAssertLessThanOrEqual(report.rounds, plan.policy.followUpRounds + 1)
        // No stored passage is duplicated as evidence.
        let ids = report.result.records.flatMap { $0.passages.map(\.id) }
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testInjectedFetchFailureResumesAndStoredEvidenceIsNotDuplicated() async throws {
        let first = "https://docs.example.invalid/kept"
        let second = "https://docs.example.invalid/later"
        let store = SnapshotStore()
        let plan = ResearchPlanner.plan("How does alpha compare with beta", mode: .deep, now: Date(timeIntervalSince1970: 0))
        let attempts = AttemptCounter()
        // Round 0 sees `first`; the bounded follow-up round sees `second`, whose
        // fetch is injected to fail.
        let searchStub: @Sendable (String) async throws -> SearchOutcome = { query in
            let target = attempts.searchCount() <= 2 ? first : second
            return .hits([SearchHit(id: "\(query)-\(target)", query: query, rank: 0, url: URL(string: target)!, title: "Source", snippet: "")])
        }
        let fetchCount = AttemptCounter()
        let available = builtFetch([first: "Alpha costs less than beta."], store: store)
        let outcome = await ResearchRunner.run(
            plan: plan,
            deadline: Date().addingTimeInterval(60),
            search: searchStub,
            store: store,
            fetch: { targets in
                // Every fetch after the first batch refuses, the way a real
                // transport failure would.
                if fetchCount.next() > 1 {
                    return targets.map {
                        FetchResult(
                            sourceID: $0.sourceID,
                            url: $0.url,
                            outcome: .refused(FetchRefusal(stage: .acquisition, kind: "transport_failure", reason: "injected")),
                            attempt: 1,
                            attempts: 1
                        )
                    }
                }
                return try await available(targets)
            },
            provider: ModeProviderSpy(),
            label: "hosted"
        )
        guard case let .completed(report) = outcome else {
            return XCTFail("expected the run to keep its first round, got \(outcome)")
        }
        XCTAssertEqual(report.stopReason, .noNewEvidence)
        XCTAssertEqual(report.roundLog.count, 2)
        XCTAssertEqual(report.roundLog[0].reason, .followUpScheduled)
        XCTAssertEqual(report.roundLog[1].reason, .noNewEvidence)
        XCTAssertEqual(report.roundLog[1].addedPassages, 0)
        let records = report.result.records
        XCTAssertEqual(records.filter { $0.finalURL == URL(string: first)! }.count, 1)
        let ids = records.flatMap { $0.passages.map(\.id) }
        XCTAssertEqual(Set(ids).count, ids.count, "no passage is duplicated by the failed round")
        for citation in report.result.compilation.citations {
            XCTAssertNoThrow(try report.result.compilation.resolve(citation.id))
        }
    }

    // MARK: Content coverage and contradictions (M007.2)

    func testCoverageMatchesContentTermsNotOnlyTheLabel() {
        let passages = [
            Passage(
                id: "p1", snapshotID: "s1", ordinal: 0, heading: "Performance",
                text: "There are advantages and drawbacks to this approach, and the cost is low.",
                textHash: "h1"
            ),
            Passage(
                id: "p2", snapshotID: "s2", ordinal: 0, heading: "Study",
                text: "The measured data show a clear improvement in the benchmark.",
                textHash: "h2"
            ),
            Passage(
                id: "p3", snapshotID: "s3", ordinal: 0, heading: "X",
                text: "Nothing here matches the scaffold at all.",
                textHash: "h3"
            ),
        ]
        let coverage = ResearchRunner.coverage(for: ["Overview", "Evidence", "Tradeoffs", "Gaps"], passages: passages)
        XCTAssertGreaterThanOrEqual(coverage["Tradeoffs"] ?? 0, 1, "advantages and drawbacks are a tradeoff discussion")
        XCTAssertGreaterThanOrEqual(coverage["Evidence"] ?? 0, 1, "measured data and a benchmark are evidence")
        XCTAssertEqual(coverage["Gaps"] ?? 0, 0)
        XCTAssertTrue(DimensionLexicon.covers("Tradeoffs", text: "the main downside is cost"))
        XCTAssertTrue(DimensionLexicon.covers("Custom", text: "a custom dimension"))
        XCTAssertFalse(DimensionLexicon.covers("Custom", text: "unrelated"))
    }

    func testNumericContradictionIsShownAndNeverAveraged() {
        func record(_ id: String, _ url: String) -> SnapshotRecord {
            SnapshotRecord(
                snapshot: Snapshot(id: id, sourceID: "src-\(id)", contentHash: "c", extractedText: "", extractorVersion: "v"),
                passages: [],
                sourceIDs: [],
                requestedURLs: [URL(string: url)!],
                finalURL: URL(string: url)!,
                attempt: 1,
                duplicateAttempts: 0
            )
        }
        let records = [record("s1", "https://alpha.example/a"), record("s2", "https://beta.example/b")]
        let passages = [
            Passage(
                id: "p1", snapshotID: "s1", ordinal: 0, heading: "H",
                text: "The benchmark reports 400 write transactions per second on the smallest instance.",
                textHash: "h1"
            ),
            Passage(
                id: "p2", snapshotID: "s2", ordinal: 0, heading: "H",
                text: "The benchmark reports 1200 write transactions per second on the smallest instance.",
                textHash: "h2"
            ),
        ]
        let found = ContradictionScan.contradictions(passages: passages, records: records)
        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(found.first?.leftValue, "400")
        XCTAssertEqual(found.first?.rightValue, "1200")
        XCTAssertTrue(found.first?.context.contains("benchmark") ?? false)
        // The same passage restated is not a contradiction.
        let restated = ContradictionScan.contradictions(passages: [passages[0]], records: records)
        XCTAssertTrue(restated.isEmpty)
        // A year inside a context is kept: two pages stating a different
        // effective year for the same rule genuinely disagree.
        let dated = ContradictionScan.claims(in: "The rule took effect in 2026 and applies from 2027.")
        XCTAssertEqual(dated.map(\.value), ["2026", "2027"])
        // A number with no quantifiable context is refused.
        XCTAssertTrue(ContradictionScan.claims(in: "See section 4.").isEmpty)
    }

    func testDiminishingFollowUpStopsWithATypedReason() async throws {
        let store = SnapshotStore()
        let plan = ResearchPlanner.plan("How does alpha compare with beta", mode: .deep, now: Date(timeIntervalSince1970: 0))
        let first = "https://docs.example.invalid/many"
        let second = "https://docs.example.invalid/few"
        let searches = AttemptCounter()
        let searchStub: @Sendable (String) async throws -> SearchOutcome = { query in
            let target = searches.searchCount() <= 2 ? first : second
            return .hits([SearchHit(id: "\(query)-\(target)", query: query, rank: 0, url: URL(string: target)!, title: "Source", snippet: "")])
        }
        // Round 0 supplies many passages; the follow-up round supplies one.
        let many = (1...10).map { "Paragraph \($0) covers alpha and beta tradeoffs." }.joined(separator: "</p><p>")
        let fetch = boundedFetch([first: many, second: "A single extra paragraph about alpha."], store: store)
        let outcome = await ResearchRunner.run(
            plan: plan,
            deadline: Date().addingTimeInterval(60),
            search: searchStub,
            store: store,
            fetch: fetch,
            provider: ModeProviderSpy(),
            label: "hosted"
        )
        guard case let .completed(report) = outcome else {
            return XCTFail("expected completion, got \(outcome)")
        }
        XCTAssertEqual(report.stopReason, .diminishingReturns)
        XCTAssertEqual(report.roundLog.last?.reason, .diminishingReturns)
        XCTAssertEqual(report.roundLog.count, 2)
    }

    // MARK: Runner end to end (offline)

    func testQuickResearchRunnerCompletesWithExactCitations() async throws {
        let base = "https://docs.example.invalid/alpha"
        let store = SnapshotStore()
        let plan = ResearchPlanner.plan("how does alpha work", mode: .quick, now: Date(timeIntervalSince1970: 0))
        let provider = ModeProviderSpy()
        let outcome = await ResearchRunner.run(
            plan: plan,
            deadline: Date().addingTimeInterval(30),
            search: search([plan.searchQueries[0]: [hit(base, query: plan.searchQueries[0])]]),
            store: store,
            fetch: boundedFetch([base: "Alpha works by doing beta and gamma."], store: store),
            provider: provider,
            label: "hosted"
        )
        guard case let .completed(report) = outcome else {
            return XCTFail("expected completion, got \(outcome)")
        }
        XCTAssertEqual(report.plan.mode, .quick)
        XCTAssertEqual(report.rounds, 1)
        XCTAssertEqual(provider.callCount, 1)
        XCTAssertGreaterThanOrEqual(report.result.compilation.citations.count, 1)
        XCTAssertTrue(report.gapDimensions.isEmpty)
        // Every displayed claim resolves to its exact stored passage.
        for citation in report.result.compilation.citations {
            XCTAssertNoThrow(try report.result.compilation.resolve(citation.id))
        }
    }

    func testDeepRunnerAddsOneBoundedFollowUpForAnUncoveredDimension() async throws {
        let first = "https://docs.example.invalid/overview"
        let second = "https://docs.example.invalid/gaps"
        let store = SnapshotStore()
        let plan = ResearchPlanner.plan("alpha beta gamma delta", mode: .deep, now: Date(timeIntervalSince1970: 0))
        let baseQuery = plan.searchQueries[0]
        let provider = ModeProviderSpy()
        // Round 0's page covers Overview, so the runner's follow-ups target the
        // remaining dimensions only.
        let followUps = ResearchRunner.followUpQueries(question: plan.question, dimensions: Array(plan.dimensions.dropFirst()), mode: .deep)
        XCTAssertFalse(followUps.isEmpty, "an uncovered dimension must generate a follow-up")

        let outcome = await ResearchRunner.run(
            plan: plan,
            deadline: Date().addingTimeInterval(30),
            search: search([
                baseQuery: [hit(first, query: baseQuery)],
                followUps[0]: [hit(second, query: followUps[0])],
            ]),
            store: store,
            fetch: boundedFetch([
                first: "alpha beta gamma delta overview of the subject",
                second: "evidence tradeoffs gaps alpha beta gamma delta",
            ], store: store),
            provider: provider,
            label: "hosted"
        )
        guard case let .completed(report) = outcome else {
            return XCTFail("expected completion, got \(outcome)")
        }
        XCTAssertEqual(report.plan.mode, .deep)
        XCTAssertEqual(report.rounds, 2, "the uncovered dimension must be retried exactly once within the Deep cap")
        XCTAssertEqual(provider.callCount, 1, "follow-up rounds are retrieval-only; the provider is called once")
    }

    func testRunnerRefusesAPlanThatDoesNotMatchItsFrozenPolicy() async throws {
        let store = SnapshotStore()
        let plan = ResearchPlan(
            mode: .deep,
            question: "alpha",
            dimensions: ["Answer"],
            searchQueries: ["alpha"],
            retrievalQueries: ["alpha"],
            policy: ModePolicy.policy(for: .quick)
        )
        let outcome = await ResearchRunner.run(
            plan: plan,
            deadline: Date().addingTimeInterval(30),
            search: search([:]),
            store: store,
            fetch: boundedFetch([:], store: store),
            provider: ModeProviderSpy(),
            label: "hosted"
        )
        guard case let .failed(reason) = outcome else {
            return XCTFail("a mismatched plan must fail closed, got \(outcome)")
        }
        XCTAssertTrue(reason.contains("frozen"))
    }

    // MARK: History

    func testHistoryStoreRoundTripsAndSkipsCorruptEntries() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("locallens-history-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ResearchHistoryStore(directory: directory)
        let artifact = LiveAnswerArtifact(
            question: "How does alpha work?",
            answer: "Alpha works. [1]",
            label: "hosted",
            provider: "deepseek-flash",
            generatedAt: "2026-09-26T00:00:00Z",
            elapsedSeconds: 4.5,
            citations: [
                LiveAnswerArtifact.Citation(
                    marker: 1,
                    claimText: "Alpha works.",
                    quote: "Alpha works.",
                    passageID: "p1",
                    snapshotID: "s1",
                    heading: "Alpha",
                    sourceURL: URL(string: "https://docs.example.invalid/alpha"),
                    passageText: "Alpha works by doing beta."
                )
            ]
        )
        let first = ResearchHistoryEntry(artifact: artifact, mode: .quick, completedAt: "2026-09-26T00:00:00Z")
        let second = ResearchHistoryEntry(artifact: artifact, mode: .deep, completedAt: "2026-09-26T00:01:00Z")
        try store.save(first)
        try store.save(second)
        // A corrupt file must be skipped, never guessed at.
        try Data("not json".utf8).write(to: directory.appendingPathComponent("broken.json"))

        let entries = try store.list()
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries.first?.completedAt, "2026-09-26T00:01:00Z", "newest first")
        XCTAssertEqual(entries.first?.mode, .deep)
        XCTAssertEqual(try store.load(id: first.id).citations.first?.quote, "Alpha works.")

        try store.delete(id: first.id)
        XCTAssertEqual(try store.list().count, 1)
        try store.clear()
        XCTAssertEqual(try store.list().count, 0)
    }

    // MARK: OpenAlex

    func testOpenAlexDecodePrefersOpenAccessThenLandingPageThenDOI() throws {
        let json = """
        {"results":[
          {"display_name":"Closed publisher page","primary_location":{"landing_page_url":"https://closed.example.invalid/article"},"best_oa_location":null,"doi":"https://doi.org/10.9/closed"},
          {"display_name":"A study","primary_location":{"landing_page_url":"https://journal.example.invalid/article/1"},"best_oa_location":{"landing_page_url":"https://repository.example.invalid/oa/1","pdf_url":"https://repository.example.invalid/oa/1.pdf"},"doi":"https://doi.org/10.1/abc"},
          {"display_name":"Only DOI","primary_location":null,"best_oa_location":null,"doi":"10.2/xyz"},
          {"display_name":"No readable target","primary_location":{},"best_oa_location":null,"doi":null}
        ]}
        """
        guard case let .hits(hits) = try OpenAlexPayload.decode(Data(json.utf8), query: "q", maxResults: 10) else {
            return XCTFail("expected hits")
        }
        XCTAssertEqual(hits.count, 3)
        // Open-access works are stably ordered first, because a paywalled or
        // JavaScript-only publisher page cannot supply a readable passage.
        XCTAssertEqual(hits[0].url.absoluteString, "https://repository.example.invalid/oa/1")
        XCTAssertEqual(hits[1].url.absoluteString, "https://closed.example.invalid/article")
        XCTAssertEqual(hits[2].url.absoluteString, "https://doi.org/10.2/xyz")
        XCTAssertTrue(hits.allSatisfy { $0.snippet.isEmpty }, "academic metadata is discovery only")
    }

    func testOpenAlexDecodeFailsClosedOnMalformedPayload() {
        XCTAssertThrowsError(try OpenAlexPayload.decode(Data("{}".utf8), query: "q", maxResults: 10)) { error in
            guard case SearchError.malformedPayload = error else {
                return XCTFail("expected a typed malformed payload, got \(error)")
            }
        }
        XCTAssertThrowsError(try OpenAlexPayload.decode(Data("not json".utf8), query: "q", maxResults: 10))
    }

    func testOpenAlexSearchSendsPoliteParamsAndNoKey() async throws {
        let transport = RecordingTransport(response: SearchResponse(
            statusCode: 200,
            body: Data(#"{"results":[{"display_name":"Work","primary_location":{"landing_page_url":"https://journal.example.invalid/w"},"doi":null}]}"#.utf8)
        ))
        let configuration = try OpenAlexConfiguration(maxResults: 5, mailto: "owner@example.invalid", timeoutSeconds: 5)
        let adapter = OpenAlexSearchAdapter(configuration: configuration, transport: transport)
        _ = try await adapter.search("spaced repetition")
        guard let request = transport.request, let components = URLComponents(url: request.url, resolvingAgainstBaseURL: false) else {
            return XCTFail("no recorded request")
        }
        let items = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value) })
        XCTAssertEqual(items["search"], "spaced repetition")
        XCTAssertEqual(items["per-page"], "5")
        XCTAssertEqual(items["mailto"], "owner@example.invalid")
        XCTAssertNil(request.headers["Authorization"], "OpenAlex needs no key and must not receive one")
        XCTAssertEqual(request.method, "GET")
    }

    func testRunnerWaitsAtThePauseCheckpointBeforeAnySearch() async throws {
        let first = "https://docs.example.invalid/paused"
        let store = SnapshotStore()
        let plan = ResearchPlanner.plan("how does alpha work", mode: .quick, now: Date(timeIntervalSince1970: 0))
        let probe = PauseProbe()
        let searches = CallCounter()
        let baseQuery = plan.searchQueries[0]
        let hits = [hit(first, query: baseQuery)]
        let searchClosure: @Sendable (String) async throws -> SearchOutcome = { query in
            searches.increment()
            return query == baseQuery ? .hits(hits) : .noResults(query: query)
        }
        let fetchClosure = boundedFetch([first: "Alpha works by doing beta."], store: store)
        let provider = ModeProviderSpy()
        let probeRef = probe

        let task = Task {
            await ResearchRunner.run(
                plan: plan,
                deadline: Date().addingTimeInterval(30),
                search: searchClosure,
                store: store,
                fetch: fetchClosure,
                provider: provider,
                label: "hosted",
                pauseCheck: { await probeRef.wait() }
            )
        }

        let entered = await waitUntil { probe.hasEntered }
        XCTAssertTrue(entered, "the run must reach the pause checkpoint")
        XCTAssertEqual(searches.value, 0, "a paused run must not search before it is resumed")
        probe.release()
        let outcome = await task.value
        guard case .completed = outcome else {
            return XCTFail("a released run must complete, got \(outcome)")
        }
        XCTAssertGreaterThan(searches.value, 0)
    }

    // MARK: Local provider

    func testLocalProviderPostsToLoopbackWithoutCredentialAndKeepsItsLabel() async throws {
        let transport = RecordingTransport(response: SearchResponse(
            statusCode: 200,
            body: Data(#"{"choices":[{"message":{"content":"{\"answer\":\"A\",\"claims\":[]}"}}],"usage":{"prompt_tokens":3,"completion_tokens":1}}"#.utf8)
        ))
        let configuration = LocalProviderConfiguration(
            baseURL: URL(string: "http://127.0.0.1:11434")!,
            model: "qwen2.5-coder:14b-instruct-q4_K_M"
        )
        let provider = LocalAnswerProvider(configuration: configuration, transport: transport)
        let passage = Passage(id: "p1", snapshotID: "s1", ordinal: 0, heading: "H", text: "Alpha works.", textHash: "h")
        let proposal = try await provider.answer(AnswerRequest(question: "How?", passages: [passage], mode: .quick, dimensions: ["Answer"]))
        XCTAssertEqual(proposal.answer, "A")
        XCTAssertEqual(configuration.label, "local/qwen2.5-coder:14b-instruct-q4_K_M")
        guard let request = transport.request else { return XCTFail("no recorded request") }
        XCTAssertEqual(request.url.absoluteString, "http://127.0.0.1:11434/v1/chat/completions")
        XCTAssertNil(request.headers["Authorization"], "a local provider must carry no credential")
        let body = String(data: request.body ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(body.contains("qwen2.5-coder:14b-instruct-q4_K_M"))
        XCTAssertFalse(body.contains("response_format"), "local servers differ in optional fields; the provider must not depend on them")
        XCTAssertFalse(body.contains("thinking"))
    }

    func testLocalDecodeAcceptsFencedOrFramedJSONAndRejectsJunk() throws {
        let fenced = """
        ```json
        {"answer":"Grounded","claims":[{"text":"A","passage_id":"p1","quote":"Alpha works."}]}
        ```
        """
        let proposal = try LocalAnswerProvider.decodeProposal(from: fenced)
        XCTAssertEqual(proposal.answer, "Grounded")
        XCTAssertEqual(proposal.claims.count, 1)
        let framed = "Here is the object: {\"answer\":\"B\",\"claims\":[]} — done."
        XCTAssertEqual(try LocalAnswerProvider.decodeProposal(from: framed).answer, "B")
        XCTAssertThrowsError(try LocalAnswerProvider.decodeProposal(from: "no json here")) { error in
            XCTAssertEqual((error as? QuickProviderError)?.kind, "provider_malformed_response")
        }
        XCTAssertThrowsError(try LocalAnswerProvider.decode(Data(#"{"choices":[{"message":{"content":""}}]}"#.utf8))) { error in
            XCTAssertEqual((error as? QuickProviderError)?.kind, "provider_empty_answer")
        }
        XCTAssertThrowsError(try LocalAnswerProvider.decode(Data("{}".utf8))) { error in
            XCTAssertEqual((error as? QuickProviderError)?.kind, "provider_malformed_response")
        }
    }

    // MARK: Scholarly providers (M005.1)

    func testArxivDecodeBuildsVersionlessAbstractHitsAndRejectsNonAbstracts() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <feed xmlns="http://www.w3.org/2005/Atom">
          <title>arXiv Query</title>
          <entry>
            <id>http://arxiv.org/abs/2401.12345v2</id>
            <title>Spaced Repetition at Scale</title>
            <summary>ignored discovery text</summary>
          </entry>
          <entry>
            <id>http://arxiv.org/abs/1706.03762v5</id>
            <title>Attention Is All You Need</title>
          </entry>
          <entry>
            <id>http://arxiv.org/list/cs.CL/2401</id>
            <title>Not an abstract page</title>
          </entry>
        </feed>
        """
        guard case let .hits(hits) = try ArxivAtomPayload.decode(Data(xml.utf8), query: "q", maxResults: 10) else {
            return XCTFail("expected arXiv hits")
        }
        XCTAssertEqual(hits.count, 2, "a listing page is not an abstract page")
        XCTAssertEqual(hits[0].url.absoluteString, "https://arxiv.org/abs/2401.12345")
        XCTAssertEqual(hits[0].title, "Spaced Repetition at Scale")
        XCTAssertEqual(hits[1].url.absoluteString, "https://arxiv.org/abs/1706.03762")
        XCTAssertTrue(hits.allSatisfy { $0.snippet.isEmpty }, "the Atom summary is discovery metadata, never evidence")
        XCTAssertThrowsError(try ArxivAtomPayload.decode(Data("not xml".utf8), query: "q", maxResults: 10))
        XCTAssertThrowsError(try ArxivAtomPayload.decode(Data("<other></other>".utf8), query: "q", maxResults: 10)) { error in
            guard case SearchError.malformedPayload = error else {
                return XCTFail("expected a typed malformed payload, got \(error)")
            }
        }
    }

    func testCrossrefDecodeNormalizesDOIAndUsesTheResolverAsIdentityAnchor() throws {
        let json = """
        {"message":{"items":[
          {"DOI":"10.1234/ABC","title":["A Study"],"URL":"https://journal.example.invalid/a","type":"journal-article"},
          {"DOI":"https://doi.org/10.5555/XYZ","title":["Only DOI"],"type":"journal-article"},
          {"DOI":null,"title":["No DOI"],"URL":"https://example.invalid/x"}
        ]}}
        """
        guard case let .hits(hits) = try CrossrefPayload.decode(Data(json.utf8), query: "q", maxResults: 10) else {
            return XCTFail("expected Crossref hits")
        }
        XCTAssertEqual(hits.count, 2, "a record with no DOI has no scholarly identity")
        XCTAssertEqual(hits[0].url.absoluteString, "https://doi.org/10.1234/abc")
        XCTAssertEqual(hits[1].url.absoluteString, "https://doi.org/10.5555/xyz")
        XCTAssertTrue(hits.allSatisfy { $0.snippet.isEmpty })
        XCTAssertThrowsError(try CrossrefPayload.decode(Data("{}".utf8), query: "q", maxResults: 10)) { error in
            guard case SearchError.malformedPayload = error else {
                return XCTFail("expected a typed malformed payload, got \(error)")
            }
        }
    }

    func testScholarlyIdentityIsCaseAndVersionInsensitive() {
        XCTAssertEqual(ScholarlyIdentity.normalizedDOI("https://doi.org/10.1000/XYZ"), "10.1000/xyz")
        XCTAssertEqual(ScholarlyIdentity.normalizedDOI("doi:10.1000/AbC"), "10.1000/abc")
        XCTAssertNil(ScholarlyIdentity.normalizedDOI("not-a-doi"))
        XCTAssertEqual(ScholarlyIdentity.versionlessArxivID("2401.12345v3"), "2401.12345")
        XCTAssertEqual(ScholarlyIdentity.versionlessArxivID("cs/0701001v1"), "cs/0701001")
        XCTAssertEqual(ScholarlyIdentity.identity(for: URL(string: "https://arxiv.org/abs/2401.12345v2")!), "arxiv:2401.12345")
        XCTAssertEqual(ScholarlyIdentity.identity(for: URL(string: "https://doi.org/10.1/AbC")!), "doi:10.1/abc")
        XCTAssertNil(ScholarlyIdentity.identity(for: URL(string: "https://blog.example.invalid/paper")!))
    }

    func testReconciliationCollapsesIdentityBearingDuplicatesDeterministically() {
        func hit(_ string: String, title: String, rank: Int) -> SearchHit {
            SearchHit(id: "h\(rank)", query: "q", rank: rank, url: URL(string: string)!, title: title, snippet: "")
        }
        // One DOI reported by two providers with different letter case is one
        // work; the first provider keeps the title and the position.
        let openAlex = hit("https://doi.org/10.1/AbC", title: "OpenAlex title", rank: 0)
        let crossref = hit("https://doi.org/10.1/abc", title: "Crossref title", rank: 1)
        let reconciled = ScholarlyReconciliation.reconcile([openAlex, crossref])
        XCTAssertEqual(reconciled.count, 1, "one DOI is one work")
        XCTAssertEqual(reconciled[0].title, "OpenAlex title", "the first provider supplies the title")
        XCTAssertEqual(reconciled[0].rank, 0, "the first-seen position is preserved")

        // Two versions of one arXiv paper are one work, and the versionless
        // abstract page is the readable target.
        let arxivV2 = hit("https://arxiv.org/abs/2401.12345v2", title: "arXiv v2", rank: 2)
        let arxivV3 = hit("https://arxiv.org/abs/2401.12345v3", title: "arXiv v3", rank: 3)
        let versions = ScholarlyReconciliation.reconcile([arxivV2, arxivV3])
        XCTAssertEqual(versions.count, 1, "two versions are one work")
        XCTAssertEqual(versions[0].url.absoluteString, "https://arxiv.org/abs/2401.12345v2")

        // A publisher URL carries no scholarly identity, so it is not merged
        // with a resolver URL; it stays a separate readable candidate.
        let publisher = hit("https://journal.example.invalid/a", title: "Publisher", rank: 4)
        XCTAssertEqual(ScholarlyReconciliation.reconcile([openAlex, publisher]).count, 2)
    }

    func testPrimarySourceOrderingPutsPapersBeforeAggregators() {
        func hit(_ string: String, rank: Int) -> SearchHit {
            SearchHit(id: "h\(rank)", query: "q", rank: rank, url: URL(string: string)!, title: "t", snippet: "")
        }
        let aggregator = hit("https://www.researchgate.net/publication/1", rank: 0)
        let general = hit("https://blog.example.invalid/x", rank: 1)
        let paper = hit("https://arxiv.org/abs/2401.12345", rank: 2)
        let reconciled = ScholarlyReconciliation.reconcile([aggregator, general, paper])
        XCTAssertEqual(
            reconciled.map(\.url.absoluteString),
            ["https://arxiv.org/abs/2401.12345", "https://blog.example.invalid/x", "https://www.researchgate.net/publication/1"],
            "a primary paper target opens before an aggregator that summarizes it"
        )
        XCTAssertEqual(ScholarlyReconciliation.primarySourceRank(URL(string: "https://doi.org/10.1/x")!), 0)
        XCTAssertEqual(ScholarlyReconciliation.primarySourceRank(URL(string: "https://pmc.ncbi.nlm.nih.gov/articles/PMC1")!), 0)
        XCTAssertEqual(ScholarlyReconciliation.primarySourceRank(URL(string: "https://some.blog/x")!), 1)
        XCTAssertEqual(ScholarlyReconciliation.primarySourceRank(URL(string: "https://medium.com/x")!), 2)
        XCTAssertEqual(ScholarlyReconciliation.primarySourceRank(URL(string: "https://en.wikipedia.org/wiki/X")!), 2)
    }

    // MARK: Export

    func testCitationExportIsDeterministicDeduplicatedAndEscaped() {
        func citation(_ marker: Int, heading: String, url: String?, passage: String) -> LiveAnswerArtifact.Citation {
            LiveAnswerArtifact.Citation(
                marker: marker,
                claimText: "claim \(marker)",
                quote: "quote \(marker)",
                passageID: "p\(marker)",
                snapshotID: "s\(marker)",
                heading: heading,
                sourceURL: url.flatMap(URL.init(string:)),
                passageText: passage
            )
        }
        let artifact = LiveAnswerArtifact(
            question: "Q",
            answer: "A [1] [2] [3]",
            label: "local",
            provider: "local/m",
            generatedAt: "t",
            elapsedSeconds: 2,
            citations: [
                citation(1, heading: "Paper {A}", url: "https://a.example.invalid/1", passage: "one"),
                citation(2, heading: "Paper A again", url: "https://a.example.invalid/1", passage: "two"),
                citation(3, heading: "Work B", url: "https://b.example.invalid/2", passage: "three"),
            ]
        )
        let bib = CitationExport.bibTeX(artifact)
        XCTAssertEqual(bib, CitationExport.bibTeX(artifact), "export must be deterministic")
        XCTAssertEqual(bib.components(separatedBy: "@misc{").count - 1, 2, "one cited work per URL")
        XCTAssertTrue(bib.contains("Paper \\{A\\}"), "a brace in a title is escaped, not truncated")
        XCTAssertTrue(bib.contains("https://b.example.invalid/2"))
        XCTAssertTrue(bib.contains("Local Lens exact passage p1"))

        let ris = CitationExport.ris(artifact)
        XCTAssertEqual(ris.components(separatedBy: "TY  - ELEC").count - 1, 2)
        XCTAssertTrue(ris.contains("ER  - "))

        let markdown = CitationExport.markdown(artifact)
        XCTAssertTrue(markdown.contains("# Q"))
        XCTAssertTrue(markdown.contains("local · 3 exact passages"))
        XCTAssertTrue(markdown.contains("> quote 3"))
    }

    // MARK: Helpers

    /// Yields until `condition` holds. It never waits on the wall clock, so a
    /// gate that wrongly blocks fails the test rather than hanging it.
    private func waitUntil(attempts: Int = 2_000, _ condition: @Sendable () async -> Bool) async -> Bool {
        for _ in 0..<attempts {
            if await condition() { return true }
            await Task.yield()
        }
        return await condition()
    }

    /// The same as `boundedFetch`, with a name that reads better at call sites
    /// where a failure is injected around it.
    private func builtFetch(
        _ byURL: [String: String],
        store: SnapshotStore
    ) -> @Sendable ([FetchTarget]) async throws -> [FetchResult] {
        boundedFetch(byURL, store: store)
    }

    /// A page whose body holds many paragraphs, for the saturation test.
    private func richFetch(
        _ byURL: [String: String],
        store: SnapshotStore
    ) -> @Sendable ([FetchTarget]) async throws -> [FetchResult] {
        let bodies = byURL
        return { targets in
            var results: [FetchResult] = []
            for target in targets {
                guard let body = bodies[target.url.absoluteString] else { continue }
                let acquisition = AcquisitionResult(
                    requestedURL: target.url,
                    finalURL: target.url,
                    statusCode: 200,
                    contentType: "text/html",
                    body: Data("<html><body><h1>Heading</h1><p>\(body)</p></body></html>".utf8),
                    redirects: []
                )
                let page = try HTMLExtraction.extract(acquisition, sourceID: target.sourceID)
                let outcome = try await store.store(page)
                results.append(
                    FetchResult(
                        sourceID: target.sourceID,
                        url: target.url,
                        outcome: .stored(outcome.record),
                        attempt: 1,
                        attempts: 1
                    )
                )
            }
            return results
        }
    }

    private func hit(_ string: String, query: String, rank: Int = 0) -> SearchHit {
        SearchHit(id: "\(query)-\(string)", query: query, rank: rank, url: URL(string: string)!, title: "Source", snippet: "")
    }

    private func search(_ byQuery: [String: [SearchHit]]) -> @Sendable (String) async throws -> SearchOutcome {
        { query in
            let hits = byQuery[query] ?? []
            return hits.isEmpty ? .noResults(query: query) : .hits(hits)
        }
    }

    private func boundedFetch(
        _ byURL: [String: String],
        store: SnapshotStore
    ) -> @Sendable ([FetchTarget]) async throws -> [FetchResult] {
        let bodies = byURL
        return { targets in
            var results: [FetchResult] = []
            for target in targets {
                guard let body = bodies[target.url.absoluteString] else {
                    results.append(
                        FetchResult(
                            sourceID: target.sourceID,
                            url: target.url,
                            outcome: .refused(FetchRefusal(stage: .acquisition, kind: "transport_failure", reason: "no fixture body")),
                            attempt: 1,
                            attempts: 1
                        )
                    )
                    continue
                }
                let acquisition = AcquisitionResult(
                    requestedURL: target.url,
                    finalURL: target.url,
                    statusCode: 200,
                    contentType: "text/html",
                    body: Data("<html><body><h1>Heading</h1><p>\(body)</p></body></html>".utf8),
                    redirects: []
                )
                let page = try HTMLExtraction.extract(acquisition, sourceID: target.sourceID)
                let outcome = try await store.store(page)
                results.append(
                    FetchResult(
                        sourceID: target.sourceID,
                        url: target.url,
                        outcome: .stored(outcome.record),
                        attempt: 1,
                        attempts: 1
                    )
                )
            }
            return results
        }
    }
}

/// Counts fetch attempts so a failure can be injected exactly once.
private final class AttemptCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    private var searches = 0
    func next() -> Int { lock.withLock { count += 1; return count } }
    func searchCount() -> Int { lock.withLock { searches += 1; return searches } }
}

/// A dated adapter with no transport, so the window can be tested offline.
private struct FixedDatedAdapter: DatedSearchAdapter {
    let queries: [String: [DatedHit]]
    func searchDated(_ query: String) async throws -> [DatedHit] { queries[query] ?? [] }
}
