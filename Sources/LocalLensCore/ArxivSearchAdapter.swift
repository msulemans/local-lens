import Foundation

/// Opt-in scholarly discovery through arXiv's Atom API.
///
/// Only the abstract-page URL and the title are consumed. The summary and any
/// author metadata are deliberately ignored: discovery metadata is never
/// citation evidence, and the live runner still fetches the abs page, stores a
/// snapshot, and extracts a passage before a claim can be cited.
public struct ArxivConfiguration: Sendable {
    public static let endpoint = URL(string: "https://export.arxiv.org/api/query")!

    public let maxResults: Int
    public let timeoutSeconds: Double

    public init(maxResults: Int = 10, timeoutSeconds: Double = 15) throws {
        guard (1...50).contains(maxResults) else {
            throw SearchError.invalidEndpoint(reason: "arXiv result count must be between 1 and 50")
        }
        guard timeoutSeconds > 0 else {
            throw SearchError.invalidEndpoint(reason: "arXiv timeout must be positive")
        }
        self.maxResults = maxResults
        self.timeoutSeconds = timeoutSeconds
    }
}

public struct ArxivSearchAdapter: SearchAdapter {
    public let configuration: ArxivConfiguration
    public let transport: any SearchTransport

    public init(configuration: ArxivConfiguration, transport: any SearchTransport) {
        self.configuration = configuration
        self.transport = transport
    }

    public func search(_ query: String) async throws -> SearchOutcome {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SearchError.emptyQuery }
        guard var components = URLComponents(url: ArxivConfiguration.endpoint, resolvingAgainstBaseURL: false) else {
            throw SearchError.invalidEndpoint(reason: "arXiv endpoint cannot be decomposed")
        }
        components.queryItems = [
            URLQueryItem(name: "search_query", value: "all:\(trimmed)"),
            URLQueryItem(name: "start", value: "0"),
            URLQueryItem(name: "max_results", value: String(configuration.maxResults)),
        ]
        guard let url = components.url else {
            throw SearchError.invalidEndpoint(reason: "arXiv endpoint cannot carry search parameters")
        }
        let request = SearchRequest(
            url: url,
            headers: ["Accept": "application/atom+xml"],
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
        return try ArxivAtomPayload.decode(response.body, query: trimmed, maxResults: configuration.maxResults)
    }
}

/// Strictly interprets the Atom feed. A malformed document fails closed; an
/// entry without a usable abs URL or title is skipped rather than repaired.
public enum ArxivAtomPayload {
    public static func decode(_ data: Data, query: String, maxResults: Int) throws -> SearchOutcome {
        let parser = XMLParser(data: data)
        let delegate = AtomDelegate(maxResults: maxResults)
        parser.delegate = delegate
        guard parser.parse() else {
            throw SearchError.malformedPayload(reason: "arXiv response is not a parseable Atom document")
        }
        guard delegate.sawFeed else {
            throw SearchError.malformedPayload(reason: "arXiv response has no feed element")
        }
        let hits = delegate.entries.enumerated().compactMap { index, entry -> SearchHit? in
            guard let url = abstractURL(entry.id) else { return nil }
            let title = entry.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            return SearchHit(
                id: StableIdentity.make("arxiv-hit", query, url.absoluteString),
                query: query,
                rank: index,
                url: url,
                title: (title?.isEmpty == false ? title! : "arXiv work"),
                snippet: ""
            )
        }
        return hits.isEmpty ? .noResults(query: query) : .hits(hits)
    }

    /// `http://arxiv.org/abs/2401.12345v2` becomes the versionless HTTPS abs
    /// URL. A non-abs arXiv URL is not a readable abstract page and is skipped.
    static func abstractURL(_ raw: String?) -> URL? {
        guard let raw, let components = URLComponents(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        guard let host = components.host?.lowercased(), host.hasSuffix("arxiv.org") else { return nil }
        let path = components.percentEncodedPath
        guard path.hasPrefix("/abs/") else { return nil }
        var identifier = String(path.dropFirst("/abs/".count))
        if let range = identifier.range(of: #"v\d+$"#, options: .regularExpression) {
            identifier.removeSubrange(range)
        }
        guard !identifier.isEmpty else { return nil }
        return URL(string: "https://arxiv.org/abs/\(identifier)")
    }

    private final class AtomDelegate: NSObject, XMLParserDelegate {
        struct Entry {
            var id: String?
            var title: String?
            var isTitle = false
        }

        let maxResults: Int
        private(set) var sawFeed = false
        private(set) var entries: [Entry] = []

        private var current: Entry?
        private var buffer = ""

        init(maxResults: Int) {
            self.maxResults = maxResults
        }

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?,
            attributes attributeDict: [String: String] = [:]
        ) {
            let name = elementName.lowercased()
            if name == "feed" { sawFeed = true }
            if name == "entry" {
                guard entries.count < maxResults else { return }
                current = Entry()
            }
            if name == "title" { current?.isTitle = true }

            // The Atom feed is parsed with the Atom namespace stripped by
            // XMLParser, so element names arrive without a prefix.
            _ = namespaceURI
            _ = qName
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            guard current != nil else { return }
            buffer += string
        }

        func parser(
            _ parser: XMLParser,
            didEndElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?
        ) {
            let name = elementName.lowercased()
            let text = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
            if name == "id", current != nil {
                current?.id = text
            } else if name == "title", current != nil {
                current?.title = text
                current?.isTitle = false
            } else if name == "entry" {
                if let entry = current { entries.append(entry) }
                current = nil
            }
            buffer = ""
        }
    }
}
