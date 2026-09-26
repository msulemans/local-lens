import Foundation

/// A privacy-safe diagnostics bundle.
///
/// It exists so a user can hand over something useful about a failure without
/// handing over their research. It contains counts, identifiers that are already
/// hashes, settings that are not secret, and typed refusal reasons. It never
/// contains a question, an answer, a claim, a quote, a URL, a search snippet, a
/// credential, or the content of any stored page.
public struct DiagnosticsReport: Codable, Equatable, Sendable {
    public struct Storage: Codable, Equatable, Sendable {
        public let historyEntries: Int
        public let snapshots: Int
        public let passages: Int
        public let bytesOnDisk: Int

        public init(historyEntries: Int, snapshots: Int, passages: Int, bytesOnDisk: Int) {
            self.historyEntries = historyEntries
            self.snapshots = snapshots
            self.passages = passages
            self.bytesOnDisk = bytesOnDisk
        }
    }

    public struct Settings: Codable, Equatable, Sendable {
        public let mode: String
        public let searchBackend: String
        public let usesLocalProvider: Bool
        /// The endpoint's scheme and host only: a loopback address is a fact
        /// worth reporting, an API key is not.
        public let localEndpointHost: String
        public let localModel: String
        public let reasoningEffort: String?
        public let hasHostedKey: Bool
        public let hasSearchKey: Bool

        public init(
            mode: String,
            searchBackend: String,
            usesLocalProvider: Bool,
            localEndpointHost: String,
            localModel: String,
            reasoningEffort: String?,
            hasHostedKey: Bool,
            hasSearchKey: Bool
        ) {
            self.mode = mode
            self.searchBackend = searchBackend
            self.usesLocalProvider = usesLocalProvider
            self.localEndpointHost = localEndpointHost
            self.localModel = localModel
            self.reasoningEffort = reasoningEffort
            self.hasHostedKey = hasHostedKey
            self.hasSearchKey = hasSearchKey
        }
    }

    public struct RecentFailure: Codable, Equatable, Sendable {
        /// Already a hash in the run's own record.
        public let runIdentifier: String
        public let mode: String
        public let reason: String
        public let at: String

        public init(runIdentifier: String, mode: String, reason: String, at: String) {
            self.runIdentifier = runIdentifier
            self.mode = mode
            self.reason = reason
            self.at = at
        }
    }

    public let appVersion: String
    public let appBuild: String
    public let protocolVersion: String
    public let operatingSystem: String
    public let architecture: String
    public let generatedAt: String
    public let storage: Storage
    public let settings: Settings
    public let recentFailures: [RecentFailure]

    public init(
        appVersion: String,
        appBuild: String,
        protocolVersion: String,
        operatingSystem: String,
        architecture: String,
        generatedAt: String,
        storage: Storage,
        settings: Settings,
        recentFailures: [RecentFailure]
    ) {
        self.appVersion = appVersion
        self.appBuild = appBuild
        self.protocolVersion = protocolVersion
        self.operatingSystem = operatingSystem
        self.architecture = architecture
        self.generatedAt = generatedAt
        self.storage = storage
        self.settings = settings
        self.recentFailures = recentFailures
    }

    public func json() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    /// Reduces an arbitrary string to a host, so a URL can be reported without
    /// its path or query. A string that is not a URL is reported as empty rather
    /// than passed through.
    public static func hostOnly(_ value: String) -> String {
        guard let url = URL(string: value), let host = url.host else { return "" }
        return host
    }

    /// Words that must never appear in a diagnostics bundle. Used by the test
    /// that proves the redaction is real, and by the packaging check.
    public static let forbiddenMarkers = [
        "question", "answer", "claim", "quote", "snippet", "api_key", "apikey",
        "authorization", "bearer", "password", "secret", "cookie", "token",
    ]
}
