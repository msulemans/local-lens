import Foundation
import XCTest
@testable import LocalLensCore

// MARK: - Frozen scenario fixture

/// The offer sequence lives in `Fixtures/snapshots/store-scenarios.json` so the
/// deduplication contract is reviewable as data. It is hand-authored, synthetic,
/// and contains no captured page and no live host.
private struct SnapshotStoreFixture: Decodable, Sendable {
    struct Meta: Decodable, Sendable {
        let synthetic: Bool
        let license: String
        let note: String
        let shape: String
    }

    struct Expected: Decodable, Sendable {
        let outcome: String
        let duplicate_reason: String?
        let snapshot_source_id: String
        let source_ids: [String]
        let requested_urls: [String]
        let passage_count: Int
        let total_attempts: Int
        let text: String
    }

    struct Case: Decodable, Sendable {
        let id: String
        let why: String
        let source_id: String
        let requested_url: String
        let final_url: String
        let content_type: String
        let body: String
        let attempt: Int
        let expected: Expected
    }

    struct Refusal: Decodable, Sendable {
        let id: String
        let why: String
        let operation: String
        let source_id: String?
        let requested_url: String?
        let final_url: String?
        let content_type: String?
        let body: String?
        let attempt: Int?
        let hit_id: String?
        let hit_url: String?
        let snapshot_id: String?
        let expected_kind: String
        let expected_reason_contains: String
    }

    let _fixture: Meta
    let cases: [Case]
    let refusals: [Refusal]
}

final class SnapshotStoreTests: XCTestCase {

    // MARK: Helpers

    private var fixtureURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/snapshots/store-scenarios.json")
    }

    private func fixtureData() throws -> Data {
        try Data(contentsOf: fixtureURL)
    }

    private func loadFixture() throws -> SnapshotStoreFixture {
        try JSONDecoder().decode(SnapshotStoreFixture.self, from: try fixtureData())
    }

    /// Extracts a fixture body through the M002.4 boundary, so the store is fed
    /// exactly what the pipeline would hand it. No transport, socket, resolver,
    /// or file is involved.
    private func page(
        sourceID: String,
        requested: String,
        final: String,
        contentType: String,
        body: String
    ) throws -> ExtractedPage {
        let requestedURL = try XCTUnwrap(URL(string: requested))
        let finalURL = try XCTUnwrap(URL(string: final))
        let result = AcquisitionResult(
            requestedURL: requestedURL,
            finalURL: finalURL,
            statusCode: 200,
            contentType: contentType,
            body: Data(body.utf8),
            redirects: requested == final ? [] : [finalURL]
        )
        return try HTMLExtraction.extract(result, sourceID: sourceID)
    }

    private func page(for entry: SnapshotStoreFixture.Case) throws -> ExtractedPage {
        try page(
            sourceID: entry.source_id,
            requested: entry.requested_url,
            final: entry.final_url,
            contentType: entry.content_type,
            body: entry.body
        )
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
        XCTAssertEqual(fixture._fixture.shape, "SnapshotStoreFixture")
        XCTAssertEqual(fixture.cases.count, 5)
        XCTAssertEqual(fixture.refusals.count, 4)

        var urls: [String] = []
        for entry in try XCTUnwrap(root["cases"] as? [[String: Any]]) {
            urls.append(try XCTUnwrap(entry["requested_url"] as? String))
            urls.append(try XCTUnwrap(entry["final_url"] as? String))
            XCTAssertFalse((entry["why"] as? String ?? "").isEmpty)
            let expected = try XCTUnwrap(entry["expected"] as? [String: Any])
            let outcome = try XCTUnwrap(expected["outcome"] as? String)
            XCTAssertTrue(["stored", "duplicate"].contains(outcome), "unknown expected outcome \(outcome)")
            if outcome == "duplicate" {
                XCTAssertFalse((expected["duplicate_reason"] as? String ?? "").isEmpty)
            }
        }
        for entry in try XCTUnwrap(root["refusals"] as? [[String: Any]]) {
            XCTAssertFalse((entry["why"] as? String ?? "").isEmpty)
            let operation = try XCTUnwrap(entry["operation"] as? String)
            XCTAssertTrue(["store", "hit", "record"].contains(operation), "unknown operation \(operation)")
            if operation == "hit" {
                urls.append(try XCTUnwrap(entry["hit_url"] as? String))
            }
            if let requested = entry["requested_url"] as? String {
                urls.append(requested)
                urls.append(try XCTUnwrap(entry["final_url"] as? String))
            }
        }

        for raw in urls {
            let url = try XCTUnwrap(URL(string: raw))
            XCTAssertEqual(url.host?.hasSuffix(".invalid"), true, "\(raw) must stay on a non-resolvable host")
        }
    }

    // MARK: Deduplication

    func testOfferSequenceStoresOnceAndRecordsEveryAttempt() async throws {
        let fixture = try loadFixture()
        let store = SnapshotStore()
        var seen: [String] = []

        for entry in fixture.cases {
            let outcome = try await store.store(try page(for: entry), attempt: entry.attempt)
            let context = "\(entry.id): \(entry.why)"

            XCTAssertEqual(outcome.kind, entry.expected.outcome, context)
            XCTAssertEqual(outcome.duplicateReason?.rawValue, entry.expected.duplicate_reason, context)

            let record = outcome.record
            seen.append(record.id)
            XCTAssertEqual(record.snapshot.sourceID, entry.expected.snapshot_source_id, context)
            XCTAssertEqual(record.sourceIDs, entry.expected.source_ids, context)
            XCTAssertEqual(record.requestedURLs.map(\.absoluteString), entry.expected.requested_urls, context)
            XCTAssertEqual(record.passages.count, entry.expected.passage_count, context)
            XCTAssertEqual(record.totalAttempts, entry.expected.total_attempts, context)
            XCTAssertEqual(record.snapshot.extractedText, entry.expected.text, context)
            XCTAssertEqual(record.snapshot.extractedText, record.passages.map(\.text).joined(separator: "\n\n"), context)
            XCTAssertEqual(record.snapshot.extractorVersion, "html-extractor-1", context)
        }

        // Four offers of the same bytes and one of different bytes: two snapshots.
        let count = await store.snapshotCount()
        XCTAssertEqual(count, 2)
        XCTAssertEqual(Set(seen.prefix(4)).count, 1, "the first four offers must all resolve to one snapshot")
        XCTAssertNotEqual(seen[0], seen[4], "different bytes must not collapse into the first snapshot")

        let records = await store.records()
        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(records.map(\.snapshot.id).sorted(), Set(seen).sorted())
    }

    func testStoredIdentityIsTheExtractorsIdentityAndIsStableAcrossStores() async throws {
        let fixture = try loadFixture()
        let entry = try XCTUnwrap(fixture.cases.first)
        let extracted = try page(for: entry)

        let first = SnapshotStore()
        let second = SnapshotStore()
        let firstOutcome = try await first.store(extracted, attempt: entry.attempt)
        let secondOutcome = try await second.store(extracted, attempt: entry.attempt)

        XCTAssertEqual(firstOutcome.kind, "stored")
        XCTAssertEqual(secondOutcome.kind, "stored")
        XCTAssertEqual(firstOutcome.record, secondOutcome.record)
        XCTAssertEqual(firstOutcome.record.snapshot, extracted.snapshot)
        XCTAssertEqual(firstOutcome.record.passages, extracted.passages)
        XCTAssertEqual(firstOutcome.record.snapshot.id, StableIdentity.make("snapshot", entry.source_id, extracted.contentHash))

        let reloaded = try await first.record(id: extracted.snapshot.id)
        XCTAssertEqual(reloaded, firstOutcome.record)
        let passages = try await first.passages(snapshotID: extracted.snapshot.id)
        XCTAssertEqual(passages, extracted.passages)
    }

    func testDuplicateOffersNeverRewriteTheStoredIdentity() async throws {
        let fixture = try loadFixture()
        let store = SnapshotStore()

        var firstRecord: SnapshotRecord?
        for entry in fixture.cases {
            let outcome = try await store.store(try page(for: entry), attempt: entry.attempt)
            if firstRecord == nil {
                firstRecord = outcome.record
            } else if outcome.kind == "duplicate" {
                XCTAssertEqual(outcome.record.snapshot.id, firstRecord?.snapshot.id, entry.id)
                XCTAssertEqual(outcome.record.passages, firstRecord?.passages, entry.id)
                XCTAssertEqual(outcome.record.attempt, firstRecord?.attempt, entry.id)
            }
        }

        // The stored attempt is the one that produced the bytes, not the last
        // offer that happened to arrive. The record is re-read from the store
        // because every later offer updated it in place.
        let alpha = try await store.record(id: try XCTUnwrap(firstRecord).snapshot.id)
        XCTAssertEqual(alpha.attempt, 1)
        XCTAssertEqual(alpha.duplicateAttempts, 3)
        XCTAssertEqual(alpha.totalAttempts, 4)
    }

    func testRecordsOrderIsDeterministicRegardlessOfInsertionOrder() async throws {
        let fixture = try loadFixture()
        let alpha = try page(for: try XCTUnwrap(fixture.cases.first))
        let gamma = try page(for: try XCTUnwrap(fixture.cases.last))

        let forward = SnapshotStore()
        try await forward.store(alpha)
        try await forward.store(gamma)

        let backward = SnapshotStore()
        try await backward.store(gamma)
        try await backward.store(alpha)

        let forwardRecords = await forward.records()
        let backwardRecords = await backward.records()
        XCTAssertEqual(forwardRecords, backwardRecords)
    }

    func testConcurrentOffersOfTheSameBytesStoreExactlyOneSnapshot() async throws {
        let fixture = try loadFixture()
        let entry = try XCTUnwrap(fixture.cases.first)
        let extracted = try page(for: entry)
        let store = SnapshotStore()

        let outcomes = try await withThrowingTaskGroup(of: SnapshotStoreOutcome.self) { group in
            for _ in 0..<8 {
                group.addTask { try await store.store(extracted) }
            }
            var collected: [SnapshotStoreOutcome] = []
            for try await outcome in group {
                collected.append(outcome)
            }
            return collected
        }

        XCTAssertEqual(outcomes.count, 8)
        XCTAssertEqual(outcomes.filter { $0.kind == "stored" }.count, 1, "exactly one offer may store")
        XCTAssertEqual(outcomes.filter { $0.kind == "duplicate" }.count, 7)
        XCTAssertTrue(outcomes.allSatisfy { $0.record.snapshot.id == extracted.snapshot.id })

        let count = await store.snapshotCount()
        XCTAssertEqual(count, 1)
        let record = try await store.record(id: extracted.snapshot.id)
        XCTAssertEqual(record.duplicateAttempts, 7)
        XCTAssertEqual(record.totalAttempts, 8)
    }

    // MARK: Evidence admission

    func testAHitResolvesOnlyThroughAnAcquiredAndExtractedSnapshot() async throws {
        let fixture = try loadFixture()
        let entry = try XCTUnwrap(fixture.cases.first)
        let store = SnapshotStore()
        let stored = try await store.store(try page(for: entry))

        let hitURL = try XCTUnwrap(URL(string: entry.requested_url))
        let hit = SearchHit(
            id: "hit-fetched",
            query: "alpha",
            rank: 1,
            url: hitURL,
            title: "Alpha",
            snippet: "a snippet that must never become evidence"
        )
        let resolved = try await store.record(forHit: hit)
        XCTAssertEqual(resolved.snapshot.id, stored.record.snapshot.id)
        XCTAssertFalse(resolved.snapshot.extractedText.contains("snippet"), "the snippet must not reach the snapshot")

        // A hit that points at the pre-redirect URL still resolves, because the
        // store records every URL it actually requested.
        let aliasedURL = try XCTUnwrap(URL(string: entry.requested_url + "?utm_source=hit"))
        let aliased = SearchHit(
            id: "hit-aliased",
            query: "alpha",
            rank: 2,
            url: aliasedURL,
            title: "Alpha",
            snippet: "snippet"
        )
        do {
            _ = try await store.record(forHit: aliased)
            XCTFail("a URL that was never fetched must not resolve to evidence")
        } catch let error as SnapshotStoreError {
            XCTAssertEqual(error.kind, "hit_is_not_evidence")
        }
    }

    func testRefusalsProduceTypedOutcomes() async throws {
        let fixture = try loadFixture()
        let store = SnapshotStore()
        for entry in fixture.cases {
            try await store.store(try page(for: entry), attempt: entry.attempt)
        }

        for refusal in fixture.refusals {
            let context = "\(refusal.id): \(refusal.why)"
            do {
                switch refusal.operation {
                case "store":
                    let result = AcquisitionResult(
                        requestedURL: try XCTUnwrap(URL(string: try XCTUnwrap(refusal.requested_url))),
                        finalURL: try XCTUnwrap(URL(string: try XCTUnwrap(refusal.final_url))),
                        statusCode: 200,
                        contentType: try XCTUnwrap(refusal.content_type),
                        body: Data(try XCTUnwrap(refusal.body).utf8),
                        redirects: []
                    )
                    let page = try HTMLExtraction.extract(
                        result,
                        sourceID: try XCTUnwrap(refusal.source_id)
                    )
                    _ = try await store.store(page, attempt: try XCTUnwrap(refusal.attempt))
                case "hit":
                    let hit = SearchHit(
                        id: try XCTUnwrap(refusal.hit_id),
                        query: "query",
                        rank: 1,
                        url: try XCTUnwrap(URL(string: try XCTUnwrap(refusal.hit_url))),
                        title: "title",
                        snippet: "snippet"
                    )
                    _ = try await store.record(forHit: hit)
                case "record":
                    _ = try await store.record(id: try XCTUnwrap(refusal.snapshot_id))
                default:
                    XCTFail("\(context): unknown operation \(refusal.operation)")
                }
                XCTFail("\(context): expected a typed refusal")
            } catch let error as SnapshotStoreError {
                XCTAssertEqual(error.kind, refusal.expected_kind, context)
                XCTAssertTrue(
                    error.reason.contains(refusal.expected_reason_contains),
                    "\(context): expected the reason to explain itself, got \(error.reason)"
                )
            }
        }

        // The refused offers must not have stored anything: two snapshots only.
        let count = await store.snapshotCount()
        XCTAssertEqual(count, 2)
    }

    func testTypedOutcomeFamilyIsEnumerated() {
        let family: [SnapshotStoreError] = [
            .invalidAttempt(attempt: 0),
            .inconsistentPage(reason: "why"),
            .hitIsNotEvidence(hitID: "hit", url: URL(string: "https://example.invalid/hit")!),
            .unknownSnapshot(id: "snapshot"),
        ]
        XCTAssertEqual(
            family.map(\.kind),
            ["invalid_attempt", "inconsistent_page", "hit_is_not_evidence", "unknown_snapshot"]
        )
        for error in family {
            XCTAssertFalse(error.reason.isEmpty)
            XCTAssertEqual(error.errorDescription, error.reason)
        }
        XCTAssertEqual(
            [DuplicateReason.repeatedAttempt, .sameContentFromAnotherURL, .sameBytesFromAnotherSource].map(\.rawValue),
            ["repeated_attempt", "same_content_from_another_url", "same_bytes_from_another_source"]
        )
    }

    func testInconsistentPagesAreRefused() async throws {
        let fixture = try loadFixture()
        let entry = try XCTUnwrap(fixture.cases.first)
        let page = try page(for: entry)
        let store = SnapshotStore()

        func assertRefused(_ mutated: ExtractedPage, _ expectation: String) async {
            do {
                _ = try await store.store(mutated)
                XCTFail("expected inconsistent_page for \(expectation)")
            } catch let error as SnapshotStoreError {
                XCTAssertEqual(error.kind, "inconsistent_page", expectation)
            } catch {
                XCTFail("expected a SnapshotStoreError for \(expectation), got \(error)")
            }
        }

        // A snapshot whose identity does not follow from its own parts.
        await assertRefused(
            ExtractedPage(
                sourceID: page.sourceID,
                requestedURL: page.requestedURL,
                finalURL: page.finalURL,
                title: page.title,
                text: page.text,
                contentHash: page.contentHash,
                extractorVersion: page.extractorVersion,
                blocks: page.blocks,
                snapshot: Snapshot(
                    id: "snapshot-not-derived",
                    sourceID: page.sourceID,
                    contentHash: page.contentHash,
                    extractedText: page.text,
                    extractorVersion: page.extractorVersion
                ),
                passages: page.passages
            ),
            "a snapshot identity that does not follow from its source and content hash"
        )

        // A passage that does not resolve to the page's snapshot.
        await assertRefused(
            ExtractedPage(
                sourceID: page.sourceID,
                requestedURL: page.requestedURL,
                finalURL: page.finalURL,
                title: page.title,
                text: page.text,
                contentHash: page.contentHash,
                extractorVersion: page.extractorVersion,
                blocks: page.blocks,
                snapshot: page.snapshot,
                passages: [
                    Passage(
                        id: page.passages[0].id,
                        snapshotID: "another-snapshot",
                        ordinal: page.passages[0].ordinal,
                        heading: page.passages[0].heading,
                        text: page.passages[0].text,
                        textHash: page.passages[0].textHash
                    ),
                    page.passages[1],
                ]
            ),
            "a passage that does not resolve to the page's snapshot"
        )

        // A passage whose text hash does not match its text.
        await assertRefused(
            ExtractedPage(
                sourceID: page.sourceID,
                requestedURL: page.requestedURL,
                finalURL: page.finalURL,
                title: page.title,
                text: page.text,
                contentHash: page.contentHash,
                extractorVersion: page.extractorVersion,
                blocks: page.blocks,
                snapshot: page.snapshot,
                passages: [
                    Passage(
                        id: page.passages[0].id,
                        snapshotID: page.passages[0].snapshotID,
                        ordinal: page.passages[0].ordinal,
                        heading: page.passages[0].heading,
                        text: page.passages[0].text,
                        textHash: "not-a-hash"
                    ),
                    page.passages[1],
                ]
            ),
            "a passage text hash that does not match its text"
        )

        // A page whose text is not its passages joined in order.
        await assertRefused(
            ExtractedPage(
                sourceID: page.sourceID,
                requestedURL: page.requestedURL,
                finalURL: page.finalURL,
                title: page.title,
                text: page.text + " trailing text",
                contentHash: page.contentHash,
                extractorVersion: page.extractorVersion,
                blocks: page.blocks,
                snapshot: page.snapshot,
                passages: page.passages
            ),
            "a text that is not the passages joined in order"
        )

        let count = await store.snapshotCount()
        XCTAssertEqual(count, 0, "a refused page must not be stored")
    }

    // MARK: Boundary guarantees

    func testStoreSourceHasNoNetworkFilesystemOrClockDependency() throws {
        // The store must stay a pure, in-memory, content-addressed record: no
        // socket, no DNS, no file, no clock. Deduplication must never depend on
        // how much wall time passed.
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/LocalLensCore/SnapshotStore.swift")
        let text = try String(contentsOf: source, encoding: .utf8)

        for forbidden in [
            "URL" + "Session",
            "URL" + "(string:",
            "getaddr" + "info",
            "File" + "Manager",
            "Data(contents" + "Of",
            "Task" + ".sleep",
            "Date(",
        ] {
            XCTAssertFalse(text.contains(forbidden), "SnapshotStore must not reach for \(forbidden)")
        }
        XCTAssertEqual(
            text.components(separatedBy: "\n").filter { $0.hasPrefix("import ") },
            ["import Foundation"],
            "the store must not grow a dependency it does not need"
        )
    }
}
