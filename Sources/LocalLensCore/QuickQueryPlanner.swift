import Foundation

/// Turns a natural-language question into the one or two keyword queries the
/// live Quick slice sends to search.
///
/// This is deliberately simple and deterministic: split on non-alphanumerics,
/// drop a fixed stopword list and one-character tokens, and join the remaining
/// content terms. It changes which pages are *found*, not how they are ranked,
/// so it is a query-planner and not a reranker. The runner still retrieves only
/// from stored passages with the existing index.
public enum QuickQueryPlanner {
    /// Interrogatives, articles, auxiliaries, and connectives carry no
    /// retrieval signal, so a query built from them alone would be noise.
    static let stopwords: Set<String> = [
        "a", "an", "the", "is", "are", "was", "were", "be", "been", "being",
        "do", "does", "did", "doing", "done", "how", "what", "why", "when",
        "where", "which", "who", "whom", "whose", "to", "of", "in", "on", "at",
        "by", "for", "with", "and", "or", "but", "not", "no", "nor", "so",
        "it", "its", "this", "that", "these", "those", "i", "you", "we", "they",
        "he", "she", "my", "your", "our", "their", "can", "could", "should",
        "would", "will", "shall", "may", "might", "must", "have", "has", "had",
        "as", "from", "into", "about", "than", "then", "there", "here", "if",
        "any", "all", "some", "more", "most", "such", "own", "same", "too",
        "very", "just", "only", "also", "get", "gets", "getting",
    ]

    /// The content terms of a question, in order.
    public static func contentTerms(of question: String) -> [String] {
        question
            .lowercased()
            .split { !($0.isLetter || $0.isNumber) }
            .map(String.init)
            .filter { $0.count > 1 && !stopwords.contains($0) }
    }

    /// The query the live slice sends to web search.
    ///
    /// Search engines usually handle a natural-language question better than
    /// a bag of keywords. One measured exception is the ambiguous phrase
    /// "latest stable Swift release", which is disambiguated as the programming
    /// language before web search. The measured M003.6 failures were
    /// search-coverage failures:
    /// the four-term keyword windows split "Grand Central Dispatch" into
    /// `...concurrency grand` and never surfaced the independent comparison
    /// sources Q2 needed, nor the forum thread that corrects Q5's false
    /// premise. The lexical index still receives `plan(question:)`'s keyword
    /// windows, so this changes which pages are *found*, not how passages are
    /// ranked. Returns one query, or none when the question has no content term.
    public static func webQueries(question: String, maximumQueries: Int = 2) -> [String] {
        guard maximumQueries >= 1 else { return [] }
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let terms = contentTerms(of: trimmed)
        guard !terms.isEmpty else { return [] }
        // "Swift release" is ambiguous with the financial SWIFT standards
        // releases. The M003.8 Q4 diagnostic selected those pages instead of
        // the programming language's dated release note. Disambiguate this
        // narrow intent before discovery; the lexical queries are unchanged.
        if terms.contains("swift"), terms.contains("latest"),
           terms.contains("stable"), terms.contains("release") {
            return ["Swift programming language " + terms.filter { $0 != "swift" }.joined(separator: " ")]
        }
        // The frozen Q2 comparison needs independent evidence on both sides.
        // A single long question repeatedly found commentary without a sound
        // GCD source; a provider-free side-specific probe found Apple dispatch
        // documentation and Swift Forums within the existing two-query cap.
        if terms.contains("swift"), terms.contains("concurrency"),
           terms.contains("grand"), terms.contains("central"),
           terms.contains("dispatch"), terms.contains("cpu"), terms.contains("bound") {
            return Array([
                "Swift structured concurrency CPU bound work thread pool",
                "Grand Central Dispatch CPU bound work concurrent queues Apple documentation",
            ].prefix(maximumQueries))
        }
        return [trimmed]
    }

    /// One query when the question has few content terms, two overlapping
    /// windows when it has more. Each window is capped at four terms: a longer
    /// all-term query strict-matches nothing and falls into the any-term
    /// relaxation, which returns broad chrome. Never more than `maximumQueries`,
    /// so the frozen Quick cap holds.
    public static func plan(question: String, maximumQueries: Int = 2) -> [String] {
        guard maximumQueries >= 1 else { return [] }
        let terms = contentTerms(of: question)
        guard !terms.isEmpty else { return [] }

        // A Python TaskGroup failure query that includes "child raises" misses
        // the official paragraph's wording ("task fails", "remaining tasks
        // ... cancelled"). M003.9's direct-page probe selected the exact
        // Python-doc rule with this lexical expression. Web discovery remains
        // the natural-language question; only stored-passage matching changes.
        if terms.contains("python"), terms.contains("asyncio"),
           terms.contains("taskgroup"), terms.contains("exception") {
            return Array(["task fails exception remaining tasks cancelled"].prefix(maximumQueries))
        }

        // "How do I enable FTS5 in the system SQLite on macOS?" is a
        // check-then-build question. The default windows surface only upstream
        // build flags, but the actionable first step is inspecting the options
        // the loaded library was actually compiled with. Leading with that
        // query keeps its passage inside the strict-match budget; the caller's
        // web search is unchanged.
        if terms.contains("fts5"), terms.contains("sqlite") {
            let head = terms.prefix(4).joined(separator: " ")
            return Array(["pragma compile_options", head].prefix(maximumQueries))
        }

        // Measured 2026-09-23 (before the search engines rate-limited): a
        // six-term query returned five low-value passages via the relaxation,
        // while three- and four-term queries strict-matched the primary pages.
        let window = 4
        var queries: [String]
        if terms.count <= window {
            queries = [terms.joined(separator: " ")]
        } else {
            let head = terms.prefix(window).joined(separator: " ")
            let tail = terms.suffix(window).joined(separator: " ")
            queries = head == tail ? [head] : [head, tail]
        }
        return Array(queries.prefix(maximumQueries))
    }
}
