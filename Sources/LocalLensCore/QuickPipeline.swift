import Foundation

// MARK: - Run plan

/// One frozen Quick question: its text, the candidate claims to bind, and the
/// source metadata needed to describe the evidence.
///
/// There is no model and no provider here. The plan is the deterministic half of
/// Quick mode: a question set whose retrieval queries and exact quotes are
/// frozen, run over already-stored snapshots.
public struct QuickRunPlan: Equatable, Sendable {
    public let id: String
    public let question: String
    public let candidates: [ClaimCandidate]
    public let sources: [Source]

    public init(id: String, question: String, candidates: [ClaimCandidate], sources: [Source]) {
        self.id = id
        self.question = question
        self.candidates = candidates
        self.sources = sources
    }
}

// MARK: - Typed refusals

/// Plan-construction failures and mid-run composition failures.
public enum QuickPipelineError: Error, Equatable, LocalizedError, Sendable {
    /// A question with no text cannot scope a run.
    case emptyQuestion(id: String)
    /// Two sources share an identity, so evidence could not be attributed.
    case duplicateSource(sourceID: String)
    /// A cited snapshot names a source the plan does not describe.
    case missingSource(sourceID: String)
    /// A cited passage names a snapshot the store does not contain, so the
    /// citation cannot resolve to stored evidence.
    case missingSnapshot(snapshotID: String)

    public var kind: String {
        switch self {
        case .emptyQuestion: "empty_question"
        case .duplicateSource: "duplicate_source"
        case .missingSource: "missing_source"
        case .missingSnapshot: "missing_snapshot"
        }
    }

    public var reason: String {
        switch self {
        case let .emptyQuestion(id):
            "question \(id) has no text"
        case let .duplicateSource(sourceID):
            "source \(sourceID) appears more than once in the plan"
        case let .missingSource(sourceID):
            "a cited snapshot names source \(sourceID), which the plan does not describe"
        case let .missingSnapshot(snapshotID):
            "a cited passage names snapshot \(snapshotID), which the store does not contain"
        }
    }

    public var errorDescription: String? { reason }
}

// MARK: - Pipeline

/// Composes a frozen Quick question set, the M003.1 lexical index, and the
/// M003.2 citation compiler into one offline run.
///
/// The pipeline opens no socket, resolves no name, reads no file, and consults
/// no clock. It drives the existing run state machine through the Quick phase
/// order and always ends in a terminal status: `complete` with a
/// retrieval-backed evidence graph, or `failed` with a stop reason that names
/// the typed refusal that stopped it.
public enum QuickPipeline {
    @discardableResult
    public static func run(
        _ plan: QuickRunPlan,
        store: SnapshotStore,
        index: LexicalIndex,
        runID: String? = nil
    ) async throws -> PersistedRun {
        try validate(plan)

        let machine = RunStateMachine(
            run: ResearchRun(id: runID ?? plan.id, question: plan.question, mode: .quick)
        )
        try await machine.transition(to: .scoped, message: "Question scope frozen")
        try await machine.transition(to: .rewriting, message: "Deterministic query plan fixed")
        try await machine.transition(to: .searching, message: "Frozen question set searched")
        try await machine.transition(to: .acquiring, message: "Synthetic sources acquired")
        try await machine.transition(to: .extracting, message: "Synthetic pages extracted")
        try await machine.transition(to: .retrieving, message: "Lexical retrieval ranked stored passages")

        let compilation: CitationCompilation
        do {
            compilation = try await CitationCompiler.compile(candidates: plan.candidates, index: index)
        } catch let error as CitationCompilerError {
            return try await fail(
                machine: machine,
                plan: plan,
                store: store,
                reason: "citation_compile_failed: \(error.kind): \(error.reason)"
            )
        }

        let payload: Payload
        do {
            payload = try await makePayload(for: compilation, plan: plan, store: store)
        } catch let error as QuickPipelineError {
            return try await fail(
                machine: machine,
                plan: plan,
                store: store,
                reason: "\(error.kind): \(error.reason)"
            )
        }

        var result = ResearchResult(
            run: await machine.run,
            summary: "Deterministic Quick run: \(compilation.citations.count) claims resolved to \(payload.sources.count) sources.",
            recommendation: compilation.claims.first?.text ?? "No claim in run.",
            openQuestion: "Not evaluated in the deterministic Quick fixture.",
            columnTitles: [],
            comparisonRows: [],
            sources: payload.sources,
            snapshots: payload.snapshots,
            passages: payload.passages,
            claims: compilation.claims,
            evidenceLinks: compilation.evidenceLinks,
            citations: compilation.citations
        )

        do {
            try DeterministicPipeline.validate(result)
        } catch {
            return try await fail(
                machine: machine,
                plan: plan,
                store: store,
                reason: "citation_integrity_failed: \(error)"
            )
        }

        try await machine.transition(to: .buildingEvidence, message: "Retrieval-backed evidence graph built")
        try await machine.transition(to: .drafting, message: "Template synthesis produced the Quick brief")
        try await machine.transition(to: .validating, message: "Citation integrity validated")
        try await machine.transition(to: .complete, message: "Quick run complete")
        result.run = await machine.run
        return PersistedRun(result: result, events: await machine.events)
    }

    // MARK: Plan validation

    static func validate(_ plan: QuickRunPlan) throws {
        guard !plan.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw QuickPipelineError.emptyQuestion(id: plan.id)
        }
        var seen: Set<String> = []
        for source in plan.sources where !seen.insert(source.id).inserted {
            throw QuickPipelineError.duplicateSource(sourceID: source.id)
        }
    }

    // MARK: Payload

    private struct Payload: Sendable {
        let sources: [Source]
        let snapshots: [Snapshot]
        let passages: [Passage]
    }

    /// Selects exactly the snapshots, sources, and passages a compilation cites,
    /// or refuses when a cited snapshot names a source the plan does not
    /// describe. Nothing is included by default, so the result contains only
    /// evidence that resolves.
    private static func makePayload(
        for compilation: CitationCompilation,
        plan: QuickRunPlan,
        store: SnapshotStore
    ) async throws -> Payload {
        let allRecords = await store.records()
        var recordsBySnapshotID: [String: SnapshotRecord] = [:]
        for record in allRecords {
            recordsBySnapshotID[record.snapshot.id] = record
        }

        let citedSnapshotIDs = Set(compilation.passages.map(\.snapshotID))
        for snapshotID in citedSnapshotIDs.sorted() where recordsBySnapshotID[snapshotID] == nil {
            throw QuickPipelineError.missingSnapshot(snapshotID: snapshotID)
        }
        let records = citedSnapshotIDs.sorted().compactMap { recordsBySnapshotID[$0] }
        let sourceIDs = Set(records.map(\.snapshot.sourceID))

        var sourcesByID: [String: Source] = [:]
        for source in plan.sources {
            sourcesByID[source.id] = source
        }
        for sourceID in sourceIDs.sorted() where sourcesByID[sourceID] == nil {
            throw QuickPipelineError.missingSource(sourceID: sourceID)
        }

        return Payload(
            sources: sourceIDs.sorted().compactMap { sourcesByID[$0] },
            snapshots: records.map(\.snapshot).sorted { $0.id < $1.id },
            passages: compilation.passages
        )
    }

    // MARK: Failed terminal

    private static func fail(
        machine: RunStateMachine,
        plan: QuickRunPlan,
        store: SnapshotStore,
        reason: String
    ) async throws -> PersistedRun {
        try await machine.fail(reason: reason)
        let records = await store.records()
        let result = ResearchResult(
            run: await machine.run,
            summary: "Deterministic Quick run failed: \(reason)",
            recommendation: "No accepted claim.",
            openQuestion: "Not evaluated in the deterministic Quick fixture.",
            columnTitles: [],
            comparisonRows: [],
            sources: plan.sources,
            snapshots: records.map(\.snapshot),
            passages: records.flatMap(\.passages),
            claims: [],
            evidenceLinks: [],
            citations: []
        )
        return PersistedRun(result: result, events: await machine.events)
    }
}
