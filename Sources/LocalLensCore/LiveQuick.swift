import Foundation

// MARK: - Answer provider boundary

/// The selected, attributed passages sent to one answer provider.
///
/// The request carries no URL and no snippet: the provider sees only stored
/// passages, so it cannot be handed a search hit as evidence.
public struct AnswerRequest: Equatable, Sendable {
    public let question: String
    public let passages: [Passage]
    /// The mode the answer is being built for. It reaches the provider as an
    /// instruction only; it cannot loosen the citation boundary, which stays
    /// exact-substring-over-stored-passage for every mode.
    public let mode: ResearchMode
    /// The dimensions the provider should cover with atomic claims.
    public let dimensions: [String]

    public init(
        question: String,
        passages: [Passage],
        mode: ResearchMode = .quick,
        dimensions: [String] = ["Answer"]
    ) {
        self.question = question
        self.passages = passages
        self.mode = mode
        self.dimensions = dimensions
    }
}

/// One factual claim the provider proposes, citing a passage id and an exact
/// quote. Proposals are untrusted until verified against stored passages.
public struct ProposedClaim: Equatable, Sendable {
    public let text: String
    public let passageID: String
    public let quote: String

    public init(text: String, passageID: String, quote: String) {
        self.text = text
        self.passageID = passageID
        self.quote = quote
    }
}

public struct AnswerProposal: Equatable, Sendable {
    public let answer: String
    public let claims: [ProposedClaim]
    /// Observed usage when the provider reports it; `nil` means unmeasured.
    public let promptTokens: Int?
    public let completionTokens: Int?

    public init(
        answer: String,
        claims: [ProposedClaim],
        promptTokens: Int? = nil,
        completionTokens: Int? = nil
    ) {
        self.answer = answer
        self.claims = claims
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
    }
}

/// One explicitly labelled answer provider. This is the only new boundary the
/// live slice needs; it exists so a hosted provider can be swapped for a local
/// one without changing the runner.
public protocol QuickAnswerProvider: Sendable {
    func answer(_ request: AnswerRequest) async throws -> AnswerProposal
}

/// A deterministic provider for offline tests and for a no-provider run.
public struct FakeAnswerProvider: QuickAnswerProvider {
    public let proposal: AnswerProposal

    public init(proposal: AnswerProposal) {
        self.proposal = proposal
    }

    public func answer(_ request: AnswerRequest) async throws -> AnswerProposal {
        proposal
    }
}

// MARK: - Trusted proposal validation

/// A provider claim that named a known passage and whose quote is an exact
/// substring of that passage.
public struct AcceptedProposal: Equatable, Sendable {
    public let proposal: ProposedClaim
    public let passage: Passage

    public init(proposal: ProposedClaim, passage: Passage) {
        self.proposal = proposal
        self.passage = passage
    }
}

/// A provider claim that was refused, with the reason a reader can check.
public struct RejectedProposal: Equatable, Sendable {
    public let proposal: ProposedClaim
    public let reason: String

    public init(proposal: ProposedClaim, reason: String) {
        self.proposal = proposal
        self.reason = reason
    }
}

public struct AnswerValidation: Equatable, Sendable {
    public let accepted: [AcceptedProposal]
    public let rejected: [RejectedProposal]

    public init(accepted: [AcceptedProposal], rejected: [RejectedProposal]) {
        self.accepted = accepted
        self.rejected = rejected
    }
}

/// Provider output is untrusted. A claim is accepted only when it names a
/// passage in the selected set and its quote appears exactly in that passage;
/// nothing is repaired and no id is ever taken from the provider.
public enum AnswerTrust {
    public static func validate(_ proposal: AnswerProposal, passages: [Passage]) -> AnswerValidation {
        var byID: [String: Passage] = [:]
        for passage in passages {
            byID[passage.id] = passage
        }

        var accepted: [AcceptedProposal] = []
        var rejected: [RejectedProposal] = []
        for claim in proposal.claims {
            guard let passage = byID[claim.passageID] else {
                rejected.append(RejectedProposal(proposal: claim, reason: "unknown passage \(claim.passageID)"))
                continue
            }
            guard EvidenceText.isUsable(passage.text, heading: passage.heading) else {
                rejected.append(RejectedProposal(proposal: claim, reason: "passage is question-shaped, heading-only, or not readable answer evidence"))
                continue
            }
            let quote = claim.quote.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !quote.isEmpty else {
                rejected.append(RejectedProposal(proposal: claim, reason: "empty quote"))
                continue
            }
            guard quote.unicodeScalars.contains(where: { CharacterSet.alphanumerics.contains($0) }) else {
                rejected.append(RejectedProposal(proposal: claim, reason: "quote carries no readable content"))
                continue
            }
            // A question is not an answer. An exact quote of a question can
            // still be an exact substring, so this is checked before the
            // substring test: it is what stops a retrieved forum question from
            // being presented as if it supported a factual claim (Q2).
            guard !quote.hasSuffix("?") else {
                rejected.append(RejectedProposal(proposal: claim, reason: "quote is a question, not an answer"))
                continue
            }
            guard passage.text.contains(claim.quote) else {
                rejected.append(RejectedProposal(proposal: claim, reason: "quote is not an exact passage substring"))
                continue
            }
            accepted.append(AcceptedProposal(proposal: claim, passage: passage))
        }
        return AnswerValidation(accepted: accepted, rejected: rejected)
    }

    /// Turns accepted proposals into compiler candidates. The compiler still
    /// owns the retrieval and the final citation identity.
    public static func candidates(from validation: AnswerValidation) -> [ClaimCandidate] {
        validation.accepted.map { item in
            let dimension = "Answer"
            return ClaimCandidate(
                claim: Claim(
                    id: StableIdentity.make("claim", dimension, item.proposal.text),
                    dimension: dimension,
                    text: item.proposal.text
                ),
                retrievalQuery: item.proposal.quote,
                quote: item.proposal.quote,
                expectedSnapshotID: item.passage.snapshotID
            )
        }
    }
}

// MARK: - Limits

/// The frozen Quick caps. A runner that exceeds them refuses before it runs.
public struct LiveQuickLimits: Equatable, Sendable {
    public let searchQueries: Int
    public let openedSources: Int
    public let synthesisPassages: Int
    public let deadlineSeconds: Double
    /// The mode whose frozen policy this budget must not exceed. Defaults to
    /// Quick so the promoted M003 slice is byte-for-byte unchanged.
    public let mode: ResearchMode

    public static let quick = LiveQuickLimits(
        searchQueries: 2,
        openedSources: 6,
        synthesisPassages: 12,
        deadlineSeconds: 60
    )

    public init(
        searchQueries: Int,
        openedSources: Int,
        synthesisPassages: Int,
        deadlineSeconds: Double,
        mode: ResearchMode = .quick
    ) {
        self.searchQueries = searchQueries
        self.openedSources = openedSources
        self.synthesisPassages = synthesisPassages
        self.deadlineSeconds = deadlineSeconds
        self.mode = mode
    }

    /// The frozen policy for the mode, as the runner's budget.
    public static func forMode(_ mode: ResearchMode) -> LiveQuickLimits {
        let policy = ModePolicy.policy(for: mode)
        return LiveQuickLimits(
            searchQueries: policy.searchQueries,
            openedSources: policy.openedSources,
            synthesisPassages: policy.synthesisPassages,
            deadlineSeconds: policy.deadlineSeconds,
            mode: mode
        )
    }

    /// Kept under its historical name because the M003 tests and evidence use
    /// it. It now validates against the named mode's policy, so Quick keeps its
    /// original 2/6/12 ceiling and every later mode is bounded by its own.
    public var isWithinQuickCaps: Bool { isWithinModeCaps }

    public var isWithinModeCaps: Bool {
        let policy = ModePolicy.policy(for: mode)
        return (1...policy.searchQueries).contains(searchQueries)
            && (1...policy.openedSources).contains(openedSources)
            && (1...policy.synthesisPassages).contains(synthesisPassages)
            && deadlineSeconds > 0
    }
}

// MARK: - Result

public struct LiveQuickObservation: Equatable, Sendable {
    public let searchQueries: Int
    public let openedSources: Int
    public let synthesisPassages: Int
    public let providerCalls: Int
    public let providerPromptTokens: Int?
    public let providerCompletionTokens: Int?

    public init(
        searchQueries: Int,
        openedSources: Int,
        synthesisPassages: Int,
        providerCalls: Int,
        providerPromptTokens: Int? = nil,
        providerCompletionTokens: Int? = nil
    ) {
        self.searchQueries = searchQueries
        self.openedSources = openedSources
        self.synthesisPassages = synthesisPassages
        self.providerCalls = providerCalls
        self.providerPromptTokens = providerPromptTokens
        self.providerCompletionTokens = providerCompletionTokens
    }
}

public struct LiveQuickResult: Equatable, Sendable {
    public let run: ResearchRun
    public let answer: String
    public let compilation: CitationCompilation
    public let accepted: [AcceptedProposal]
    public let rejected: [RejectedProposal]
    /// "hosted" or "local", recorded on every result so local and hosted work
    /// never merge.
    public let label: String
    public let observation: LiveQuickObservation
    /// Stored source records used to resolve a citation back to the actual
    /// fetched document URL. These are not search snippets.
    public let records: [SnapshotRecord]

    public init(
        run: ResearchRun,
        answer: String,
        compilation: CitationCompilation,
        accepted: [AcceptedProposal],
        rejected: [RejectedProposal],
        label: String,
        observation: LiveQuickObservation,
        records: [SnapshotRecord]
    ) {
        self.run = run
        self.answer = answer
        self.compilation = compilation
        self.accepted = accepted
        self.rejected = rejected
        self.label = label
        self.observation = observation
        self.records = records
    }
}

public enum LiveQuickOutcome: Error, Equatable, Sendable {
    case completed(LiveQuickResult)
    case abstained(reason: String)
    case failed(reason: String)
}

// MARK: - Retrieval-only result

public struct LiveRetrievalResult: Equatable, Sendable {
    public let question: String
    public let searchQueries: Int
    public let openedSources: Int
    public let passages: [Passage]
    public let records: [SnapshotRecord]
    public let fetchResults: [FetchResult]

    public init(
        question: String,
        searchQueries: Int,
        openedSources: Int,
        passages: [Passage],
        records: [SnapshotRecord],
        fetchResults: [FetchResult]
    ) {
        self.question = question
        self.searchQueries = searchQueries
        self.openedSources = openedSources
        self.passages = passages
        self.records = records
        self.fetchResults = fetchResults
    }
}

// MARK: - Runner

/// The live Quick composition. Search, fetch, and the answer provider are
/// injected, so the same runner is exercised offline with fakes and, once a
/// redirect-safe fetch transport exists, against the open web.
///
/// It enforces the Quick caps in code: at most two queries, six opened sources,
/// twelve synthesis passages, one deadline, and zero provider calls without
/// stored evidence.
public enum LiveQuickRunner {
    /// Search, bounded fetch, extraction, storage, indexing, and retrieval,
    /// with no provider call. This is the offline-verifiable half of the slice
    /// and the live executable's retrieval mode.
    public static func retrieve(
        question: String,
        queries: [String],
        retrievalQueries: [String]? = nil,
        limits: LiveQuickLimits = .quick,
        deadline: Date,
        search: @Sendable (String) async throws -> SearchOutcome,
        store: SnapshotStore,
        fetch: @Sendable ([FetchTarget]) async throws -> [FetchResult]
    ) async -> Result<LiveRetrievalResult, LiveQuickOutcome> {
        switch await prepare(
            question: question,
            queries: queries,
            retrievalQueries: retrievalQueries,
            limits: limits,
            deadline: deadline,
            search: search,
            store: store,
            fetch: fetch
        ) {
        case let .success(prepared):
            return .success(
                LiveRetrievalResult(
                    question: question,
                    searchQueries: prepared.searchQueries,
                    openedSources: prepared.opened,
                    passages: prepared.passages,
                    records: prepared.records,
                    fetchResults: prepared.fetchResults
                )
            )
        case let .failure(outcome):
            return .failure(outcome)
        }
    }

    public static func run(
        question: String,
        queries: [String],
        retrievalQueries: [String]? = nil,
        limits: LiveQuickLimits = .quick,
        deadline: Date,
        search: @Sendable (String) async throws -> SearchOutcome,
        store: SnapshotStore,
        fetch: @Sendable ([FetchTarget]) async throws -> [FetchResult],
        provider: any QuickAnswerProvider,
        label: String,
        runID: String = "live-quick"
    ) async -> LiveQuickOutcome {
        let prepared: Prepared
        switch await prepare(
            question: question,
            queries: queries,
            retrievalQueries: retrievalQueries,
            limits: limits,
            deadline: deadline,
            search: search,
            store: store,
            fetch: fetch
        ) {
        case let .failure(outcome):
            return outcome
        case let .success(value):
            prepared = value
        }

        if Date() >= deadline { return .abstained(reason: "deadline exceeded before the provider") }
        guard !prepared.passages.isEmpty else {
            return .abstained(reason: "no usable retrieved evidence")
        }

        return await answerAndCompile(
            question: question,
            mode: .quick,
            dimensions: ["Answer"],
            passages: prepared.passages,
            index: prepared.index,
            provider: provider,
            label: label,
            runID: runID,
            searchQueries: prepared.searchQueries,
            openedSources: prepared.opened,
            records: prepared.records
        )
    }

    /// The shared provider-to-citation half of every mode.
    ///
    /// It is the trust boundary: the provider sees only selected, attributed
    /// passages; proposals are validated against exact stored text; each claim
    /// is probe-compiled alone so one ambiguity cannot erase an independent
    /// claim; and the answer is assembled from accepted claims only. Every mode
    /// calls this, so Deep, Academic, and News cannot loosen it.
    public static func answerAndCompile(
        question: String,
        mode: ResearchMode,
        dimensions: [String],
        passages: [Passage],
        index: LexicalIndex,
        provider: any QuickAnswerProvider,
        label: String,
        runID: String,
        searchQueries: Int,
        openedSources: Int,
        records: [SnapshotRecord]
    ) async -> LiveQuickOutcome {
        if Task.isCancelled { return .failed(reason: "cancelled") }
        guard !passages.isEmpty else { return .abstained(reason: "no usable retrieved evidence") }

        // The provider sees only the selected, attributed passages.
        let proposal: AnswerProposal
        do {
            proposal = try await provider.answer(
                AnswerRequest(question: question, passages: passages, mode: mode, dimensions: dimensions)
            )
        } catch is CancellationError {
            return .failed(reason: "cancelled")
        } catch let error as QuickProviderError {
            return .failed(reason: "provider failed: \(error.reason)")
        } catch {
            return .failed(reason: "provider failed: \(error)")
        }

        // Untrusted proposals are verified here, then compiled by the existing
        // citation boundary.
        let validation = AnswerTrust.validate(proposal, passages: passages)
        guard !validation.accepted.isEmpty else {
            return .abstained(reason: "the provider proposed no verifiable claim")
        }
        // One ambiguous claim must not erase independently supportable claims.
        // Probe each candidate through the unchanged compiler and retain only
        // candidates that compile alone; the final batch is compiled again as
        // one validated result. Nothing ambiguous is displayed or repaired.
        var compilable: [AcceptedProposal] = []
        var rejected = validation.rejected
        var seenClaimIDs: Set<String> = []
        for item in validation.accepted {
            let candidate = AnswerTrust.candidates(from: AnswerValidation(accepted: [item], rejected: []))[0]
            guard seenClaimIDs.insert(candidate.claim.id).inserted else {
                rejected.append(RejectedProposal(proposal: item.proposal, reason: "duplicate claim"))
                continue
            }
            do {
                _ = try await CitationCompiler.compile(candidates: [candidate], index: index)
                compilable.append(item)
            } catch let error as CitationCompilerError {
                rejected.append(RejectedProposal(proposal: item.proposal, reason: "citation refused: \(error.kind)"))
            } catch {
                return .failed(reason: "citation compilation failed: \(error)")
            }
        }
        guard !compilable.isEmpty else {
            return .abstained(reason: "the provider proposed no unambiguous cited claim")
        }
        let candidates = AnswerTrust.candidates(from: AnswerValidation(accepted: compilable, rejected: []))
        let compilation: CitationCompilation
        do {
            compilation = try await CitationCompiler.compile(candidates: candidates, index: index)
        } catch {
            return .failed(reason: "citation compilation failed: \(error)")
        }

        var run = ResearchRun(id: runID, question: question, mode: mode)
        run.status = .complete
        return .completed(
            LiveQuickResult(
                run: run,
                answer: Self.assembleAnswer(compilation),
                compilation: compilation,
                accepted: compilable,
                rejected: rejected,
                label: label,
                observation: LiveQuickObservation(
                    searchQueries: searchQueries,
                    openedSources: openedSources,
                    synthesisPassages: passages.count,
                    providerCalls: 1,
                    providerPromptTokens: proposal.promptTokens,
                    providerCompletionTokens: proposal.completionTokens
                ),
                records: records
            )
        )
    }

    /// The user-facing answer is assembled only from accepted claims that
    /// compiled to a resolvable citation, each with a visible marker. The
    /// model's free prose is deliberately discarded: a sentence that is not a
    /// checked claim must never appear as if it were sourced. Because the
    /// markers follow the compilation's order, `[n]` resolves to
    /// `compilation.citations[n - 1]`.
    static func assembleAnswer(_ compilation: CitationCompilation) -> String {
        var spans: [String] = []
        for (index, citation) in compilation.citations.enumerated() {
            guard let resolved = try? compilation.resolve(citation.id) else { continue }
            let text = resolved.claim.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            spans.append("\(text) [\(index + 1)]")
        }
        return spans.joined(separator: " ")
    }

    // MARK: Shared preparation

    private struct Prepared {
        let searchQueries: Int
        let opened: Int
        let passages: [Passage]
        let records: [SnapshotRecord]
        let fetchResults: [FetchResult]
        let index: LexicalIndex
    }

    private static func prepare(
        question: String,
        queries: [String],
        retrievalQueries: [String]?,
        limits: LiveQuickLimits,
        deadline: Date,
        search: @Sendable (String) async throws -> SearchOutcome,
        store: SnapshotStore,
        fetch: @Sendable ([FetchTarget]) async throws -> [FetchResult]
    ) async -> Result<Prepared, LiveQuickOutcome> {
        func expired() -> Bool { Date() >= deadline }

        guard limits.isWithinQuickCaps else {
            return .failure(.failed(reason: "limits exceed the frozen Quick caps"))
        }
        guard !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(.failed(reason: "empty question"))
        }
        // Web search and lexical retrieval want different query shapes. Search
        // is handed the natural-language question by the callers; the index is
        // handed the keyword windows derived from the question. When a caller
        // supplies no retrieval queries, the search queries are reused, which
        // preserves the earlier single-query tests unchanged.
        let effectiveQueries = Array(queries.prefix(limits.searchQueries))
        let effectiveRetrievalQueries = Array((retrievalQueries ?? queries).prefix(limits.searchQueries))
        guard !effectiveQueries.isEmpty else {
            return .failure(.failed(reason: "no search queries"))
        }
        guard !effectiveRetrievalQueries.isEmpty else {
            return .failure(.failed(reason: "no retrieval queries"))
        }
        if expired() { return .failure(.abstained(reason: "deadline exceeded before search")) }

        var hits: [SearchHit] = []
        do {
            for query in effectiveQueries {
                if expired() { return .failure(.abstained(reason: "deadline exceeded during search")) }
                switch try await search(query) {
                case let .hits(found):
                    hits.append(contentsOf: found)
                case .noResults:
                    continue
                }
            }
        } catch is CancellationError {
            return .failure(.failed(reason: "cancelled"))
        } catch {
            return .failure(.failed(reason: "search failed: \(error)"))
        }

        var seenURLs: Set<String> = []
        var targets: [FetchTarget] = []
        // Open official documentation and project forums before general blogs.
        // The ordering is deterministic and preserves the search engine's order
        // within each tier; it changes discovery only, never citation evidence.
        for hit in SourceAuthority.ordered(hits) {
            guard let scheme = hit.url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { continue }
            if seenURLs.insert(hit.url.absoluteString).inserted {
                targets.append(
                    FetchTarget(
                        sourceID: StableIdentity.make("source", hit.url.absoluteString),
                        url: hit.url
                    )
                )
            }
            if targets.count >= limits.openedSources { break }
        }
        guard !targets.isEmpty else {
            return .failure(.abstained(reason: "no openable search hits"))
        }

        let results: [FetchResult]
        do {
            results = try await fetch(targets)
        } catch is CancellationError {
            return .failure(.failed(reason: "cancelled"))
        } catch {
            return .failure(.failed(reason: "fetch schedule failed: \(error)"))
        }
        let opened = results.filter { $0.outcome.record != nil }.count
        guard opened > 0, await store.snapshotCount() > 0 else {
            return .failure(.abstained(reason: "no readable evidence"))
        }
        if expired() { return .failure(.abstained(reason: "deadline exceeded after fetch")) }

        let policy: LexicalQueryPolicy
        do {
            policy = try LexicalQueryPolicy(
                maximumResults: limits.synthesisPassages,
                // The two-per-source diversity cap is useful when several
                // documents opened. On a user-supplied single page it can
                // discard every answer paragraph behind two highly ranked
                // question paragraphs before evidence hygiene runs.
                maximumPassagesPerSource: opened == 1 ? limits.synthesisPassages : 2,
                maximumCandidates: max(200, limits.synthesisPassages)
            )
        } catch {
            return .failure(.failed(reason: "invalid retrieval policy: \(error)"))
        }
        let index: LexicalIndex
        let records = await store.records()
        do {
            index = try LexicalIndex(policy: policy)
            for record in records {
                _ = try await index.ingest(record)
            }
        } catch {
            return .failure(.failed(reason: "index unavailable: \(error)"))
        }

        // Retrieve per search query and union the passages, capped at
        // `synthesisPassages`. The search queries are keyword-shaped, so they
        // retrieve better than a natural-language question under an AND match.
        var passages: [Passage] = []
        var seenPassageIDs: Set<String> = []
        func collect(_ found: [IndexedHit]) {
            for hit in found where seenPassageIDs.insert(hit.passage.id).inserted {
                // A heading match surfaces the whole row, and `LexicalIndex`
                // indexes a passage's heading and body together, so a
                // relevant heading can carry a body that is only a bullet,
                // a separator, or a navigation label. Such a body is not
                // evidence and must not consume the twelve-passage budget.
                guard EvidenceText.isUsable(hit.passage.text, heading: hit.passage.heading) else { continue }
                passages.append(hit.passage)
                if passages.count >= limits.synthesisPassages { break }
            }
        }
        do {
            for query in effectiveRetrievalQueries {
                collect(try await index.search(query))
                if passages.count >= limits.synthesisPassages { break }
            }
            // Fill any remaining synthesis budget with an any-term BM25 pass
            // over the same keyword queries. Strict windows are precise but
            // narrow: a question that needs two independent sources can open
            // six relevant pages and still strict-match one passage. The fill
            // is ranked, appended after the strict hits, and still filtered by
            // `EvidenceText`, so it widens recall without lowering the
            // precision floor. If even this finds no usable text, the run
            // abstains honestly.
            if passages.count < limits.synthesisPassages {
                for query in effectiveRetrievalQueries {
                    collect(try await index.searchAnyTerm(query))
                    if passages.count >= limits.synthesisPassages { break }
                }
            }
        } catch let error as LexicalIndexError where error.kind == "empty_query" {
            return .failure(.abstained(reason: "a search query has no retrievable term"))
        } catch {
            return .failure(.failed(reason: "retrieval failed: \(error)"))
        }
        return .success(
            Prepared(
                searchQueries: effectiveQueries.count,
                opened: opened,
                passages: passages,
                records: records,
                fetchResults: results,
                index: index
            )
        )
    }
}

// MARK: - Evidence text

/// Whether a retrieved passage carries enough readable text to serve as
/// evidence.
///
/// `LexicalIndex` indexes a passage's heading and body in one FTS5 row, so a
/// query whose terms all appear in the heading matches the row even when the
/// body is a bullet, a separator, or a navigation label. Those bodies are not
/// evidence: they must not consume the Quick synthesis budget, and a document
/// whose passages are all chrome must abstain rather than answer from chrome.
///
/// This inspects the passage text only; it never rewrites, merges, or
/// truncates it, so the exact stored text and its hash are unchanged.
enum EvidenceText {
    static func isUsable(_ raw: String, heading: String? = nil) -> Bool {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let heading,
           text.caseInsensitiveCompare(heading.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame {
            return false
        }
        var alphanumeric = 0
        for scalar in text.unicodeScalars where CharacterSet.alphanumerics.contains(scalar) {
            alphanumeric += 1
        }
        // A bullet, separator, or punctuation-only run carries no content.
        guard alphanumeric >= 3 else { return false }

        // A forum question can match a query perfectly while supplying no
        // answer. A purely interrogative passage must not take a scarce
        // synthesis slot away from a declarative reply. Keep mixed passages
        // that contain a sentence before the question.
        if let lastQuestion = text.lastIndex(of: "?") {
            let after = text[text.index(after: lastQuestion)...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if after.count < 20 { return false }
        }

        // A short, word-poor run is navigation chrome (`Using Swift`), not a
        // readable passage. Real prose or code carries at least a few words or
        // a longer alphanumeric run.
        var words = 0
        for word in text.split(whereSeparator: { $0.isWhitespace }) {
            if word.unicodeScalars.contains(where: { CharacterSet.alphanumerics.contains($0) }) {
                words += 1
            }
        }
        return words >= 3 || alphanumeric >= 16
    }
}
