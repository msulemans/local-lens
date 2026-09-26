import Foundation
import XCTest
@testable import LocalLensCore

private actor TavilyTransportStub: SearchTransport {
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

final class TavilySearchAdapterTests: XCTestCase {
    private let key = "synthetic-tavily-secret"

    private func adapter(_ transport: any SearchTransport, maxResults: Int = 10) throws -> TavilySearchAdapter {
        try TavilySearchAdapter(
            configuration: TavilySearchConfiguration(apiKey: key, maxResults: maxResults),
            transport: transport
        )
    }

    func testBasicSearchIsBoundedAndDoesNotRequestProviderAnswerOrRawContent() async throws {
        let stub = TavilyTransportStub(body: #"{"results":[]}"#)
        let outcome = try await adapter(stub).search("  Swift task groups ")
        XCTAssertEqual(outcome, .noResults(query: "Swift task groups"))
        let requests = await stub.requests
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.url, TavilySearchConfiguration.endpoint)
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.headers["Authorization"], "Bearer \(key)")
        XCTAssertFalse(request.url.absoluteString.contains(key))
        let body = try XCTUnwrap(request.body)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(payload["query"] as? String, "Swift task groups")
        XCTAssertEqual(payload["search_depth"] as? String, "basic")
        XCTAssertEqual(payload["max_results"] as? Int, 10)
        XCTAssertEqual(payload["include_answer"] as? Bool, false)
        XCTAssertEqual(payload["include_raw_content"] as? Bool, false)
        XCTAssertNil(payload["api_key"])
        XCTAssertFalse(String(data: body, encoding: .utf8)!.contains(key))
    }

    func testResultsAreStableBoundedDiscoveryMetadataOnly() async throws {
        let body = #"{"answer":"ignore me","results":[{"title":"Official","url":"https://docs.swift.org/guide#fragment","content":"discovery only","raw_content":"must not become evidence"},{"title":"Other","url":"https://example.org/other","content":null},{"title":"Beyond cap","url":"file:///private"}]}"#
        let stub = TavilyTransportStub(body: body)
        let first = try await adapter(stub, maxResults: 2).search("swift guide")
        let second = try await adapter(stub, maxResults: 2).search("swift guide")
        guard case let .hits(hits) = first else { return XCTFail("expected hits") }
        XCTAssertEqual(first, second)
        XCTAssertEqual(hits.count, 2)
        XCTAssertEqual(hits.map(\.rank), [0, 1])
        XCTAssertEqual(hits[0].url.absoluteString, "https://docs.swift.org/guide")
        XCTAssertEqual(hits[0].snippet, "discovery only")
        XCTAssertEqual(hits[1].snippet, "")
        XCTAssertFalse(hits[0].snippet.contains("must not become evidence"))
    }

    func testMalformedConsumedFieldsFailClosed() async throws {
        for body in [
            "{}",
            #"{"results":{}}"#,
            #"{"results":[{"title":"bad","url":"file:///private"}]}"#,
            #"{"results":[{"title":"bad","url":"https://user:pass@example.org/"}]}"#,
            #"{"results":[{"title":"bad","url":"https://example.org/","content":5}]}"#,
        ] {
            do {
                _ = try await adapter(TavilyTransportStub(body: body)).search("swift")
                XCTFail("expected malformed response")
            } catch let error as SearchError {
                guard case .malformedPayload = error else { return XCTFail("wrong error: \(error)") }
            }
        }
    }

    func testTypedStatusTransportAndConfigurationFailures() async throws {
        XCTAssertThrowsError(try TavilySearchConfiguration(apiKey: ""))
        XCTAssertThrowsError(try TavilySearchConfiguration(apiKey: key, maxResults: 21))
        XCTAssertThrowsError(try TavilySearchConfiguration(apiKey: key, timeoutSeconds: 0))
        do {
            _ = try await adapter(TavilyTransportStub(body: "{}")).search(" ")
            XCTFail("expected empty query")
        } catch let error as SearchError {
            XCTAssertEqual(error, .emptyQuery)
        }
        do {
            _ = try await adapter(TavilyTransportStub(status: 432, body: "quota exceeded")).search("swift")
            XCTFail("expected status error")
        } catch let error as SearchError {
            guard case let .httpStatus(code, url) = error else { return XCTFail("wrong error: \(error)") }
            XCTAssertEqual(code, 432)
            XCTAssertFalse(url.absoluteString.contains(key))
        }
        do {
            _ = try await adapter(TavilyTransportStub(failure: "offline")).search("swift")
            XCTFail("expected transport error")
        } catch let error as SearchError {
            XCTAssertEqual(error, .transportFailure(reason: "offline"))
        }
    }

    func testNewsRequestCarriesTheWindowAndParsesReportedDates() async throws {
        let stub = TavilyTransportStub(body: #"""
        {"results":[
          {"title":"A report","url":"https://news.example/a?utm_source=x#frag","content":"c","published_date":"Mon, 21 Sep 2026 08:34:00 GMT"},
          {"title":"An ISO report","url":"https://news.example/d","content":"c","published_date":"2026-09-24T09:15:00Z"},
          {"title":"Undated","url":"https://news.example/b","content":"c"},
          {"title":"Bad date","url":"https://news.example/c","content":"c","published_date":"last Tuesday"}
        ]}
        """#)
        let news = try TavilySearchAdapter(
            configuration: TavilySearchConfiguration(apiKey: key, topic: "news", days: 14),
            transport: stub
        )
        let dated = try await news.searchDated("query")
        XCTAssertEqual(dated.count, 4)
        XCTAssertEqual(
            dated[0].publishedAt,
            ISO8601DateFormatter().date(from: "2026-09-21T08:34:00Z"),
            "the live news topic reports RFC 1123, which must still parse"
        )
        XCTAssertEqual(dated[1].publishedAt, ISO8601DateFormatter().date(from: "2026-09-24T09:15:00Z"))
        XCTAssertNil(dated[2].publishedAt, "a missing date is not invented")
        XCTAssertNil(dated[3].publishedAt, "an unparseable date is not guessed")
        XCTAssertEqual(dated[0].hit.url.absoluteString, "https://news.example/a?utm_source=x")
        let requests = await stub.requests
        let request = try XCTUnwrap(requests.first)
        let body = try XCTUnwrap(request.body)
        let decoded = try XCTUnwrap(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(decoded["topic"] as? String, "news")
        XCTAssertEqual(decoded["days"] as? Int, 14)
        XCTAssertEqual(decoded["include_raw_content"] as? Bool, false)
        // The dated path still honours the discovery boundary.
        guard case .hits(let hits) = try await news.search("query") else {
            return XCTFail("expected hits")
        }
        XCTAssertEqual(hits.count, 4)
    }

    func testGeneralTopicNeverSendsADayWindow() async throws {
        let stub = TavilyTransportStub(body: #"{"results":[]}"#)
        let general = try TavilySearchAdapter(
            configuration: TavilySearchConfiguration(apiKey: key, days: 14),
            transport: stub
        )
        _ = try await general.search("q")
        let requests = await stub.requests
        let request = try XCTUnwrap(requests.first)
        let decoded = try XCTUnwrap(try JSONSerialization.jsonObject(with: XCTUnwrap(request.body)) as? [String: Any])
        XCTAssertEqual(decoded["topic"] as? String, "general")
        XCTAssertNil(decoded["days"])
    }
}
