import Foundation
import XCTest
@testable import LocalLensCore

// MARK: - Frozen scenario fixture

/// The citation decision table lives in
/// `Fixtures/retrieval/citation-scenarios.json` so the binding rules are
/// reviewable as data. It is hand-authored, synthetic, and contains no captured
/// page and no resolvable host.
private struct CitationFixture: Decodable, Sendable {
    struct Meta: Decodable, Sendable {
        let synthetic: Bool
        let license: String
        let shape: String
        let note: String
    }

    struct Document: Decodable, Sendable {
        let id: String
        let source_id: String
        let url: String
        let content_type: String
        let why: String
        let body: String
    }

    struct Candidate: Decodable, Sendable {
        let id: String?
        let why: String?
        let dimension: String
        let text: String
        let claim_id: String?
        let query: String
        let quote: String
        let expected_snapshot_id: String?
        let expected_source_id: String?
        let expected_ordinal: Int?
    }

    struct Refusal: Decodable, Sendable {
        let id: String
        let why: String
        let candidates: [Candidate]
        let limit: Int?
        let expected_kind: String
        let expected_reason_contains: String
    }

    let _fixture: Meta
    let documents: [Document]
    let candidates: [Candidate]
    let refusals: [Refusal]
}

final class CitationCompilerTests: XCTestCase {

    // MARK: Helpers

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private var fixtureURL: URL {
        repositoryRoot.appendingPathComponent("Fixtures/retrieval/citation-scenarios.json")
    }

    private func fixtureData() throws -> Data {
        try Data(contentsOf: fixtureURL)
    }

    private func loadFixture() throws -> CitationFixture {
        try JSONDecoder().decode(CitationFixture.self, from: try fixtureData())
    }

    /// Extracts a fixture body through the M002.4 boundary, so the index is fed
    /// exactly what the pipeline would hand it. No transport, socket, resolver,
    /// or file is involved.
    private func page(for document: CitationFixture.Document) throws -> ExtractedPage {
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
    /// store -> lexical index. The compiler therefore binds stored passages,
    /// never fixture rows authored to look like passages.
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

    private func claimCandidate(_ entry: CitationFixture.Candidate) -> ClaimCandidate {
        let claimID = entry.claim_id ?? StableIdentity.make("claim", entry.dimension, entry.text)
        let claim = Claim(id: claimID, dimension: entry.dimension, text: entry.text)
        return ClaimCandidate(
            claim: claim,
            retrievalQuery: entry.query,
            quote: entry.quote,
            expectedSnapshotID: entry.expected_snapshot_id
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
        XCTAssertEqual(fixture._fixture.shape, "CitationCompilationFixture")
        XCTAssertEqual(fixture.documents.count, 4)
        XCTAssertEqual(fixture.candidates.count, 3)
        XCTAssertEqual(fixture.refusals.count, 9)

        var documentIDs: [String] = []
        for document in fixture.documents {
            documentIDs.append(document.id)
            XCTAssertFalse(document.why.isEmpty)
            let url = try XCTUnwrap(URL(string: document.url))
            XCTAssertEqual(url.host?.hasSuffix(".invalid"), true, "\(document.id) must stay on a non-resolvable host")
        }
        XCTAssertEqual(Set(documentIDs).count, documentIDs.count, "document ids must be unique")

        for candidate in fixture.candidates {
            XCTAssertFalse((candidate.id ?? "").isEmpty)
            XCTAssertFalse((candidate.why ?? "").isEmpty)
        }
        for refusal in fixture.refusals {
            XCTAssertFalse(refusal.why.isEmpty)
            XCTAssertFalse(refusal.candidates.isEmpty)
            XCTAssertEqual(CitationCompilerError.knownKind(refusal.expected_kind), true, refusal.expected_kind)
        }
    }

    // MARK: Compilation

    func testAcceptedCandidatesCompileToExactStoredPassages() async throws {
        let fixture = try loadFixture()
        let (index, store, _) = try await indexedFixture()
        let candidates = fixture.candidates.map(claimCandidate)
        let compilation = try await CitationCompiler.compile(candidates: candidates, index: index)

        XCTAssertEqual(compilation.citations.count, fixture.candidates.count)
        XCTAssertEqual(compilation.claims.count, fixture.candidates.count)
        XCTAssertEqual(compilation.evidenceLinks.count, fixture.candidates.count)

        for (entry, candidate) in zip(fixture.candidates, candidates) {
            let context = entry.id ?? candidate.claim.id
            let citationID = StableIdentity.make("citation", candidate.claim.id)
            let resolved = try compilation.resolve(citationID)

            XCTAssertEqual(resolved.claim, candidate.claim, context)
            XCTAssertEqual(resolved.evidenceLink.quote, candidate.quote, context)
            XCTAssertTrue(resolved.passage.text.contains(candidate.quote), context)
            XCTAssertEqual(resolved.evidenceLink.passageID, resolved.passage.id, context)
            XCTAssertEqual(resolved.citation.evidenceLinkIDs, [resolved.evidenceLink.id], context)
            XCTAssertEqual(resolved.citation.claimID, candidate.claim.id, context)
            XCTAssertEqual(resolved.evidenceLink.relation, .supports, context)

            // The citation must resolve to the exact stored passage and snapshot,
            // not to a fixture row that merely looks like one.
            let expectedSource = try XCTUnwrap(entry.expected_source_id)
            let expectedOrdinal = try XCTUnwrap(entry.expected_ordinal)
            let record = try await store.record(id: resolved.snapshotID)
            XCTAssertEqual(record.snapshot.sourceID, expectedSource, context)
            XCTAssertEqual(resolved.passage.ordinal, expectedOrdinal, context)
            XCTAssertTrue(record.passages.contains(resolved.passage), context)
        }
    }

    func testCompilationIsDeterministicAcrossRunsAndIndexes() async throws {
        let fixture = try loadFixture()
        let (index, _, records) = try await indexedFixture()
        let candidates = fixture.candidates.map(claimCandidate)

        let first = try await CitationCompiler.compile(candidates: candidates, index: index)
        for _ in 0..<3 {
            let repeatRun = try await CitationCompiler.compile(candidates: candidates, index: index)
            XCTAssertEqual(repeatRun, first)
        }

        let rebuilt = try LexicalIndex()
        for record in records {
            _ = try await rebuilt.ingest(record)
        }
        let rebuiltCompilation = try await CitationCompiler.compile(candidates: candidates, index: rebuilt)
        XCTAssertEqual(rebuiltCompilation, first, "a second index must compile identical citations")
    }

    func testAnEmptyCandidateListCompilesToAnEmptyValidCompilation() async throws {
        let (index, _, _) = try await indexedFixture()
        let compilation = try await CitationCompiler.compile(candidates: [], index: index)
        XCTAssertTrue(compilation.citations.isEmpty)
        XCTAssertNoThrow(try compilation.validate())
    }

    // MARK: Refusals

    func testRefusalsProduceTypedOutcomes() async throws {
        let fixture = try loadFixture()
        let (index, _, _) = try await indexedFixture()

        for refusal in fixture.refusals {
            let context = "\(refusal.id): \(refusal.why)"
            let candidates = refusal.candidates.map(claimCandidate)
            do {
                _ = try await CitationCompiler.compile(
                    candidates: candidates,
                    index: index,
                    limit: refusal.limit
                )
                XCTFail("\(context): expected a typed refusal")
            } catch let error as CitationCompilerError {
                XCTAssertEqual(error.kind, refusal.expected_kind, context)
                XCTAssertTrue(
                    error.reason.contains(refusal.expected_reason_contains),
                    "\(context): expected the reason to explain itself, got \(error.reason)"
                )
            }
        }
    }

    func testTypedOutcomeFamilyIsEnumerated() {
        let family: [CitationCompilerError] = [
            .invalidClaim(claimID: "claim", reason: "why"),
            .emptyQuery(claimID: "claim"),
            .retrievalFailed(claimID: "claim", kind: "limit_exceeds_policy", reason: "why"),
            .noResults(claimID: "claim", query: "query"),
            .quoteNotRetrieved(claimID: "claim", query: "query", quote: "quote"),
            .emptyQuote(claimID: "claim"),
            .wrongSnapshot(claimID: "claim", expected: "expected", actual: "actual"),
            .ambiguousQuote(claimID: "claim", passageIDs: ["a", "b"]),
            .duplicateBinding(claimID: "claim"),
            .unknownCitation(citationID: "citation"),
            .emptyCitation(claimID: "claim"),
            .unknownClaim(claimID: "claim"),
            .unknownEvidence(evidenceID: "evidence"),
            .unknownPassage(passageID: "passage"),
            .quoteNotExact(passageID: "passage", claimID: "claim"),
            .inconsistentCitation(citationID: "citation", reason: "why"),
        ]
        XCTAssertEqual(
            family.map(\.kind),
            [
                "invalid_claim", "empty_query", "retrieval_failed", "no_results",
                "quote_not_retrieved", "empty_quote", "wrong_snapshot", "ambiguous_quote", "duplicate_binding",
                "unknown_citation", "empty_citation", "unknown_claim", "unknown_evidence",
                "unknown_passage", "quote_not_exact", "inconsistent_citation",
            ]
        )
        for error in family {
            XCTAssertFalse(error.reason.isEmpty)
            XCTAssertEqual(error.errorDescription, error.reason)
        }
        XCTAssertEqual(
            Set(family.map(\.kind)),
            CitationCompilerError.kinds,
            "the enumerated family and the fixture vocabulary must be the same set"
        )
    }

    // MARK: Resolve boundary

    func testResolveFailsClosedOnDanglingReferences() throws {
        let claim = Claim(id: StableIdentity.make("claim", "d", "t"), dimension: "d", text: "t")
        let otherClaim = Claim(id: StableIdentity.make("claim", "d", "other"), dimension: "d", text: "other")
        let body = "A body that contains the quote."
        let passage = Passage(
            id: StableIdentity.make("passage", "snap", "0", StableIdentity.digest(body)),
            snapshotID: "snap",
            ordinal: 0,
            heading: "h",
            text: body,
            textHash: StableIdentity.digest(body)
        )
        let link = EvidenceLink(
            id: StableIdentity.make("evidence", claim.id, passage.id, "quote"),
            claimID: claim.id,
            passageID: passage.id,
            relation: .supports,
            quote: "quote"
        )
        let citation = Citation(
            id: StableIdentity.make("citation", claim.id),
            claimID: claim.id,
            evidenceLinkIDs: [link.id]
        )

        func compilation(
            claims: [Claim] = [claim],
            links: [EvidenceLink] = [link],
            citations: [Citation] = [citation],
            passages: [Passage] = [passage]
        ) -> CitationCompilation {
            CitationCompilation(claims: claims, evidenceLinks: links, citations: citations, passages: passages)
        }

        // A well-formed compilation resolves.
        XCTAssertNoThrow(try compilation().resolve(citation.id))

        func expects(_ kind: String, _ body: () throws -> Void) {
            XCTAssertThrowsError(try body()) { error in
                XCTAssertEqual((error as? CitationCompilerError)?.kind, kind)
            }
        }

        expects("unknown_citation") {
            _ = try compilation().resolve("citation-that-does-not-exist")
        }
        expects("empty_citation") {
            let empty = Citation(id: "citation", claimID: claim.id, evidenceLinkIDs: [])
            _ = try compilation(citations: [empty]).resolve("citation")
        }
        expects("unknown_claim") {
            let orphan = Citation(id: "citation", claimID: "missing-claim", evidenceLinkIDs: [link.id])
            _ = try compilation(citations: [orphan]).resolve("citation")
        }
        expects("unknown_evidence") {
            let dangling = Citation(id: "citation", claimID: claim.id, evidenceLinkIDs: ["missing-evidence"])
            _ = try compilation(citations: [dangling]).resolve("citation")
        }
        expects("unknown_passage") {
            let missing = EvidenceLink(
                id: StableIdentity.make("evidence", claim.id, "missing-passage", "quote"),
                claimID: claim.id,
                passageID: "missing-passage",
                relation: .supports,
                quote: "quote"
            )
            let citation = Citation(id: "citation", claimID: claim.id, evidenceLinkIDs: [missing.id])
            _ = try compilation(links: [missing], citations: [citation]).resolve("citation")
        }
        expects("quote_not_exact") {
            let altered = EvidenceLink(
                id: StableIdentity.make("evidence", claim.id, passage.id, "not in the body"),
                claimID: claim.id,
                passageID: passage.id,
                relation: .supports,
                quote: "not in the body"
            )
            let citation = Citation(id: "citation", claimID: claim.id, evidenceLinkIDs: [altered.id])
            _ = try compilation(links: [altered], citations: [citation]).resolve("citation")
        }
        expects("inconsistent_citation") {
            let conflicting = EvidenceLink(
                id: StableIdentity.make("evidence", otherClaim.id, passage.id, "quote"),
                claimID: otherClaim.id,
                passageID: passage.id,
                relation: .supports,
                quote: "quote"
            )
            let citation = Citation(id: "citation", claimID: claim.id, evidenceLinkIDs: [conflicting.id])
            _ = try compilation(
                claims: [claim, otherClaim],
                links: [conflicting],
                citations: [citation]
            ).resolve("citation")
        }
        expects("unknown_evidence") {
            // The valid first link must not hide a dangling second link.
            let citation = Citation(
                id: "citation",
                claimID: claim.id,
                evidenceLinkIDs: [link.id, "dangling-second-link"]
            )
            _ = try compilation(citations: [citation]).resolve("citation")
        }
        expects("empty_quote") {
            let blank = EvidenceLink(
                id: StableIdentity.make("evidence", claim.id, passage.id, "   "),
                claimID: claim.id,
                passageID: passage.id,
                relation: .supports,
                quote: "   "
            )
            let citation = Citation(id: "citation", claimID: claim.id, evidenceLinkIDs: [blank.id])
            _ = try compilation(links: [blank], citations: [citation]).resolve("citation")
        }
    }

    // MARK: Boundary guarantees

    func testCompilerSourceHoldsNoNetworkClockOrSearchHit() throws {
        // The compiler is a pure function of candidates and the index. It must
        // not open a socket, resolve a name, read a file, consult a clock, or
        // accept a search hit (which carries a snippet) as evidence. The
        // forbidden literals are built by concatenation so this guard does not
        // match its own source.
        let source = repositoryRoot.appendingPathComponent("Sources/LocalLensCore/CitationCompiler.swift")
        let text = try String(contentsOf: source, encoding: .utf8)

        for forbidden in [
            "URL" + "Session",
            "System" + "HostResolver",
            "getaddr" + "info",
            "Task" + ".sleep",
            "Date(",
            "File" + "Manager",
            "Search" + "Hit",
        ] {
            XCTAssertFalse(text.contains(forbidden), "CitationCompiler must not reach for \(forbidden)")
        }
        XCTAssertEqual(
            text.components(separatedBy: "\n").filter { $0.hasPrefix("import ") },
            ["import Foundation"],
            "the compiler must not grow a dependency it does not need"
        )
    }
}

// MARK: - Kind vocabulary helper

extension CitationCompilerError {
    /// The frozen set of kinds, so the fixture cannot name a kind that does not
    /// exist. Kept next to the tests that enumerate the family.
    static let kinds: Set<String> = [
        "invalid_claim", "empty_query", "retrieval_failed", "no_results",
        "quote_not_retrieved", "empty_quote", "wrong_snapshot", "ambiguous_quote", "duplicate_binding",
        "unknown_citation", "empty_citation", "unknown_claim", "unknown_evidence",
        "unknown_passage", "quote_not_exact", "inconsistent_citation",
    ]

    static func knownKind(_ kind: String) -> Bool { kinds.contains(kind) }
}
