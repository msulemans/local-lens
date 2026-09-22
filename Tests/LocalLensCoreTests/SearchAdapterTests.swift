import Foundation
import XCTest
@testable import LocalLensCore

// MARK: - Stub transport

/// The only HTTP implementation a test may use. Every test in this file drives
/// the adapter through this stub, so no test can open a socket.
private enum StubBehavior: Sendable {
    case respond(statusCode: Int, body: Data)
    case failTransport(String)
    case failUnexpected(String)
    case cancel
}

private struct UnexpectedStubError: Error, Sendable {
    let reason: String
}

private actor StubSearchTransport: SearchTransport {
    private let behavior: StubBehavior
    private(set) var requests: [SearchRequest] = []

    init(_ behavior: StubBehavior) {
        self.behavior = behavior
    }

    var requestCount: Int { requests.count }

    func send(_ request: SearchRequest) async throws -> SearchResponse {
        requests.append(request)
        switch behavior {
        case let .respond(statusCode, body):
            return SearchResponse(statusCode: statusCode, body: body)
        case let .failTransport(reason):
            throw TransportFailure(reason)
        case let .failUnexpected(reason):
            throw UnexpectedStubError(reason: reason)
        case .cancel:
            throw CancellationError()
        }
    }
}

// MARK: - Tests

final class SearchAdapterTests: XCTestCase {

    private static let endpoint = "http://searxng.invalid:8888"
    private let query = "does cold brew contain less acid than hot drip coffee"

    private var fixtureURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/search/searxng-quick-coffee.json")
    }

    private func fixtureData() throws -> Data {
        try Data(contentsOf: fixtureURL)
    }

    private func makeAdapter(
        _ transport: SearchTransport,
        maxResults: Int = 10,
        endpoint: String = SearchAdapterTests.endpoint
    ) throws -> SearXNGSearchAdapter {
        let configuration = try SearXNGConfiguration(
            endpoint: try XCTUnwrap(URL(string: endpoint)),
            maxResults: maxResults
        )
        return SearXNGSearchAdapter(configuration: configuration, transport: transport)
    }

    private func respondWithFixture(maxResults: Int = 10) async throws -> SearchOutcome {
        let stub = StubSearchTransport(.respond(statusCode: 200, body: try fixtureData()))
        return try await makeAdapter(stub, maxResults: maxResults).search(query)
    }

    /// Runs an operation that must fail and returns the typed search error.
    private func expectSearchError(
        _ operation: () async throws -> SearchOutcome,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async -> SearchError? {
        do {
            let outcome = try await operation()
            XCTFail("expected a typed SearchError, got \(outcome)", file: file, line: line)
            return nil
        } catch let error as SearchError {
            return error
        } catch {
            XCTFail("expected SearchError, got \(error)", file: file, line: line)
            return nil
        }
    }

    private func hits(_ outcome: SearchOutcome, file: StaticString = #filePath, line: UInt = #line) -> [SearchHit] {
        guard case let .hits(hits) = outcome else {
            XCTFail("expected hits, got \(outcome)", file: file, line: line)
            return []
        }
        return hits
    }

    // MARK: Frozen fixture decoding

    func testFixtureDecodesIntoOrderedHitsWithStableIdentities() async throws {
        let first = try await respondWithFixture()
        let second = try await respondWithFixture()

        let decoded = hits(first)
        XCTAssertEqual(decoded.count, 3)
        XCTAssertEqual(decoded.map(\.rank), [0, 1, 2])
        XCTAssertEqual(decoded.map(\.query), Array(repeating: query, count: 3))
        XCTAssertEqual(Set(decoded.map(\.id)).count, 3, "identities must be unique within a result set")
        XCTAssertEqual(decoded[0].title, "Acidity in brewed coffee (synthetic search result)")
        XCTAssertTrue(decoded[0].snippet.hasPrefix("A controlled trial reports cold brew at pH 5.6"))
        XCTAssertTrue(decoded[2].snippet.contains("Chlorogenic acid lactones"))

        // Identity is content-derived, not positional state: it is recomputable
        // and identical across independent adapter instances.
        XCTAssertEqual(
            decoded[0].id,
            StableIdentity.make("hit", query, "https://example.invalid/brew-review", "0")
        )
        XCTAssertEqual(first, second, "two decodes of one fixture must agree exactly")
    }

    func testFragmentIsStrippedFromHitURLWithoutChangingThePath() async throws {
        let decoded = hits(try await respondWithFixture())

        XCTAssertEqual(decoded[1].url.absoluteString, "https://example.invalid/sensory-panel")
        XCTAssertNil(decoded[1].url.fragment)
        XCTAssertEqual(decoded[1].url.path, "/sensory-panel")
    }

    func testIdentityTracksTheQueryButNotTheTransport() async throws {
        let other = hits(try await makeAdapter(
            StubSearchTransport(.respond(statusCode: 200, body: try fixtureData()))
        ).search("cold brew acidity"))

        let baseline = hits(try await respondWithFixture())
        XCTAssertEqual(other.count, baseline.count)
        XCTAssertNotEqual(other.map(\.id), baseline.map(\.id))
        XCTAssertEqual(other[0].url, baseline[0].url, "the same source keeps the same URL")
        XCTAssertEqual(other.map(\.query), Array(repeating: "cold brew acidity", count: 3))
    }

    func testNullDisplayMetadataIsAcceptedAsEmpty() async throws {
        let payload = """
        {"results":[{"url":"https://example.invalid/a","title":null,"content":null}]}
        """
        let outcome = try await makeAdapter(
            StubSearchTransport(.respond(statusCode: 200, body: Data(payload.utf8)))
        ).search(query)

        let decoded = hits(outcome)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].title, "")
        XCTAssertEqual(decoded[0].snippet, "")
    }

    func testMaxResultsBoundsParsingSoJunkBeyondTheBoundIsNotTrusted() async throws {
        let payload = """
        {"results":[
          {"url":"https://example.invalid/a","title":"a","content":"a"},
          {"url":"https://example.invalid/b","title":"b","content":"b"},
          {"url":"https://example.invalid/c","title":"c","content":"c"},
          {"url":123,"title":null}
        ]}
        """
        let stub = StubSearchTransport(.respond(statusCode: 200, body: Data(payload.utf8)))
        let decoded = hits(try await makeAdapter(stub, maxResults: 3).search(query))

        XCTAssertEqual(decoded.map(\.rank), [0, 1, 2])
        XCTAssertEqual(decoded.map(\.url.lastPathComponent), ["a", "b", "c"])
    }

    // MARK: Request shape

    func testRequestIsATrimmedJSONGETThroughTheInjectedTransport() async throws {
        let stub = StubSearchTransport(.respond(statusCode: 200, body: try fixtureData()))
        _ = try await makeAdapter(stub).search("  \(query)\n")

        let requests = await stub.requests
        XCTAssertEqual(requests.count, 1)
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.headers["Accept"], "application/json")
        XCTAssertEqual(request.timeoutSeconds, 10)
        XCTAssertEqual(request.url.path, "/search")
        XCTAssertEqual(request.url.host, "searxng.invalid")

        let items = URLComponents(url: request.url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(items.first { $0.name == "q" }?.value, query, "the query must be trimmed before sending")
        XCTAssertEqual(items.first { $0.name == "format" }?.value, "json")
        XCTAssertNil(items.first { $0.name == "language" }, "language is omitted when unset")
    }

    func testConfiguredLanguageIsSent() async throws {
        let stub = StubSearchTransport(.respond(statusCode: 200, body: try fixtureData()))
        let configuration = try SearXNGConfiguration(
            endpoint: try XCTUnwrap(URL(string: Self.endpoint)),
            language: "en-AU"
        )
        _ = try await SearXNGSearchAdapter(configuration: configuration, transport: stub).search(query)

        let requests = await stub.requests
        let url = try XCTUnwrap(requests.first?.url)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(items.first { $0.name == "language" }?.value, "en-AU")
    }

    func testSearchPathIsCompletedOnlyForABareBaseEndpoint() throws {
        func searchURL(_ endpoint: String) throws -> String {
            let url = try XCTUnwrap(URL(string: endpoint), "\(endpoint) must parse")
            return try SearXNGConfiguration(endpoint: url).searchURL.absoluteString
        }

        XCTAssertEqual(try searchURL("http://searxng.invalid:8888"), "http://searxng.invalid:8888/search")
        XCTAssertEqual(try searchURL("http://searxng.invalid:8888/"), "http://searxng.invalid:8888/search")
        XCTAssertEqual(try searchURL("http://searxng.invalid:8888/search"), "http://searxng.invalid:8888/search")
        XCTAssertEqual(try searchURL("https://search.invalid/searxng/"), "https://search.invalid/searxng/")
    }

    // MARK: Typed failures

    func testTransportFailureIsTypedAndKeepsTheReason() async throws {
        let stub = StubSearchTransport(.failTransport("dns lookup failed for searxng.invalid"))
        let observed = await expectSearchError { try await self.makeAdapter(stub).search(self.query) }

        XCTAssertEqual(observed, .transportFailure(reason: "dns lookup failed for searxng.invalid"))
    }

    func testUnexpectedTransportErrorIsMappedIntoTheTypedFamily() async throws {
        let stub = StubSearchTransport(.failUnexpected("socket closed mid-body"))
        let observed = await expectSearchError { try await self.makeAdapter(stub).search(self.query) }

        guard case let .transportFailure(reason)? = observed else {
            return XCTFail("expected transportFailure, got \(String(describing: observed))")
        }
        XCTAssertTrue(reason.contains("socket closed mid-body"), "reason was \(reason)")
    }

    func testCancellationIsNeverFoldedIntoTransportFailure() async throws {
        let stub = StubSearchTransport(.cancel)
        do {
            let outcome = try await makeAdapter(stub).search(query)
            XCTFail("expected CancellationError, got \(outcome)")
        } catch is CancellationError {
            // Cancellation stays the run-level state machine's decision.
        } catch {
            XCTFail("expected CancellationError, got \(error)")
        }
    }

    func testEveryNon200StatusIsTypedAndNamesTheRequestedURL() async throws {
        for statusCode in [301, 404, 429, 500, 503] {
            let stub = StubSearchTransport(
                .respond(statusCode: statusCode, body: Data("not a JSON search payload".utf8))
            )
            let observed = await expectSearchError { try await self.makeAdapter(stub).search(self.query) }

            guard case let .httpStatus(code, url)? = observed else {
                XCTFail("HTTP \(statusCode) should be a typed httpStatus error, got \(String(describing: observed))")
                continue
            }
            XCTAssertEqual(code, statusCode)
            XCTAssertEqual(url.host, "searxng.invalid")
            XCTAssertEqual(url.path, "/search")
        }
    }

    func testMalformedPayloadVariantsAllFailClosed() async throws {
        let variants: [(String, String)] = [
            ("not-json", "{ this is not json"),
            ("empty-body", ""),
            ("root-array", "[{\"url\":\"https://example.invalid/a\"}]"),
            ("root-string", "\"ok\""),
            ("missing-results", "{\"query\":\"x\"}"),
            ("results-null", "{\"results\":null}"),
            ("results-not-array", "{\"results\":{\"url\":\"https://example.invalid/a\"}}"),
            ("entry-not-object", "{\"results\":[\"https://example.invalid/a\"]}"),
            ("missing-url", "{\"results\":[{\"title\":\"no url\"}]}"),
            ("null-url", "{\"results\":[{\"url\":null}]}"),
            ("empty-url", "{\"results\":[{\"url\":\"\"}]}"),
            ("relative-url", "{\"results\":[{\"url\":\"/relative\"}]}"),
            ("non-http-scheme", "{\"results\":[{\"url\":\"ftp://example.invalid/file\"}]}"),
            ("hostless-url", "{\"results\":[{\"url\":\"https://\"}]}"),
            ("title-not-string", "{\"results\":[{\"url\":\"https://example.invalid/a\",\"title\":42}]}"),
            ("content-not-string", "{\"results\":[{\"url\":\"https://example.invalid/a\",\"content\":[\"x\"]}]}"),
        ]

        for (name, payload) in variants {
            let stub = StubSearchTransport(.respond(statusCode: 200, body: Data(payload.utf8)))
            let observed = await expectSearchError { try await self.makeAdapter(stub).search(self.query) }

            guard case .malformedPayload? = observed else {
                XCTFail("\(name) should be malformedPayload, got \(String(describing: observed))")
                continue
            }
        }
    }

    func testEmptyResultsIsATypedEmptyOutcomeNotSilentSuccess() async throws {
        let payload = "{\"query\":\"x\",\"number_of_results\":0,\"results\":[]}"
        let stub = StubSearchTransport(.respond(statusCode: 200, body: Data(payload.utf8)))
        let outcome = try await makeAdapter(stub).search(query)

        XCTAssertEqual(outcome, .noResults(query: query))
        let requestCount = await stub.requestCount
        XCTAssertEqual(requestCount, 1, "an empty result set is still one search, not a retry loop")
    }

    func testEmptyQueryIsRejectedBeforeAnyRequestIsSent() async throws {
        let stub = StubSearchTransport(.respond(statusCode: 200, body: try fixtureData()))
        let observed = await expectSearchError { try await self.makeAdapter(stub).search("   \n") }

        XCTAssertEqual(observed, .emptyQuery)
        let requestCount = await stub.requestCount
        XCTAssertEqual(requestCount, 0, "an empty query must not reach the transport")
    }

    func testInvalidConfigurationIsRejectedAtConstruction() throws {
        for endpoint in ["ftp://searxng.invalid", "searxng.invalid:8888", "http:///search"] {
            let url = try XCTUnwrap(URL(string: endpoint), "\(endpoint) must parse before it can be rejected")
            XCTAssertThrowsError(try SearXNGConfiguration(endpoint: url), "\(endpoint) should be rejected") { error in
                guard case .invalidEndpoint? = error as? SearchError else {
                    return XCTFail("expected invalidEndpoint for \(endpoint), got \(error)")
                }
            }
        }

        let valid = try XCTUnwrap(URL(string: Self.endpoint))
        for configuration in [
            try? SearXNGConfiguration(endpoint: valid, maxResults: 0),
            try? SearXNGConfiguration(endpoint: valid, timeoutSeconds: 0),
        ] {
            XCTAssertNil(configuration)
        }
    }

    // MARK: Offline guarantees

    func testFixtureIsSyntheticAndCannotResolve() throws {
        let root = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: try fixtureData()) as? [String: Any]
        )
        let fixture = try XCTUnwrap(root["_fixture"] as? [String: Any])
        XCTAssertEqual(fixture["synthetic"] as? Bool, true)
        XCTAssertEqual(fixture["license"] as? String, "redistributable")

        let results = try XCTUnwrap(root["results"] as? [[String: Any]])
        XCTAssertEqual(results.count, 3)
        for result in results {
            let url = try XCTUnwrap(URL(string: try XCTUnwrap(result["url"] as? String)))
            XCTAssertEqual(url.host?.hasSuffix(".invalid"), true, "fixture hosts must stay non-resolvable")
        }
    }

    func testNoTestOrAppSourceCanReachTheNetwork() throws {
        // The production transport is named in one place only: its own
        // definition inside LocalLensCore. This guard keeps it that way, so the
        // "no test performs network access" rule cannot silently regress.
        let needle = "URL" + "Session"
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        var scanned: [String] = []
        for relative in ["Tests", "Sources/LocalLensApp"] {
            let directory = root.appendingPathComponent(relative)
            let files = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil)?
                .compactMap { $0 as? URL }
                .filter { $0.pathExtension == "swift" } ?? []

            for file in files {
                let text = try String(contentsOf: file, encoding: .utf8)
                scanned.append(file.lastPathComponent)
                XCTAssertFalse(text.contains(needle), "\(file.path) must not reference the production transport")
            }
        }

        XCTAssertTrue(scanned.contains("SearchAdapterTests.swift"), "the guard must scan its own test target")
        XCTAssertGreaterThan(scanned.count, 1, "the guard must scan the app target as well as the tests")
    }
}
