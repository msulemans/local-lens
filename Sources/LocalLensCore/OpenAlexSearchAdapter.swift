import Foundation

/// Opt-in scholarly discovery through OpenAlex.
///
/// Academic mode resolves scholarly metadata before general web search. This
/// adapter returns work records as discovery hits only: the title and the
/// landing-page URL. No abstract, no inverted index, and no vendor snippet is
/// turned into evidence. The live runner still fetches the landing page, stores
/// the snapshot, and extracts a passage before any citation can exist.
///
/// OpenAlex is used without a key. A `mailto` is sent for the polite pool when
/// one is configured; it is not an identity or a secret.
public struct OpenAlexConfiguration: Sendable {
    public static let endpoint = URL(string: "https://api.openalex.org/works")!

    public let maxResults: Int
    public let mailto: String?
    public let timeoutSeconds: Double

    public init(maxResults: Int = 10, mailto: String? = nil, timeoutSeconds: Double = 15) throws {
        guard (1...50).contains(maxResults) else {
            throw SearchError.invalidEndpoint(reason: "OpenAlex result count must be between 1 and 50")
        }
        guard timeoutSeconds > 0 else {
            throw SearchError.invalidEndpoint(reason: "OpenAlex timeout must be positive")
        }
        if let mailto, !mailto.contains("@") {
            throw SearchError.invalidEndpoint(reason: "OpenAlex mailto must be an email address")
        }
        self.maxResults = maxResults
        self.mailto = mailto
        self.timeoutSeconds = timeoutSeconds
    }
}

public struct OpenAlexSearchAdapter: SearchAdapter {
    public let configuration: OpenAlexConfiguration
    public let transport: any SearchTransport

    public init(configuration: OpenAlexConfiguration, transport: any SearchTransport) {
        self.configuration = configuration
        self.transport = transport
    }

    public func search(_ query: String) async throws -> SearchOutcome {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SearchError.emptyQuery }
        guard var components = URLComponents(url: OpenAlexConfiguration.endpoint, resolvingAgainstBaseURL: false) else {
            throw SearchError.invalidEndpoint(reason: "OpenAlex endpoint cannot be decomposed")
        }
        var items = [
            URLQueryItem(name: "search", value: trimmed),
            URLQueryItem(name: "per-page", value: String(configuration.maxResults)),
        ]
        if let mailto = configuration.mailto {
            items.append(URLQueryItem(name: "mailto", value: mailto))
        }
        components.queryItems = items
        guard let url = components.url else {
            throw SearchError.invalidEndpoint(reason: "OpenAlex endpoint cannot carry search parameters")
        }
        let request = SearchRequest(
            url: url,
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
        return try OpenAlexPayload.decode(response.body, query: trimmed, maxResults: configuration.maxResults)
    }
}

/// Strictly interprets only the discovery fields that are consumed. A work
/// without a usable public landing page (or DOI) is skipped rather than
/// repaired, because a scholarly hit with no readable target is not evidence.
public enum OpenAlexPayload {
    public static func decode(_ data: Data, query: String, maxResults: Int) throws -> SearchOutcome {
        let raw: Any
        do {
            raw = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw SearchError.malformedPayload(reason: "OpenAlex response is not valid JSON")
        }
        guard let root = raw as? [String: Any] else {
            throw SearchError.malformedPayload(reason: "OpenAlex response is not an object")
        }
        guard let rawResults = root["results"] as? [Any] else {
            throw SearchError.malformedPayload(reason: "OpenAlex results is not an array")
        }
        guard !rawResults.isEmpty else { return .noResults(query: query) }

        var candidates: [(hit: SearchHit, isOpenAccess: Bool)] = []
        for rawWork in rawResults.prefix(maxResults) {
            guard let work = rawWork as? [String: Any] else { continue }
            guard let url = landingURL(for: work) else { continue }
            let title = (work["display_name"] as? String)
                ?? (work["title"] as? String)
                ?? url.host
                ?? "scholarly work"
            let oa = hasOpenAccessLocation(work)
            candidates.append((
                SearchHit(
                    id: StableIdentity.make("openalex-hit", query, url.absoluteString),
                    query: query,
                    rank: candidates.count,
                    url: url,
                    title: title,
                    snippet: ""
                ),
                oa
            ))
        }
        // Open-access works are stably ordered first: a paywalled or
        // JavaScript-only publisher page cannot supply a readable passage, and
        // the opened-source budget is bounded. OpenAlex relevance order is
        // preserved inside each group.
        let hits = candidates.enumerated()
            .sorted { left, right in
                let leftOA = left.element.isOpenAccess ? 0 : 1
                let rightOA = right.element.isOpenAccess ? 0 : 1
                if leftOA != rightOA { return leftOA < rightOA }
                return left.offset < right.offset
            }
            .map(\.element.hit)
        return hits.isEmpty ? .noResults(query: query) : .hits(hits)
    }

    /// Whether the work carries an open-access location. A PDF-only OA location
    /// still counts: it is discovery signal, and the fetch boundary refuses an
    /// unreadable target with a typed outcome rather than fabricating text.
    static func hasOpenAccessLocation(_ work: [String: Any]) -> Bool {
        guard let best = work["best_oa_location"] as? [String: Any] else { return false }
        if let landing = best["landing_page_url"] as? String, publicHTTPURL(landing) != nil { return true }
        if let pdf = best["pdf_url"] as? String, publicHTTPURL(pdf) != nil { return true }
        return false
    }

    /// Prefers an open-access HTML landing page, then the publisher landing
    /// page, then the DOI resolver. An `openalex.org/W...` API id is never used.
    static func landingURL(for work: [String: Any]) -> URL? {
        if let best = work["best_oa_location"] as? [String: Any] {
            if let landing = best["landing_page_url"] as? String, let url = publicHTTPURL(landing) {
                return url
            }
        }
        if let location = work["primary_location"] as? [String: Any] {
            if let landing = location["landing_page_url"] as? String, let url = publicHTTPURL(landing) {
                return url
            }
        }
        if let doi = work["doi"] as? String {
            let trimmed = doi.trimmingCharacters(in: .whitespacesAndNewlines)
            let bare = trimmed.hasPrefix("https://doi.org/") ? String(trimmed.dropFirst("https://doi.org/".count)) : trimmed
            if !bare.isEmpty, let url = publicHTTPURL("https://doi.org/\(bare)") {
                return url
            }
        }
        return nil
    }

    private static func publicHTTPURL(_ raw: String) -> URL? {
        guard var components = URLComponents(string: raw) else { return nil }
        guard let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil else { return nil }
        components.scheme = scheme
        components.fragment = nil
        return components.url
    }
}
