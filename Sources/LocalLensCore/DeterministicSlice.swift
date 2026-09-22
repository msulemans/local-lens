import Foundation

// MARK: - Strict decoding helpers

/// Coding key that accepts any string, so unknown JSON fields remain visible
/// to the strictness check instead of being silently dropped.
struct AnyKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        return nil
    }
}

func requireKnownKeys(_ decoder: Decoder, allowed: [String], context: String) throws {
    let container = try decoder.container(keyedBy: AnyKey.self)
    let unknown = Set(container.allKeys.map(\.stringValue)).subtracting(allowed)
    guard unknown.isEmpty else {
        throw DecodingError.dataCorrupted(
            .init(
                codingPath: decoder.codingPath,
                debugDescription: "\(context) contains unknown fields: \(unknown.sorted().joined(separator: ", "))"
            )
        )
    }
}

// MARK: - Frozen fixture corpus

public struct FixtureParagraph: Codable, Equatable, Sendable {
    public let heading: String
    public let text: String
}

public struct FixtureSource: Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let publisher: String
    public let canonicalURL: URL
    public let sourceType: String
    public let paragraphs: [FixtureParagraph]
}

public struct FixtureAnchor: Codable, Equatable, Sendable {
    public let sourceID: String
    public let quote: String
}

public struct FixtureClaim: Codable, Equatable, Sendable {
    public let dimension: String
    public let text: String
    public let anchor: FixtureAnchor
}

public struct FixtureCorpus: Codable, Equatable, Sendable {
    public let schemaVersion: String
    public let synthetic: Bool
    public let question: String
    public let mode: ResearchMode
    public let sources: [FixtureSource]
    public let claims: [FixtureClaim]
}

extension FixtureParagraph {
    private enum CodingKeys: String, CodingKey {
        case heading
        case text
    }

    public init(from decoder: Decoder) throws {
        try requireKnownKeys(decoder, allowed: ["heading", "text"], context: "fixture paragraph")
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            heading: try container.decode(String.self, forKey: .heading),
            text: try container.decode(String.self, forKey: .text)
        )
    }
}

extension FixtureSource {
    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case publisher
        case canonicalURL
        case sourceType
        case paragraphs
    }

    public init(from decoder: Decoder) throws {
        try requireKnownKeys(
            decoder,
            allowed: ["id", "title", "publisher", "canonicalURL", "sourceType", "paragraphs"],
            context: "fixture source"
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            title: try container.decode(String.self, forKey: .title),
            publisher: try container.decode(String.self, forKey: .publisher),
            canonicalURL: try container.decode(URL.self, forKey: .canonicalURL),
            sourceType: try container.decode(String.self, forKey: .sourceType),
            paragraphs: try container.decode([FixtureParagraph].self, forKey: .paragraphs)
        )
    }
}

extension FixtureAnchor {
    private enum CodingKeys: String, CodingKey {
        case sourceID
        case quote
    }

    public init(from decoder: Decoder) throws {
        try requireKnownKeys(decoder, allowed: ["sourceID", "quote"], context: "fixture anchor")
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            sourceID: try container.decode(String.self, forKey: .sourceID),
            quote: try container.decode(String.self, forKey: .quote)
        )
    }
}

extension FixtureClaim {
    private enum CodingKeys: String, CodingKey {
        case dimension
        case text
        case anchor
    }

    public init(from decoder: Decoder) throws {
        try requireKnownKeys(decoder, allowed: ["dimension", "text", "anchor"], context: "fixture claim")
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            dimension: try container.decode(String.self, forKey: .dimension),
            text: try container.decode(String.self, forKey: .text),
            anchor: try container.decode(FixtureAnchor.self, forKey: .anchor)
        )
    }
}

extension FixtureCorpus {
    private enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case synthetic
        case question
        case mode
        case sources
        case claims
    }

    public init(from decoder: Decoder) throws {
        try requireKnownKeys(
            decoder,
            allowed: ["schema_version", "synthetic", "question", "mode", "sources", "claims"],
            context: "fixture corpus"
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            schemaVersion: try container.decode(String.self, forKey: .schemaVersion),
            synthetic: try container.decode(Bool.self, forKey: .synthetic),
            question: try container.decode(String.self, forKey: .question),
            mode: try container.decode(ResearchMode.self, forKey: .mode),
            sources: try container.decode([FixtureSource].self, forKey: .sources),
            claims: try container.decode([FixtureClaim].self, forKey: .claims)
        )
    }
}

// MARK: - Integrity failures

public enum IntegrityError: Error, Equatable, LocalizedError {
    case quoteNotFound(claimID: String)
    case unknownReference(kind: String, id: String)
    case emptyCitation(claimID: String)

    public var errorDescription: String? {
        switch self {
        case let .quoteNotFound(claimID):
            "No passage contains the anchored quote for claim \(claimID)."
        case let .unknownReference(kind, id):
            "Dangling \(kind) reference: \(id)."
        case let .emptyCitation(claimID):
            "Citation for claim \(claimID) has no evidence links."
        }
    }
}

// MARK: - Deterministic fake pipeline

public enum DeterministicPipeline {

    /// Runs the frozen fixture through deterministic fake adapters. No network,
    /// keys, Docker, or model weights are involved. Two runs over the same
    /// corpus produce byte-identical persisted runs.
    public static func run(_ corpus: FixtureCorpus, runID: String = "fixture-run") async throws -> PersistedRun {
        let machine = RunStateMachine(run: ResearchRun(id: runID, question: corpus.question, mode: corpus.mode))

        try await machine.transition(to: .scoped, message: "Fixture scope frozen")
        try await machine.transition(to: .rewriting, message: "Fixture queries fixed")

        var hits: [SearchHit] = []
        for (rank, fixtureSource) in corpus.sources.enumerated() {
            hits.append(
                SearchHit(
                    id: StableIdentity.make("hit", fixtureSource.canonicalURL.absoluteString, String(rank)),
                    query: corpus.question,
                    rank: rank,
                    url: fixtureSource.canonicalURL,
                    title: fixtureSource.title,
                    snippet: String(fixtureSource.paragraphs.first?.text.prefix(80) ?? "")
                )
            )
        }
        try await machine.transition(to: .searching, message: "Fake search returned \(hits.count) hits")

        try await machine.transition(to: .acquiring, message: "Fake fetcher returned fixture bodies")
        try await machine.transition(to: .extracting, message: "Fixture extraction produced immutable snapshots")

        var sources: [Source] = []
        var snapshots: [Snapshot] = []
        var passages: [Passage] = []
        var snapshotsBySourceID: [String: Snapshot] = [:]

        for fixtureSource in corpus.sources {
            let sourceID = StableIdentity.make("source", fixtureSource.canonicalURL.absoluteString)
            let text = fixtureSource.paragraphs.map(\.text).joined(separator: "\n\n")
            let snapshot = Snapshot(
                id: StableIdentity.make("snapshot", sourceID, StableIdentity.digest(text)),
                sourceID: sourceID,
                contentHash: StableIdentity.digest(text),
                extractedText: text,
                extractorVersion: "fixture-extractor-1"
            )
            sources.append(
                Source(
                    id: sourceID,
                    title: fixtureSource.title,
                    publisher: fixtureSource.publisher,
                    canonicalURL: fixtureSource.canonicalURL,
                    sourceType: fixtureSource.sourceType
                )
            )
            snapshots.append(snapshot)
            snapshotsBySourceID[fixtureSource.id] = snapshot

            for (ordinal, paragraph) in fixtureSource.paragraphs.enumerated() {
                passages.append(
                    Passage(
                        id: StableIdentity.make("passage", snapshot.id, String(ordinal), StableIdentity.digest(paragraph.text)),
                        snapshotID: snapshot.id,
                        ordinal: ordinal,
                        heading: paragraph.heading,
                        text: paragraph.text,
                        textHash: StableIdentity.digest(paragraph.text)
                    )
                )
            }
        }

        try await machine.transition(to: .retrieving, message: "Lexical retrieval ranked fixture passages")

        var claims: [Claim] = []
        var evidenceLinks: [EvidenceLink] = []
        var citations: [Citation] = []

        for fixtureClaim in corpus.claims {
            let claimID = StableIdentity.make("claim", fixtureClaim.dimension, fixtureClaim.text)
            guard let snapshot = snapshotsBySourceID[fixtureClaim.anchor.sourceID] else {
                throw IntegrityError.unknownReference(kind: "source", id: fixtureClaim.anchor.sourceID)
            }
            guard let passage = passages.first(where: { $0.snapshotID == snapshot.id && $0.text.contains(fixtureClaim.anchor.quote) }) else {
                throw IntegrityError.quoteNotFound(claimID: claimID)
            }
            claims.append(Claim(id: claimID, dimension: fixtureClaim.dimension, text: fixtureClaim.text))
            let link = EvidenceLink(
                id: StableIdentity.make("evidence", claimID, passage.id, fixtureClaim.anchor.quote),
                claimID: claimID,
                passageID: passage.id,
                relation: .supports,
                quote: fixtureClaim.anchor.quote
            )
            evidenceLinks.append(link)
            citations.append(
                Citation(
                    id: StableIdentity.make("citation", claimID),
                    claimID: claimID,
                    evidenceLinkIDs: [link.id]
                )
            )
        }

        try await machine.transition(to: .buildingEvidence, message: "Evidence graph built from fixture anchors")
        try await machine.transition(to: .drafting, message: "Template synthesis produced the fixture brief")
        try await machine.transition(to: .validating, message: "Citation integrity validated")
        try await machine.transition(to: .complete, message: "Fixture run complete")

        let result = ResearchResult(
            run: await machine.run,
            summary: "Fixture synthesis: \(claims.count) claims resolved to \(sources.count) synthetic sources.",
            recommendation: corpus.claims.first?.text ?? "No claim in fixture.",
            openQuestion: "Not evaluated in the deterministic fixture.",
            columnTitles: [],
            comparisonRows: [],
            sources: sources,
            snapshots: snapshots,
            passages: passages,
            claims: claims,
            evidenceLinks: evidenceLinks,
            citations: citations
        )
        try validate(result)
        return PersistedRun(result: result, events: await machine.events)
    }

    /// Structural proof that every factual link resolves. Any dangling or
    /// unsupported reference throws; nothing is "fixed up" silently.
    public static func validate(_ result: ResearchResult) throws {
        var claimsByID: Set<String> = []
        for claim in result.claims { claimsByID.insert(claim.id) }

        var passagesByID: [String: Passage] = [:]
        for passage in result.passages { passagesByID[passage.id] = passage }

        var linksByID: [String: EvidenceLink] = [:]
        for link in result.evidenceLinks { linksByID[link.id] = link }

        for link in result.evidenceLinks {
            guard claimsByID.contains(link.claimID) else {
                throw IntegrityError.unknownReference(kind: "claim", id: link.claimID)
            }
            guard let passage = passagesByID[link.passageID] else {
                throw IntegrityError.unknownReference(kind: "passage", id: link.passageID)
            }
            guard passage.text.contains(link.quote) else {
                throw IntegrityError.quoteNotFound(claimID: link.claimID)
            }
        }

        for citation in result.citations {
            guard claimsByID.contains(citation.claimID) else {
                throw IntegrityError.unknownReference(kind: "claim", id: citation.claimID)
            }
            guard !citation.evidenceLinkIDs.isEmpty else {
                throw IntegrityError.emptyCitation(claimID: citation.claimID)
            }
            for linkID in citation.evidenceLinkIDs where linksByID[linkID] == nil {
                throw IntegrityError.unknownReference(kind: "evidence", id: linkID)
            }
        }

        var citationIDs: Set<String> = []
        for citation in result.citations { citationIDs.insert(citation.id) }
        for row in result.comparisonRows {
            for value in row.values where !citationIDs.contains(value.citationID) {
                throw IntegrityError.unknownReference(kind: "citation", id: value.citationID)
            }
        }
    }
}

// MARK: - Run persistence

public struct RunStore: Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public func save(_ persisted: PersistedRun) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        try encoder.encode(persisted).write(to: fileURL(for: persisted.result.run.id), options: .atomic)
    }

    public func load(runID: String) throws -> PersistedRun {
        let data = try Data(contentsOf: fileURL(for: runID))
        return try JSONDecoder().decode(PersistedRun.self, from: data)
    }

    private func fileURL(for runID: String) -> URL {
        directory.appendingPathComponent("\(runID).json")
    }
}
