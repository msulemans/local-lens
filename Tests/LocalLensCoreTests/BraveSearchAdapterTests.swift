import Foundation
import XCTest
@testable import LocalLensCore

private actor BraveTransportStub: SearchTransport {
    let result: Result<SearchResponse, TransportFailure>
    private(set) var requests: [SearchRequest] = []

    init(status: Int = 200, body: String) {
        result = .success(SearchResponse(statusCode: status, body: Data(body.utf8)))
    }

    init(failure: String) {
        result = .failure(TransportFailure(failure))
    }

    func send(_ request: SearchRequest) async throws -> SearchResponse {
        requests.append(request)
        return try result.get()
    }
}

final class BraveSearchAdapterTests: XCTestCase {
    private let key = "synthetic-secret-never-log"

    private func adapter(_ transport: any SearchTransport, maxResults: Int = 10) throws -> BraveSearchAdapter {
        try BraveSearchAdapter(
            configuration: BraveSearchConfiguration(apiKey: key, maxResults: maxResults),
            transport: transport
        )
    }

    func testRequestUsesPinnedEndpointAndHeaderOnlyKey() async throws {
        let stub = BraveTransportStub(body: #"{"web":{"results":[]}}"#)
        let result = try await adapter(stub).search("  Swift task groups  ")
        XCTAssertEqual(result, .noResults(query: "Swift task groups"))
        let requests = await stub.requests
        XCTAssertEqual(requests.count, 1)
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.url.host, "api.search.brave.com")
        XCTAssertEqual(request.url.path, "/res/v1/web/search")
        let items = try XCTUnwrap(URLComponents(url: request.url, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(items.first(where: { $0.name == "q" })?.value, "Swift task groups")
        XCTAssertEqual(items.first(where: { $0.name == "count" })?.value, "10")
        XCTAssertEqual(request.headers["X-Subscription-Token"], key)
        XCTAssertFalse(request.url.absoluteString.contains(key), "secret must not enter a URL or typed status error")
    }

    func testResultsAreBoundedStableAndOnlyDiscoveryMetadata() async throws {
        let body = #"{"web":{"results":[{"title":"Official","url":"https://docs.swift.org/guide#fragment","description":"discovery only","extra_snippets":["not evidence"]},{"title":"Other","url":"https://example.org/other","description":null},{"title":"Bad beyond cap","url":"file:///secret"}]}}"#
        let stub = BraveTransportStub(body: body)
        let first = try await adapter(stub, maxResults: 2).search("swift guide")
        let second = try await adapter(stub, maxResults: 2).search("swift guide")
        guard case let .hits(hits) = first else { return XCTFail("expected hits") }
        XCTAssertEqual(first, second)
        XCTAssertEqual(hits.count, 2)
        XCTAssertEqual(hits.map(\.rank), [0, 1])
        XCTAssertEqual(hits[0].url.absoluteString, "https://docs.swift.org/guide")
        XCTAssertEqual(hits[0].snippet, "discovery only")
        XCTAssertEqual(hits[1].snippet, "")
        XCTAssertFalse(hits[0].snippet.contains("not evidence"))
    }

    func testMalformedConsumedFieldFailsClosed() async throws {
        let badBodies = [
            "{}",
            #"{"web":{"results":{}}}"#,
            #"{"web":{"results":[{"title":"bad","url":"file:///tmp/private"}]}}"#,
            #"{"web":{"results":[{"title":"bad","url":"https://user:pass@example.org/"}]}}"#,
            #"{"web":{"results":[{"title":"bad","url":"https://example.org/","description":5}]}}"#,
        ]
        for body in badBodies {
            do {
                _ = try await adapter(BraveTransportStub(body: body)).search("swift")
                XCTFail("expected malformed payload for \(body)")
            } catch let error as SearchError {
                guard case .malformedPayload = error else { return XCTFail("wrong error: \(error)") }
            }
        }
    }

    func testTypedStatusTransportEmptyAndConfigurationFailures() async throws {
        XCTAssertThrowsError(try BraveSearchConfiguration(apiKey: ""))
        XCTAssertThrowsError(try BraveSearchConfiguration(apiKey: key, maxResults: 21))
        XCTAssertThrowsError(try BraveSearchConfiguration(apiKey: key, timeoutSeconds: 0))

        do {
            _ = try await adapter(BraveTransportStub(body: "{}" )).search("  ")
            XCTFail("expected empty query")
        } catch let error as SearchError {
            XCTAssertEqual(error, .emptyQuery)
        }
        do {
            _ = try await adapter(BraveTransportStub(status: 429, body: "rate limited")).search("swift")
            XCTFail("expected status failure")
        } catch let error as SearchError {
            guard case let .httpStatus(code, url) = error else { return XCTFail("wrong error: \(error)") }
            XCTAssertEqual(code, 429)
            XCTAssertFalse(url.absoluteString.contains(key))
        }
        do {
            _ = try await adapter(BraveTransportStub(failure: "offline")).search("swift")
            XCTFail("expected transport failure")
        } catch let error as SearchError {
            XCTAssertEqual(error, .transportFailure(reason: "offline"))
        }
    }
}
