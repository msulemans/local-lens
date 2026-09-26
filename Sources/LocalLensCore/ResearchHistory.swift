import Foundation

/// One completed research run kept in the on-disk history.
public struct ResearchHistoryEntry: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let question: String
    public let mode: ResearchMode
    /// ISO-8601, UTC. The view formats it; storage never depends on the locale.
    public let completedAt: String
    public let citationCount: Int
    public let label: String
    public let provider: String
    public let elapsedSeconds: Double
    public let answer: String
    public let citations: [LiveAnswerArtifact.Citation]

    public init(
        id: String,
        question: String,
        mode: ResearchMode,
        completedAt: String,
        citationCount: Int,
        label: String,
        provider: String,
        elapsedSeconds: Double,
        answer: String,
        citations: [LiveAnswerArtifact.Citation]
    ) {
        self.id = id
        self.question = question
        self.mode = mode
        self.completedAt = completedAt
        self.citationCount = citationCount
        self.label = label
        self.provider = provider
        self.elapsedSeconds = elapsedSeconds
        self.answer = answer
        self.citations = citations
    }

    public init(artifact: LiveAnswerArtifact, mode: ResearchMode, completedAt: String) {
        self.init(
            id: StableIdentity.make("history", artifact.question, mode.rawValue, artifact.provider, completedAt),
            question: artifact.question,
            mode: mode,
            completedAt: completedAt,
            citationCount: artifact.citations.count,
            label: artifact.label,
            provider: artifact.provider,
            elapsedSeconds: artifact.elapsedSeconds,
            answer: artifact.answer,
            citations: artifact.citations
        )
    }

    /// Rebuilds the serialized artifact shape the evidence pane renders, so a
    /// history entry and a live result share one renderer.
    public var artifact: LiveAnswerArtifact {
        LiveAnswerArtifact(
            question: question,
            answer: answer,
            label: label,
            provider: provider,
            generatedAt: completedAt,
            elapsedSeconds: elapsedSeconds,
            citations: citations
        )
    }
}

/// The on-disk research history.
///
/// It stores only the serialized artifact: an answered question with exact
/// stored-passage citations. It never stores a raw HTML body, a model
/// transcript, or a secret. A corrupt entry is skipped rather than repaired, so
/// a damaged file cannot invent a citation.
public struct ResearchHistoryStore: Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    private var fileManager: FileManager { .default }

    /// The default location under Application Support.
    public static func applicationSupport() throws -> ResearchHistoryStore {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return ResearchHistoryStore(directory: base.appendingPathComponent("LocalLens/history", isDirectory: true))
    }

    private func ensureDirectory() throws {
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    private func fileURL(for id: String) -> URL {
        directory.appendingPathComponent("\(id).json")
    }

    public func save(_ entry: ResearchHistoryEntry) throws {
        try ensureDirectory()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(entry).write(to: fileURL(for: entry.id), options: .atomic)
    }

    public func load(id: String) throws -> ResearchHistoryEntry {
        let data = try Data(contentsOf: fileURL(for: id))
        return try JSONDecoder().decode(ResearchHistoryEntry.self, from: data)
    }

    public func delete(id: String) throws {
        let url = fileURL(for: id)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    public func clear() throws {
        guard fileManager.fileExists(atPath: directory.path) else { return }
        for url in try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            try fileManager.removeItem(at: url)
        }
    }

    /// Newest first. Undecodable entries are skipped, never guessed at.
    public func list() throws -> [ResearchHistoryEntry] {
        guard fileManager.fileExists(atPath: directory.path) else { return [] }
        let urls = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        var entries: [ResearchHistoryEntry] = []
        for url in urls {
            guard let data = try? Data(contentsOf: url),
                  let entry = try? JSONDecoder().decode(ResearchHistoryEntry.self, from: data) else { continue }
            entries.append(entry)
        }
        return entries.sorted { $0.completedAt > $1.completedAt }
    }
}
