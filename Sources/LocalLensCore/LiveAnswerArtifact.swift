import Foundation

/// A serialized, offline-renderable view of one completed live Quick answer.
///
/// The live executable writes it after a completed run; the native app reads it.
/// The app therefore never reaches the network and never calls a provider: it
/// renders a recorded live result. Every citation is resolved through the
/// existing `CitationCompilation`, so a citation in the artifact is an exact
/// stored quote over an immutable passage, never a search snippet.
public struct LiveAnswerArtifact: Codable, Equatable, Sendable {
    public struct Citation: Codable, Equatable, Sendable {
        public let marker: Int
        public let claimText: String
        public let quote: String
        public let passageID: String
        public let snapshotID: String
        public let heading: String
        /// The fetched document URL, not an unvisited search-result link.
        public let sourceURL: URL?
        /// Full saved passage for inspection. Older artifacts may have only
        /// the exact quoted span, so this is optional for decoding.
        public let passageText: String?

        public init(
            marker: Int,
            claimText: String,
            quote: String,
            passageID: String,
            snapshotID: String,
            heading: String,
            sourceURL: URL? = nil,
            passageText: String? = nil
        ) {
            self.marker = marker
            self.claimText = claimText
            self.quote = quote
            self.passageID = passageID
            self.snapshotID = snapshotID
            self.heading = heading
            self.sourceURL = sourceURL
            self.passageText = passageText
        }
    }

    public let question: String
    /// The assembled answer: accepted claims only, each with its marker.
    public let answer: String
    /// `hosted` or `local`. The view shows it verbatim; the two are never merged.
    public let label: String
    public let provider: String
    public let generatedAt: String
    public let elapsedSeconds: Double
    public let citations: [Citation]

    public init(
        question: String,
        answer: String,
        label: String,
        provider: String,
        generatedAt: String,
        elapsedSeconds: Double,
        citations: [Citation]
    ) {
        self.question = question
        self.answer = answer
        self.label = label
        self.provider = provider
        self.generatedAt = generatedAt
        self.elapsedSeconds = elapsedSeconds
        self.citations = citations
    }

    /// Builds the artifact from a completed live result. Only citations that
    /// resolve to an exact stored passage are included, so the artifact cannot
    /// carry an unbound citation.
    public static func make(
        from result: LiveQuickResult,
        provider: String,
        elapsedSeconds: Double,
        generatedAt: String
    ) -> LiveAnswerArtifact {
        var entries: [Citation] = []
        for (index, citation) in result.compilation.citations.enumerated() {
            guard let resolved = try? result.compilation.resolve(citation.id) else { continue }
            entries.append(
                Citation(
                    marker: index + 1,
                    claimText: resolved.claim.text,
                    quote: resolved.evidenceLink.quote,
                    passageID: resolved.passage.id,
                    snapshotID: resolved.passage.snapshotID,
                    heading: resolved.passage.heading,
                    sourceURL: result.records.first(where: { $0.snapshot.id == resolved.passage.snapshotID })?.finalURL,
                    passageText: resolved.passage.text
                )
            )
        }
        return LiveAnswerArtifact(
            question: result.run.question,
            answer: result.answer,
            label: result.label,
            provider: provider,
            generatedAt: generatedAt,
            elapsedSeconds: elapsedSeconds,
            citations: entries
        )
    }

    public func write(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: url, options: .atomic)
    }

    public static func load(from url: URL) throws -> LiveAnswerArtifact {
        try JSONDecoder().decode(LiveAnswerArtifact.self, from: Data(contentsOf: url))
    }
}
