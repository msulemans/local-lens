import Foundation

/// Opt-in scholarly discovery through Crossref's REST API.
///
/// Crossref is the DOI registration authority, so it is the boundary that makes
/// DOI identity authoritative. Only the DOI, title, and a public HTTP landing
/// URL are consumed; abstracts, references, and license fields are ignored as
/// discovery metadata. No key is required; a `mailto` enters the polite pool.
public struct CrossrefConfiguration: Sendable {
    public static let endpoint = URL(string: "https://api.crossref.org/works")!

    public let maxResults: Int
    public let mailto: String?
    public let timeoutSeconds: Double

    public init(maxResults: Int = 10, mailto: String? = nil, timeoutSeconds: Double = 15) throws {
        guard (1...50).contains(maxResults) else {
            throw SearchError.invalidEndpoint(reason: "Crossref result count must be between 1 and 50")
        }
        guard timeoutSeconds > 0 else {
            throw SearchError.invalidEndpoint(reason: "Crossref timeout must be positive")
        }
        if let mailto, !mailto.contains("@") {
            throw SearchError.invalidEndpoint(reason: "Crossref mailto must be an email address")
        }
        self.maxResults = maxResults
        self.mailto = mailto
        self.timeoutSeconds = timeoutSeconds
    }
}

public struct CrossrefSearchAdapter: SearchAdapter {
    public let configuration: CrossrefConfiguration
    public let transport: any SearchTransport

    public init(configuration: CrossrefConfiguration, transport: any SearchTransport) {
        self.configuration = configuration
        self.transport = transport
    }

    public func search(_ query: String) async throws -> SearchOutcome {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SearchError.emptyQuery }
        guard var components = URLComponents(url: CrossrefConfiguration.endpoint, resolvingAgainstBaseURL: false) else {
            throw SearchError.invalidEndpoint(reason: "Crossref endpoint cannot be decomposed")
        }
        var items = [
            URLQueryItem(name: "query.bibliographic", value: trimmed),
            URLQueryItem(name: "rows", value: String(configuration.maxResults)),
            URLQueryItem(name: "select", value: "DOI,title,URL,type"),
        ]
        if let mailto = configuration.mailto {
            items.append(URLQueryItem(name: "mailto", value: mailto))
        }
        components.queryItems = items
        guard let url = components.url else {
            throw SearchError.invalidEndpoint(reason: "Crossref endpoint cannot carry search parameters")
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
        return try CrossrefPayload.decode(response.body, query: trimmed, maxResults: configuration.maxResults)
    }
}

public enum CrossrefPayload {
    public static func decode(_ data: Data, query: String, maxResults: Int) throws -> SearchOutcome {
        let raw: Any
        do {
            raw = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw SearchError.malformedPayload(reason: "Crossref response is not valid JSON")
        }
        guard let root = raw as? [String: Any],
              let message = root["message"] as? [String: Any],
              let rawItems = message["items"] as? [Any] else {
            throw SearchError.malformedPayload(reason: "Crossref response has no message.items array")
        }
        guard !rawItems.isEmpty else { return .noResults(query: query) }

        var hits: [SearchHit] = []
        for rawItem in rawItems.prefix(maxResults) {
            guard let item = rawItem as? [String: Any] else { continue }
            guard let doi = normalizedDOI(item["DOI"] as? String) else { continue }
            // Crossref is the DOI authority, so its discovery target is the
            // canonical DOI resolver. That makes the work's identity explicit
            // to reconciliation, and the bounded fetch follows the resolver's
            // redirect, recording the publisher URL it actually landed on. A
            // publisher URL copied here would carry no identity and could not
            // be joined to the same work from another provider.
            guard let url = URL(string: "https://doi.org/\(doi)") else { continue }
            let title = (item["title"] as? [Any])?.first as? String
            hits.append(SearchHit(
                id: StableIdentity.make("crossref-hit", query, url.absoluteString),
                query: query,
                rank: hits.count,
                url: url,
                title: (title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? title! : doi),
                snippet: ""
            ))
        }
        return hits.isEmpty ? .noResults(query: query) : .hits(hits)
    }

    /// Crossref DOIs arrive bare. Normalizing here gives reconciliation one
    /// stable identity shape regardless of provider.
    public static func normalizedDOI(_ raw: String?) -> String? {
        guard var doi = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !doi.isEmpty else { return nil }
        for prefix in ["https://doi.org/", "http://doi.org/", "doi:"] where doi.hasPrefix(prefix) {
            doi = String(doi.dropFirst(prefix.count))
        }
        return doi.isEmpty ? nil : doi
    }

    /// `https://doi.org/<doi>` — the canonical, identity-bearing target.
    static func doiResolverURL(doi: String) -> URL? {
        URL(string: "https://doi.org/\(doi)")
    }
}
