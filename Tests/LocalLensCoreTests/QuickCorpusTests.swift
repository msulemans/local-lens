import Foundation
import XCTest
@testable import LocalLensCore

final class QuickCorpusTests: XCTestCase {

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private var viewFixtureURL: URL {
        repositoryRoot.appendingPathComponent("Fixtures/retrieval/quick-view.json")
    }

    func testViewFixtureLoadsAndPlansThreeClaims() throws {
        let corpus = try QuickCorpus.load(from: viewFixtureURL)

        XCTAssertEqual(corpus._fixture.shape, "QuickViewFixture")
        XCTAssertTrue(corpus._fixture.synthetic)
        XCTAssertEqual(corpus.sources.count, 3)
        XCTAssertEqual(corpus.documents.count, 3)
        XCTAssertEqual(corpus.questions.count, 1)
        XCTAssertEqual(corpus.domainSources.count, 3)

        for source in corpus.sources {
            XCTAssertTrue(source.canonicalURL.host?.hasSuffix(".invalid") == true)
        }

        let question = try XCTUnwrap(corpus.questions.first)
        let plan = corpus.plan(for: question)
        XCTAssertEqual(plan.id, "q-espresso-view")
        XCTAssertEqual(plan.candidates.count, 3)
        XCTAssertEqual(plan.sources.count, 3)
        for entry in question.claims {
            XCTAssertTrue(
                plan.candidates.contains {
                    $0.claim.id == StableIdentity.make("claim", entry.dimension, entry.text)
                        && $0.retrievalQuery == entry.query
                        && $0.quote == entry.quote
                },
                entry.text
            )
        }
    }

    func testViewFixtureRunsThroughThePipelineWithResolvableCitations() async throws {
        let corpus = try QuickCorpus.load(from: viewFixtureURL)
        let question = try XCTUnwrap(corpus.questions.first)
        let indexed = try await corpus.makeIndexedStore()
        let persisted = try await QuickPipeline.run(
            corpus.plan(for: question),
            store: indexed.store,
            index: indexed.index,
            runID: "quick-view"
        )

        XCTAssertEqual(persisted.result.run.status, .complete)
        XCTAssertEqual(persisted.result.run.mode, .quick)
        XCTAssertEqual(persisted.result.citations.count, 3)

        let inspections = try FixtureWorkspace.inspections(in: persisted.result)
        XCTAssertEqual(inspections.count, 3)
        let expectedSources = Set(question.claims.map(\.expectedSourceID))
        XCTAssertEqual(Set(inspections.map(\.source.id)), expectedSources)
        for (inspection, entry) in zip(inspections, question.claims) {
            XCTAssertEqual(inspection.source.id, entry.expectedSourceID)
            XCTAssertTrue(inspection.passage.text.contains(entry.quote))
        }
    }

    func testStrictDecodingRejectsUnknownFields() throws {
        let withUnknownTopLevel = """
        {
          "_fixture": { "synthetic": true, "license": "redistributable", "shape": "x", "note": "y" },
          "sources": [],
          "documents": [],
          "questions": [],
          "unknown": 1
        }
        """
        XCTAssertThrowsError(
            try JSONDecoder().decode(QuickCorpus.self, from: Data(withUnknownTopLevel.utf8))
        )

        let withUnknownQuestionField = """
        {
          "_fixture": { "synthetic": true, "license": "redistributable", "shape": "x", "note": "y" },
          "sources": [],
          "documents": [],
          "questions": [ { "id": "q", "why": "w", "text": "t", "claims": [], "extra": true } ]
        }
        """
        XCTAssertThrowsError(
            try JSONDecoder().decode(QuickCorpus.self, from: Data(withUnknownQuestionField.utf8))
        )
    }

    func testCorpusSourceHoldsNoNetworkClockOrModel() throws {
        // Loading the corpus reads one JSON file and nothing else; building the
        // index uses the extraction, storage, and lexical boundaries. The
        // forbidden literals are built by concatenation so this guard does not
        // match its own source.
        let source = repositoryRoot.appendingPathComponent("Sources/LocalLensCore/QuickCorpus.swift")
        let text = try String(contentsOf: source, encoding: .utf8)

        for forbidden in [
            "URL" + "Session",
            "System" + "HostResolver",
            "getaddr" + "info",
            "Task" + ".sleep",
            "Date(",
            "Language" + "Model",
            "MLX",
        ] {
            XCTAssertFalse(text.contains(forbidden), "QuickCorpus must not reach for \(forbidden)")
        }
        XCTAssertEqual(
            text.components(separatedBy: "\n").filter { $0.hasPrefix("import ") },
            ["import Foundation"],
            "the corpus loader must not grow a dependency it does not need"
        )
    }
}
