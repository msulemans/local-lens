import Foundation

public enum ResearchMode: String, Codable, CaseIterable, Sendable {
    case quick = "Quick"
    case deep = "Deep"
    case academic = "Academic"
    case news = "News"
}

public enum RunStatus: String, Codable, Sendable {
    case created
    case scoped
    case rewriting
    case searching
    case acquiring
    case extracting
    case retrieving
    case buildingEvidence = "building_evidence"
    case drafting
    case validating
    case complete
    case cancelled
    case budgetExhausted = "budget_exhausted"
    case failed
    case needsUserInput = "needs_user_input"

    public var isTerminal: Bool {
        switch self {
        case .complete, .cancelled, .budgetExhausted, .failed, .needsUserInput:
            true
        default:
            false
        }
    }
}

public enum EvidenceRelation: String, Codable, Sendable {
    case supports
    case partiallySupports = "partially_supports"
    case conflicts
}

public struct ResearchRun: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let question: String
    public let mode: ResearchMode
    public var status: RunStatus
    public var stopReason: String?

    public init(
        id: String,
        question: String,
        mode: ResearchMode,
        status: RunStatus = .created,
        stopReason: String? = nil
    ) {
        self.id = id
        self.question = question
        self.mode = mode
        self.status = status
        self.stopReason = stopReason
    }
}

public struct SearchHit: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let query: String
    public let rank: Int
    public let url: URL
    public let title: String
    public let snippet: String
}

public struct Source: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let publisher: String
    public let canonicalURL: URL
    public let sourceType: String
}

public struct Snapshot: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let sourceID: String
    public let contentHash: String
    public let extractedText: String
    public let extractorVersion: String
}

public struct Passage: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let snapshotID: String
    public let ordinal: Int
    public let heading: String
    public let text: String
    public let textHash: String
}

public struct Claim: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let dimension: String
    public let text: String
}

public struct EvidenceLink: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let claimID: String
    public let passageID: String
    public let relation: EvidenceRelation
    public let quote: String
}

public struct Citation: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let claimID: String
    public let evidenceLinkIDs: [String]
}

public struct ComparisonValue: Codable, Equatable, Sendable {
    public let rating: String
    public let detail: String
    public let citationID: String

    public init(rating: String, detail: String, citationID: String) {
        self.rating = rating
        self.detail = detail
        self.citationID = citationID
    }
}

public struct ComparisonRow: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let criterion: String
    public let values: [ComparisonValue]

    public init(id: String, criterion: String, values: [ComparisonValue]) {
        self.id = id
        self.criterion = criterion
        self.values = values
    }
}

public struct ResearchResult: Codable, Equatable, Sendable {
    public var run: ResearchRun
    public let summary: String
    public let recommendation: String
    public let openQuestion: String
    public let columnTitles: [String]
    public let comparisonRows: [ComparisonRow]
    public let sources: [Source]
    public let snapshots: [Snapshot]
    public let passages: [Passage]
    public let claims: [Claim]
    public let evidenceLinks: [EvidenceLink]
    public let citations: [Citation]

    public func passage(for citationID: String) -> Passage? {
        guard
            let citation = citations.first(where: { $0.id == citationID }),
            let evidenceID = citation.evidenceLinkIDs.first,
            let evidence = evidenceLinks.first(where: { $0.id == evidenceID })
        else { return nil }

        return passages.first(where: { $0.id == evidence.passageID })
    }

    public func source(for passage: Passage) -> Source? {
        guard let snapshot = snapshots.first(where: { $0.id == passage.snapshotID }) else {
            return nil
        }
        return sources.first(where: { $0.id == snapshot.sourceID })
    }

    public var citationGraphSignature: String {
        citations
            .sorted(by: { $0.id < $1.id })
            .map { "\($0.id):\($0.claimID):\($0.evidenceLinkIDs.joined(separator: ","))" }
            .joined(separator: "|")
    }
}

public struct RunEvent: Codable, Equatable, Sendable {
    public let sequence: Int
    public let status: RunStatus
    public let message: String

    public init(sequence: Int, status: RunStatus, message: String) {
        self.sequence = sequence
        self.status = status
        self.message = message
    }
}

public struct PersistedRun: Codable, Equatable, Sendable {
    public let result: ResearchResult
    public let events: [RunEvent]

    public init(result: ResearchResult, events: [RunEvent]) {
        self.result = result
        self.events = events
    }
}

extension RunEvent {
    private enum CodingKeys: String, CodingKey {
        case sequence
        case status
        case message
    }

    public init(from decoder: Decoder) throws {
        try requireKnownKeys(decoder, allowed: ["sequence", "status", "message"], context: "run event")
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            sequence: try container.decode(Int.self, forKey: .sequence),
            status: try container.decode(RunStatus.self, forKey: .status),
            message: try container.decode(String.self, forKey: .message)
        )
    }
}

extension PersistedRun {
    private enum CodingKeys: String, CodingKey {
        case result
        case events
    }

    public init(from decoder: Decoder) throws {
        try requireKnownKeys(decoder, allowed: ["result", "events"], context: "persisted run")
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            result: try container.decode(ResearchResult.self, forKey: .result),
            events: try container.decode([RunEvent].self, forKey: .events)
        )
    }
}
