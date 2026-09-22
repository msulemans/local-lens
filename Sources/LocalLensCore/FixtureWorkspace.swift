import Foundation

/// A citation resolved all the way to its exact saved passage and source.
public struct CitationInspection: Equatable, Sendable {
    public let citation: Citation
    public let claim: Claim
    public let passage: Passage
    public let source: Source
}

/// Read-only helpers that turn a persisted run into inspectable citations.
/// Every failure is typed; nothing is guessed or repaired silently.
public enum FixtureWorkspace {

    public static func loadFixture(from url: URL) throws -> FixtureCorpus {
        try JSONDecoder().decode(FixtureCorpus.self, from: Data(contentsOf: url))
    }

    public static func inspections(in result: ResearchResult) throws -> [CitationInspection] {
        try result.citations.map { try inspection(for: $0.id, in: result) }
    }

    public static func inspection(for citationID: String, in result: ResearchResult) throws -> CitationInspection {
        guard let citation = result.citations.first(where: { $0.id == citationID }) else {
            throw IntegrityError.unknownReference(kind: "citation", id: citationID)
        }
        guard let claim = result.claims.first(where: { $0.id == citation.claimID }) else {
            throw IntegrityError.unknownReference(kind: "claim", id: citation.claimID)
        }
        guard
            let linkID = citation.evidenceLinkIDs.first,
            let link = result.evidenceLinks.first(where: { $0.id == linkID })
        else {
            throw IntegrityError.emptyCitation(claimID: citation.claimID)
        }
        guard let passage = result.passages.first(where: { $0.id == link.passageID }) else {
            throw IntegrityError.unknownReference(kind: "passage", id: link.passageID)
        }
        guard let source = result.source(for: passage) else {
            throw IntegrityError.unknownReference(kind: "source", id: passage.snapshotID)
        }
        return CitationInspection(citation: citation, claim: claim, passage: passage, source: source)
    }

    /// Builds the minimal evidence map: one node per citation, carrying its
    /// claim, relation, exact passage, and source. Fails closed on any
    /// dangling reference, exactly like `inspections(in:)`.
    public static func evidenceMap(in result: ResearchResult) throws -> EvidenceMap {
        let nodes = try result.citations.map { citation -> EvidenceMapNode in
            let inspection = try inspection(for: citation.id, in: result)
            guard let link = result.evidenceLinks.first(where: { citation.evidenceLinkIDs.contains($0.id) }) else {
                throw IntegrityError.emptyCitation(claimID: citation.claimID)
            }
            return EvidenceMapNode(
                id: inspection.claim.id,
                claim: inspection.claim,
                relation: link.relation,
                citationID: citation.id,
                passage: inspection.passage,
                source: inspection.source
            )
        }
        return EvidenceMap(question: result.run.question, nodes: nodes)
    }
}

/// One claim on the map with its evidence relationship and provenance.
public struct EvidenceMapNode: Equatable, Sendable, Identifiable {
    public let id: String
    public let claim: Claim
    public let relation: EvidenceRelation
    public let citationID: String
    public let passage: Passage
    public let source: Source
}

/// Minimal Living Research Map model rendered by the native shell.
public struct EvidenceMap: Equatable, Sendable {
    public let question: String
    public let nodes: [EvidenceMapNode]

    public var sources: [Source] {
        var seen: Set<String> = []
        var unique: [Source] = []
        for node in nodes where !seen.contains(node.source.id) {
            seen.insert(node.source.id)
            unique.append(node.source)
        }
        return unique
    }
}
