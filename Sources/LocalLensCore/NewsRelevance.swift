import Foundation

/// Topical relevance for News discovery, and the depth of the claim set a News
/// run produced.
///
/// Both exist because a live four-mode run (2026-09-26) measured two News
/// defects that the frozen window does not address:
///
/// - The news index enforces recency, not relevance. A search for what changed
///   in the EU AI Act returned a stablecoin approval, a biodiversity brief, an
///   anti-deforestation story, and a commercial-vehicle brief, and some of them
///   reached the citations.
/// - The answer rested on three claims of which exactly one was carried by a
///   second independent voice, and nothing in the surface said the claim set
///   was thin, because the run opened ten domains and the independence line
///   reported ten.
///
/// Relevance is lexical and deterministic: the result's headline and snippet
/// must share a content term with the question. No model, no embedding, no
/// reranker. A term must match as a whole word, so "EUDR" is not a match for
/// "EU". When the filter would drop everything, it keeps everything and says so
/// rather than starving the run: a strict filter that silently returns no
/// results is the failure the window already produced once.
public enum NewsRelevance {

    /// The words a headline or snippet must share with the question to count as
    /// on topic.
    ///
    /// Two-character terms are kept only when the question wrote them as an
    /// acronym ("AI", "EU", "UK"), because no other two-letter token carries
    /// topic meaning.
    public static func questionTerms(of question: String) -> [String] {
        var seen = Set<String>()
        var terms: [String] = []
        for token in question.split(whereSeparator: { !($0.isLetter || $0.isNumber) }) {
            let lowered = token.lowercased()
            guard lowered.count > 1, !QuickQueryPlanner.stopwords.contains(lowered) else { continue }
            if lowered.count == 2 {
                // Keep a shouted acronym, drop a shouted stopword-like pair.
                guard token.count == 2, token.allSatisfy({ $0.isUppercase || $0.isNumber }) else { continue }
            }
            if seen.insert(lowered).inserted { terms.append(lowered) }
        }
        return terms
    }

    /// Whole-word, case-insensitive containment. Substring matching would match
    /// "eu" inside "european" only by accident and "eu" inside "eudr" wrongly.
    public static func containsTerm(_ term: String, in haystack: String) -> Bool {
        guard !term.isEmpty else { return false }
        let haystack = haystack.lowercased()
        var searchStart = haystack.startIndex
        while let found = haystack.range(of: term, range: searchStart..<haystack.endIndex) {
            let before = found.lowerBound == haystack.startIndex ? nil : haystack[haystack.index(before: found.lowerBound)]
            let after = found.upperBound == haystack.endIndex ? nil : haystack[found.upperBound]
            let isWord = { (character: Character?) -> Bool in
                guard let character else { return true }
                return !(character.isLetter || character.isNumber)
            }
            if isWord(before) && isWord(after) { return true }
            searchStart = found.upperBound
        }
        return false
    }

    /// A headline matches when it shares a phrase from the question, or two of
    /// the question's words, or one distinctive word.
    ///
    /// The first version kept any result that shared a single term, which made
    /// the filter useless on a real question: "What changed in the EU AI Act
    /// enforcement this month?" has the terms *month* and *act*, and a
    /// newsletter called "Content of the Month" matched on *month* while an
    /// item about "the AI space" matched on *ai*. A live run therefore measured
    /// zero drops. One word is only enough when the word itself is
    /// distinctive.
    public static func matches(title: String, snippet: String, terms: [String]) -> Bool {
        guard !terms.isEmpty else { return true }
        let haystack = title + " " + snippet
        let matched = terms.filter { containsTerm($0, in: haystack) }
        if matched.count >= 2 { return true }
        if adjacentPhrase(of: terms, in: haystack) { return true }
        return matched.contains { isDistinctive($0) }
    }

    /// Two question terms next to each other in the question, appearing next to
    /// each other in the result. "ai act" and "eu ai" are phrases; a lone "ai"
    /// is not.
    private static func adjacentPhrase(of terms: [String], in haystack: String) -> Bool {
        guard terms.count >= 2 else { return false }
        for index in 0..<(terms.count - 1) where containsTerm("\(terms[index]) \(terms[index + 1])", in: haystack) {
            return true
        }
        return false
    }

    /// A word carries the topic alone when it is long enough to be about
    /// something and is not part of the vocabulary of every news cycle.
    static func isDistinctive(_ term: String) -> Bool {
        term.count >= 5 && !commonWords.contains(term)
    }

    /// Words that appear in the headline of almost anything, so a single match
    /// on one of them says nothing about the subject.
    static let commonWords: Set<String> = [
        "about", "after", "again", "against", "ahead", "another", "around", "before",
        "being", "between", "could", "during", "every", "first", "found", "going",
        "issue", "large", "later", "latest", "major", "might", "month", "months",
        "more", "most", "much", "near", "news", "next", "other", "over", "report",
        "reports", "right", "same", "several", "should", "since", "small", "still",
        "such", "than", "that", "their", "there", "these", "they", "thing", "things",
        "this", "those", "three", "through", "today", "under", "until", "update",
        "updates", "using", "very", "week", "weeks", "well", "what", "when", "where",
        "which", "while", "will", "with", "within", "without", "would", "year",
        "years", "your", "change", "changed", "changes", "change",
    ]

    /// Splits discovery results into on-topic and off-topic, and refuses to
    /// starve the run.
    public static func apply(_ items: [NewsRelevantItem], question: String) -> NewsRelevanceDecision {
        let terms = questionTerms(of: question)
        guard !terms.isEmpty else {
            return NewsRelevanceDecision(kept: items, dropped: [], terms: [], isStarved: false)
        }
        let kept = items.filter { matches(title: $0.title, snippet: $0.snippet, terms: terms) }
        let dropped = items.filter { !matches(title: $0.title, snippet: $0.snippet, terms: terms) }
        if kept.isEmpty && !items.isEmpty {
            // Starvation guard: the mode's own query terms are not in the news
            // index's headline text for every legitimate story. Returning
            // nothing would be worse than returning something flagged.
            return NewsRelevanceDecision(kept: items, dropped: dropped, terms: terms, isStarved: true)
        }
        return NewsRelevanceDecision(kept: kept, dropped: dropped, terms: terms, isStarved: false)
    }
}

/// The parts of a discovery result that topical relevance needs. Kept separate
/// from `SearchHit` and `DatedHit` so the rule is testable without a transport.
public struct NewsRelevantItem: Equatable, Sendable {
    public let id: String
    public let title: String
    public let snippet: String
    public let domain: String

    public init(id: String, title: String, snippet: String, domain: String) {
        self.id = id
        self.title = title
        self.snippet = snippet
        self.domain = domain
    }

    public init(_ hit: SearchHit) {
        let host = hit.url.host ?? ""
        self.init(
            id: hit.id,
            title: hit.title,
            snippet: hit.snippet,
            domain: host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        )
    }

    public init(_ dated: DatedHit) {
        self.init(dated.hit)
    }
}

public struct NewsRelevanceDecision: Equatable, Sendable {
    public let kept: [NewsRelevantItem]
    public let dropped: [NewsRelevantItem]
    public let terms: [String]
    /// True when the filter would have dropped every result and the run kept
    /// them all instead. Shown, never hidden.
    public let isStarved: Bool

    public init(kept: [NewsRelevantItem], dropped: [NewsRelevantItem], terms: [String], isStarved: Bool) {
        self.kept = kept
        self.dropped = dropped
        self.terms = terms
        self.isStarved = isStarved
    }

    public var droppedCount: Int { dropped.count }

    /// Domains the filter removed, for the run's own account of what it did.
    public var droppedDomains: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for item in dropped where !item.domain.isEmpty {
            if seen.insert(item.domain).inserted { result.append(item.domain) }
        }
        return result
    }
}

/// How deep the claim set of a News answer is.
///
/// The mode promises independent confirmation. A run can open ten domains and
/// still produce a claim set that no second voice carries, which is exactly
/// what a live run measured: three claims, one of them confirmed. The count is
/// per claim, so the surface cannot report breadth where it has none.
public struct NewsClaimDepth: Equatable, Sendable {
    public let claimCount: Int
    /// Claims carried by two or more independent voices.
    public let confirmedClaimCount: Int
    public let maximumSupport: Int

    public init(claimCount: Int, confirmedClaimCount: Int, maximumSupport: Int) {
        self.claimCount = claimCount
        self.confirmedClaimCount = confirmedClaimCount
        self.maximumSupport = maximumSupport
    }

    /// A claim set with no confirmed claim is thin: every claim rests on the
    /// single outlet that published it.
    public var isThin: Bool { claimCount > 0 && confirmedClaimCount == 0 }

    public var summary: String {
        guard claimCount > 0 else { return "No claim survived the citation boundary." }
        if confirmedClaimCount == claimCount {
            return "Every one of the \(claimCount) claims is carried by at least two independent voices."
        }
        if confirmedClaimCount == 0 {
            return "Thin claim set: none of the \(claimCount) claims is carried by a second independent voice, so the answer is single-source throughout."
        }
        return "\(confirmedClaimCount) of \(claimCount) claims are carried by a second independent voice; the rest are single-source."
    }

    /// Evaluates per-claim voice counts, one entry per accepted claim, in
    /// citation order.
    public static func evaluate(support: [Int]) -> NewsClaimDepth {
        NewsClaimDepth(
            claimCount: support.count,
            confirmedClaimCount: support.filter { $0 >= 2 }.count,
            maximumSupport: support.max() ?? 0
        )
    }
}
