import Foundation

// MARK: - Provider errors

/// The typed failures of one answer provider. Kept small on purpose: the live
/// slice needs to tell a transport fault from a bad status from an unreadable
/// body, and nothing more.
public enum QuickProviderError: Error, Equatable, LocalizedError, Sendable {
    case transportFailure(reason: String)
    case httpStatus(code: Int)
    case malformedResponse(reason: String)
    case emptyAnswer

    public var kind: String {
        switch self {
        case .transportFailure: "provider_transport"
        case .httpStatus: "provider_http_status"
        case .malformedResponse: "provider_malformed_response"
        case .emptyAnswer: "provider_empty_answer"
        }
    }

    public var reason: String {
        switch self {
        case let .transportFailure(reason):
            "the answer provider transport failed: \(reason)"
        case let .httpStatus(code):
            "the answer provider returned HTTP \(code)"
        case let .malformedResponse(reason):
            "the answer provider response could not be read: \(reason)"
        case .emptyAnswer:
            "the answer provider returned no content"
        }
    }

    public var errorDescription: String? { reason }
}

// MARK: - Configuration

public struct DeepSeekConfiguration: Equatable, Sendable {
    public let baseURL: URL
    public let model: String
    /// Never logged, echoed, or persisted. Sent only in the request header.
    public let apiKey: String
    public let timeoutSeconds: Double
    /// Quick disables thinking mode, so this cap is reserved for final JSON.
    /// It remains at the existing 4,000-token experiment ceiling rather than
    /// silently expanding paid output after a failed run.
    public let maximumOutputTokens: Int

    public init(
        baseURL: URL = URL(string: "https://api.deepseek.com")!,
        model: String = "deepseek-flash",
        apiKey: String,
        timeoutSeconds: Double = 30,
        maximumOutputTokens: Int = 4000
    ) {
        self.baseURL = baseURL
        self.model = model
        self.apiKey = apiKey
        self.timeoutSeconds = timeoutSeconds
        self.maximumOutputTokens = maximumOutputTokens
    }
}

// MARK: - Provider

/// The hosted DeepSeek answer provider. It uses the existing `SearchTransport`
/// for its POST so tests drive it with a stub, and it treats the model's JSON
/// as an untrusted proposal that the runner validates against stored passages.
///
/// Verified against the official docs on 2026-09-23: base URL
/// `https://api.deepseek.com`, `POST /chat/completions`, current model
/// `deepseek-flash` (DeepSeek-V4.1-Flash). The packet's assumed
/// `deepseek-v4-flash` has been retired.
public struct DeepSeekAnswerProvider: QuickAnswerProvider {
    public let configuration: DeepSeekConfiguration
    private let transport: any SearchTransport

    public init(configuration: DeepSeekConfiguration, transport: any SearchTransport) {
        self.configuration = configuration
        self.transport = transport
    }

    public func answer(_ request: AnswerRequest) async throws -> AnswerProposal {
        let endpoint = configuration.baseURL.appendingPathComponent("chat/completions")
        let body = try Self.requestBody(for: request, configuration: configuration)
        let httpRequest = SearchRequest(
            url: endpoint,
            method: "POST",
            headers: [
                "Content-Type": "application/json",
                "Accept": "application/json",
                "Authorization": "Bearer \(configuration.apiKey)",
            ],
            timeoutSeconds: configuration.timeoutSeconds,
            body: body
        )

        let response: SearchResponse
        do {
            response = try await transport.send(httpRequest)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw QuickProviderError.transportFailure(reason: String(describing: error))
        }
        guard response.statusCode == 200 else {
            throw QuickProviderError.httpStatus(code: response.statusCode)
        }
        return try Self.decode(response.body)
    }

    // MARK: Wire format

    /// The provider sees only the selected passage ids, headings, and text.
    /// It is told the exact JSON shape and that quotes must be exact.
    public static func requestBody(
        for request: AnswerRequest,
        configuration: DeepSeekConfiguration
    ) throws -> Data {
        let system = AnswerPrompt.system(mode: request.mode, dimensions: request.dimensions)
        let user = AnswerPrompt.user(question: request.question, passages: request.passages)
        let wire = WireRequest(
            model: configuration.model,
            messages: [
                WireRequest.Message(role: "system", content: system),
                WireRequest.Message(role: "user", content: user),
            ],
            thinking: WireRequest.Thinking(type: "disabled"),
            responseFormat: WireRequest.ResponseFormat(type: "json_object"),
            maxTokens: configuration.maximumOutputTokens,
            temperature: 0
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(wire)
    }

    public static func decode(_ data: Data) throws -> AnswerProposal {
        let response: WireResponse
        do {
            response = try JSONDecoder().decode(WireResponse.self, from: data)
        } catch {
            throw QuickProviderError.malformedResponse(reason: "envelope: \(error)")
        }
        guard let content = response.choices.first?.message.content, !content.isEmpty else {
            throw QuickProviderError.emptyAnswer
        }
        guard let contentData = content.data(using: .utf8) else {
            throw QuickProviderError.malformedResponse(reason: "content is not UTF-8")
        }
        let proposal: WireProposal
        do {
            proposal = try JSONDecoder().decode(WireProposal.self, from: contentData)
        } catch {
            throw QuickProviderError.malformedResponse(reason: "content: \(error)")
        }
        return AnswerProposal(
            answer: proposal.answer,
            claims: proposal.claims.map {
                ProposedClaim(text: $0.text, passageID: $0.passageID, quote: $0.quote)
            },
            promptTokens: response.usage?.promptTokens,
            completionTokens: response.usage?.completionTokens
        )
    }

    // MARK: Private wire types

    private struct WireRequest: Encodable {
        struct Message: Encodable {
            let role: String
            let content: String
        }

        struct ResponseFormat: Encodable {
            let type: String
        }

        struct Thinking: Encodable {
            let type: String
        }

        let model: String
        let messages: [Message]
        let thinking: Thinking
        let responseFormat: ResponseFormat
        let maxTokens: Int
        let temperature: Double

        private enum CodingKeys: String, CodingKey {
            case model
            case messages
            case thinking
            case responseFormat = "response_format"
            case maxTokens = "max_tokens"
            case temperature
        }
    }

    private struct WireResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let content: String?
            }
            let message: Message
        }

        struct Usage: Decodable {
            let promptTokens: Int?
            let completionTokens: Int?

            private enum CodingKeys: String, CodingKey {
                case promptTokens = "prompt_tokens"
                case completionTokens = "completion_tokens"
            }
        }

        let choices: [Choice]
        let usage: Usage?
    }

    private struct WireProposal: Decodable {
        struct Claim: Decodable {
            let text: String
            let passageID: String
            let quote: String

            private enum CodingKeys: String, CodingKey {
                case text
                case passageID = "passage_id"
                case quote
            }
        }

        let answer: String
        let claims: [Claim]
    }
}
