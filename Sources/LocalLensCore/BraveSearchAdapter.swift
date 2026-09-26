import Foundation

/// Opt-in, no-Docker web discovery. Brave's result title and description are
/// search metadata only; the live runner still fetches and stores each page
/// before any passage can support a citation.
public struct BraveSearchConfiguration: Sendable {
    public static let endpoint = URL(string: "https://api.search.brave.com/res/v1/web/search")!

    fileprivate let apiKey: String
    public let maxResults: Int
    public let language: String
    public let timeoutSeconds: Double

    public init(apiKey: String, maxResults: Int = 10, language: String = "en", timeoutSeconds: Double = 10) throws {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SearchError.invalidEndpoint(reason: "Brave Search API key is empty")
        }
        guard (1...20).contains(maxResults) else {
            throw SearchError.invalidEndpoint(reason: "Brave result count must be between 1 and 20")
        }
        guard timeoutSeconds > 0 else {
            throw SearchError.invalidEndpoint(reason: "Brave search timeout must be positive")
        }
        self.apiKey = apiKey
        self.maxResults = maxResults
        self.language = language
        self.timeoutSeconds = timeoutSeconds
    }
}

public struct BraveSearchAdapter: SearchAdapter {
    public let configuration: BraveSearchConfiguration
    public let transport: any SearchTransport

    public init(configuration: BraveSearchConfiguration, transport: any SearchTransport) {
        self.configuration = configuration
        self.transport = transport
    }

    public func search(_ query: String) async throws -> SearchOutcome {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SearchError.emptyQuery }
        guard var components = URLComponents(url: BraveSearchConfiguration.endpoint, resolvingAgainstBaseURL: false) else {
            throw SearchError.invalidEndpoint(reason: "Brave endpoint cannot be decomposed")
        }
        components.queryItems = [
            URLQueryItem(name: "q", value: trimmed),
            URLQueryItem(name: "count", value: String(configuration.maxResults)),
            URLQueryItem(name: "search_lang", value: configuration.language),
        ]
        guard let url = components.url else {
            throw SearchError.invalidEndpoint(reason: "Brave endpoint cannot carry search parameters")
        }
        let request = SearchRequest(
            url: url,
            headers: [
                "Accept": "application/json",
                "X-Subscription-Token": configuration.apiKey,
            ],
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
            // The URL is safe to report: the token is only ever a header.
            throw SearchError.httpStatus(code: response.statusCode, url: request.url)
        }
        return try BraveSearchPayload.decode(response.body, query: trimmed, maxResults: configuration.maxResults)
    }
}

/// Strictly interprets only the fields used for discovery. Unknown Brave
/// fields are ignored, and a bad consumed field fails rather than becoming a
/// plausible-looking source. No raw API result is persisted.
public enum BraveSearchPayload {
    public static func decode(_ data: Data, query: String, maxResults: Int) throws -> SearchOutcome {
        let raw: Any
        do {
            raw = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw SearchError.malformedPayload(reason: "Brave response is not valid JSON")
        }
        guard let root = raw as? [String: Any], let web = root["web"] else {
            throw SearchError.malformedPayload(reason: "Brave response has no web field")
        }
        if web is NSNull { return .noResults(query: query) }
        guard let object = web as? [String: Any], let rawResults = object["results"] as? [Any] else {
            throw SearchError.malformedPayload(reason: "Brave web.results is not an array")
        }
        guard !rawResults.isEmpty else { return .noResults(query: query) }

        var hits: [SearchHit] = []
        for (rank, rawResult) in rawResults.prefix(maxResults).enumerated() {
            guard let item = rawResult as? [String: Any],
                  let title = item["title"] as? String,
                  let rawURL = item["url"] as? String,
                  var components = URLComponents(string: rawURL),
                  let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme),
                  let host = components.host, !host.isEmpty,
                  components.user == nil, components.password == nil else {
                throw SearchError.malformedPayload(reason: "Brave result \(rank) has no usable title or public HTTP(S) URL")
            }
            components.scheme = scheme
            components.fragment = nil
            guard let url = components.url else {
                throw SearchError.malformedPayload(reason: "Brave result \(rank) URL cannot be normalized")
            }
            let snippet: String
            if let description = item["description"], !(description is NSNull) {
                guard let text = description as? String else {
                    throw SearchError.malformedPayload(reason: "Brave result \(rank) description is not text")
                }
                snippet = text
            } else {
                snippet = ""
            }
            hits.append(SearchHit(
                id: StableIdentity.make("hit", query, url.absoluteString, String(rank)),
                query: query,
                rank: rank,
                url: url,
                title: title,
                snippet: snippet
            ))
        }
        return .hits(hits)
    }
}
