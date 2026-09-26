import Foundation

/// The live transport composition behind one factory.
///
/// The native app must not name a network primitive: the repository offline
/// guard forbids `URLSession`, `SystemHostResolver`, and `getaddrinfo` in
/// `Sources/LocalLensApp`. This factory therefore lives in the core and is
/// called only by an explicitly opted-in surface. A default app launch and
/// every gated test never call it, so the offline guards are unchanged.
///
/// It is a factory, not an abstraction: it composes the existing boundaries
/// (search adapter, bounded safe fetch, snapshot store, DeepSeek provider) and
/// returns their closures and values.
public enum LiveQuickComposition {
    public struct Live: Sendable {
        public let search: @Sendable (String) async throws -> SearchOutcome
        public let fetch: @Sendable ([FetchTarget]) async throws -> [FetchResult]
        public let store: SnapshotStore
        public let provider: any QuickAnswerProvider
        /// `hosted` or `local`; never merged.
        public let label: String
        public let providerName: String
        /// Present only for the windowed News path. It reports what the mode's
        /// time window excluded at discovery; it is never evidence.
        public let newsRecency: NewsRecencyLedger?
    }

    /// Builds the live composition. `apiKey` is used only inside the provider
    /// configuration and is never logged, echoed, or persisted here.
    public static func make(
        searxng: URL = URL(string: "http://127.0.0.1:8888")!,
        language: String = "en",
        apiKey: String,
        local: LocalProviderConfiguration? = nil
    ) throws -> Live {
        let transport = URLSessionSearchTransport()
        let searchConfiguration = try SearXNGConfiguration(endpoint: searxng, language: language)
        let adapter = SearXNGSearchAdapter(configuration: searchConfiguration, transport: transport)
        return compose(transport: transport, search: { try await adapter.search($0) }, apiKey: apiKey, local: local)
    }

    /// Normal-user open-web search with a user-provided Brave key. The key is
    /// carried only in the adapter's request header; no Docker service is
    /// required. Search hits are still discovery only.
    public static func makeBrave(
        braveKey: String,
        apiKey: String,
        local: LocalProviderConfiguration? = nil
    ) throws -> Live {
        let transport = URLSessionSearchTransport()
        let configuration = try BraveSearchConfiguration(apiKey: braveKey)
        let adapter = BraveSearchAdapter(configuration: configuration, transport: transport)
        return compose(transport: transport, search: { try await adapter.search($0) }, apiKey: apiKey, local: local)
    }

    /// No-Docker, no-card open-web discovery through Tavily's user-owned key.
    /// Its result content is never promoted to citation evidence.
    public static func makeTavily(
        tavilyKey: String,
        apiKey: String,
        local: LocalProviderConfiguration? = nil
    ) throws -> Live {
        let transport = URLSessionSearchTransport()
        let configuration = try TavilySearchConfiguration(apiKey: tavilyKey)
        let adapter = TavilySearchAdapter(configuration: configuration, transport: transport)
        return compose(transport: transport, search: { try await adapter.search($0) }, apiKey: apiKey, local: local)
    }

    /// News discovery asks the provider's news index for the mode's window and
    /// then enforces that window locally, before a fetch is planned: a result
    /// outside the window, or one whose publication time the provider does not
    /// report, is excluded and counted. The window is the frozen policy value,
    /// never a request parameter chosen per run.
    public static func makeNews(
        tavilyKey: String,
        apiKey: String,
        local: LocalProviderConfiguration? = nil,
        question: String = "",
        now: @escaping @Sendable () -> Date = { Date() }
    ) throws -> Live {
        let transport = URLSessionSearchTransport()
        let windowDays = ModePolicy.policy(for: .news).timeWindowDays ?? 14
        let configuration = try TavilySearchConfiguration(
            apiKey: tavilyKey,
            maxResults: 10,
            topic: "news",
            days: windowDays
        )
        let adapter = TavilySearchAdapter(configuration: configuration, transport: transport)
        let windowed = WindowedSearchAdapter(
            wrapped: adapter,
            windowDays: windowDays,
            question: question,
            now: now
        )
        return compose(
            transport: transport,
            search: { try await windowed.search($0) },
            apiKey: apiKey,
            local: local,
            newsRecency: windowed.ledger
        )
    }

    /// Academic mode discovers scholarly works through OpenAlex before the open
    /// web. The keyless metadata provider is the only difference: the fetch,
    /// storage, retrieval, and citation boundaries are the same ones every
    /// other mode uses, so a paper claim still requires an exact stored
    /// passage.
    public static func makeAcademic(
        apiKey: String,
        mailto: String? = nil,
        fallbackTavilyKey: String? = nil,
        local: LocalProviderConfiguration? = nil
    ) throws -> Live {
        let transport = URLSessionSearchTransport()
        let openAlexConfiguration = try OpenAlexConfiguration(mailto: mailto)
        let openAlex = OpenAlexSearchAdapter(configuration: openAlexConfiguration, transport: transport)
        let arxiv = ArxivSearchAdapter(configuration: try ArxivConfiguration(), transport: transport)
        let crossref = CrossrefSearchAdapter(configuration: try CrossrefConfiguration(mailto: mailto), transport: transport)
        // At most 8 scholarly targets per run; the remaining opened-source
        // budget is reserved for the readable general-web fallback.
        let scholarlyBudget = AcademicScholarlyBudget(limit: 8)
        let fallback: (@Sendable (String) async throws -> SearchOutcome)?
        if let fallbackTavilyKey, !fallbackTavilyKey.isEmpty {
            let configuration = try TavilySearchConfiguration(apiKey: fallbackTavilyKey)
            let adapter = TavilySearchAdapter(configuration: configuration, transport: transport)
            fallback = { try await adapter.search($0) }
        } else {
            fallback = nil
        }
        return compose(transport: transport, search: { query in
            // Three scholarly metadata boundaries run together, then reconcile
            // by DOI or versionless arXiv identity so one work cannot occupy
            // three fetch slots. OpenAlex supplies the titles and first-seen
            // positions; arXiv and Crossref add identity and coverage.
            //
            // The scholarly pass is capped below the mode's opened-source
            // budget so the general-web fallback is guaranteed readable slots.
            // Measured on 2026-09-26: without the reservation, three scholarly
            // providers filled all 14 slots with DOI resolvers and arXiv
            // abstracts and the run selected 3 passages instead of 22.
            func hits(_ outcome: SearchOutcome) -> [SearchHit] {
                if case let .hits(found) = outcome { return found }
                return []
            }
            async let openAlexOutcome = openAlex.search(query)
            async let arxivOutcome = arxiv.search(query)
            let openAlexHits = hits((try? await openAlexOutcome) ?? .noResults(query: query))
            let arxivHits = hits((try? await arxivOutcome) ?? .noResults(query: query))
            // Crossref is the DOI authority and the slowest boundary. It is
            // called only when the first two providers leave the scholarly list
            // thin, which is the measured M005.3 latency defect: three providers
            // per query across up to five queries took as long as 89.76 s.
            let preliminary = ScholarlyReconciliation.reconcile([openAlexHits, arxivHits])
            let crossrefHits: [SearchHit]
            if preliminary.count < 6 {
                crossrefHits = hits((try? await crossref.search(query)) ?? .noResults(query: query))
            } else {
                crossrefHits = []
            }
            // Per-provider caps drawn from one run-scoped scholarly budget, so
            // neither a single provider nor the first query can consume it all.
            // OpenAlex is the relevance provider, arXiv the open-access full
            // text, and Crossref the DOI authority.
            let scholarly = ScholarlyReconciliation.reconcile([
                Array(openAlexHits.prefix(scholarlyBudget.take(min(openAlexHits.count, 3)))),
                Array(arxivHits.prefix(scholarlyBudget.take(min(arxivHits.count, 2)))),
                Array(crossrefHits.prefix(scholarlyBudget.take(min(crossrefHits.count, 2)))),
            ])
            let limitedScholarly = scholarly
            guard let fallback else {
                return limitedScholarly.isEmpty ? .noResults(query: query) : .hits(limitedScholarly)
            }
            let web = hits((try? await fallback(query)) ?? .noResults(query: query))
            let combined = ScholarlyReconciliation.reconcile([limitedScholarly, web])
            return combined.isEmpty ? .noResults(query: query) : .hits(combined)
        }, apiKey: apiKey, local: local)
    }

    private static func compose(
        transport: URLSessionSearchTransport,
        search: @escaping @Sendable (String) async throws -> SearchOutcome,
        apiKey: String,
        local: LocalProviderConfiguration? = nil,
        newsRecency: NewsRecencyLedger? = nil
    ) -> Live {
        let fetcher = BoundedFetcher(
            transport: transport,
            resolver: SystemHostResolver(),
            userAgent: "LocalLens/0.1 (M003.6 development; contact: repository owner)"
        )
        if let local {
            let provider = LocalAnswerProvider(configuration: local, transport: transport)
            return Live(
                search: search,
                fetch: { try await fetcher.fetch($0) },
                store: fetcher.snapshotStore,
                provider: provider,
                label: "local",
                providerName: local.label,
                newsRecency: newsRecency
            )
        }
        let providerConfiguration = DeepSeekConfiguration(apiKey: apiKey)
        let provider = DeepSeekAnswerProvider(configuration: providerConfiguration, transport: transport)

        return Live(
            search: search,
            fetch: { try await fetcher.fetch($0) },
            store: fetcher.snapshotStore,
            provider: provider,
            label: "hosted",
            providerName: providerConfiguration.model,
            newsRecency: newsRecency
        )
    }

    /// A user-supplied public page is a discovery target, not evidence. This
    /// substitutes only the search result; `LiveQuickRunner` still sends it
    /// through the same bounded, policy-checked fetch and stored-passage path.
    /// It performs no network operation itself.
    public static func providedPageSearch(
        url: URL
    ) throws -> @Sendable (String) async throws -> SearchOutcome {
        guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = url.host, !host.isEmpty, url.user == nil, url.password == nil else {
            throw SearchError.invalidEndpoint(reason: "source must be an absolute HTTP(S) URL without embedded credentials")
        }
        return { query in
            .hits([SearchHit(
                id: StableIdentity.make("provided-hit", query, url.absoluteString),
                query: query,
                rank: 1,
                url: url,
                title: host,
                snippet: ""
            )])
        }
    }
}

/// A run-scoped counter for the Academic scholarly-discovery reservation.
///
/// It exists so three scholarly providers cannot consume the whole fetch
/// budget: the benchmark measurement on 2026-09-26 showed 3 selected passages
/// when they did, against 22 when the readable general-web fallback was
/// guaranteed slots. It is discovery bookkeeping only and never inspects or
/// promotes a passage.
private final class AcademicScholarlyBudget: @unchecked Sendable {
    private let lock = NSLock()
    private var remaining: Int

    init(limit: Int) {
        self.remaining = max(0, limit)
    }

    func take(_ count: Int) -> Int {
        lock.withLock {
            let granted = max(0, min(count, remaining))
            remaining -= granted
            return granted
        }
    }
}
