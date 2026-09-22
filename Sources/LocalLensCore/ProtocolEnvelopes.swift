import Foundation

/// Frozen protocol version carried by every envelope.
public enum ProtocolVersion {
    public static let v1 = "1.0.0"
}

public enum ProtocolError: Error, Equatable, LocalizedError {
    case unsupportedVersion(String)
    case unknownCommand(String)
    case unknownEventKind(String)
    case unknownErrorCode(String)

    public var errorDescription: String? {
        switch self {
        case let .unsupportedVersion(version):
            "Unsupported protocol version: \(version)."
        case let .unknownCommand(command):
            "Unknown command: \(command)."
        case let .unknownEventKind(kind):
            "Unknown event kind: \(kind)."
        case let .unknownErrorCode(code):
            "Unknown error code: \(code)."
        }
    }
}

// MARK: - Commands

public enum ResearchCommand: Equatable, Sendable {
    case startRun(runID: String, question: String, mode: ResearchMode)
    case cancelRun(runID: String, reason: String?)
}

extension ResearchCommand: Codable {

    private enum DiscriminatorKey: String, CodingKey {
        case schemaVersion = "schema_version"
        case command
    }

    private enum StartRunKey: String, CodingKey {
        case schemaVersion = "schema_version"
        case command
        case runID = "run_id"
        case question
        case mode
    }

    private enum CancelRunKey: String, CodingKey {
        case schemaVersion = "schema_version"
        case command
        case runID = "run_id"
        case reason
    }

    public init(from decoder: Decoder) throws {
        let discriminator = try decoder.container(keyedBy: DiscriminatorKey.self)
        let version = try discriminator.decode(String.self, forKey: .schemaVersion)
        guard version == ProtocolVersion.v1 else {
            throw ProtocolError.unsupportedVersion(version)
        }
        let command = try discriminator.decode(String.self, forKey: .command)
        switch command {
        case "start_run":
            try requireKnownKeys(
                decoder,
                allowed: ["schema_version", "command", "run_id", "question", "mode"],
                context: "start_run command"
            )
            let container = try decoder.container(keyedBy: StartRunKey.self)
            self = .startRun(
                runID: try container.decode(String.self, forKey: .runID),
                question: try container.decode(String.self, forKey: .question),
                mode: try container.decode(ResearchMode.self, forKey: .mode)
            )
        case "cancel_run":
            try requireKnownKeys(
                decoder,
                allowed: ["schema_version", "command", "run_id", "reason"],
                context: "cancel_run command"
            )
            let container = try decoder.container(keyedBy: CancelRunKey.self)
            self = .cancelRun(
                runID: try container.decode(String.self, forKey: .runID),
                reason: try container.decodeIfPresent(String.self, forKey: .reason)
            )
        default:
            throw ProtocolError.unknownCommand(command)
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case let .startRun(runID, question, mode):
            var container = encoder.container(keyedBy: StartRunKey.self)
            try container.encode(ProtocolVersion.v1, forKey: .schemaVersion)
            try container.encode("start_run", forKey: .command)
            try container.encode(runID, forKey: .runID)
            try container.encode(question, forKey: .question)
            try container.encode(mode, forKey: .mode)
        case let .cancelRun(runID, reason):
            var container = encoder.container(keyedBy: CancelRunKey.self)
            try container.encode(ProtocolVersion.v1, forKey: .schemaVersion)
            try container.encode("cancel_run", forKey: .command)
            try container.encode(runID, forKey: .runID)
            try container.encodeIfPresent(reason, forKey: .reason)
        }
    }
}

// MARK: - Events

public struct EventEnvelope: Codable, Equatable, Sendable {
    public let runID: String
    public let event: RunEvent

    public init(runID: String, event: RunEvent) {
        self.runID = runID
        self.event = event
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case kind
        case runID = "run_id"
        case event
    }

    public init(from decoder: Decoder) throws {
        try requireKnownKeys(decoder, allowed: ["schema_version", "kind", "run_id", "event"], context: "event envelope")
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(String.self, forKey: .schemaVersion)
        guard version == ProtocolVersion.v1 else {
            throw ProtocolError.unsupportedVersion(version)
        }
        let kind = try container.decode(String.self, forKey: .kind)
        guard kind == "run_event" else {
            throw ProtocolError.unknownEventKind(kind)
        }
        self.init(
            runID: try container.decode(String.self, forKey: .runID),
            event: try container.decode(RunEvent.self, forKey: .event)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(ProtocolVersion.v1, forKey: .schemaVersion)
        try container.encode("run_event", forKey: .kind)
        try container.encode(runID, forKey: .runID)
        try container.encode(event, forKey: .event)
    }
}

// MARK: - Errors

public enum ErrorCode: String, Codable, CaseIterable, Sendable {
    case illegalTransition = "illegal_transition"
    case terminalState = "terminal_state"
    case unknownField = "unknown_field"
    case unsupportedSchemaVersion = "unsupported_schema_version"
    case invalidReference = "invalid_reference"
    case integrityFailure = "integrity_failure"
}

public struct ErrorEnvelope: Codable, Equatable, Sendable {
    public let code: ErrorCode
    public let message: String
    public let runID: String?

    public init(code: ErrorCode, message: String, runID: String? = nil) {
        self.code = code
        self.message = message
        self.runID = runID
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case code
        case message
        case runID = "run_id"
    }

    public init(from decoder: Decoder) throws {
        try requireKnownKeys(decoder, allowed: ["schema_version", "code", "message", "run_id"], context: "error envelope")
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(String.self, forKey: .schemaVersion)
        guard version == ProtocolVersion.v1 else {
            throw ProtocolError.unsupportedVersion(version)
        }
        let rawCode = try container.decode(String.self, forKey: .code)
        guard let code = ErrorCode(rawValue: rawCode) else {
            throw ProtocolError.unknownErrorCode(rawCode)
        }
        self.init(
            code: code,
            message: try container.decode(String.self, forKey: .message),
            runID: try container.decodeIfPresent(String.self, forKey: .runID)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(ProtocolVersion.v1, forKey: .schemaVersion)
        try container.encode(code, forKey: .code)
        try container.encode(message, forKey: .message)
        try container.encodeIfPresent(runID, forKey: .runID)
    }
}
