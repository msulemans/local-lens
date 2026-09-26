import Foundation

/// No-Docker discovery with a user-owned Tavily free-tier key. Search content
/// remains metadata: citations must come from independently fetched passages.
public struct TavilySearchConfiguration: Sendable {
    public static let endpoint = URL(string: "https://api.tavily.com/search")!

    fileprivate let apiKey: String
    public let maxResults: Int
    public let timeoutSeconds: Double
    /// `"news"` asks the provider for its news index and makes it report a
    /// publication date per result. `nil` keeps the general index.
    public let topic: String?
    /// The provider-side lookback, only sent with the news topic. The mode's own
    /// window is still enforced locally by `NewsRecency`; this narrows the
    /// request so stale pages are not fetched at all.
    public let days: Int?

    public init(
        apiKey: String,
        maxResults: Int = 10,
        timeoutSeconds: Double = 10,
        topic: String? = nil,
        days: Int? = nil
    ) throws {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SearchError.invalidEndpoint(reason: "Tavily API key is empty")
        }
        guard (1...20).contains(maxResults) else {
            throw SearchError.invalidEndpoint(reason: "Tavily result count must be between 1 and 20")
        }
        guard timeoutSeconds > 0 else {
            throw SearchError.invalidEndpoint(reason: "Tavily search timeout must be positive")
        }
        if let topic, !["general", "news", "finance"].contains(topic) {
            throw SearchError.invalidEndpoint(reason: "Tavily topic must be general, news, or finance")
        }
        if let days, !(1...365).contains(days) {
            throw SearchError.invalidEndpoint(reason: "Tavily days must be between 1 and 365")
        }
        self.apiKey = apiKey
        self.maxResults = maxResults
        self.timeoutSeconds = timeoutSeconds
        self.topic = topic
        self.days = days
    }
}

public struct TavilySearchAdapter: SearchAdapter, DatedSearchAdapter {
    public let configuration: TavilySearchConfiguration
    public let transport: any SearchTransport

    public init(configuration: TavilySearchConfiguration, transport: any SearchTransport) {
        self.configuration = configuration
        self.transport = transport
    }

    public func search(_ query: String) async throws -> SearchOutcome {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let dated = try await searchDated(trimmed)
        return dated.isEmpty ? .noResults(query: trimmed) : .hits(dated.map(\.hit))
    }

    public func searchDated(_ query: String) async throws -> [DatedHit] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SearchError.emptyQuery }
        var payload: [String: Any] = [
            "query": trimmed,
            "search_depth": "basic",
            "max_results": configuration.maxResults,
            "topic": configuration.topic ?? "general",
            "include_answer": false,
            "include_raw_content": false,
            "include_images": false,
            "auto_parameters": false,
        ]
        if let days = configuration.days, configuration.topic == "news" {
            payload["days"] = days
        }
        let body = try JSONSerialization.data(withJSONObject: payload)
        let request = SearchRequest(
            url: TavilySearchConfiguration.endpoint,
            method: "POST",
            headers: [
                "Authorization": "Bearer \(configuration.apiKey)",
                "Content-Type": "application/json",
                "Accept": "application/json",
            ],
            timeoutSeconds: configuration.timeoutSeconds,
            body: body
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
            // Never include the response body, which may echo provider metadata.
            throw SearchError.httpStatus(code: response.statusCode, url: request.url)
        }
        return try TavilySearchPayload.decodeDated(response.body, query: trimmed, maxResults: configuration.maxResults)
    }
}

public enum TavilySearchPayload {
    /// Parses the provider's `published_date`. It returns `nil` rather than
    /// guessing when the field is missing or unparseable: an unread date must
    /// not be invented.
    ///
    /// Live measurement on 2026-09-26: the news topic reports an RFC 1123
    /// instant (`Mon, 21 Sep 2026 08:34:00 GMT`), not ISO-8601, so the first
    /// implementation counted every result as undated and the windowed run
    /// starved with `no openable search hits`. Both shapes are accepted now.
    public static func publicationDate(_ raw: Any?) -> Date? {
        guard let text = raw as? String else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: trimmed) { return date }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: trimmed) { return date }
        if let date = rfc1123.date(from: trimmed) { return date }
        let day = DateFormatter()
        day.locale = Locale(identifier: "en_US_POSIX")
        day.timeZone = TimeZone(identifier: "UTC")
        day.dateFormat = "yyyy-MM-dd"
        return day.date(from: trimmed)
    }

    private static let rfc1123: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter
    }()

    public static func decodeDated(_ data: Data, query: String, maxResults: Int) throws -> [DatedHit] {
        let raw: Any
        do {
            raw = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw SearchError.malformedPayload(reason: "Tavily response is not valid JSON")
        }
        guard let root = raw as? [String: Any], let rawResults = root["results"] as? [Any] else {
            throw SearchError.malformedPayload(reason: "Tavily results is not an array")
        }
        guard !rawResults.isEmpty else { return [] }

        var hits: [DatedHit] = []
        for (rank, rawResult) in rawResults.prefix(maxResults).enumerated() {
            guard let item = rawResult as? [String: Any],
                  let title = item["title"] as? String,
                  let rawURL = item["url"] as? String,
                  var components = URLComponents(string: rawURL),
                  let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme),
                  let host = components.host, !host.isEmpty,
                  components.user == nil, components.password == nil else {
                throw SearchError.malformedPayload(reason: "Tavily result \(rank) has no usable title or HTTP(S) URL")
            }
            components.scheme = scheme
            components.fragment = nil
            guard let url = components.url else {
                throw SearchError.malformedPayload(reason: "Tavily result \(rank) URL cannot be normalized")
            }
            let snippet: String
            if let content = item["content"], !(content is NSNull) {
                guard let text = content as? String else {
                    throw SearchError.malformedPayload(reason: "Tavily result \(rank) content is not text")
                }
                snippet = text
            } else {
                snippet = ""
            }
            hits.append(DatedHit(
                hit: SearchHit(
                    id: StableIdentity.make("hit", query, url.absoluteString, String(rank)),
                    query: query,
                    rank: rank,
                    url: url,
                    title: title,
                    snippet: snippet
                ),
                publishedAt: publicationDate(item["published_date"])
            ))
        }
        return hits
    }

    public static func decode(_ data: Data, query: String, maxResults: Int) throws -> SearchOutcome {
        let raw: Any
        do {
            raw = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw SearchError.malformedPayload(reason: "Tavily response is not valid JSON")
        }
        guard let root = raw as? [String: Any], let rawResults = root["results"] as? [Any] else {
            throw SearchError.malformedPayload(reason: "Tavily results is not an array")
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
                throw SearchError.malformedPayload(reason: "Tavily result \(rank) has no usable title or HTTP(S) URL")
            }
            components.scheme = scheme
            components.fragment = nil
            guard let url = components.url else {
                throw SearchError.malformedPayload(reason: "Tavily result \(rank) URL cannot be normalized")
            }
            let snippet: String
            if let content = item["content"], !(content is NSNull) {
                guard let text = content as? String else {
                    throw SearchError.malformedPayload(reason: "Tavily result \(rank) content is not text")
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
