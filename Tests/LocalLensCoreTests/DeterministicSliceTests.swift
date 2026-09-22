import Foundation
import XCTest
@testable import LocalLensCore

final class DeterministicSliceTests: XCTestCase {

    private var fixtureURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/deterministic/quick-coffee.json")
    }

    private func loadFixture() throws -> FixtureCorpus {
        try JSONDecoder().decode(FixtureCorpus.self, from: Data(contentsOf: fixtureURL))
    }

    private func sortedJSON<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    func testFixtureRunsOfflineTwiceWithIdenticalEvidenceAndCitationGraph() async throws {
        let corpus = try loadFixture()

        let first = try await DeterministicPipeline.run(corpus)
        let second = try await DeterministicPipeline.run(corpus)

        XCTAssertEqual(first.result.run.status, .complete)
        XCTAssertEqual(first.result.citations.count, corpus.claims.count)
        XCTAssertEqual(first.result.citationGraphSignature, second.result.citationGraphSignature)
        XCTAssertEqual(try sortedJSON(first), try sortedJSON(second))
    }

    func testEveryCitationResolvesToExactPassageAndQuote() async throws {
        let corpus = try loadFixture()
        let persisted = try await DeterministicPipeline.run(corpus)
        let result = persisted.result

        XCTAssertFalse(result.citations.isEmpty)
        for citation in result.citations {
            let passage = try XCTUnwrap(result.passage(for: citation.id))
            let link = try XCTUnwrap(result.evidenceLinks.first { citation.evidenceLinkIDs.contains($0.id) })
            XCTAssertEqual(link.passageID, passage.id)
            XCTAssertTrue(passage.text.contains(link.quote), "quote must be an exact substring of the passage")
            XCTAssertEqual(passage.textHash, StableIdentity.digest(passage.text))
            XCTAssertNotNil(result.source(for: passage))
        }
    }

    func testUnknownFixtureFieldFailsClosed() throws {
        var object = try JSONSerialization.jsonObject(with: Data(contentsOf: fixtureURL)) as! [String: Any]
        object["unexpected_field"] = true
        let data = try JSONSerialization.data(withJSONObject: object)

        XCTAssertThrowsError(try JSONDecoder().decode(FixtureCorpus.self, from: data)) { error in
            guard let decodingError = error as? DecodingError, case .dataCorrupted = decodingError else {
                return XCTFail("expected dataCorrupted, got \(error)")
            }
        }
    }

    func testMissingAnchorQuoteFailsClosedWithTypedError() async throws {
        let corpus = try loadFixture()
        let broken = FixtureCorpus(
            schemaVersion: corpus.schemaVersion,
            synthetic: corpus.synthetic,
            question: corpus.question,
            mode: corpus.mode,
            sources: corpus.sources,
            claims: [
                FixtureClaim(
                    dimension: "Broken",
                    text: "Broken claim",
                    anchor: FixtureAnchor(sourceID: corpus.sources[0].id, quote: "this quote appears in no passage")
                )
            ]
        )

        do {
            _ = try await DeterministicPipeline.run(broken)
            XCTFail("expected quoteNotFound")
        } catch let error as IntegrityError {
            XCTAssertEqual(error, .quoteNotFound(claimID: StableIdentity.make("claim", "Broken", "Broken claim")))
        }
    }

    func testIntegrityValidatorRejectsDanglingReference() async throws {
        let corpus = try loadFixture()
        let result = try await DeterministicPipeline.run(corpus).result
        let brokenCitation = Citation(
            id: StableIdentity.make("citation", "broken"),
            claimID: result.claims[0].id,
            evidenceLinkIDs: ["evidence-missing"]
        )
        let broken = ResearchResult(
            run: result.run,
            summary: result.summary,
            recommendation: result.recommendation,
            openQuestion: result.openQuestion,
            columnTitles: result.columnTitles,
            comparisonRows: result.comparisonRows,
            sources: result.sources,
            snapshots: result.snapshots,
            passages: result.passages,
            claims: result.claims,
            evidenceLinks: result.evidenceLinks,
            citations: result.citations + [brokenCitation]
        )

        XCTAssertThrowsError(try DeterministicPipeline.validate(broken)) { error in
            XCTAssertEqual(error as? IntegrityError, .unknownReference(kind: "evidence", id: "evidence-missing"))
        }
    }

    func testCompletedRunPersistsAndReloadsUnchanged() async throws {
        let corpus = try loadFixture()
        let persisted = try await DeterministicPipeline.run(corpus)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("local-lens-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }

        try RunStore(directory: directory).save(persisted)
        let reloaded = try RunStore(directory: directory).load(runID: persisted.result.run.id)

        XCTAssertEqual(reloaded, persisted)
    }

    func testPersistedRunRejectsUnknownFields() async throws {
        let corpus = try loadFixture()
        let persisted = try await DeterministicPipeline.run(corpus)
        var object = try JSONSerialization.jsonObject(with: try sortedJSON(persisted)) as! [String: Any]
        object["extra_manifest_field"] = "not allowed"
        let data = try JSONSerialization.data(withJSONObject: object)

        XCTAssertThrowsError(try JSONDecoder().decode(PersistedRun.self, from: data)) { error in
            guard let decodingError = error as? DecodingError, case .dataCorrupted = decodingError else {
                return XCTFail("expected dataCorrupted, got \(error)")
            }
        }
    }
}
