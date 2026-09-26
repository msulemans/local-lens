import Foundation

// MARK: - Injectable HTTP boundary

/// One outbound HTTP request issued by a search adapter.
///
/// An adapter never owns a socket: every request travels through an injected
/// `SearchTransport`, which is the only place a test may substitute behaviour.
public struct SearchRequest: Equatable, Sendable {
    public let url: URL
    public let method: String
    public let headers: [String: String]
    public let timeoutSeconds: Double
    /// An optional request body. Search leaves it `nil`; a provider POST sets
    /// it. The transport stays payload-agnostic.
    public let body: Data?

    public init(
        url: URL,
        method: String = "GET",
        headers: [String: String] = [:],
        timeoutSeconds: Double = 10,
        body: Data? = nil
    ) {
        self.url = url
        self.method = method
        self.headers = headers
        self.timeoutSeconds = timeoutSeconds
        self.body = body
    }
}

/// A raw HTTP response. The transport never interprets provider payloads; the
/// adapter owns status-code and body validation.
public struct SearchResponse: Equatable, Sendable {
    public let statusCode: Int
    public let body: Data
    public let headers: [String: String]

    public init(statusCode: Int, body: Data, headers: [String: String] = [:]) {
        self.statusCode = statusCode
        self.body = body
        self.headers = headers
    }
}

/// The injectable HTTP boundary. Search uses it first; the safe-acquisition
/// boundary later in M002 is expected to share it rather than open its own
/// sockets. Tests always inject a stub; only `URLSessionSearchTransport`
/// touches the network and no test uses it.
public protocol SearchTransport: Sendable {
    func send(_ request: SearchRequest) async throws -> SearchResponse
}

/// A failure raised before an HTTP response exists: DNS, TLS, connection,
/// timeout, or a non-HTTP response. Adapters map it to
/// `SearchError.transportFailure` so callers see one typed family.
public struct TransportFailure: Error, Equatable, LocalizedError, Sendable {
    public let reason: String

    public init(_ reason: String) {
        self.reason = reason
    }

    public var errorDescription: String? {
        "Search transport failed: \(reason)"
    }
}

/// The only production transport. It is deliberately thin: no retries, no
/// payload knowledge, and one redirect rule - it refuses to follow any HTTP
/// redirect, so a 3xx is returned to the caller. The acquisition boundary
/// validates each hop itself; a transport that followed redirects internally
/// would bypass that check.
public struct URLSessionSearchTransport: SearchTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ request: SearchRequest) async throws -> SearchResponse {
        var urlRequest = URLRequest(url: request.url, timeoutInterval: request.timeoutSeconds)
        urlRequest.httpMethod = request.method
        for (field, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: field)
        }
        urlRequest.httpBody = request.body

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(
                for: urlRequest,
                delegate: RedirectRefusingDelegate()
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw TransportFailure(String(describing: error))
        }

        guard let http = response as? HTTPURLResponse else {
            throw TransportFailure("response is not HTTP")
        }

        var headers: [String: String] = [:]
        for (key, value) in http.allHeaderFields {
            if let name = key as? String, let text = value as? String {
                headers[name] = text
            }
        }
        return SearchResponse(statusCode: http.statusCode, body: data, headers: headers)
    }
}

// MARK: - Redirect refusal

/// Returns `nil` for every redirect so `URLSession` reports the 3xx response
/// instead of following it. Stateless, so it is safe to share.
private final class RedirectRefusingDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

// MARK: - Typed search outcomes

/// Every way a search can fail, plus the empty-but-successful outcome.
///
/// `noResults` is deliberately not an error: an honest empty answer is a
/// product outcome, not a fault. Cancellation is not folded in here; it stays
/// a `CancellationError` so the run-level typed `cancelled` state remains the
/// state machine's decision.
public enum SearchError: Error, Equatable, LocalizedError, Sendable {
    case invalidEndpoint(reason: String)
    case emptyQuery
    case transportFailure(reason: String)
    case httpStatus(code: Int, url: URL)
    case malformedPayload(reason: String)

    public var errorDescription: String? {
        switch self {
        case let .invalidEndpoint(reason):
            "Invalid search endpoint: \(reason)."
        case .emptyQuery:
            "Search query is empty."
        case let .transportFailure(reason):
            "Search transport failed: \(reason)."
        case let .httpStatus(code, url):
            "Search provider returned HTTP \(code) for \(url.absoluteString)."
        case let .malformedPayload(reason):
            "Malformed search payload: \(reason)."
        }
    }
}

/// A successful search either produced ordered hits or honestly produced none.
public enum SearchOutcome: Equatable, Sendable {
    case hits([SearchHit])
    case noResults(query: String)
}

/// The replaceable search boundary. SearXNG is the first adapter, not the
/// contract.
public protocol SearchAdapter: Sendable {
    func search(_ query: String) async throws -> SearchOutcome
}

// MARK: - SearXNG configuration

public struct SearXNGConfiguration: Equatable, Sendable {
    /// SearXNG serves its JSON API from `/search`.
    public static let defaultSearchPath = "search"

    public let endpoint: URL
    public let maxResults: Int
    public let language: String?
    public let timeoutSeconds: Double

    /// Validates configuration once, so `search` never has to re-litigate it.
    /// A base URL (`http://host:port`) and a full endpoint
    /// (`http://host:port/search`) are both accepted.
    public init(
        endpoint: URL,
        maxResults: Int = 10,
        language: String? = nil,
        timeoutSeconds: Double = 10
    ) throws {
        guard let scheme = endpoint.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            throw SearchError.invalidEndpoint(reason: "endpoint must be an absolute http(s) URL")
        }
        guard let host = endpoint.host, !host.isEmpty else {
            throw SearchError.invalidEndpoint(reason: "endpoint has no host")
        }
        guard maxResults >= 1 else {
            throw SearchError.invalidEndpoint(reason: "maxResults must be at least 1")
        }
        guard timeoutSeconds > 0 else {
            throw SearchError.invalidEndpoint(reason: "timeoutSeconds must be positive")
        }

        self.endpoint = endpoint
        self.maxResults = maxResults
        self.language = language
        self.timeoutSeconds = timeoutSeconds
    }

    /// The endpoint completed with the JSON API path when only a base was given.
    public var searchURL: URL {
        let path = endpoint.path
        guard path.isEmpty || path == "/" else { return endpoint }
        return endpoint.appendingPathComponent(Self.defaultSearchPath)
    }
}

// MARK: - SearXNG adapter

/// SearXNG JSON adapter over an injected transport.
///
/// Contract: `GET {endpoint}/search?q=...&format=json`, HTTP 200 required, then
/// the payload is decoded into ordered `SearchHit` values whose identity is
/// content-derived from the query, the fragment-free URL, and the provider
/// rank.
public struct SearXNGSearchAdapter: SearchAdapter {
    public let configuration: SearXNGConfiguration
    public let transport: SearchTransport

    public init(configuration: SearXNGConfiguration, transport: SearchTransport) {
        self.configuration = configuration
        self.transport = transport
    }

    public func search(_ query: String) async throws -> SearchOutcome {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SearchError.emptyQuery
        }

        let request = SearchRequest(
            url: try requestURL(for: trimmed),
            headers: ["Accept": "application/json"],
            timeoutSeconds: configuration.timeoutSeconds
        )

        let response: SearchResponse
        do {
            response = try await transport.send(request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let failure as TransportFailure {
            throw SearchError.transportFailure(reason: failure.reason)
        } catch {
            throw SearchError.transportFailure(reason: String(describing: error))
        }

        guard response.statusCode == 200 else {
            throw SearchError.httpStatus(code: response.statusCode, url: request.url)
        }

        return try SearXNGPayload.decode(
            response.body,
            query: trimmed,
            maxResults: configuration.maxResults
        )
    }

    private func requestURL(for query: String) throws -> URL {
        guard var components = URLComponents(url: configuration.searchURL, resolvingAgainstBaseURL: false) else {
            throw SearchError.invalidEndpoint(reason: "endpoint cannot be decomposed into components")
        }
        var items = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "format", value: "json"),
        ]
        if let language = configuration.language, !language.isEmpty {
            items.append(URLQueryItem(name: "language", value: language))
        }
        components.queryItems = items
        guard let url = components.url else {
            throw SearchError.invalidEndpoint(reason: "endpoint cannot carry query items")
        }
        return url
    }
}

// MARK: - SearXNG JSON decoding

/// Decodes the SearXNG JSON payload.
///
/// The provider payload is not our frozen wire schema, so unknown provider
/// fields (`engine`, `score`, `positions`, `category`, `thumbnail`, ...) are
/// ignored rather than rejected: they are third-party metadata we do not
/// consume. Everything this adapter does consume is validated strictly, and
/// any payload it cannot interpret fails closed as `malformedPayload` instead
/// of being partially trusted.
///
/// Only the first `maxResults` entries are parsed, so a provider that appends
/// junk beyond the requested bound cannot fail an otherwise usable search.
public enum SearXNGPayload {

    public static func decode(_ data: Data, query: String, maxResults: Int) throws -> SearchOutcome {
        let root: Any
        do {
            root = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw SearchError.malformedPayload(reason: "response body is not valid JSON")
        }

        guard let object = root as? [String: Any] else {
            throw SearchError.malformedPayload(reason: "response root is not a JSON object")
        }
        guard let rawResults = object["results"] else {
            throw SearchError.malformedPayload(reason: "response has no results field")
        }
        guard let results = rawResults as? [Any] else {
            throw SearchError.malformedPayload(reason: "results is not an array")
        }
        guard !results.isEmpty else {
            return .noResults(query: query)
        }

        var hits: [SearchHit] = []
        for (rank, element) in results.prefix(maxResults).enumerated() {
            guard let entry = element as? [String: Any] else {
                throw SearchError.malformedPayload(reason: "result \(rank) is not a JSON object")
            }
            guard let rawURL = entry["url"] else {
                throw SearchError.malformedPayload(reason: "result \(rank) has no url")
            }
            guard let urlString = rawURL as? String, !urlString.isEmpty else {
                throw SearchError.malformedPayload(reason: "result \(rank) url is not a non-empty string")
            }
            guard let url = normalizedURL(urlString) else {
                throw SearchError.malformedPayload(reason: "result \(rank) url is not an absolute http(s) URL")
            }

            hits.append(
                SearchHit(
                    id: StableIdentity.make("hit", query, url.absoluteString, String(rank)),
                    query: query,
                    rank: rank,
                    url: url,
                    title: try text(entry["title"], field: "title", rank: rank),
                    snippet: try text(entry["content"], field: "content", rank: rank)
                )
            )
        }

        return hits.isEmpty ? .noResults(query: query) : .hits(hits)
    }

    /// Title and snippet are display metadata: absent or explicit `null` means
    /// empty, because SearXNG emits `null` for fields it did not fill. A
    /// present value of the wrong type is still a malformed payload.
    private static func text(_ value: Any?, field: String, rank: Int) throws -> String {
        guard let value, !(value is NSNull) else { return "" }
        guard let text = value as? String else {
            throw SearchError.malformedPayload(reason: "result \(rank) \(field) is not a string")
        }
        return text
    }

    /// Only absolute http(s) URLs are accepted, and the fragment is removed so
    /// identity does not churn when a provider adds an anchor.
    private static func normalizedURL(_ raw: String) -> URL? {
        guard var components = URLComponents(string: raw) else { return nil }
        guard let scheme = components.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return nil
        }
        guard let host = components.host, !host.isEmpty else { return nil }
        components.scheme = scheme
        components.fragment = nil
        return components.url
    }
}
