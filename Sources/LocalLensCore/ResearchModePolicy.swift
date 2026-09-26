import Foundation

/// The kind of source a mode is allowed to treat as discovery input.
///
/// Modes are frozen execution policies, not prompt labels (D007). The source
/// kind is part of the policy: Academic resolves scholarly metadata before the
/// open web, News keeps a time window and demands independent confirmation, and
/// Quick/Deep use the general web.
public enum SourceKind: String, Codable, CaseIterable, Sendable {
    case web
    case documentation
    case scholarly
    case news
}

/// The frozen, per-mode execution policy.
///
/// Every number here is a ceiling the runner enforces in code. A plan that
/// exceeds its policy is refused rather than trimmed, so no mode can silently
/// borrow another mode's budget.
public struct ModePolicy: Equatable, Sendable {
    public let mode: ResearchMode
    public let searchQueries: Int
    public let openedSources: Int
    public let synthesisPassages: Int
    public let deadlineSeconds: Double
    public let followUpRounds: Int
    public let timeWindowDays: Int?
    public let sourceKind: SourceKind

    public init(
        mode: ResearchMode,
        searchQueries: Int,
        openedSources: Int,
        synthesisPassages: Int,
        deadlineSeconds: Double,
        followUpRounds: Int,
        timeWindowDays: Int?,
        sourceKind: SourceKind
    ) {
        self.mode = mode
        self.searchQueries = searchQueries
        self.openedSources = openedSources
        self.synthesisPassages = synthesisPassages
        self.deadlineSeconds = deadlineSeconds
        self.followUpRounds = followUpRounds
        self.timeWindowDays = timeWindowDays
        self.sourceKind = sourceKind
    }

    /// The frozen policies. Quick is unchanged from the promoted M003 slice.
    public static func policy(for mode: ResearchMode) -> ModePolicy {
        switch mode {
        case .quick:
            ModePolicy(mode: .quick, searchQueries: 2, openedSources: 6, synthesisPassages: 12,
                       deadlineSeconds: 60, followUpRounds: 0, timeWindowDays: nil, sourceKind: .web)
        case .deep:
            ModePolicy(mode: .deep, searchQueries: 6, openedSources: 16, synthesisPassages: 24,
                       deadlineSeconds: 180, followUpRounds: 2, timeWindowDays: nil, sourceKind: .web)
        case .academic:
            ModePolicy(mode: .academic, searchQueries: 5, openedSources: 14, synthesisPassages: 24,
                       deadlineSeconds: 180, followUpRounds: 1, timeWindowDays: nil, sourceKind: .scholarly)
        case .news:
            ModePolicy(mode: .news, searchQueries: 5, openedSources: 14, synthesisPassages: 20,
                       deadlineSeconds: 120, followUpRounds: 1, timeWindowDays: 14, sourceKind: .news)
        }
    }

    /// A one-line disclosure shown in the toolbar next to the mode.
    public var boundarySummary: String {
        switch mode {
        case .quick:
            "2 queries · 6 sources · 12 passages · 60s"
        case .deep:
            "6 queries · 16 sources · 24 passages · 2 follow-up rounds · 180s"
        case .academic:
            "scholarly metadata first · 5 queries · 14 sources · 24 passages · 180s"
        case .news:
            "last 14 days · independent confirmation · 5 queries · 14 sources · 120s"
        }
    }
}

/// A deterministic, frozen execution plan for one question in one mode.
public struct ResearchPlan: Equatable, Sendable {
    public let mode: ResearchMode
    public let question: String
    /// The answer dimensions the evidence map groups claims by.
    public let dimensions: [String]
    public let searchQueries: [String]
    public let retrievalQueries: [String]
    public let policy: ModePolicy

    public init(
        mode: ResearchMode,
        question: String,
        dimensions: [String],
        searchQueries: [String],
        retrievalQueries: [String],
        policy: ModePolicy
    ) {
        self.mode = mode
        self.question = question
        self.dimensions = dimensions
        self.searchQueries = searchQueries
        self.retrievalQueries = retrievalQueries
        self.policy = policy
    }
}

/// Why a dimension plan cannot be used as written. Typed, so the surface can
/// say exactly what is wrong instead of silently trimming or dropping input.
public enum ResearchPlanError: Error, Equatable, LocalizedError {
    case noDimensions
    case tooManyDimensions(mode: ResearchMode, maximum: Int, given: Int)
    case duplicateDimension(String)
    case dimensionTooLong(String)

    public var errorDescription: String? {
        switch self {
        case .noDimensions:
            "A plan needs at least one dimension."
        case let .tooManyDimensions(mode, maximum, given):
            "\(mode.rawValue) mode allows at most \(maximum) dimensions; \(given) were given."
        case let .duplicateDimension(name):
            "The dimension \"\(name)\" appears more than once."
        case let .dimensionTooLong(name):
            "The dimension \"\(name.prefix(30))...\" is longer than 60 characters."
        }
    }
}

/// Turns a question into the frozen plan for its mode.
///
/// This is a deterministic query planner, not a model: it reuses the measured
/// `QuickQueryPlanner` tokenizer and adds mode-shaped windows. It changes which
/// pages are found and how the map is grouped, never how a passage becomes a
/// citation.
public enum ResearchPlanner {
    /// The most dimensions a mode's evidence map will group by. A user-edited
    /// plan is validated against this, and the planner's own default never
    /// exceeds it.
    public static func maximumDimensions(for mode: ResearchMode) -> Int {
        switch mode {
        case .quick: 1
        case .deep: 6
        case .academic: 5
        case .news: 4
        }
    }

    /// Validates a user-supplied dimension plan against the mode's caps.
    ///
    /// Trimming and whitespace collapsing are allowed because they do not change
    /// meaning. Dropping a dimension, merging duplicates, or truncating a label
    /// is not: the surface is told what is wrong instead.
    public static func validatedDimensions(_ raw: [String], mode: ResearchMode) throws -> [String] {
        let cleaned = raw.map {
            $0.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        }.filter { !$0.isEmpty }
        guard !cleaned.isEmpty else { throw ResearchPlanError.noDimensions }
        let maximum = maximumDimensions(for: mode)
        guard cleaned.count <= maximum else {
            throw ResearchPlanError.tooManyDimensions(mode: mode, maximum: maximum, given: cleaned.count)
        }
        var seen: Set<String> = []
        for dimension in cleaned {
            guard dimension.count <= 60 else { throw ResearchPlanError.dimensionTooLong(dimension) }
            let key = dimension.lowercased()
            guard seen.insert(key).inserted else {
                throw ResearchPlanError.duplicateDimension(dimension)
            }
        }
        return cleaned
    }

    /// Splits a comma- or newline-separated field into dimension candidates.
    public static func splitDimensions(_ text: String) -> [String] {
        text.split(whereSeparator: { $0 == "," || $0 == "\n" }).map(String.init)
    }

    public static func plan(_ question: String, mode: ResearchMode, now: Date = Date()) -> ResearchPlan {
        let policy = ModePolicy.policy(for: mode)
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let dimensions = dimensions(for: trimmed, mode: mode)
        let searchQueries = Array(dedupe(searchQueries(for: trimmed, mode: mode, dimensions: dimensions, now: now)).prefix(policy.searchQueries))
        let retrievalQueries = Array(dedupe(retrievalQueries(for: trimmed, mode: mode, dimensions: dimensions, now: now)).prefix(policy.searchQueries))
        return ResearchPlan(
            mode: mode,
            question: trimmed,
            dimensions: dimensions,
            searchQueries: searchQueries,
            retrievalQueries: retrievalQueries,
            policy: policy
        )
    }

    /// Plans with a user-edited dimension list. The dimensions take part in the
    /// same query generation as the defaults; nothing else about the run
    /// changes.
    public static func plan(
        _ question: String,
        mode: ResearchMode,
        now: Date = Date(),
        dimensions edited: [String]
    ) throws -> ResearchPlan {
        let dimensions = try validatedDimensions(edited, mode: mode)
        let policy = ModePolicy.policy(for: mode)
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let searchQueries = Array(dedupe(searchQueries(for: trimmed, mode: mode, dimensions: dimensions, now: now)).prefix(policy.searchQueries))
        let retrievalQueries = Array(dedupe(retrievalQueries(for: trimmed, mode: mode, dimensions: dimensions, now: now)).prefix(policy.searchQueries))
        return ResearchPlan(
            mode: mode,
            question: trimmed,
            dimensions: dimensions,
            searchQueries: searchQueries,
            retrievalQueries: retrievalQueries,
            policy: policy
        )
    }

    // MARK: Dimensions

    /// The answer dimensions the evidence map groups by. Deterministic and
    /// small: a comparison yields its two sides plus tradeoffs, everything else
    /// gets the mode's fixed scaffold.
    public static func dimensions(for question: String, mode: ResearchMode) -> [String] {
        switch mode {
        case .quick:
            return ["Answer"]
        case .deep:
            if let sides = comparisonSides(question), sides.count == 2 {
                return [sides[0], sides[1], "Tradeoffs", "Gaps"]
            }
            return ["Overview", "Evidence", "Tradeoffs", "Gaps"]
        case .academic:
            return ["Findings", "Method", "Limitations"]
        case .news:
            return ["What happened", "Timeline", "Independent confirmation"]
        }
    }

    /// "A vs B", "A versus B", and "compare A and B" are the comparison shapes
    /// the Deep mode exposes as explicit columns.
    static func comparisonSides(_ question: String) -> [String]? {
        let lower = question.lowercased()
        for separator in [" vs ", " versus ", " or "] {
            if let range = lower.range(of: separator) {
                let left = String(question[question.startIndex..<range.lowerBound])
                let right = String(question[range.upperBound...])
                let sides = [cleanSide(left), cleanSide(right)].filter { !$0.isEmpty }
                if sides.count == 2 { return sides }
            }
        }
        if lower.hasPrefix("compare ") {
            let rest = String(question.dropFirst("compare ".count))
            let parts = rest.components(separatedBy: " and ")
            if parts.count == 2 {
                let sides = parts.map { cleanSide($0) }.filter { !$0.isEmpty }
                if sides.count == 2 { return sides }
            }
        }
        return nil
    }

    private static func cleanSide(_ raw: String) -> String {
        var side = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["compare ", "should i use ", "is ", "are ", "which is better, "] where side.lowercased().hasPrefix(prefix) {
            side = String(side.dropFirst(prefix.count))
        }
        return side.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Queries

    static func searchQueries(
        for question: String,
        mode: ResearchMode,
        dimensions: [String],
        now: Date
    ) -> [String] {
        guard !question.isEmpty else { return [] }
        switch mode {
        case .quick:
            return QuickQueryPlanner.webQueries(question: question, maximumQueries: 2)
        case .deep:
            // Round 0 stays narrow: the natural-language question, or its
            // measured rewrite. Dimension queries are generated as bounded
            // follow-ups only for a dimension the first round left uncovered,
            // so Deep cannot spam the same query twice.
            return QuickQueryPlanner.webQueries(question: question, maximumQueries: 2)
        case .academic:
            var queries = [question]
            queries.append("\(question) study")
            queries.append("\(question) survey")
            for dimension in dimensions where queries.count < 5 {
                queries.append("\(question) \(dimension)")
            }
            return queries
        case .news:
            let stamp = newsStamp(now)
            return [
                "\(question) news \(stamp)",
                "\(question) \(stamp)",
                question,
            ]
        }
    }

    static func retrievalQueries(
        for question: String,
        mode: ResearchMode,
        dimensions: [String],
        now: Date
    ) -> [String] {
        guard !question.isEmpty else { return [] }
        var queries = QuickQueryPlanner.plan(question: question, maximumQueries: mode == .quick ? 2 : 4)
        guard !queries.isEmpty else { return [] }
        for dimension in dimensions {
            let terms = QuickQueryPlanner.contentTerms(of: dimension)
            if !terms.isEmpty {
                queries.append(terms.joined(separator: " "))
            }
        }
        if mode == .news {
            let terms = QuickQueryPlanner.contentTerms(of: question)
            if !terms.isEmpty { queries.append(terms.prefix(3).joined(separator: " ")) }
        }
        return queries
    }

    /// A deterministic, locale-independent month/year stamp for News queries.
    static func newsStamp(_ now: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let components = calendar.dateComponents([.month, .year], from: now)
        let month = components.month ?? 1
        let year = components.year ?? 1970
        let names = ["January", "February", "March", "April", "May", "June",
                     "July", "August", "September", "October", "November", "December"]
        let name = names[max(0, min(11, month - 1))]
        return "\(name) \(year)"
    }

    static func dedupe(_ queries: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for query in queries {
            let key = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty, seen.insert(key).inserted else { continue }
            result.append(query.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return result
    }
}

/// Deterministic source-independence treatment for News mode.
///
/// A syndicated copy is not a second source. Clustering stored passages by the
/// registrable domain of the page they came from makes the independence of a
/// claim visible without touching citation evidence: the cluster is a view over
/// already-stored snapshots, and every factual claim still resolves to its own
/// exact passage.
public struct NewsSourceCluster: Equatable, Sendable {
    public let registrableDomain: String
    public let passageIDs: [String]
    public let sourceURLs: [URL]

    public init(registrableDomain: String, passageIDs: [String], sourceURLs: [URL]) {
        self.registrableDomain = registrableDomain
        self.passageIDs = passageIDs
        self.sourceURLs = sourceURLs
    }
}

public enum NewsIndependence {
    /// The registrable-ish domain: the last two labels of the host, dropping a
    /// leading `www.`. This is honest about its limits: it does not consult a
    /// public-suffix list, so a two-label ccTLD such as `co.uk` stays distinct
    /// from `example.co.uk`. The view labels it "domain", not "publisher".
    public static func domain(of url: URL) -> String? {
        guard let rawHost = url.host?.lowercased(), !rawHost.isEmpty else { return nil }
        let host = rawHost.hasPrefix("www.") ? String(rawHost.dropFirst(4)) : rawHost
        let labels = host.split(separator: ".").map(String.init)
        guard labels.count >= 2 else { return host }
        return labels.suffix(2).joined(separator: ".")
    }

    /// Groups stored passages by the domain of the page that supplied them.
    public static func clusters(passages: [Passage], records: [SnapshotRecord]) -> [NewsSourceCluster] {
        var urlBySnapshot: [String: URL] = [:]
        for record in records {
            urlBySnapshot[record.snapshot.id] = record.finalURL
        }
        var grouped: [String: (passageIDs: [String], urls: [URL])] = [:]
        for passage in passages {
            guard let url = urlBySnapshot[passage.snapshotID], let domain = domain(of: url) else { continue }
            var entry = grouped[domain] ?? ([], [])
            entry.passageIDs.append(passage.id)
            if !entry.urls.contains(url) { entry.urls.append(url) }
            grouped[domain] = entry
        }
        return grouped
            .map { NewsSourceCluster(registrableDomain: $0.key, passageIDs: $0.value.passageIDs, sourceURLs: $0.value.urls) }
            .sorted { $0.registrableDomain < $1.registrableDomain }
    }

    /// One independent voice: a domain, or the group of domains that published
    /// the same headline. Two outlets running the same wire report are one
    /// voice, not two confirmations.
    public struct NewsVoice: Equatable, Sendable {
        public let signature: String
        public let headline: String
        public let domains: [String]
        public let passageIDs: [String]

        public init(signature: String, headline: String, domains: [String], passageIDs: [String]) {
            self.signature = signature
            self.headline = headline
            self.domains = domains
            self.passageIDs = passageIDs
        }
    }

    /// Groups stored passages into independent voices.
    ///
    /// The headline is the page heading the extractor already stored, not a new
    /// inference: no title is fetched, guessed, or invented. Two headings that
    /// reduce to the same four-or-more-word signature count once, which is the
    /// deterministic copy test this repository can honestly make. A heading
    /// that is missing or too short stays unique, so a generic "Introduction"
    /// can never silently merge two unrelated reports.
    public static func voices(passages: [Passage], records: [SnapshotRecord]) -> [NewsVoice] {
        let grouped = clusters(passages: passages, records: records)
        var order: [String] = []
        var bySignature: [String: (headline: String, domains: [String], passageIDs: [String])] = [:]
        for cluster in grouped {
            // The longest heading in the cluster, not the first: live News
            // measurement on 2026-09-26 showed clusters whose first heading was
            // page furniture ("By Type", "Company", "Thank you!") while the
            // article headline sat on a later passage. A longer heading is the
            // better copy proxy, and the four-word minimum still refuses to
            // judge navigation text. The extractor's heading quality on news
            // pages remains an open defect.
            let candidate = passages.filter { cluster.passageIDs.contains($0.id) }.map(\.heading)
            let heading = candidate.max { left, right in
                (headlineSignature(left) ?? "").count < (headlineSignature(right) ?? "").count
            } ?? ""
            let signature = headlineSignature(heading) ?? "domain:\(cluster.registrableDomain)"
            if bySignature[signature] == nil {
                order.append(signature)
                bySignature[signature] = (heading, [], [])
            }
            bySignature[signature]?.domains.append(cluster.registrableDomain)
            bySignature[signature]?.passageIDs.append(contentsOf: cluster.passageIDs)
        }
        return order.compactMap { signature in
            guard let entry = bySignature[signature] else { return nil }
            return NewsVoice(
                signature: signature,
                headline: entry.headline,
                domains: entry.domains.sorted(),
                passageIDs: entry.passageIDs
            )
        }
    }

    /// The shared-headline test. Returns `nil` when a heading cannot support a
    /// copy judgement, which keeps that cluster independent.
    public static func headlineSignature(_ heading: String) -> String? {
        let alphanumerics = heading.lowercased().map { character -> Character in
            character.isLetter || character.isNumber ? character : " "
        }
        let words = String(alphanumerics)
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }
        guard words.count >= 4 else { return nil }
        return words.prefix(10).joined(separator: " ")
    }

    /// How many distinct domains back the evidence. A materially confirmed
    /// News answer needs at least two; one is visible uncertainty.
    public static func independentDomainCount(passages: [Passage], records: [SnapshotRecord]) -> Int {
        clusters(passages: passages, records: records).count
    }

    /// Independent voices: how many confirmations the evidence really carries
    /// once copied headlines are counted once.
    public static func independentVoiceCount(passages: [Passage], records: [SnapshotRecord]) -> Int {
        voices(passages: passages, records: records).count
    }

    /// One entry on the current-event timeline: where the report sits in time.
    public struct NewsTimelineEntry: Equatable, Sendable, Identifiable {
        public let signature: String
        public let headline: String
        public let domains: [String]
        public let publishedAt: Date?

        public var id: String { signature }
    }

    /// Orders independent voices newest first, undated last.
    ///
    /// The date is the publication time the discovery provider reported for a
    /// stored page. A page the provider did not date keeps its place at the end
    /// and is shown without a timestamp rather than given an invented one.
    public static func timeline(
        passages: [Passage],
        records: [SnapshotRecord],
        publicationDates: [String: Date]
    ) -> [NewsTimelineEntry] {
        var urlBySnapshot: [String: URL] = [:]
        for record in records { urlBySnapshot[record.snapshot.id] = record.finalURL }
        let voices = voices(passages: passages, records: records)
        let clusters = clusters(passages: passages, records: records)
        var datesByDomain: [String: Date] = [:]
        for cluster in clusters {
            for url in cluster.sourceURLs {
                guard let date = publicationDates[url.absoluteString] else { continue }
                if let existing = datesByDomain[cluster.registrableDomain], existing > date { continue }
                datesByDomain[cluster.registrableDomain] = date
            }
        }
        let entries = voices.map { voice -> NewsTimelineEntry in
            let dates = voice.domains.compactMap { datesByDomain[$0] }
            return NewsTimelineEntry(
                signature: voice.signature,
                headline: voice.headline,
                domains: voice.domains,
                publishedAt: dates.max()
            )
        }
        return entries.sorted { left, right in
            switch (left.publishedAt, right.publishedAt) {
            case let (l?, r?) where l != r:
                return l > r
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            default:
                return left.signature < right.signature
            }
        }
    }

    /// How many independent voices back the page a claim was quoted from.
    ///
    /// A claim drawn from a report that only one outlet carries is
    /// single-source, even when several domains are present in the run. The
    /// surface shows that as visible uncertainty instead of implying
    /// confirmation.
    public static func snapshotSupport(
        passages: [Passage],
        records: [SnapshotRecord],
        snapshotID: String
    ) -> Int {
        guard let url = records.first(where: { $0.snapshot.id == snapshotID })?.finalURL,
              let domain = domain(of: url) else { return 0 }
        return voices(passages: passages, records: records)
            .filter { $0.domains.contains(domain) }
            .count
    }

    /// Per-snapshot support for a whole run, so a view can mark one claim
    /// without recomputing the clustering for every row.
    public static func snapshotSupportMap(
        passages: [Passage],
        records: [SnapshotRecord]
    ) -> [String: Int] {
        let voices = voices(passages: passages, records: records)
        var urlBySnapshot: [String: URL] = [:]
        for record in records { urlBySnapshot[record.snapshot.id] = record.finalURL }
        var map: [String: Int] = [:]
        for snapshotID in Set(passages.map(\.snapshotID)) {
            guard let url = urlBySnapshot[snapshotID], let domain = domain(of: url) else { continue }
            map[snapshotID] = voices.filter { $0.domains.contains(domain) }.count
        }
        return map
    }
}
