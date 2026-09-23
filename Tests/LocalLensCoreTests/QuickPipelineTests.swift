import Foundation
import XCTest
@testable import LocalLensCore

// MARK: - Frozen scenario fixture

/// The deterministic Quick question set lives in
/// `Fixtures/retrieval/quick-scenarios.json` so the run composition is
/// reviewable as data. It is hand-authored, synthetic, and contains no captured
/// page and no resolvable host.
private struct QuickFixture: Decodable, Sendable {
    struct Meta: Decodable, Sendable {
        let synthetic: Bool
        let license: String
        let shape: String
        let note: String
    }

    struct SourceEntry: Decodable, Sendable {
        let id: String
        let title: String
        let publisher: String
        let canonical_url: String
        let source_type: String
    }

    struct Document: Decodable, Sendable {
        let id: String
        let source_id: String
        let url: String
        let content_type: String
        let why: String
        let body: String
    }

    struct Claim: Decodable, Sendable {
        let dimension: String
        let text: String
        let query: String
        let quote: String
        let expected_source_id: String
    }

    struct Question: Decodable, Sendable {
        let id: String
        let why: String
        let text: String
        let claims: [Claim]
    }

    let _fixture: Meta
    let sources: [SourceEntry]
    let documents: [Document]
    let questions: [Question]
}

final class QuickPipelineTests: XCTestCase {

    private let failingQuestionID = "q-mercury"

    // MARK: Helpers

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private var fixtureURL: URL {
        repositoryRoot.appendingPathComponent("Fixtures/retrieval/quick-scenarios.json")
    }

    private func fixtureData() throws -> Data {
        try Data(contentsOf: fixtureURL)
    }

    private func loadFixture() throws -> QuickFixture {
        try JSONDecoder().decode(QuickFixture.self, from: try fixtureData())
    }

    /// Extracts a fixture body through the M002.4 boundary, so the index is fed
    /// exactly what the pipeline would hand it. No transport, socket, resolver,
    /// or file is involved.
    private func page(for document: QuickFixture.Document) throws -> ExtractedPage {
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

    /// Builds the full offline pipeline from the fixture: bytes -> extraction ->
    /// snapshot store -> lexical index. The Quick run therefore binds stored
    /// passages, never fixture rows authored to look like passages.
    private func indexedFixture() async throws -> (index: LexicalIndex, store: SnapshotStore, records: [SnapshotRecord]) {
        let fixture = try loadFixture()
        let store = SnapshotStore()
        for document in fixture.documents {
            _ = try await store.store(try page(for: document))
        }
        let records = await store.records()
        let index = try LexicalIndex()
        for record in records {
            _ = try await index.ingest(record)
        }
        return (index, store, records)
    }

    private func source(_ entry: QuickFixture.SourceEntry) throws -> Source {
        Source(
            id: entry.id,
            title: entry.title,
            publisher: entry.publisher,
            canonicalURL: try XCTUnwrap(URL(string: entry.canonical_url)),
            sourceType: entry.source_type
        )
    }

    private func plan(for question: QuickFixture.Question, sources: [Source]) -> QuickRunPlan {
        let candidates = question.claims.map { claim in
            let claimID = StableIdentity.make("claim", claim.dimension, claim.text)
            return ClaimCandidate(
                claim: Claim(id: claimID, dimension: claim.dimension, text: claim.text),
                retrievalQuery: claim.query,
                quote: claim.quote
            )
        }
        return QuickRunPlan(id: question.id, question: question.text, candidates: candidates, sources: sources)
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
        XCTAssertEqual(fixture._fixture.shape, "QuickPipelineFixture")
        XCTAssertEqual(fixture.sources.count, 4)
        XCTAssertEqual(fixture.documents.count, 4)
        XCTAssertEqual(fixture.questions.count, 4)

        var sourceIDs: [String] = []
        for entry in fixture.sources {
            sourceIDs.append(entry.id)
            let url = try XCTUnwrap(URL(string: entry.canonical_url))
            XCTAssertEqual(url.host?.hasSuffix(".invalid"), true, "\(entry.id) must stay on a non-resolvable host")
        }
        XCTAssertEqual(Set(sourceIDs).count, sourceIDs.count, "source ids must be unique")

        for document in fixture.documents {
            XCTAssertFalse(document.why.isEmpty)
            let url = try XCTUnwrap(URL(string: document.url))
            XCTAssertEqual(url.host?.hasSuffix(".invalid"), true, "\(document.id) must stay on a non-resolvable host")
        }
        for question in fixture.questions {
            XCTAssertFalse(question.why.isEmpty)
            XCTAssertFalse(question.text.isEmpty)
            XCTAssertFalse(question.claims.isEmpty)
        }
    }

    // MARK: Completed runs

    func testAcceptedQuestionsCompleteWithResolvableCitations() async throws {
        let fixture = try loadFixture()
        let (index, store, _) = try await indexedFixture()
        let sources = try fixture.sources.map(source)

        var completed = 0
        for question in fixture.questions where question.id != failingQuestionID {
            let runPlan = plan(for: question, sources: sources)
            let persisted = try await QuickPipeline.run(runPlan, store: store, index: index)
            let context = question.id

            XCTAssertEqual(persisted.result.run.status, .complete, context)
            XCTAssertNil(persisted.result.run.stopReason, context)
            XCTAssertEqual(persisted.result.run.mode, .quick, context)
            XCTAssertEqual(persisted.events.last?.status, .complete, context)
            XCTAssertEqual(persisted.result.citations.count, question.claims.count, context)

            // Citation integrity is re-derived here through the same resolver
            // the UI uses, not merely trusted from the compiler.
            let inspections = try FixtureWorkspace.inspections(in: persisted.result)
            XCTAssertEqual(inspections.count, question.claims.count, context)
            for (inspection, claim) in zip(inspections, question.claims) {
                XCTAssertEqual(inspection.source.id, claim.expected_source_id, context)
                XCTAssertTrue(inspection.passage.text.contains(claim.quote), context)
                XCTAssertEqual(
                    inspection.citation.claimID,
                    StableIdentity.make("claim", claim.dimension, claim.text),
                    context
                )
                XCTAssertTrue(
                    persisted.result.snapshots.contains { $0.id == inspection.passage.snapshotID },
                    "\(context): the cited snapshot must be in the result"
                )
            }
            completed += 1
        }
        XCTAssertEqual(completed, 3, "three accepted questions must complete")
    }

    func testTwoRunsProduceIdenticalPersistedRuns() async throws {
        let fixture = try loadFixture()
        let (index, store, _) = try await indexedFixture()
        let sources = try fixture.sources.map(source)
        let question = try XCTUnwrap(fixture.questions.first { $0.id != failingQuestionID })
        let runPlan = plan(for: question, sources: sources)

        let first = try await QuickPipeline.run(runPlan, store: store, index: index, runID: "deterministic-quick")
        let second = try await QuickPipeline.run(runPlan, store: store, index: index, runID: "deterministic-quick")
        XCTAssertEqual(first, second)
    }

    // MARK: Failed runs

    func testAQuestionThatRetrievesNothingEndsFailedWithATypedReason() async throws {
        let fixture = try loadFixture()
        let (index, store, _) = try await indexedFixture()
        let sources = try fixture.sources.map(source)
        let question = try XCTUnwrap(fixture.questions.first { $0.id == failingQuestionID })
        let runPlan = plan(for: question, sources: sources)

        let persisted = try await QuickPipeline.run(runPlan, store: store, index: index)
        XCTAssertEqual(persisted.result.run.status, .failed)
        let reason = try XCTUnwrap(persisted.result.run.stopReason)
        XCTAssertTrue(reason.contains("citation_compile_failed"), reason)
        XCTAssertTrue(reason.contains("no_results"), reason)
        XCTAssertEqual(persisted.events.last?.status, .failed)
        XCTAssertTrue(persisted.result.citations.isEmpty)
        XCTAssertTrue(persisted.result.claims.isEmpty)
    }

    func testACitedSourceMissingFromThePlanFailsTheRun() async throws {
        let fixture = try loadFixture()
        let (index, store, _) = try await indexedFixture()
        let question = try XCTUnwrap(fixture.questions.first { $0.id != failingQuestionID })

        // The claim compiles against the index, but the plan describes no
        // sources, so the citation cannot be attributed and the run fails closed.
        let persisted = try await QuickPipeline.run(plan(for: question, sources: []), store: store, index: index)
        XCTAssertEqual(persisted.result.run.status, .failed)
        let reason = try XCTUnwrap(persisted.result.run.stopReason)
        XCTAssertTrue(reason.contains("missing_source"), reason)
        XCTAssertTrue(persisted.result.citations.isEmpty)
    }

    func testACitedSnapshotMissingFromTheStoreFailsTheRun() async throws {
        let fixture = try loadFixture()
        let (index, _, _) = try await indexedFixture()
        let sources = try fixture.sources.map(source)
        let question = try XCTUnwrap(fixture.questions.first { $0.id != failingQuestionID })

        // The index holds the passage but the store handed to the run does not,
        // so the citation cannot resolve to stored evidence.
        let emptyStore = SnapshotStore()
        let persisted = try await QuickPipeline.run(
            plan(for: question, sources: sources),
            store: emptyStore,
            index: index
        )
        XCTAssertEqual(persisted.result.run.status, .failed)
        XCTAssertTrue(try XCTUnwrap(persisted.result.run.stopReason).contains("missing_snapshot"))
        XCTAssertTrue(persisted.result.citations.isEmpty)
    }

    // MARK: Plan validation

    func testPlanValidationRefusesAnEmptyQuestionAndDuplicateSources() throws {
        XCTAssertThrowsError(
            try QuickPipeline.validate(
                QuickRunPlan(id: "q", question: "   ", candidates: [], sources: [])
            )
        ) { error in
            XCTAssertEqual((error as? QuickPipelineError)?.kind, "empty_question")
        }

        let first = Source(
            id: "src",
            title: "Title",
            publisher: "Publisher",
            canonicalURL: URL(string: "https://source.example.invalid/")!,
            sourceType: "article"
        )
        XCTAssertThrowsError(
            try QuickPipeline.validate(
                QuickRunPlan(id: "q", question: "A question", candidates: [], sources: [first, first])
            )
        ) { error in
            XCTAssertEqual((error as? QuickPipelineError)?.kind, "duplicate_source")
        }
    }

    func testTypedOutcomeFamilyIsEnumerated() {
        let family: [QuickPipelineError] = [
            .emptyQuestion(id: "q"),
            .duplicateSource(sourceID: "src"),
            .missingSource(sourceID: "src"),
            .missingSnapshot(snapshotID: "snap"),
        ]
        XCTAssertEqual(
            family.map(\.kind),
            ["empty_question", "duplicate_source", "missing_source", "missing_snapshot"]
        )
        for error in family {
            XCTAssertFalse(error.reason.isEmpty)
            XCTAssertEqual(error.errorDescription, error.reason)
        }
    }

    // MARK: Boundary guarantees

    func testPipelineSourceHoldsNoNetworkClockOrModel() throws {
        // The pipeline is a pure composition of the run state machine, the
        // lexical index, and the citation compiler. It must not open a socket,
        // resolve a name, read a file, consult a clock, or name a model. The
        // forbidden literals are built by concatenation so this guard does not
        // match its own source.
        let source = repositoryRoot.appendingPathComponent("Sources/LocalLensCore/QuickPipeline.swift")
        let text = try String(contentsOf: source, encoding: .utf8)

        for forbidden in [
            "URL" + "Session",
            "System" + "HostResolver",
            "getaddr" + "info",
            "Task" + ".sleep",
            "Date(",
            "File" + "Manager",
            "Language" + "Model",
            "MLX",
        ] {
            XCTAssertFalse(text.contains(forbidden), "QuickPipeline must not reach for \(forbidden)")
        }
        XCTAssertEqual(
            text.components(separatedBy: "\n").filter { $0.hasPrefix("import ") },
            ["import Foundation"],
            "the pipeline must not grow a dependency it does not need"
        )
    }
}
