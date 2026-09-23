import Foundation

// MARK: - Candidate claims

/// A claim that should be bound to evidence, plus the retrieval query that finds
/// it and the exact quote the supporting passage must contain.
///
/// There is deliberately no URL and no snippet field. A claim is bound only to a
/// passage that was retrieved from the index and that contains the exact quote;
/// the search hit that pointed at the page is never consulted.
public struct ClaimCandidate: Equatable, Sendable {
    public let claim: Claim
    public let retrievalQuery: String
    public let quote: String
    /// When present, the supporting passage must belong to this snapshot, or the
    /// claim is refused. A claim known to come from one source must not be
    /// evidenced by a different one.
    public let expectedSnapshotID: String?

    public init(
        claim: Claim,
        retrievalQuery: String,
        quote: String,
        expectedSnapshotID: String? = nil
    ) {
        self.claim = claim
        self.retrievalQuery = retrievalQuery
        self.quote = quote
        self.expectedSnapshotID = expectedSnapshotID
    }
}

// MARK: - Resolved evidence

/// One citation resolved all the way to its claim, exact stored passage, and
/// evidence link. The passage carries its own snapshot identity, so the
/// resolution names the immutable document the quote came from.
public struct CompiledCitation: Equatable, Sendable {
    public let citation: Citation
    public let claim: Claim
    public let evidenceLink: EvidenceLink
    public let passage: Passage

    public init(
        citation: Citation,
        claim: Claim,
        evidenceLink: EvidenceLink,
        passage: Passage
    ) {
        self.citation = citation
        self.claim = claim
        self.evidenceLink = evidenceLink
        self.passage = passage
    }

    public var snapshotID: String { passage.snapshotID }
}

// MARK: - Compilation

/// The deterministic result of compiling a run's claims over retrieved passages.
///
/// The compilation is a plain value. It can be built by the compiler or by a
/// caller, and both `validate()` and `resolve(_:)` re-check every reference and
/// every exact quote before anything is returned, so a dangling or altered
/// compilation fails closed.
public struct CitationCompilation: Equatable, Sendable {
    public let claims: [Claim]
    public let evidenceLinks: [EvidenceLink]
    public let citations: [Citation]
    public let passages: [Passage]

    public init(
        claims: [Claim],
        evidenceLinks: [EvidenceLink],
        citations: [Citation],
        passages: [Passage]
    ) {
        self.claims = claims
        self.evidenceLinks = evidenceLinks
        self.citations = citations
        self.passages = passages
    }

    public var citationIDs: [String] { citations.map(\.id) }

    /// Resolves one citation to its exact claim, passage, and evidence link, or
    /// refuses with a typed reason. Nothing is guessed or repaired.
    public func resolve(_ citationID: String) throws -> CompiledCitation {
        try resolved(citationID)
    }

    /// Proves that every citation in the compilation resolves.
    public func validate() throws {
        for citation in citations {
            _ = try resolved(citation.id)
        }
    }

    private func resolved(_ citationID: String) throws -> CompiledCitation {
        guard let citation = citations.first(where: { $0.id == citationID }) else {
            throw CitationCompilerError.unknownCitation(citationID: citationID)
        }
        guard let claim = claims.first(where: { $0.id == citation.claimID }) else {
            throw CitationCompilerError.unknownClaim(claimID: citation.claimID)
        }
        guard !citation.evidenceLinkIDs.isEmpty else {
            throw CitationCompilerError.emptyCitation(claimID: citation.claimID)
        }
        // Every link in the citation is checked, not only the one that is
        // returned, so a dangling or altered later link cannot hide behind a
        // valid first one.
        var firstResolved: CompiledCitation?
        for linkID in citation.evidenceLinkIDs {
            guard let link = evidenceLinks.first(where: { $0.id == linkID }) else {
                throw CitationCompilerError.unknownEvidence(evidenceID: linkID)
            }
            guard link.claimID == claim.id else {
                throw CitationCompilerError.inconsistentCitation(
                    citationID: citation.id,
                    reason: "the evidence link names claim \(link.claimID) but the citation names \(claim.id)"
                )
            }
            guard !link.quote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw CitationCompilerError.emptyQuote(claimID: claim.id)
            }
            guard let passage = passages.first(where: { $0.id == link.passageID }) else {
                throw CitationCompilerError.unknownPassage(passageID: link.passageID)
            }
            guard passage.text.contains(link.quote) else {
                throw CitationCompilerError.quoteNotExact(passageID: passage.id, claimID: claim.id)
            }
            if firstResolved == nil {
                firstResolved = CompiledCitation(
                    citation: citation,
                    claim: claim,
                    evidenceLink: link,
                    passage: passage
                )
            }
        }
        guard let firstResolved else {
            throw CitationCompilerError.emptyCitation(claimID: citation.claimID)
        }
        return firstResolved
    }
}

// MARK: - Typed refusals

/// Why a claim could not be compiled into evidence, or a citation could not be
/// resolved. Every case is a different fact: an empty query is not a claim that
/// retrieved nothing, and a quote that no passage contains is not a quote that
/// is merely absent.
public enum CitationCompilerError: Error, Equatable, LocalizedError, Sendable {
    /// The claim id does not follow from its dimension and text.
    case invalidClaim(claimID: String, reason: String)
    /// The candidate's retrieval query held no retrievable term.
    case emptyQuery(claimID: String)
    /// The lexical index refused the query for a reason other than emptiness.
    case retrievalFailed(claimID: String, kind: String, reason: String)
    /// The query retrieved nothing at all.
    case noResults(claimID: String, query: String)
    /// The query retrieved passages, but none contains the exact quote.
    case quoteNotRetrieved(claimID: String, query: String, quote: String)
    /// The candidate names no quote, or a quote of only whitespace. An empty
    /// quote is a substring of every passage, so it can never be evidence.
    case emptyQuote(claimID: String)
    /// The supporting passage belongs to a different snapshot than the one the
    /// candidate declared.
    case wrongSnapshot(claimID: String, expected: String, actual: String)
    /// More than one distinct retrieved passage contains the exact quote, so the
    /// binding is ambiguous rather than chosen silently.
    case ambiguousQuote(claimID: String, passageIDs: [String])
    /// The same claim or citation identity would be compiled twice.
    case duplicateBinding(claimID: String)
    /// Resolution named a citation the compilation does not contain.
    case unknownCitation(citationID: String)
    /// A citation names no evidence link.
    case emptyCitation(claimID: String)
    /// A citation or evidence link names a claim the compilation does not contain.
    case unknownClaim(claimID: String)
    /// A citation names an evidence link the compilation does not contain.
    case unknownEvidence(evidenceID: String)
    /// An evidence link names a passage the compilation does not contain.
    case unknownPassage(passageID: String)
    /// The stored quote is no longer an exact substring of the stored passage.
    case quoteNotExact(passageID: String, claimID: String)
    /// A compiled citation no longer describes itself consistently.
    case inconsistentCitation(citationID: String, reason: String)

    public var kind: String {
        switch self {
        case .invalidClaim: "invalid_claim"
        case .emptyQuery: "empty_query"
        case .retrievalFailed: "retrieval_failed"
        case .noResults: "no_results"
        case .quoteNotRetrieved: "quote_not_retrieved"
        case .emptyQuote: "empty_quote"
        case .wrongSnapshot: "wrong_snapshot"
        case .ambiguousQuote: "ambiguous_quote"
        case .duplicateBinding: "duplicate_binding"
        case .unknownCitation: "unknown_citation"
        case .emptyCitation: "empty_citation"
        case .unknownClaim: "unknown_claim"
        case .unknownEvidence: "unknown_evidence"
        case .unknownPassage: "unknown_passage"
        case .quoteNotExact: "quote_not_exact"
        case .inconsistentCitation: "inconsistent_citation"
        }
    }

    public var reason: String {
        switch self {
        case let .invalidClaim(claimID, reason):
            "claim \(claimID) is not a self-consistent claim: \(reason)"
        case let .emptyQuery(claimID):
            "claim \(claimID) has no retrievable query term"
        case let .retrievalFailed(claimID, kind, reason):
            "retrieval for claim \(claimID) failed at \(kind): \(reason)"
        case let .noResults(claimID, query):
            "the query \"\(query)\" for claim \(claimID) retrieved no passage"
        case let .quoteNotRetrieved(claimID, query, quote):
            "no passage retrieved by \"\(query)\" contains the exact quote \"\(quote)\" for claim \(claimID)"
        case let .emptyQuote(claimID):
            "claim \(claimID) has an empty quote, so no passage can support it"
        case let .wrongSnapshot(claimID, expected, actual):
            "claim \(claimID) requires snapshot \(expected) but the retrieved passage belongs to \(actual)"
        case let .ambiguousQuote(claimID, passageIDs):
            "claim \(claimID) has the same exact quote in \(passageIDs.count) distinct passages: \(passageIDs.joined(separator: ", "))"
        case let .duplicateBinding(claimID):
            "claim \(claimID) was offered more than once and cannot be bound twice"
        case let .unknownCitation(citationID):
            "no citation \(citationID) is in the compilation"
        case let .emptyCitation(claimID):
            "citation for claim \(claimID) names no evidence link"
        case let .unknownClaim(claimID):
            "no claim \(claimID) is in the compilation"
        case let .unknownEvidence(evidenceID):
            "no evidence link \(evidenceID) is in the compilation"
        case let .unknownPassage(passageID):
            "no passage \(passageID) is in the compilation"
        case let .quoteNotExact(passageID, claimID):
            "the quote for claim \(claimID) is not an exact substring of passage \(passageID)"
        case let .inconsistentCitation(citationID, reason):
            "citation \(citationID) does not describe itself: \(reason)"
        }
    }

    public var errorDescription: String? { reason }
}

// MARK: - Compiler

/// Binds accepted claims to the exact ranked passages that support them.
///
/// The compiler is a pure function of the candidates and the index: it opens no
/// socket, resolves no name, reads no file, and consults no clock. For each
/// candidate it retrieves ranked passages, requires exactly one distinct
/// passage to contain the exact quote, and derives the evidence and citation
/// identity from the claim, the passage, and the quote. Nothing is repaired
/// silently: a missing passage, a non-exact quote, a wrong snapshot, an
/// ambiguous quote, and a duplicate binding all refuse with a typed outcome.
public enum CitationCompiler {
    @discardableResult
    public static func compile(
        candidates: [ClaimCandidate],
        index: LexicalIndex,
        limit: Int? = nil
    ) async throws -> CitationCompilation {
        var claims: [Claim] = []
        var evidenceLinks: [EvidenceLink] = []
        var citations: [Citation] = []
        var passages: [Passage] = []
        var seenClaimIDs: Set<String> = []
        var seenCitationIDs: Set<String> = []
        var seenPassageIDs: Set<String> = []

        for candidate in candidates {
            let claim = candidate.claim
            guard claim.id == StableIdentity.make("claim", claim.dimension, claim.text) else {
                throw CitationCompilerError.invalidClaim(
                    claimID: claim.id,
                    reason: "the claim id does not follow from its dimension and text"
                )
            }
            guard !seenClaimIDs.contains(claim.id) else {
                throw CitationCompilerError.duplicateBinding(claimID: claim.id)
            }
            guard !candidate.quote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw CitationCompilerError.emptyQuote(claimID: claim.id)
            }

            let hits: [IndexedHit]
            do {
                hits = try await index.search(candidate.retrievalQuery, limit: limit)
            } catch let error as LexicalIndexError {
                if case .emptyQuery = error {
                    throw CitationCompilerError.emptyQuery(claimID: claim.id)
                }
                throw CitationCompilerError.retrievalFailed(
                    claimID: claim.id,
                    kind: error.kind,
                    reason: error.reason
                )
            }

            guard !hits.isEmpty else {
                throw CitationCompilerError.noResults(
                    claimID: claim.id,
                    query: candidate.retrievalQuery
                )
            }

            let matching = hits.filter { $0.passage.text.contains(candidate.quote) }
            guard !matching.isEmpty else {
                throw CitationCompilerError.quoteNotRetrieved(
                    claimID: claim.id,
                    query: candidate.retrievalQuery,
                    quote: candidate.quote
                )
            }

            let distinctIDs = Set(matching.map(\.passage.id)).sorted()
            guard distinctIDs.count == 1, let hit = matching.first else {
                throw CitationCompilerError.ambiguousQuote(claimID: claim.id, passageIDs: distinctIDs)
            }

            if let expected = candidate.expectedSnapshotID, expected != hit.passage.snapshotID {
                throw CitationCompilerError.wrongSnapshot(
                    claimID: claim.id,
                    expected: expected,
                    actual: hit.passage.snapshotID
                )
            }

            let citationID = StableIdentity.make("citation", claim.id)
            guard !seenCitationIDs.contains(citationID) else {
                throw CitationCompilerError.duplicateBinding(claimID: claim.id)
            }
            let link = EvidenceLink(
                id: StableIdentity.make("evidence", claim.id, hit.passage.id, candidate.quote),
                claimID: claim.id,
                passageID: hit.passage.id,
                relation: .supports,
                quote: candidate.quote
            )

            seenClaimIDs.insert(claim.id)
            seenCitationIDs.insert(citationID)
            claims.append(claim)
            evidenceLinks.append(link)
            citations.append(Citation(id: citationID, claimID: claim.id, evidenceLinkIDs: [link.id]))
            if seenPassageIDs.insert(hit.passage.id).inserted {
                passages.append(hit.passage)
            }
        }

        let compilation = CitationCompilation(
            claims: claims,
            evidenceLinks: evidenceLinks,
            citations: citations,
            passages: passages
        )
        try compilation.validate()
        return compilation
    }
}
