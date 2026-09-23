import Foundation
import XCTest
@testable import LocalLensCore

// MARK: - Frozen scenario fixture

/// The retrieval decision table lives in
/// `Fixtures/retrieval/lexical-scenarios.json` so the ranking rules are
/// reviewable as data. It is hand-authored, synthetic, and contains no captured
/// page and no resolvable host.
private struct LexicalFixture: Decodable, Sendable {
    struct Meta: Decodable, Sendable {
        let synthetic: Bool
        let license: String
        let note: String
        let shape: String
    }

    struct Document: Decodable, Sendable {
        let id: String
        let source_id: String
        let url: String
        let content_type: String
        let why: String
        let body: String
    }

    struct Expected: Decodable, Sendable {
        let source_id: String
        let ordinal: Int
    }

    struct Query: Decodable, Sendable {
        let id: String
        let why: String
        let query: String
        let limit: Int
        let expected: [Expected]
    }

    struct Refusal: Decodable, Sendable {
        let id: String
        let why: String
        let operation: String
        let query: String?
        let limit: Int?
        let passage_id: String?
        let expected_kind: String
        let expected_reason_contains: String
    }

    let _fixture: Meta
    let documents: [Document]
    let queries: [Query]
    let refusals: [Refusal]
}

/// A hit's location, so a candidate order can be compared without depending on
/// a content hash that the reader cannot see.
private struct HitLocation: Equatable, Sendable {
    let sourceID: String
    let ordinal: Int
}

final class LexicalIndexTests: XCTestCase {

    // MARK: Helpers

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private var fixtureURL: URL {
        repositoryRoot.appendingPathComponent("Fixtures/retrieval/lexical-scenarios.json")
    }

    private func fixtureData() throws -> Data {
        try Data(contentsOf: fixtureURL)
    }

    private func loadFixture() throws -> LexicalFixture {
        try JSONDecoder().decode(LexicalFixture.self, from: try fixtureData())
    }

    /// Extracts a fixture body through the M002.4 boundary, so the index is fed
    /// exactly what the pipeline would hand it. No transport, socket, resolver,
    /// or file is involved.
    private func page(for document: LexicalFixture.Document) throws -> ExtractedPage {
        let requestedURL = try XCTUnwrap(URL(string: document.url))
        let result = AcquisitionResult(
            requestedURL: requestedURL,
            finalURL: requestedURL,
            statusCode: 200,
            contentType: document.content_type,
            body: Data(document.body.utf8),
            redirects: []
        )
        return try HTMLExtraction.extract(result, sourceID: document.source_id)
    }

    /// Builds the full pipeline from the fixture: bytes -> extraction -> snapshot
    /// store -> lexical index. The index therefore holds stored passages, never
    /// fixture rows authored to look like passages.
    private func indexedFixture(
        policy: LexicalQueryPolicy = .default
    ) async throws -> (index: LexicalIndex, store: SnapshotStore, records: [SnapshotRecord]) {
        let fixture = try loadFixture()
        let store = SnapshotStore()
        for document in fixture.documents {
            _ = try await store.store(try page(for: document))
        }
        let records = await store.records()
        let index = try LexicalIndex(policy: policy)
        for record in records {
            _ = try await index.ingest(record)
        }
        return (index, store, records)
    }

    // MARK: Fixture integrity

    func testFixtureIsSyntheticOfflineAndExplained() throws {
        let root = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: try fixtureData()) as? [String: Any]
        )
        let meta = try XCTUnwrap(root["_fixture"] as? [String: Any])
        XCTAssertEqual(meta["synthetic"] as? Bool, true)
        XCTAssertEqual(meta["license"] as? String, "redistributable")
        XCTAssertFalse((meta["note"] as? String ?? "").isEmpty)

        let fixture = try loadFixture()
        XCTAssertEqual(fixture._fixture.shape, "LexicalRetrievalFixture")
        XCTAssertEqual(fixture.documents.count, 6)
        XCTAssertEqual(fixture.queries.count, 4)
        XCTAssertEqual(fixture.refusals.count, 6)

        var ids: [String] = []
        for document in try XCTUnwrap(root["documents"] as? [[String: Any]]) {
            ids.append(try XCTUnwrap(document["id"] as? String))
            XCTAssertFalse((document["why"] as? String ?? "").isEmpty)
            let url = try XCTUnwrap(URL(string: try XCTUnwrap(document["url"] as? String)))
            XCTAssertEqual(url.host?.hasSuffix(".invalid"), true, "\(document["id"] ?? "?") must stay on a non-resolvable host")
        }
        XCTAssertEqual(Set(ids).count, ids.count, "document ids must be unique")

        for entry in try XCTUnwrap(root["queries"] as? [[String: Any]]) {
            XCTAssertFalse((entry["why"] as? String ?? "").isEmpty)
            XCTAssertGreaterThanOrEqual((entry["limit"] as? Int) ?? 0, 1)
        }
        for refusal in fixture.refusals {
            XCTAssertFalse(refusal.why.isEmpty)
            XCTAssertTrue(["query", "resolve"].contains(refusal.operation), "unknown operation \(refusal.operation)")
        }
    }

    // MARK: Ranking

    func testQueriesReturnTheFrozenRankedOrder() async throws {
        let fixture = try loadFixture()
        let (index, _, _) = try await indexedFixture()

        for entry in fixture.queries {
            let context = "\(entry.id): \(entry.why)"
            let hits = try await index.search(entry.query, limit: entry.limit)
            let actual = hits.map { HitLocation(sourceID: $0.sourceID, ordinal: $0.passage.ordinal) }
            let expected = entry.expected.map { HitLocation(sourceID: $0.source_id, ordinal: $0.ordinal) }
            XCTAssertEqual(actual, expected, context)
            XCTAssertEqual(hits.map(\.rank), Array(1...hits.count), "\(context): rank must be the 1-based position")
        }
    }

    func testResultLimitTruncatesTheRankedOrder() async throws {
        let (index, _, _) = try await indexedFixture()
        let full = try await index.search("quokka", limit: 10)
        let bounded = try await index.search("quokka", limit: 2)

        XCTAssertEqual(full.count, 3)
        XCTAssertEqual(bounded.count, 2)
        XCTAssertEqual(bounded.map(\.passage.id), full.prefix(2).map(\.passage.id))
    }

    func testResultLimitCannotExceedTheRecordedPolicy() async throws {
        let (index, _, _) = try await indexedFixture()

        // Exactly the recorded maximum is honoured.
        let atMaximum = try await index.search("water", limit: 10)
        XCTAssertFalse(atMaximum.isEmpty, "the maximum limit must still retrieve")

        // One above it is refused rather than silently capped.
        do {
            _ = try await index.search("water", limit: 11)
            XCTFail("a limit above the policy maximum must be refused")
        } catch let error as LexicalIndexError {
            XCTAssertEqual(error.kind, "limit_exceeds_policy")
            XCTAssertTrue(error.reason.contains("exceeds the policy maximum"), error.reason)
        }
    }

    func testEqualScoresAreBrokenByTheRecordedRule() async throws {
        // The default diversity bound would hide the third tied body match, so
        // this case widens the bound to observe every tie member.
        let permissive = try LexicalQueryPolicy(maximumPassagesPerSource: 5, maximumCandidates: 200)
        let (index, _, _) = try await indexedFixture(policy: permissive)
        let hits = try await index.search("quokka", limit: 10)

        // The recorded rule: ascending score, then ascending ordinal, then
        // ascending passage id. The returned order must already satisfy it.
        let ordered = hits.sorted { first, second in
            if first.score != second.score { return first.score < second.score }
            if first.passage.ordinal != second.passage.ordinal {
                return first.passage.ordinal < second.passage.ordinal
            }
            return first.passage.id < second.passage.id
        }
        XCTAssertEqual(hits, ordered, "the result must satisfy the recorded tie-break rule")

        // Three body-only matches are genuinely tied, and the ordinal rule is
        // what separates them.
        let tied = hits.filter { $0.sourceID == "src-tie" }
        XCTAssertEqual(tied.count, 3)
        XCTAssertEqual(Set(tied.map(\.score)).count, 1, "equal-length, equal-frequency passages must tie")
        XCTAssertEqual(tied.map(\.passage.ordinal), [1, 2, 3])
    }

    func testRankingIsDeterministicAcrossRepeatedRunsAndIndexes() async throws {
        let fixture = try loadFixture()
        let (index, _, records) = try await indexedFixture()

        for entry in fixture.queries {
            let first = try await index.search(entry.query, limit: entry.limit)
            for _ in 0..<4 {
                let repeatRun = try await index.search(entry.query, limit: entry.limit)
                XCTAssertEqual(repeatRun, first, entry.id)
            }

            let rebuilt = try LexicalIndex()
            for record in records {
                _ = try await rebuilt.ingest(record)
            }
            let rebuiltHits = try await rebuilt.search(entry.query, limit: entry.limit)
            XCTAssertEqual(rebuiltHits, first, "\(entry.id): a second index must rank identically")
        }
    }

    // MARK: Evidence admission

    func testEveryHitResolvesToAStoredPassageAndSnapshot() async throws {
        let fixture = try loadFixture()
        let (index, store, _) = try await indexedFixture()

        for entry in fixture.queries {
            for hit in try await index.search(entry.query, limit: entry.limit) {
                let evidence = try await index.resolve(hit.passage.id)
                XCTAssertEqual(evidence.passage, hit.passage, entry.id)
                XCTAssertEqual(evidence.sourceID, hit.sourceID, entry.id)

                // The hit must resolve through the snapshot store that produced
                // the indexed passage, not through a fixture row.
                let record = try await store.record(id: hit.passage.snapshotID)
                XCTAssertEqual(record.snapshot.sourceID, hit.sourceID, entry.id)
                XCTAssertTrue(record.passages.contains(hit.passage), "\(entry.id): the hit must be a stored passage")
            }
        }
    }

    func testTheDiversityBoundCapsPassagesPerSource() async throws {
        let (defaultIndex, _, _) = try await indexedFixture()
        let defaultHits = try await defaultIndex.search("water", limit: 10)
        XCTAssertFalse(defaultHits.isEmpty)
        for (source, count) in Dictionary(grouping: defaultHits, by: \.sourceID).mapValues(\.count) {
            XCTAssertLessThanOrEqual(count, 2, "\(source) exceeded the default per-source bound")
        }

        let single = try LexicalQueryPolicy(maximumPassagesPerSource: 1, maximumCandidates: 200)
        let (strictIndex, _, _) = try await indexedFixture(policy: single)
        let strictHits = try await strictIndex.search("water", limit: 10)
        let counts = Dictionary(grouping: strictHits, by: \.sourceID).mapValues(\.count)
        XCTAssertEqual(counts.values.max(), 1)
        XCTAssertGreaterThan(strictHits.count, 1, "the bound must not collapse the result to one hit")
    }

    // MARK: Typed refusals

    func testRefusalsProduceTypedOutcomes() async throws {
        let fixture = try loadFixture()
        let (index, _, _) = try await indexedFixture()

        for refusal in fixture.refusals {
            let context = "\(refusal.id): \(refusal.why)"
            do {
                switch refusal.operation {
                case "query":
                    let query = try XCTUnwrap(refusal.query)
                    if let limit = refusal.limit {
                        _ = try await index.search(query, limit: limit)
                    } else {
                        _ = try await index.search(query)
                    }
                case "resolve":
                    _ = try await index.resolve(try XCTUnwrap(refusal.passage_id))
                default:
                    XCTFail("\(context): unknown operation \(refusal.operation)")
                }
                XCTFail("\(context): expected a typed refusal")
            } catch let error as LexicalIndexError {
                XCTAssertEqual(error.kind, refusal.expected_kind, context)
                XCTAssertTrue(
                    error.reason.contains(refusal.expected_reason_contains),
                    "\(context): expected the reason to explain itself, got \(error.reason)"
                )
            }
        }
    }

    func testTypedOutcomeFamilyIsEnumerated() {
        let family: [LexicalIndexError] = [
            .unavailable(reason: "why"),
            .invalidPolicy(reason: "why"),
            .invalidSnapshot(reason: "why"),
            .invalidPassage(passageID: "passage", reason: "why"),
            .emptyQuery,
            .invalidLimit(limit: 0),
            .limitExceedsPolicy(limit: 11, maximum: 10),
            .unknownPassage(passageID: "passage"),
            .inconsistentRow(passageID: "passage", reason: "why"),
        ]
        XCTAssertEqual(
            family.map(\.kind),
            [
                "unavailable", "invalid_policy", "invalid_snapshot", "invalid_passage",
                "empty_query", "invalid_limit", "limit_exceeds_policy", "unknown_passage", "inconsistent_row",
            ]
        )
        for error in family {
            XCTAssertFalse(error.reason.isEmpty)
            XCTAssertEqual(error.errorDescription, error.reason)
        }

        let first = LexicalIngestOutcome.indexed(snapshotID: "snapshot", passageCount: 2)
        let repeatOffer = LexicalIngestOutcome.duplicate(snapshotID: "snapshot", passageCount: 2)
        XCTAssertEqual([first.kind, repeatOffer.kind], ["indexed", "duplicate"])
        XCTAssertEqual(first.snapshotID, "snapshot")
        XCTAssertEqual(first.passageCount, 2)
    }

    // MARK: Ingest

    func testIngestIsIdempotentAndTyped() async throws {
        let fixture = try loadFixture()
        let document = try XCTUnwrap(fixture.documents.first)
        let store = SnapshotStore()
        let outcome = try await store.store(try page(for: document))
        let record = outcome.record

        let index = try LexicalIndex()
        let first = try await index.ingest(record)
        let second = try await index.ingest(record)

        XCTAssertEqual(first.kind, "indexed")
        XCTAssertEqual(first.passageCount, record.passages.count)
        XCTAssertEqual(second.kind, "duplicate")
        XCTAssertEqual(second.passageCount, record.passages.count)
        let count = try await index.passageCount()
        let snapshotIDs = try await index.indexedSnapshotIDs()
        XCTAssertEqual(count, record.passages.count)
        XCTAssertEqual(snapshotIDs, [record.snapshot.id])
    }

    func testInconsistentRecordsAreRefused() async throws {
        let fixture = try loadFixture()
        let page = try page(for: try XCTUnwrap(fixture.documents.first))
        let store = SnapshotStore()
        let record = try await store.store(page).record
        let index = try LexicalIndex()

        func refuses(_ mutated: SnapshotRecord) async {
            do {
                _ = try await index.ingest(mutated)
                XCTFail("expected a typed refusal")
            } catch let error as LexicalIndexError {
                XCTAssertTrue(
                    ["invalid_snapshot", "invalid_passage"].contains(error.kind),
                    "expected a consistency refusal, got \(error.kind)"
                )
            } catch {
                XCTFail("expected a LexicalIndexError, got \(error)")
            }
        }

        await refuses(
            SnapshotRecord(
                snapshot: record.snapshot,
                passages: [],
                sourceIDs: record.sourceIDs,
                requestedURLs: record.requestedURLs,
                finalURL: record.finalURL,
                attempt: record.attempt,
                duplicateAttempts: record.duplicateAttempts
            )
        )

        await refuses(
            SnapshotRecord(
                snapshot: Snapshot(
                    id: "snapshot-not-derived",
                    sourceID: record.snapshot.sourceID,
                    contentHash: record.snapshot.contentHash,
                    extractedText: record.snapshot.extractedText,
                    extractorVersion: record.snapshot.extractorVersion
                ),
                passages: record.passages,
                sourceIDs: record.sourceIDs,
                requestedURLs: record.requestedURLs,
                finalURL: record.finalURL,
                attempt: record.attempt,
                duplicateAttempts: record.duplicateAttempts
            )
        )

        await refuses(
            SnapshotRecord(
                snapshot: record.snapshot,
                passages: [
                    Passage(
                        id: record.passages[0].id,
                        snapshotID: record.passages[0].snapshotID,
                        ordinal: record.passages[0].ordinal,
                        heading: record.passages[0].heading,
                        text: record.passages[0].text,
                        textHash: "not-a-hash"
                    )
                ] + record.passages.dropFirst(),
                sourceIDs: record.sourceIDs,
                requestedURLs: record.requestedURLs,
                finalURL: record.finalURL,
                attempt: record.attempt,
                duplicateAttempts: record.duplicateAttempts
            )
        )

        let count = try await index.passageCount()
        XCTAssertEqual(count, 0, "a refused record must index nothing")
    }

    func testPolicyRefusesUnusableNumbers() {
        XCTAssertThrowsError(try LexicalQueryPolicy(maximumResults: 0)) { error in
            XCTAssertEqual((error as? LexicalIndexError)?.kind, "invalid_policy")
        }
        XCTAssertThrowsError(try LexicalQueryPolicy(maximumPassagesPerSource: 0)) { error in
            XCTAssertEqual((error as? LexicalIndexError)?.kind, "invalid_policy")
        }
        XCTAssertThrowsError(try LexicalQueryPolicy(maximumResults: 10, maximumCandidates: 5)) { error in
            XCTAssertEqual((error as? LexicalIndexError)?.kind, "invalid_policy")
        }
        XCTAssertThrowsError(try LexicalQueryPolicy(headingWeight: .nan)) { error in
            XCTAssertEqual((error as? LexicalIndexError)?.kind, "invalid_policy")
        }
        XCTAssertThrowsError(try LexicalQueryPolicy(bodyWeight: 0)) { error in
            XCTAssertEqual((error as? LexicalIndexError)?.kind, "invalid_policy")
        }
        XCTAssertNoThrow(try LexicalQueryPolicy())
    }

    func testAHugeCandidateBudgetIsHonouredRatherThanTrapped() async throws {
        // The candidate ceiling reaches SQL directly. A value at the top of
        // `Int` must bind exactly, not trap in a narrowing conversion and not
        // become SQLite's `LIMIT -1` ("no limit").
        let wide = try LexicalQueryPolicy(maximumCandidates: Int.max)
        XCTAssertEqual(wide.maximumCandidates, Int.max)

        let (index, _, _) = try await indexedFixture(policy: wide)
        let hits = try await index.search("water")
        XCTAssertFalse(hits.isEmpty, "a wide candidate budget must still retrieve")
    }

    // MARK: Durability

    func testDurableIndexSurvivesReopening() async throws {
        let fixture = try loadFixture()
        let document = try XCTUnwrap(fixture.documents.first)
        let store = SnapshotStore()
        let record = try await store.store(try page(for: document)).record

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("local-lens-lexical-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("lexical.sqlite").path

        let first = try LexicalIndex(databasePath: path)
        _ = try await first.ingest(record)

        let reopened = try LexicalIndex(databasePath: path)
        let snapshotIDs = try await reopened.indexedSnapshotIDs()
        XCTAssertEqual(snapshotIDs, [record.snapshot.id])
        let hits = try await reopened.search("espresso")
        XCTAssertFalse(hits.isEmpty, "a reopened index must still retrieve its stored passages")
        XCTAssertTrue(hits.allSatisfy { $0.passage.snapshotID == record.snapshot.id })
    }

    // MARK: Boundary guarantees

    func testIndexSourceHasNoNetworkDnsOrClockDependency() throws {
        // The index is local database work: no socket, no DNS, no wall clock,
        // and no snippet field, because a snippet is discovery metadata and can
        // never become evidence. The forbidden literals are built by
        // concatenation so this guard does not match its own source.
        let source = repositoryRoot.appendingPathComponent("Sources/LocalLensCore/LexicalIndex.swift")
        let text = try String(contentsOf: source, encoding: .utf8)

        for forbidden in [
            "URL" + "Session",
            "getaddr" + "info",
            "File" + "Manager",
            "Task" + ".sleep",
            "Date(",
            "snip" + "pet:",
        ] {
            XCTAssertFalse(text.contains(forbidden), "LexicalIndex must not reach for \(forbidden)")
        }
        XCTAssertEqual(
            text.components(separatedBy: "\n").filter { $0.hasPrefix("import ") },
            ["import Foundation", "import SQLite3"],
            "the index must not grow a dependency it does not need"
        )
    }
}
