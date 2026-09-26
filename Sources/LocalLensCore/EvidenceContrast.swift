import Foundation

/// A deterministic lexicon for the scaffold dimensions the planner emits.
///
/// Coverage used to match the dimension's own label, which is measurably wrong
/// for Deep's generic scaffold: a passage that discusses advantages and costs
/// never contains the word "Tradeoffs", so the run reported `Tradeoffs · 0` and
/// spent a follow-up round on a gap that did not exist.
///
/// This is a fixed word list in code, not a model, and it is used only for
/// grouping and for generating follow-up queries. It never decides whether a
/// claim is supported: that remains an exact stored passage.
public enum DimensionLexicon {
    /// Extra match terms for a dimension. A user's own dimension still matches
    /// on its label and on its content terms, so an unlisted dimension is not
    /// silently uncovered.
    public static func terms(for dimension: String) -> [String] {
        // A dimension with a fixed vocabulary matches on its strong terms; a
        // custom dimension matches on its own content terms. Both paths run
        // through the whole-word rule, so neither can match by accident.
        let vocabulary = strongTerms(for: dimension)
        if !vocabulary.isEmpty { return vocabulary }
        return QuickQueryPlanner.contentTerms(of: dimension)
    }

    /// True when a passage's text satisfies a dimension.
    ///
    /// Two corrections came from a live four-mode run that measured keyword
    /// coincidence counted as coverage:
    ///
    /// 1. Matching is whole-word. Substring matching let the term `20` mark any
    ///    passage containing a year as timeline evidence (`Timeline · 16`), and
    ///    let `cost` match `costly`, `benefit` match `benefited`, and so on.
    /// 2. A single weak term is no longer enough. `however`, `remains`, and
    ///    `may` are legitimate gap vocabulary but appear in ordinary prose, so a
    ///    dimension counts as covered on one strong term or on two *distinct*
    ///    weak terms. Measured effect: the same Deep question that reported
    ///    `Gaps · 2` on one "however" reported `Gaps · 0`.
    ///
    /// A user's own dimension still matches on its own words, so an unlisted
    /// dimension is never silently uncovered. Over-counting coverage only means
    /// the runner stops looking, which is why the weaker rule was the original
    /// choice; the four-mode run showed that the false-positive direction has a
    /// cost too, because it reports a gap as addressed.
    public static func covers(_ dimension: String, text: String) -> Bool {
        let haystack = text.lowercased()
        if wordMatch(dimension.lowercased(), in: haystack) { return true }
        let strong = strongTerms(for: dimension)
        let weak = weakTerms(for: dimension)
        if strong.contains(where: { wordMatch($0, in: haystack) }) { return true }
        return weak.filter { wordMatch($0, in: haystack) }.count >= 2
    }

    /// Terms that carry a dimension on their own.
    public static func strongTerms(for dimension: String) -> [String] {
        let key = key(for: dimension)
        if neutral.contains(key) { return [] }
        if let fixed = strong[key] { return fixed }
        return QuickQueryPlanner.contentTerms(of: dimension)
    }

    /// Terms that are suggestive rather than decisive: present in the general
    /// vocabulary of the subject, so two of them are required.
    public static func weakTerms(for dimension: String) -> [String] {
        let key = key(for: dimension)
        return weak[key] ?? []
    }

    private static func words(_ text: String) -> [String] {
        text.split { !($0.isLetter || $0.isNumber) }.map(String.init)
    }

    /// Whole-word containment, so `20` cannot match `2026` and `cost` cannot
    /// match `costly`. A multi-word term matches as a phrase.
    public static func wordMatch(_ term: String, in haystack: String) -> Bool {
        NewsRelevance.containsTerm(term, in: haystack)
    }

    private static func key(for dimension: String) -> String {
        dimension
            .lowercased()
            .split(whereSeparator: { !($0.isLetter || $0.isNumber) })
            .joined(separator: " ")
    }

    /// Dimensions whose coverage is decided by the question's own words rather
    /// than a fixed vocabulary.
    private static let neutral: Set<String> = ["answer"]

    private static let strong: [String: [String]] = [
        "answer": [],
        "overview": ["overview", "introduction", "background", "summary", "overall", "how it works", "in short"],
        "evidence": [
            "evidence", "study", "studies", "research", "experiment", "benchmark", "measurement",
            "measured", "data", "finding", "findings", "result", "results", "report", "analysis",
        ],
        "tradeoffs": [
            "tradeoff", "tradeoffs", "trade-off", "trade-offs", "drawback", "drawbacks", "downside",
            "downsides", "advantage", "advantages", "disadvantage", "disadvantages", "benefit",
            "benefits", "cost", "costs", "limitation", "limitations", "compromise",
        ],
        "gaps": ["gap", "gaps", "open question", "open questions", "no evidence", "unknown", "unresolved"],
        "findings": [
            "finding", "findings", "result", "results", "measured", "we found", "observed",
            "increase", "decrease", "improvement", "effect",
        ],
        "method": [
            "method", "methods", "methodology", "participants", "procedure", "randomized",
            "randomised", "sample", "dataset", "protocol", "experiment",
        ],
        "limitations": [
            "limitation", "limitations", "caveat", "caveats", "small sample", "not significant",
            "generaliz", "generalis",
        ],
        "what happened": [
            "announced", "said", "effective", "became", "entered into force", "approved", "ruled",
            "launched", "published", "reported", "confirmed", "signed", "agreed",
        ],
        "timeline": [
            "timeline", "deadline", "deadlines", "schedule", "january", "february", "march", "april",
            "may", "june", "july", "august", "september", "october", "november", "december",
        ],
        "independent confirmation": [
            "independently", "independent", "corroborated", "corroboration", "second source",
            "second outlet", "also reported", "also reports", "confirmed by", "concurrent reporting",
        ],
    ]

    /// Weak vocabulary: real signals of the dimension, but common enough in
    /// ordinary prose that one occurrence proves nothing. Two distinct terms
    /// are required, and the dead terms the four-mode run caught are gone.
    private static let weak: [String: [String]] = [
        "gap": ["however", "unknown", "unclear", "remains", "remain", "missing", "future work", "not addressed"],
        "gaps": ["however", "unknown", "unclear", "remains", "remain", "missing", "future work", "not addressed"],
        "limitation": ["however", "cannot", "did not", "further work", "future work"],
        "limitations": ["however", "cannot", "did not", "further work", "future work"],
        "timeline": ["date", "dates", "when", "since", "until", "from", "between", "before", "after"],
        "method": ["design", "measured using", "we recruited", "session", "condition", "conditions"],
    ]
}

/// A numeric disagreement between two stored passages.
///
/// This is the only contradiction this repository can detect honestly without a
/// model: two pages stating a different value for the same measured context.
/// It never averages the values and never picks a winner. The surface shows both
/// passages and both numbers.
public struct EvidenceContradiction: Equatable, Sendable, Identifiable {
    public let id: String
    /// The shared context, normalised, that both passages quantify.
    public let context: String
    public let leftPassageID: String
    public let leftSnapshotID: String
    public let leftValue: String
    public let leftSentence: String
    public let rightPassageID: String
    public let rightSnapshotID: String
    public let rightValue: String
    public let rightSentence: String
}

/// Deterministic extraction and pairing of numbers stated inside a sentence.
public enum ContradictionScan {
    /// A number with the context words it quantifies.
    public struct NumericClaim: Equatable, Sendable {
        public let value: String
        public let context: String
        /// The words the value quantifies ("write transaction second"). A value
        /// with no unit is a date or a reference, not a measurement.
        public let units: [String]
        public let sentence: String
    }

    private static let contextStopWords: Set<String> = [
        "the", "a", "an", "of", "to", "in", "on", "for", "and", "or", "is", "are", "was", "were",
        "be", "by", "with", "at", "as", "it", "its", "this", "that", "these", "those", "than",
        "then", "from", "into", "about", "more", "most", "less", "least", "up", "down", "also",
        "which", "while", "when", "where", "how", "what", "can", "could", "may", "might", "not",
    ]

    /// Numbers with the context they quantify.
    ///
    /// A four-digit value is not special-cased out as a year: two pages that
    /// state a different effective year for the same rule genuinely disagree,
    /// and the surface labels these as numbers to check rather than as findings.
    /// The `context.count >= 2` rule is what keeps a stray "5" out.
    public static func claims(in text: String) -> [NumericClaim] {
        var found: [NumericClaim] = []
        for sentence in sentences(of: text) {
            let words = sentence.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            for (index, word) in words.enumerated() {
                guard let value = numericValue(word) else { continue }
                let context = contextWords(words: words, valueIndex: index)
                guard !context.isEmpty else { continue }
                found.append(NumericClaim(
                    value: value,
                    context: context.joined(separator: " "),
                    units: context,
                    sentence: sentence
                ))
            }
        }
        return found
    }

    private static func numericValue(_ word: String) -> String? {
        let cleaned = word.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?()[]\"'“”"))
        guard !cleaned.isEmpty else { return nil }
        // Reject a number that is part of an identifier or a version string.
        guard cleaned.allSatisfy({ $0.isNumber || $0 == "." || $0 == "%" || $0 == "," }) else { return nil }
        let digits = cleaned.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: "%", with: "")
        guard !digits.isEmpty, Double(digits) != nil else { return nil }
        guard digits.contains(where: { $0.isNumber }) else { return nil }
        return digits
    }

    /// Words that point at a numbered artefact rather than quantify one:
    /// "section 4", "Figure 2", and "step 3" are references, not measurements.
    private static let referenceWords: Set<String> = [
        "section", "figure", "fig", "table", "chapter", "page", "step", "footnote",
        "appendix", "version", "part", "ref", "reference", "note", "item", "rule",
        "article", "clause", "exhibit", "listing", "equation", "line",
    ]

    /// The words a value quantifies: the nearest content words before it and the
    /// unit-ish words after it. A shared context means two pages are talking
    /// about the same thing.
    private static func contextWords(words: [String], valueIndex: Int) -> [String] {
        var before: [String] = []
        var index = valueIndex - 1
        while index >= 0, before.count < 4 {
            let word = normalise(words[index])
            if !word.isEmpty, !contextStopWords.contains(word) {
                before.insert(word, at: 0)
            }
            index -= 1
        }
        var after: [String] = []
        index = valueIndex + 1
        while index < words.count, after.count < 3 {
            let word = normalise(words[index])
            if !word.isEmpty, !contextStopWords.contains(word), numericValue(words[index]) == nil {
                after.append(word)
            }
            index += 1
        }
        let quantifiers = before.filter { !referenceWords.contains($0) && $0.count > 1 }
        let units = after.filter { $0.count > 1 }
        let context = quantifiers + units
        // A pointer such as "section 4" leaves at most one word behind, and one
        // lone word is too weak to call a disagreement.
        guard context.count >= 2 else { return [] }
        return context
    }

    private static func normalise(_ word: String) -> String {
        let lowered = word.lowercased()
        // Strip a short plural so "passages" and "passage" share a context.
        if lowered.count > 4, lowered.hasSuffix("s") { return String(lowered.dropLast()) }
        return lowered.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?()[]\"'“”"))
    }

    /// Sentences of a passage, whitespace-collapsed. No language model, no
    /// sentence splitting beyond terminal punctuation followed by a space.
    public static func sentences(of text: String) -> [String] {
        var sentences: [String] = []
        var current = ""
        let characters = Array(text)
        var index = 0
        while index < characters.count {
            let character = characters[index]
            current.append(character)
            let isTerminator = character == "." || character == "!" || character == "?"
            let nextIsBoundary = index + 1 >= characters.count
                || (characters[index + 1] == " " || characters[index + 1] == "\n")
            if isTerminator, nextIsBoundary {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { sentences.append(trimmed) }
                current = ""
            }
            index += 1
        }
        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { sentences.append(tail) }
        return sentences
    }

    /// Content terms of a sentence, for the shared-context test. The whole
    /// sentence vocabulary, not the four words before a number, is what two
    /// pages describing the same measurement actually share.
    public static func contextTerms(of sentence: String) -> Set<String> {
        var terms: Set<String> = []
        for word in sentence.split(whereSeparator: { $0.isWhitespace }) {
            let normalised = normalise(String(word))
            guard normalised.count > 1, !contextStopWords.contains(normalised) else { continue }
            guard numericValue(String(word)) == nil else { continue }
            terms.insert(normalised)
        }
        return terms
    }

    /// True when a bare four-digit value is likely a year rather than a
    /// measurement. Measured numbers almost always carry a unit, so a year is
    /// only treated as a measurement when the sentence also carries unit words.
    public static func looksLikeYear(_ value: String, sentence: String) -> Bool {
        guard value.count == 4, let number = Double(value), (1500...2200).contains(number) else { return false }
        // A citation list such as "(Bjork, 1999; Karpicke, 2006)" is not a claim
        // about a measured year.
        let years = sentences(of: sentence)
            .flatMap { $0.split(whereSeparator: { $0.isWhitespace }) }
            .compactMap { numericValue(String($0)) }
            .filter { $0.count == 4 }
        return years.count >= 2
    }

    /// Pairs two pages that state a different value for the *same* context
    /// words, in this order.
    ///
    /// This rule is deliberately strict, and that is a measured decision. Two
    /// looser variants were implemented and run against live pages: matching on
    /// shared sentence terms produced pairs such as `2000, 2005, 2006` against
    /// `1978` drawn from citation lists, and requiring only a shared unit word
    /// still produced pairs such as "after" and "memory" joining unrelated
    /// numbers. Neither is a contradiction, and a surface that showed them would
    /// be asserting something the evidence does not say. The strict rule found
    /// no pair on four live runs; an empty contrast panel is the honest result.
    ///
    /// Conditions: the context words are identical; the passages come from
    /// different pages; the values differ; and a four-digit value is not a year
    /// inside a citation list. Ordering is deterministic.
    public static func contradictions(
        passages: [Passage],
        records: [SnapshotRecord]
    ) -> [EvidenceContradiction] {
        struct Stated {
            let passage: Passage
            let claim: NumericClaim
        }
        var byContext: [String: [Stated]] = [:]
        for passage in passages {
            for claim in claims(in: passage.text) {
                guard !claim.units.isEmpty else { continue }
                guard !looksLikeYear(claim.value, sentence: claim.sentence) else { continue }
                byContext[claim.context, default: []].append(Stated(passage: passage, claim: claim))
            }
        }
        var found: [EvidenceContradiction] = []
        for (context, entries) in byContext {
            guard entries.count > 1 else { continue }
            let ordered = entries.sorted { left, right in
                if left.passage.id != right.passage.id { return left.passage.id < right.passage.id }
                return left.claim.value < right.claim.value
            }
            for leftIndex in ordered.indices {
                for rightIndex in ordered.indices where rightIndex > leftIndex {
                    let left = ordered[leftIndex]
                    let right = ordered[rightIndex]
                    guard left.passage.snapshotID != right.passage.snapshotID else { continue }
                    guard left.claim.value != right.claim.value else { continue }
                    let id = StableIdentity.make(
                        "contradiction",
                        context,
                        left.passage.id,
                        left.claim.value,
                        right.passage.id,
                        right.claim.value
                    )
                    found.append(EvidenceContradiction(
                        id: id,
                        context: context,
                        leftPassageID: left.passage.id,
                        leftSnapshotID: left.passage.snapshotID,
                        leftValue: left.claim.value,
                        leftSentence: left.claim.sentence,
                        rightPassageID: right.passage.id,
                        rightSnapshotID: right.passage.snapshotID,
                        rightValue: right.claim.value,
                        rightSentence: right.claim.sentence
                    ))
                }
            }
        }
        return found.sorted { left, right in
            if left.context != right.context { return left.context < right.context }
            if left.leftPassageID != right.leftPassageID { return left.leftPassageID < right.leftPassageID }
            return left.rightPassageID < right.rightPassageID
        }
    }
}
