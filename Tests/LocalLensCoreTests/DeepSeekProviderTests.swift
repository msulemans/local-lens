import Foundation
import XCTest
@testable import LocalLensCore

/// A transport that records the last request and returns a canned response.
private final class CapturingTransport: SearchTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var captured: SearchRequest?
    private let response: SearchResponse

    init(response: SearchResponse) {
        self.response = response
    }

    var lastRequest: SearchRequest? {
        lock.withLock { captured }
    }

    func send(_ request: SearchRequest) async throws -> SearchResponse {
        lock.withLock { captured = request }
        return response
    }
}

final class DeepSeekProviderTests: XCTestCase {

    private func passage(_ text: String) -> Passage {
        Passage(
            id: StableIdentity.make("passage", "snap", "0", StableIdentity.digest(text)),
            snapshotID: "snap",
            ordinal: 0,
            heading: "Heading",
            text: text,
            textHash: StableIdentity.digest(text)
        )
    }

    private func envelope(content: String, promptTokens: Int = 12, completionTokens: Int = 3) throws -> Data {
        let object: [String: Any] = [
            "choices": [["message": ["content": content]]],
            "usage": ["prompt_tokens": promptTokens, "completion_tokens": completionTokens],
        ]
        return try JSONSerialization.data(withJSONObject: object)
    }

    func testRequestBodyCarriesPassagesAndNeverTheKey() throws {
        let stored = passage("The stored passage text.")
        let request = AnswerRequest(question: "What is stored?", passages: [stored])
        let configuration = DeepSeekConfiguration(apiKey: "super-secret-key", maximumOutputTokens: 512)
        let body = try DeepSeekAnswerProvider.requestBody(for: request, configuration: configuration)
        let text = try XCTUnwrap(String(data: body, encoding: .utf8))

        XCTAssertTrue(text.contains(stored.id), "the passage id must be in the prompt")
        XCTAssertTrue(text.contains("The stored passage text."), "the passage text must be in the prompt")
        XCTAssertTrue(text.contains("What is stored?"))
        XCTAssertFalse(text.contains("super-secret-key"), "the request body must never carry the key")
        XCTAssertTrue(text.contains("\"model\":\"deepseek-flash\""))
        XCTAssertTrue(text.contains("\"response_format\""))
        XCTAssertTrue(text.contains("\"thinking\":{\"type\":\"disabled\"}"), "Quick must reserve output for the final JSON rather than reasoning tokens")
        XCTAssertTrue(text.contains("\"max_tokens\":512"))
    }

    func testProviderSendsTheKeyOnlyInTheHeaderAndDecodesTheProposal() async throws {
        let contentData = try JSONSerialization.data(withJSONObject: [
            "answer": "A concise answer.",
            "claims": [["text": "a claim", "passage_id": "p1", "quote": "a quote"]],
        ])
        let content = try XCTUnwrap(String(data: contentData, encoding: .utf8))
        let data = try envelope(content: content)
        let transport = CapturingTransport(response: SearchResponse(statusCode: 200, body: data))
        let provider = DeepSeekAnswerProvider(
            configuration: DeepSeekConfiguration(apiKey: "hosted-key"),
            transport: transport
        )

        let proposal = try await provider.answer(AnswerRequest(question: "Q?", passages: [passage("body")]))

        XCTAssertEqual(proposal.answer, "A concise answer.")
        XCTAssertEqual(proposal.claims, [ProposedClaim(text: "a claim", passageID: "p1", quote: "a quote")])
        XCTAssertEqual(proposal.promptTokens, 12)
        XCTAssertEqual(proposal.completionTokens, 3)

        let captured = try XCTUnwrap(transport.lastRequest)
        XCTAssertEqual(captured.method, "POST")
        XCTAssertEqual(captured.headers["Authorization"], "Bearer hosted-key")
        XCTAssertTrue(captured.url.absoluteString.hasSuffix("/chat/completions"))
        let capturedBody = try XCTUnwrap(captured.body.flatMap { String(data: $0, encoding: .utf8) })
        XCTAssertFalse(capturedBody.contains("hosted-key"))
    }

    func testNon200IsATypedHTTPStatus() async throws {
        let transport = CapturingTransport(response: SearchResponse(statusCode: 429, body: Data()))
        let provider = DeepSeekAnswerProvider(
            configuration: DeepSeekConfiguration(apiKey: "k"),
            transport: transport
        )
        do {
            _ = try await provider.answer(AnswerRequest(question: "Q?", passages: [passage("body")]))
            XCTFail("expected a typed failure")
        } catch let error as QuickProviderError {
            XCTAssertEqual(error.kind, "provider_http_status")
        }
    }

    func testUnreadableEnvelopeIsAMalformedResponse() {
        XCTAssertThrowsError(try DeepSeekAnswerProvider.decode(Data("{}".utf8))) { error in
            XCTAssertEqual((error as? QuickProviderError)?.kind, "provider_malformed_response")
        }
    }

    func testEmptyChoicesIsAnEmptyAnswer() throws {
        let data = try JSONSerialization.data(withJSONObject: ["choices": []])
        XCTAssertThrowsError(try DeepSeekAnswerProvider.decode(data)) { error in
            XCTAssertEqual((error as? QuickProviderError)?.kind, "provider_empty_answer")
        }
    }

    func testNonJSONContentIsAMalformedResponse() throws {
        let data = try envelope(content: "not json at all")
        XCTAssertThrowsError(try DeepSeekAnswerProvider.decode(data)) { error in
            XCTAssertEqual((error as? QuickProviderError)?.kind, "provider_malformed_response")
        }
    }

    func testDefaultOutputCapRemainsWithinRecordedBudget() {
        // Thinking is explicitly disabled for Quick, but the existing paid
        // output ceiling is not raised to hide an earlier empty response.
        XCTAssertEqual(DeepSeekConfiguration(apiKey: "k").maximumOutputTokens, 4000)
    }

    /// The measured truncation failure: the cap is spent on `reasoning_content`
    /// and `content` comes back empty. It must be refused, not accepted.
    func testReasoningOnlyResponseIsRefusedAsEmpty() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "choices": [[
                "finish_reason": "length",
                "message": ["content": "", "reasoning_content": String(repeating: "x", count: 500)],
            ]],
        ])
        XCTAssertThrowsError(try DeepSeekAnswerProvider.decode(data)) { error in
            XCTAssertEqual(error as? QuickProviderError, .emptyAnswer)
        }
    }

    /// A proposal cut off by the cap is a malformed response, not a silent
    /// answer: the JSON body no longer decodes.
    func testTruncatedProposalIsRefusedAsMalformed() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "choices": [[
                "finish_reason": "length",
                "message": ["content": "{\"answer\": \"partial\"", "reasoning_content": "..."],
            ]],
        ])
        XCTAssertThrowsError(try DeepSeekAnswerProvider.decode(data)) { error in
            XCTAssertEqual((error as? QuickProviderError)?.kind, "provider_malformed_response")
        }
    }

    func testProviderErrorFamilyIsEnumerated() {
        let family: [QuickProviderError] = [
            .transportFailure(reason: "why"),
            .httpStatus(code: 500),
            .malformedResponse(reason: "why"),
            .emptyAnswer,
        ]
        XCTAssertEqual(
            family.map(\.kind),
            ["provider_transport", "provider_http_status", "provider_malformed_response", "provider_empty_answer"]
        )
        for error in family {
            XCTAssertFalse(error.reason.isEmpty)
            XCTAssertEqual(error.errorDescription, error.reason)
        }
    }
}
