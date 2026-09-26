import Foundation

/// A discovery hit together with the publication time the provider reported.
///
/// The date is provider metadata used only to apply a mode's time window. It is
/// never citation evidence, it is never stored as a passage fact, and it never
/// substitutes for an exact passage: a News claim still needs one.
public struct DatedHit: Equatable, Sendable {
    public let hit: SearchHit
    public let publishedAt: Date?

    public init(hit: SearchHit, publishedAt: Date?) {
        self.hit = hit
        self.publishedAt = publishedAt
    }
}

/// A discovery boundary that reports when each result was published, if the
/// provider says. Not every adapter can; only the windowed News path needs it.
public protocol DatedSearchAdapter: Sendable {
    func searchDated(_ query: String) async throws -> [DatedHit]
}

/// One query's window decision. Exclusions are counted so the surface can say
/// what was left out instead of quietly shrinking the result set.
public struct NewsRecencyDecision: Equatable, Sendable {
    public let kept: [SearchHit]
    public let excludedStale: [DatedHit]
    public let excludedUndated: [DatedHit]

    public init(kept: [SearchHit], excludedStale: [DatedHit], excludedUndated: [DatedHit]) {
        self.kept = kept
        self.excludedStale = excludedStale
        self.excludedUndated = excludedUndated
    }

    public var isStarved: Bool { kept.isEmpty }
    public var excludedCount: Int { excludedStale.count + excludedUndated.count }
}

public enum NewsRecency {
    public static let secondsPerDay: TimeInterval = 86_400

    /// True when a reported publication time falls inside the window. A page
    /// published slightly ahead of the device clock is still accepted, because
    /// a publisher's clock is not a claim about the future.
    public static func isWithinWindow(_ publishedAt: Date, windowDays: Int, now: Date) -> Bool {
        guard windowDays > 0 else { return true }
        let earliest = now.addingTimeInterval(-Double(windowDays) * secondsPerDay)
        let latest = now.addingTimeInterval(secondsPerDay)
        return publishedAt >= earliest && publishedAt <= latest
    }

    /// Applies a mode's window to one query's discovery.
    ///
    /// A page that reports no publication time cannot satisfy a bounded window,
    /// so it is excluded and counted rather than assumed fresh. This is the
    /// strict reading: News promises a window, and an undated page cannot be
    /// shown to honour it.
    public static func apply(_ hits: [DatedHit], windowDays: Int, now: Date) -> NewsRecencyDecision {
        var kept: [SearchHit] = []
        var stale: [DatedHit] = []
        var undated: [DatedHit] = []
        for dated in hits {
            guard let publishedAt = dated.publishedAt else {
                undated.append(dated)
                continue
            }
            if isWithinWindow(publishedAt, windowDays: windowDays, now: now) {
                kept.append(dated.hit)
            } else {
                stale.append(dated)
            }
        }
        return NewsRecencyDecision(kept: kept, excludedStale: stale, excludedUndated: undated)
    }
}

/// A run-scoped, thread-safe tally of what a window excluded.
public final class NewsRecencyLedger: @unchecked Sendable {
    private let lock = NSLock()
    private var stale = 0
    private var undated = 0
    private var queries = 0
    private var starved = 0
    private var dates: [Date] = []
    private var byURL: [String: Date] = [:]
    private var offTopic = 0
    private var offTopicDomains: [String] = []
    private var relevanceStarved = 0

    public init() {}

    func record(_ decision: NewsRecencyDecision, kept: [DatedHit]) {
        lock.withLock {
            queries += 1
            stale += decision.excludedStale.count
            undated += decision.excludedUndated.count
            if decision.isStarved && decision.excludedCount > 0 { starved += 1 }
            for dated in kept {
                guard let publishedAt = dated.publishedAt else { continue }
                dates.append(publishedAt)
                // First report wins when two queries surface the same page.
                if byURL[dated.hit.url.absoluteString] == nil {
                    byURL[dated.hit.url.absoluteString] = publishedAt
                }
            }
        }
    }

    /// Records what the topical filter removed at discovery. Counted, never
    /// silently dropped.
    func recordRelevance(_ decision: NewsRelevanceDecision) {
        lock.withLock {
            offTopic += decision.droppedCount
            if decision.isStarved && decision.droppedCount > 0 { relevanceStarved += 1 }
            for domain in decision.droppedDomains where !offTopicDomains.contains(domain) {
                offTopicDomains.append(domain)
            }
        }
    }

    public var offTopicCount: Int { lock.withLock { offTopic } }
    public var offTopicDomainsList: [String] { lock.withLock { offTopicDomains } }
    /// True when relevance filtering would have removed every result and the
    /// run kept them all instead. Shown, never hidden.
    public var relevanceWasStarved: Bool { lock.withLock { relevanceStarved > 0 } }

    /// The publication time the provider reported for a URL, when it reported
    /// one. Provider metadata, never evidence.
    public func publicationDate(for url: URL) -> Date? {
        lock.withLock { byURL[url.absoluteString] }
    }

    /// Every reported date, keyed by the URL it belongs to.
    public var publicationDates: [String: Date] { lock.withLock { byURL } }

    public var excludedStaleCount: Int { lock.withLock { stale } }
    public var excludedUndatedCount: Int { lock.withLock { undated } }
    public var queryCount: Int { lock.withLock { queries } }
    public var starvedQueryCount: Int { lock.withLock { starved } }
    public var keptPublicationDates: [Date] { lock.withLock { dates } }

    /// The observed span of published reports that survived the window, oldest
    /// first. Empty when no result reported a date.
    public var observedWindow: (oldest: Date, newest: Date)? {
        let sorted = keptPublicationDates.sorted()
        guard let first = sorted.first, let last = sorted.last else { return nil }
        return (first, last)
    }

    public var summary: String {
        lock.withLock {
            guard queries > 0 else { return "" }
            var parts = ["\(dates.count) dated results inside the window"]
            if stale > 0 { parts.append("\(stale) outside it") }
            if undated > 0 { parts.append("\(undated) without a date") }
            if offTopic > 0 { parts.append("\(offTopic) off topic for this question") }
            if relevanceStarved > 0 { parts.append("relevance filter found nothing and was not applied") }
            return parts.joined(separator: ", ")
        }
    }
}

/// Enforces a time window at discovery, before any fetch is planned.
///
/// Excluded results are counted and dropped; they are never fetched, stored, or
/// offered as evidence. The wrapped adapter is the only network boundary.
public struct WindowedSearchAdapter: SearchAdapter {
    public let wrapped: any DatedSearchAdapter
    public let windowDays: Int
    public let now: @Sendable () -> Date
    public let ledger: NewsRecencyLedger
    /// The question the run is answering. Its content terms decide which
    /// in-window results are on topic. Empty means relevance is not applied.
    public let question: String

    public init(
        wrapped: any DatedSearchAdapter,
        windowDays: Int,
        ledger: NewsRecencyLedger = NewsRecencyLedger(),
        question: String = "",
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.wrapped = wrapped
        self.windowDays = windowDays
        self.ledger = ledger
        self.question = question
        self.now = now
    }

    public func search(_ query: String) async throws -> SearchOutcome {
        let dated: [DatedHit]
        do {
            dated = try await wrapped.searchDated(query)
        } catch is CancellationError {
            throw CancellationError()
        }
        let decision = NewsRecency.apply(dated, windowDays: windowDays, now: now())
        ledger.record(decision, kept: dated.filter { entry in
            decision.kept.contains(where: { $0.id == entry.hit.id })
        })
        // The frozen window runs first; topical relevance is a refinement of
        // what it kept, so a result outside the window is never resurrected by
        // being on topic.
        let items = decision.kept.map(NewsRelevantItem.init)
        let relevant = NewsRelevance.apply(items, question: question)
        if !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ledger.recordRelevance(relevant)
        }
        let keptIDs = Set(relevant.kept.map(\.id))
        let keptHits = decision.kept.filter { keptIDs.contains($0.id) }
        return keptHits.isEmpty ? .noResults(query: query) : .hits(keptHits)
    }
}
