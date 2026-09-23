import Foundation

// MARK: - Frozen Quick corpus

/// A frozen, offline Quick corpus: synthetic sources, their documents, and a
/// question set with retrieval queries and exact quotes.
///
/// The corpus is data, not a live run. Loading it opens a file and nothing else;
/// `makeIndexedStore()` turns its documents into stored snapshots through the
/// same M002.4 extraction and M002.5 storage boundaries the pipeline uses, so a
/// value built here is the same kind of evidence a real run would produce.
public struct QuickCorpus: Decodable, Equatable, Sendable {
    public struct Meta: Decodable, Equatable, Sendable {
        public let synthetic: Bool
        public let license: String
        public let shape: String
        public let note: String

        public init(synthetic: Bool, license: String, shape: String, note: String) {
            self.synthetic = synthetic
            self.license = license
            self.shape = shape
            self.note = note
        }
    }

    public struct SourceEntry: Decodable, Equatable, Sendable {
        public let id: String
        public let title: String
        public let publisher: String
        public let canonicalURL: URL
        public let sourceType: String

        public init(id: String, title: String, publisher: String, canonicalURL: URL, sourceType: String) {
            self.id = id
            self.title = title
            self.publisher = publisher
            self.canonicalURL = canonicalURL
            self.sourceType = sourceType
        }
    }

    public struct Document: Decodable, Equatable, Sendable {
        public let id: String
        public let sourceID: String
        public let url: URL
        public let contentType: String
        public let why: String
        public let body: String

        public init(id: String, sourceID: String, url: URL, contentType: String, why: String, body: String) {
            self.id = id
            self.sourceID = sourceID
            self.url = url
            self.contentType = contentType
            self.why = why
            self.body = body
        }
    }

    public struct ClaimEntry: Decodable, Equatable, Sendable {
        public let dimension: String
        public let text: String
        public let query: String
        public let quote: String
        public let expectedSourceID: String

        public init(dimension: String, text: String, query: String, quote: String, expectedSourceID: String) {
            self.dimension = dimension
            self.text = text
            self.query = query
            self.quote = quote
            self.expectedSourceID = expectedSourceID
        }
    }

    public struct Question: Decodable, Equatable, Sendable {
        public let id: String
        public let why: String
        public let text: String
        public let claims: [ClaimEntry]

        public init(id: String, why: String, text: String, claims: [ClaimEntry]) {
            self.id = id
            self.why = why
            self.text = text
            self.claims = claims
        }
    }

    public let _fixture: Meta
    public let sources: [SourceEntry]
    public let documents: [Document]
    public let questions: [Question]

    public init(_fixture: Meta, sources: [SourceEntry], documents: [Document], questions: [Question]) {
        self._fixture = _fixture
        self.sources = sources
        self.documents = documents
        self.questions = questions
    }

    public static func load(from url: URL) throws -> QuickCorpus {
        try JSONDecoder().decode(QuickCorpus.self, from: Data(contentsOf: url))
    }

    /// The source records a plan needs, in fixture order.
    public var domainSources: [Source] {
        sources.map {
            Source(
                id: $0.id,
                title: $0.title,
                publisher: $0.publisher,
                canonicalURL: $0.canonicalURL,
                sourceType: $0.sourceType
            )
        }
    }

    /// Turn one frozen question into a deterministic run plan.
    public func plan(for question: Question) -> QuickRunPlan {
        let candidates = question.claims.map { entry in
            ClaimCandidate(
                claim: Claim(
                    id: StableIdentity.make("claim", entry.dimension, entry.text),
                    dimension: entry.dimension,
                    text: entry.text
                ),
                retrievalQuery: entry.query,
                quote: entry.quote
            )
        }
        return QuickRunPlan(
            id: question.id,
            question: question.text,
            candidates: candidates,
            sources: domainSources
        )
    }

    /// Builds the store and index from the corpus documents through the real
    /// extraction, storage, and lexical boundaries. No network, DNS, clock, or
    /// file beyond the already-loaded bodies.
    public func makeIndexedStore() async throws -> (store: SnapshotStore, index: LexicalIndex) {
        let store = SnapshotStore()
        for document in documents {
            _ = try await store.store(try Self.page(for: document))
        }
        let index = try LexicalIndex()
        for record in await store.records() {
            _ = try await index.ingest(record)
        }
        return (store, index)
    }

    private static func page(for document: Document) throws -> ExtractedPage {
        let result = AcquisitionResult(
            requestedURL: document.url,
            finalURL: document.url,
            statusCode: 200,
            contentType: document.contentType,
            body: Data(document.body.utf8),
            redirects: []
        )
        return try HTMLExtraction.extract(result, sourceID: document.sourceID)
    }
}

// MARK: - Strict decoding

extension QuickCorpus {
    private enum CodingKeys: String, CodingKey {
        case _fixture
        case sources
        case documents
        case questions
    }

    public init(from decoder: Decoder) throws {
        try requireKnownKeys(
            decoder,
            allowed: ["_fixture", "sources", "documents", "questions"],
            context: "quick corpus"
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            _fixture: try container.decode(Meta.self, forKey: ._fixture),
            sources: try container.decode([SourceEntry].self, forKey: .sources),
            documents: try container.decode([Document].self, forKey: .documents),
            questions: try container.decode([Question].self, forKey: .questions)
        )
    }
}

extension QuickCorpus.Meta {
    private enum CodingKeys: String, CodingKey {
        case synthetic
        case license
        case shape
        case note
    }

    public init(from decoder: Decoder) throws {
        try requireKnownKeys(decoder, allowed: ["synthetic", "license", "shape", "note"], context: "quick corpus meta")
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            synthetic: try container.decode(Bool.self, forKey: .synthetic),
            license: try container.decode(String.self, forKey: .license),
            shape: try container.decode(String.self, forKey: .shape),
            note: try container.decode(String.self, forKey: .note)
        )
    }
}

extension QuickCorpus.SourceEntry {
    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case publisher
        case canonicalURL = "canonical_url"
        case sourceType = "source_type"
    }

    public init(from decoder: Decoder) throws {
        try requireKnownKeys(
            decoder,
            allowed: ["id", "title", "publisher", "canonical_url", "source_type"],
            context: "quick corpus source"
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            title: try container.decode(String.self, forKey: .title),
            publisher: try container.decode(String.self, forKey: .publisher),
            canonicalURL: try container.decode(URL.self, forKey: .canonicalURL),
            sourceType: try container.decode(String.self, forKey: .sourceType)
        )
    }
}

extension QuickCorpus.Document {
    private enum CodingKeys: String, CodingKey {
        case id
        case sourceID = "source_id"
        case url
        case contentType = "content_type"
        case why
        case body
    }

    public init(from decoder: Decoder) throws {
        try requireKnownKeys(
            decoder,
            allowed: ["id", "source_id", "url", "content_type", "why", "body"],
            context: "quick corpus document"
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            sourceID: try container.decode(String.self, forKey: .sourceID),
            url: try container.decode(URL.self, forKey: .url),
            contentType: try container.decode(String.self, forKey: .contentType),
            why: try container.decode(String.self, forKey: .why),
            body: try container.decode(String.self, forKey: .body)
        )
    }
}

extension QuickCorpus.ClaimEntry {
    private enum CodingKeys: String, CodingKey {
        case dimension
        case text
        case query
        case quote
        case expectedSourceID = "expected_source_id"
    }

    public init(from decoder: Decoder) throws {
        try requireKnownKeys(
            decoder,
            allowed: ["dimension", "text", "query", "quote", "expected_source_id"],
            context: "quick corpus claim"
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            dimension: try container.decode(String.self, forKey: .dimension),
            text: try container.decode(String.self, forKey: .text),
            query: try container.decode(String.self, forKey: .query),
            quote: try container.decode(String.self, forKey: .quote),
            expectedSourceID: try container.decode(String.self, forKey: .expectedSourceID)
        )
    }
}

extension QuickCorpus.Question {
    private enum CodingKeys: String, CodingKey {
        case id
        case why
        case text
        case claims
    }

    public init(from decoder: Decoder) throws {
        try requireKnownKeys(decoder, allowed: ["id", "why", "text", "claims"], context: "quick corpus question")
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            why: try container.decode(String.self, forKey: .why),
            text: try container.decode(String.self, forKey: .text),
            claims: try container.decode([QuickCorpus.ClaimEntry].self, forKey: .claims)
        )
    }
}
