import Foundation

/// One completed multi-mode research run.
///
/// It wraps the unchanged `LiveQuickResult` (same trust boundary, same exact
/// citations) and adds only view-level facts: which dimensions the evidence
/// covered, how many independent domains backed it, and which dimensions
/// remained gaps. It never fabricates a claim or a citation.
/// Why a research loop stopped. Every run ends on exactly one of these, and a
/// round records the same value, so a stop is never inferred after the fact.
public enum ResearchLoopReason: String, Codable, Equatable, Sendable, CaseIterable {
    /// The round added evidence and an uncovered dimension was scheduled next.
    case followUpScheduled = "follow_up_scheduled"
    /// The mode's passage ceiling was reached.
    case evidenceSaturated = "evidence_saturated"
    /// The round stored no passage it had not already stored.
    case noNewEvidence = "no_new_evidence"
    /// Every declared dimension already has evidence.
    case dimensionsCovered = "dimensions_covered"
    /// The mode's bounded follow-up rounds are used up.
    case followUpBudgetExhausted = "follow_up_budget_exhausted"
    /// The plan had no further query to run.
    case queriesExhausted = "queries_exhausted"
    /// The mode's wall deadline passed.
    case deadlineReached = "deadline_reached"
    /// The first round stored nothing usable.
    case noEvidence = "no_evidence"
    case cancelled = "cancelled"
    /// A follow-up round added materially less than the round before it.
    case diminishingReturns = "diminishing_returns"

    public var explanation: String {
        switch self {
        case .followUpScheduled: "evidence added; an uncovered dimension was scheduled"
        case .evidenceSaturated: "reached the mode's passage ceiling"
        case .noNewEvidence: "the round stored nothing new"
        case .dimensionsCovered: "every dimension already had evidence"
        case .followUpBudgetExhausted: "the mode's follow-up rounds were used up"
        case .queriesExhausted: "the plan had no further query"
        case .deadlineReached: "the mode's deadline passed"
        case .noEvidence: "the first round stored nothing usable"
        case .cancelled: "cancelled"
        case .diminishingReturns: "the follow-up added materially less evidence than the round before it"
        }
    }
}

/// One executed round and the reason the loop continued or stopped after it.
public struct ResearchRoundRecord: Equatable, Sendable {
    public let index: Int
    public let queries: [String]
    public let addedPassages: Int
    public let reason: ResearchLoopReason

    public init(index: Int, queries: [String], addedPassages: Int, reason: ResearchLoopReason) {
        self.index = index
        self.queries = queries
        self.addedPassages = addedPassages
        self.reason = reason
    }
}

public struct ResearchReport: Equatable, Sendable {
    public let plan: ResearchPlan
    public let result: LiveQuickResult
    public let rounds: Int
    public let dimensionCoverage: [String: Int]
    public let newsClusters: [NewsSourceCluster]
    public let independentSourceCount: Int
    /// Independent voices: domains that published the same headline count once,
    /// so a syndicated wire report cannot look like two confirmations.
    public let newsVoices: [NewsIndependence.NewsVoice]
    /// Independent voices backing the page each snapshot came from, so a
    /// single-source claim can be shown as uncertain.
    public let newsSnapshotSupport: [String: Int]
    /// How deep the News claim set is: how many accepted claims a second
    /// independent voice carries. Present only for News; nil elsewhere.
    public let newsClaimDepth: NewsClaimDepth?
    public let gapDimensions: [String]
    /// One record per executed round, in order, each with its typed reason.
    public let roundLog: [ResearchRoundRecord]
    /// Why the loop stopped.
    public let stopReason: ResearchLoopReason
    /// Numeric disagreements between stored passages from different pages. They
    /// are shown side by side; they are never averaged or resolved.
    public let contradictions: [EvidenceContradiction]

    public init(
        plan: ResearchPlan,
        result: LiveQuickResult,
        rounds: Int,
        dimensionCoverage: [String: Int],
        newsClusters: [NewsSourceCluster],
        independentSourceCount: Int,
        newsVoices: [NewsIndependence.NewsVoice] = [],
        newsSnapshotSupport: [String: Int] = [:],
        newsClaimDepth: NewsClaimDepth? = nil,
        gapDimensions: [String],
        roundLog: [ResearchRoundRecord] = [],
        stopReason: ResearchLoopReason = .queriesExhausted,
        contradictions: [EvidenceContradiction] = []
    ) {
        self.plan = plan
        self.result = result
        self.rounds = rounds
        self.dimensionCoverage = dimensionCoverage
        self.newsClusters = newsClusters
        self.independentSourceCount = independentSourceCount
        self.newsVoices = newsVoices
        self.newsSnapshotSupport = newsSnapshotSupport
        self.newsClaimDepth = newsClaimDepth
        self.gapDimensions = gapDimensions
        self.roundLog = roundLog
        self.stopReason = stopReason
        self.contradictions = contradictions
    }
}

public enum ResearchOutcome: Error, Equatable, Sendable {
    case completed(ResearchReport)
    case abstained(reason: String)
    case failed(reason: String)
}

/// The generalized runner. Quick, Deep, Academic, and News all execute through
/// here; the only thing that changes between modes is the frozen `ModePolicy`
/// and `ResearchPlan`.
///
/// Deep performs bounded follow-up rounds: a round that leaves a declared
/// dimension uncovered is retried once with that dimension's query, up to the
/// policy's `followUpRounds`. Every round shares one `SnapshotStore`, so a
/// repeated page is deduplicated by content hash and cannot consume a second
/// slot. The provider-to-citation boundary is the shared
/// `LiveQuickRunner.answerAndCompile`, so no mode can weaken exact citations.
public enum ResearchRunner {
    public static func run(
        plan: ResearchPlan,
        deadline: Date,
        search: @Sendable (String) async throws -> SearchOutcome,
        store: SnapshotStore,
        fetch: @Sendable ([FetchTarget]) async throws -> [FetchResult],
        provider: any QuickAnswerProvider,
        label: String,
        runID: String = "research",
        pauseCheck: (@Sendable () async -> Void)? = nil
    ) async -> ResearchOutcome {
        let limits = LiveQuickLimits.forMode(plan.mode)
        guard plan.policy == ModePolicy.policy(for: plan.mode) else {
            return .failed(reason: "plan does not match the frozen \(plan.mode.rawValue) policy")
        }
        guard !plan.question.isEmpty else { return .failed(reason: "empty question") }
        guard !plan.searchQueries.isEmpty, !plan.retrievalQueries.isEmpty else {
            return .failed(reason: "no search queries")
        }

        var accumulated: [Passage] = []
        var seenPassageIDs: Set<String> = []
        var roundPassages: [String: [Passage]] = [:]
        var rounds = 0
        var lastRecords: [SnapshotRecord] = []
        var totalSearchQueries = 0
        var totalOpened = 0
        var pendingSearch = plan.searchQueries
        var pendingRetrieval = plan.retrievalQueries
        var roundLog: [ResearchRoundRecord] = []
        var stopReason = ResearchLoopReason.queriesExhausted

        for round in 0...(plan.policy.followUpRounds) {
            if Task.isCancelled { return .failed(reason: "cancelled") }
            await pauseCheck?()
            if Task.isCancelled { return .failed(reason: "cancelled") }
            if Date() >= deadline {
                roundLog.append(ResearchRoundRecord(index: round, queries: pendingSearch, addedPassages: 0, reason: .deadlineReached))
                stopReason = .deadlineReached
                break
            }
            if pendingSearch.isEmpty || pendingRetrieval.isEmpty {
                stopReason = .queriesExhausted
                break
            }

            rounds += 1
            var added: [Passage] = []
            // Exactly one typed reason is decided per round and appended once.
            var roundReason: ResearchLoopReason?
            let outcome = await LiveQuickRunner.retrieve(
                question: plan.question,
                queries: pendingSearch,
                retrievalQueries: pendingRetrieval,
                limits: limits,
                deadline: deadline,
                search: search,
                store: store,
                fetch: fetch
            )
            switch outcome {
            case let .success(retrieval):
                totalSearchQueries += retrieval.searchQueries
                totalOpened += retrieval.openedSources
                lastRecords = retrieval.records
                for passage in retrieval.passages where seenPassageIDs.insert(passage.id).inserted {
                    accumulated.append(passage)
                    added.append(passage)
                    if accumulated.count >= limits.synthesisPassages { break }
                }
                roundPassages["\(round)"] = added
                if accumulated.count >= limits.synthesisPassages {
                    roundReason = .evidenceSaturated
                }
            case let .failure(failure):
                switch failure {
                case .abstained:
                    // A round that finds nothing does not erase a prior round's
                    // evidence; if this was the first round it is terminal.
                    if accumulated.isEmpty, round == 0 {
                        return .abstained(reason: reasons(failure))
                    }
                case .failed:
                    if accumulated.isEmpty { return .failed(reason: reasons(failure)) }
                case .completed:
                    break
                }
                // A later round that stores nothing is not `noEvidence`: the run
                // already holds evidence, and the distinction matters to a
                // reader of the stop reason.
                if added.isEmpty, round == 0 { roundReason = .noEvidence }
            }

            if roundReason == nil {
                if added.isEmpty {
                    // A round that added no new passage cannot make the next
                    // round's identical follow-up queries succeed.
                    roundReason = .noNewEvidence
                } else if round >= plan.policy.followUpRounds {
                    roundReason = .followUpBudgetExhausted
                } else if let previous = roundLog.last?.addedPassages,
                          previous >= 4,
                          added.count * 2 <= previous {
                    // A follow-up that cannot add half of what the previous round
                    // added is not worth another bounded round.
                    roundReason = .diminishingReturns
                } else {
                    // Follow-ups are generated only for a declared dimension the
                    // evidence has not touched, so Deep cannot spam a query.
                    let coverage = coverage(for: plan.dimensions, passages: accumulated)
                    let gaps = plan.dimensions.filter { (coverage[$0] ?? 0) == 0 }
                    let followUps = followUpQueries(question: plan.question, dimensions: gaps, mode: plan.mode)
                    if followUps.isEmpty {
                        roundReason = .dimensionsCovered
                    } else {
                        roundReason = .followUpScheduled
                        pendingSearch = followUps
                        pendingRetrieval = followUps
                    }
                }
            }

            guard let reason = roundReason else { break }
            roundLog.append(ResearchRoundRecord(index: round, queries: pendingSearch, addedPassages: added.count, reason: reason))
            stopReason = reason
            if reason != .followUpScheduled { break }
        }

        guard !accumulated.isEmpty else {
            return .abstained(reason: "no usable retrieved evidence")
        }
        if Task.isCancelled {
            stopReason = .cancelled
            return .failed(reason: "cancelled")
        }
        await pauseCheck?()
        if Task.isCancelled { return .failed(reason: "cancelled") }
        if Date() >= deadline { return .abstained(reason: "deadline exceeded before the provider") }

        let passages = Array(accumulated.prefix(limits.synthesisPassages))
        let index: LexicalIndex
        do {
            let policy = try LexicalQueryPolicy(
                maximumResults: limits.synthesisPassages,
                maximumPassagesPerSource: totalOpened <= 1 ? limits.synthesisPassages : 3,
                maximumCandidates: max(400, limits.synthesisPassages * 20)
            )
            index = try LexicalIndex(policy: policy)
            let records = lastRecords.isEmpty ? await store.records() : lastRecords
            for record in records {
                _ = try await index.ingest(record)
            }
        } catch {
            return .failed(reason: "index unavailable: \(error)")
        }

        let answer = await LiveQuickRunner.answerAndCompile(
            question: plan.question,
            mode: plan.mode,
            dimensions: plan.dimensions,
            passages: passages,
            index: index,
            provider: provider,
            label: label,
            runID: runID,
            searchQueries: totalSearchQueries,
            openedSources: totalOpened,
            records: lastRecords
        )

        switch answer {
        case let .completed(result):
            // Coverage counts accepted claims as well as passages: a dimension
            // can be answered by a claim whose exact quote lives in a passage
            // that never names the dimension (Quick's generic "Answer").
            let claimTexts = result.accepted.map(\.proposal.text)
            let coverage = coverage(for: plan.dimensions, passages: passages, claims: claimTexts)
            let gaps = plan.dimensions.filter { (coverage[$0] ?? 0) == 0 }
            let clusters = NewsIndependence.clusters(passages: passages, records: result.records)
            let voices = NewsIndependence.voices(passages: passages, records: result.records)
            let support = NewsIndependence.snapshotSupportMap(passages: passages, records: result.records)
            // Per-claim depth, in citation order: a run with ten domains can
            // still carry a claim set no second voice confirms.
            let claimSupport = result.compilation.citations.map { citation -> Int in
                guard let resolved = try? result.compilation.resolve(citation.id),
                      let snapshotID = resolved.passage.snapshotID as String?
                else { return 0 }
                return support[snapshotID] ?? 0
            }
            let claimDepth = NewsClaimDepth.evaluate(support: claimSupport)
            let contradictions = ContradictionScan.contradictions(passages: passages, records: result.records)
            return .completed(
                ResearchReport(
                    plan: plan,
                    result: result,
                    rounds: rounds,
                    dimensionCoverage: coverage,
                    newsClusters: plan.mode == .news ? clusters : [],
                    independentSourceCount: clusters.count,
                    newsVoices: plan.mode == .news ? voices : [],
                    newsSnapshotSupport: plan.mode == .news ? support : [:],
                    newsClaimDepth: plan.mode == .news ? claimDepth : nil,
                    gapDimensions: gaps,
                    roundLog: roundLog,
                    stopReason: stopReason,
                    // The scan was computed and then not passed to the report,
                    // so the contrast panel could not render for any run. It is
                    // passed here, empty or not.
                    contradictions: contradictions
                )
            )
        case let .abstained(reason):
            return .abstained(reason: reason)
        case let .failed(reason):
            return .failed(reason: reason)
        }
    }

    /// A deterministic, lexical coverage check. A dimension counts as covered
    /// when a retrieved passage or an accepted claim contains any of its
    /// content terms. The single-dimension modes (Quick) are covered by their
    /// accepted claims, because prose rarely repeats the literal word
    /// "answer". It is a view over stored text and accepted claims only; it
    /// does not rank, rewrite, or promote anything.
    public static func coverage(for dimensions: [String], passages: [Passage], claims: [String] = []) -> [String: Int] {
        var result: [String: Int] = [:]
        for dimension in dimensions {
            let terms = DimensionLexicon.terms(for: dimension)
            var count = 0
            for passage in passages {
                guard !terms.isEmpty else { count += 1; continue }
                let haystack = passage.heading + " " + passage.text
                if DimensionLexicon.covers(dimension, text: haystack) { count += 1 }
            }
            for claim in claims {
                guard !terms.isEmpty else { count += 1; continue }
                if DimensionLexicon.covers(dimension, text: claim) { count += 1 }
            }
            // A single-dimension mode has no scaffold to match against: its one
            // dimension is "Answer", so every accepted claim answers it.
            if count == 0, dimensions.count == 1, !claims.isEmpty { count = claims.count }
            result[dimension] = count
        }
        return result
    }

    static func followUpQueries(question: String, dimensions: [String], mode: ResearchMode) -> [String] {
        var queries: [String] = []
        for dimension in dimensions {
            let terms = QuickQueryPlanner.contentTerms(of: dimension)
            guard !terms.isEmpty else { continue }
            switch mode {
            case .news:
                queries.append("\(question) \(dimension) news")
            case .academic:
                queries.append("\(question) \(dimension)")
            case .deep, .quick:
                queries.append("\(question) \(dimension)")
            }
        }
        return ResearchPlanner.dedupe(queries)
    }

    private static func reasons(_ outcome: LiveQuickOutcome) -> String {
        switch outcome {
        case let .abstained(reason), let .failed(reason): reason
        case .completed: ""
        }
    }
}
