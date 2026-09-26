import Foundation

/// The answer-provider instruction shared by every provider boundary.
///
/// One function owns the contract so a hosted and a local provider cannot
/// drift into different trust instructions. It carries no secret and no
/// passage that was not already selected for synthesis.
public enum AnswerPrompt {
    public static func system(mode: ResearchMode, dimensions: [String]) -> String {
        let covered = dimensions.isEmpty ? ["Answer"] : dimensions
        return """
        You answer from supplied passages only. Return one JSON object:
        {"answer": "concise answer", "claims": [{"text": "atomic claim", "passage_id": "id", "quote": "exact substring"}]}
        Use only passage_id values from the passages. Each quote must be copied exactly from its passage. \
        Cover these answer dimensions, one or more atomic claims each: \(covered.joined(separator: ", ")).
        The mode is \(mode.rawValue). Never state anything the passages do not support, and never merge a snippet into a claim. \
        If the passages do not support the question, return "claims": [] and say so in the answer.
        """
    }

    public static func user(question: String, passages: [Passage]) -> String {
        var rendered = ""
        for passage in passages {
            rendered += "\n[\(passage.id)] \(passage.heading)\n\(passage.text)\n"
        }
        return "Question: \(question)\nPassages:\(rendered)"
    }
}

/// Configuration for an explicitly local, OpenAI-compatible answer endpoint.
///
/// This is the "explicit compatible endpoint" of the release contract: Ollama,
/// llama.cpp's server, LM Studio, and similar servers speak this shape. The
/// default model is a locally present instruction-tuned model; nothing is
/// downloaded by this code.
public struct LocalProviderConfiguration: Equatable, Sendable {
    public let baseURL: URL
    public let model: String
    public let timeoutSeconds: Double
    public let maximumOutputTokens: Int

    public init(
        baseURL: URL = URL(string: "http://127.0.0.1:11434")!,
        model: String = "qwen2.5-coder:14b-instruct-q4_K_M",
        timeoutSeconds: Double = 120,
        maximumOutputTokens: Int = 2000
    ) {
        self.baseURL = baseURL
        self.model = model
        self.timeoutSeconds = timeoutSeconds
        self.maximumOutputTokens = maximumOutputTokens
    }

    /// The OpenAI-compatible chat endpoint under the configured base.
    public var chatCompletionsURL: URL {
        baseURL.appendingPathComponent("v1/chat/completions")
    }

    /// A stable label for the toolbar and every artifact. It is never mixed
    /// with a hosted label.
    public var label: String { "local/\(model)" }
}

/// The local answer provider. It posts the same untrusted proposal contract to
/// a loopback OpenAI-compatible server and carries no credential.
///
/// The model's output is still only a proposal: `AnswerTrust` verifies every
/// claim against stored passages before a citation can exist. A local model is
/// never granted a weaker trust boundary than a hosted one.
public struct LocalAnswerProvider: QuickAnswerProvider {
    public let configuration: LocalProviderConfiguration
    private let transport: any SearchTransport

    public init(configuration: LocalProviderConfiguration, transport: any SearchTransport) {
        self.configuration = configuration
        self.transport = transport
    }

    public func answer(_ request: AnswerRequest) async throws -> AnswerProposal {
        let body = try Self.requestBody(for: request, configuration: configuration)
        let httpRequest = SearchRequest(
            url: configuration.chatCompletionsURL,
            method: "POST",
            headers: [
                "Content-Type": "application/json",
                "Accept": "application/json",
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

    /// The wire request. No `response_format` and no `thinking` field: local
    /// servers differ in which of those they accept, and a server-side 400
    /// would be a worse failure than tolerant extraction on our side.
    public static func requestBody(
        for request: AnswerRequest,
        configuration: LocalProviderConfiguration
    ) throws -> Data {
        let wire = WireRequest(
            model: configuration.model,
            messages: [
                WireRequest.Message(role: "system", content: AnswerPrompt.system(mode: request.mode, dimensions: request.dimensions)),
                WireRequest.Message(role: "user", content: AnswerPrompt.user(question: request.question, passages: request.passages)),
            ],
            temperature: 0,
            maxTokens: configuration.maximumOutputTokens,
            stream: false
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
        guard let content = response.choices.first?.message.content?
            .trimmingCharacters(in: .whitespacesAndNewlines), !content.isEmpty else {
            throw QuickProviderError.emptyAnswer
        }
        let proposal = try decodeProposal(from: content)
        return AnswerProposal(
            answer: proposal.answer,
            claims: proposal.claims.map {
                ProposedClaim(text: $0.text, passageID: $0.passageID, quote: $0.quote)
            },
            promptTokens: response.usage?.promptTokens,
            completionTokens: response.usage?.completionTokens
        )
    }

    /// Local models sometimes wrap JSON in a fenced block or add a sentence of
    /// framing. This extracts the outermost JSON object and decodes it
    /// strictly; it never repairs a field, invents a claim, or accepts a
    /// malformed passage id.
    static func decodeProposal(from content: String) throws -> WireProposal {
        var text = content
        if text.hasPrefix("```") {
            text = text
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start <= end else {
            throw QuickProviderError.malformedResponse(reason: "content carries no JSON object")
        }
        let json = String(text[start...end])
        guard let data = json.data(using: .utf8) else {
            throw QuickProviderError.malformedResponse(reason: "content is not UTF-8")
        }
        do {
            return try JSONDecoder().decode(WireProposal.self, from: data)
        } catch {
            throw QuickProviderError.malformedResponse(reason: "content: \(error)")
        }
    }

    // MARK: Wire types

    struct WireProposal: Decodable {
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

    private struct WireRequest: Encodable {
        struct Message: Encodable {
            let role: String
            let content: String
        }

        let model: String
        let messages: [Message]
        let temperature: Double
        let maxTokens: Int
        let stream: Bool

        private enum CodingKeys: String, CodingKey {
            case model
            case messages
            case temperature
            case maxTokens = "max_tokens"
            case stream
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
}
