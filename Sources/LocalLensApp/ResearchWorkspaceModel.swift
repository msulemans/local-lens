import Foundation
import LocalLensCore
import SwiftUI

/// The state behind the Living Research Map.
///
/// It owns the run lifecycle (idle, running, completed, stopped), the bounded
/// pause/cancel controls, the on-disk history, and the connection settings. It
/// never names a network primitive: live transport is composed inside
/// `LocalLensCore`, and the offline guard on this target is unchanged.
@MainActor
final class ResearchWorkspaceModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case running
        case completed(ResearchReport)
        case preview(LiveRetrievalResult)
        case recorded(ResearchHistoryEntry)
        case stopped(reason: String, hint: String?)
    }

    enum SearchBackend: String, CaseIterable, Identifiable {
        case tavily
        case brave
        case searxng
        var id: Self { self }
        var label: String {
            switch self {
            case .tavily: "Tavily · free"
            case .brave: "Brave API"
            case .searxng: "Self-hosted"
            }
        }
    }

    @Published var question = ""
    @Published var mode: ResearchMode = .quick
    @Published var phase: Phase = .idle
    @Published var elapsed: TimeInterval = 0
    @Published var isPaused = false
    @Published var selectedCitation: Int?
    @Published var selectedDimension: String?
    /// What the News time window left out at discovery, for the run's own mode.
    /// Empty for every other mode.
    @Published var newsRecencySummary = ""
    /// What the News topical filter removed at discovery, counted. Never
    /// evidence: a dropped result is one that was never fetched or stored.
    @Published var newsOffTopicCount = 0
    @Published var newsOffTopicDomains: [String] = []
    @Published var newsRelevanceStarved = false
    /// Provider-reported publication times, read from the News ledger once the
    /// run has finished. Reading it before the run would snapshot an empty map.
    @Published var newsPublicationDates: [String: Date] = [:]
    @Published var history: [ResearchHistoryEntry] = []
    @Published var showsHistory = false
    @Published var launcherPresented = false
    @Published var connectionExpanded = false
    @Published var searchBackend: SearchBackend = .tavily
    // Secrets are read on demand, never at launch: a launch-time read makes
    // macOS prompt for the keychain before the user has asked for anything, and
    // a rebuilt development bundle is asked again every time.
    @Published var tavilyKey = ""
    @Published var braveKey = ""
    @Published var providerKey = ""
    @Published var endpoint = "http://127.0.0.1:8888"
    /// Local-first answer boundary. When enabled, the provider is a loopback
    /// OpenAI-compatible server and no credential leaves the machine.
    /// An edited dimension plan. Empty means the mode's own scaffold is used.
    @Published var customDimensions = ""
    @Published var usesCustomDimensions = false
    @Published var planExpanded = false
    @Published var privacyExpanded = false
    /// Counts and sizes of what this app keeps on disk, refreshed on demand.
    @Published var storageSummary = ""
    @Published var diagnosticsMessage = ""
    @Published var reasoningEffort = "high"
    @Published var confirmClearHistory = false
    /// Non-empty when the keychain was refused, so the surface can say so.
    @Published var keychainMessage = ""
    @Published var useLocalProvider = false
    @Published var localEndpoint = "http://127.0.0.1:11434"
    @Published var localModel = "qwen2.5-coder:14b-instruct-q4_K_M"

    private var runTask: Task<Void, Never>?
    /// A continuation-based pause gate. Pausing resumes the runner at a safe
    /// checkpoint without polling or a wall-clock sleep.
    private let pauseGate = PauseGate()
    private var startedAt: Date?
    private var pausedTotal: TimeInterval = 0
    private var pauseStartedAt: Date?
    private(set) var historyStore: ResearchHistoryStore?

    var isRunning: Bool {
        if case .running = phase { return true }
        return false
    }

    var providerName: String {
        useLocalProvider ? "local/\(localModel)" : "deepseek-flash"
    }

    /// The boundary shown in the toolbar and recorded on every artifact. Local
    /// and hosted are never merged.
    var boundaryLabel: String {
        useLocalProvider ? "LOCAL · \(localModel)" : "HOSTED · DEEPSEEK"
    }

    var canAskWithAI: Bool {
        useLocalProvider || !providerKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var plan: ResearchPlan {
        ResearchPlanner.plan(question, mode: mode)
    }

    init() {
        historyStore = try? ResearchHistoryStore.applicationSupport()
        reloadHistory()
    }

    /// An edited question starts a new workspace. Keeping the previous answer
    /// beside a different (or empty) question made the result look current.
    func updateQuestion(_ value: String) {
        guard question != value, !isRunning else { return }
        question = value
        phase = .idle
        selectedCitation = nil
        selectedDimension = nil
    }

    // MARK: Run lifecycle

    func askWithAI() { start(useProvider: true) }

    func findEvidenceOnly() { start(useProvider: false) }

    private func start(useProvider: Bool) {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isRunning else { return }
        let plan: ResearchPlan
        do {
            plan = try makePlan(trimmed)
        } catch {
            phase = .stopped(
                reason: "The dimension plan is not valid.",
                hint: (error as? ResearchPlanError)?.errorDescription ?? "\(error)"
            )
            planExpanded = true
            return
        }
        // Validate before touching the keychain. A malformed local plan must
        // refuse immediately, with no credential prompt or network attempt.
        // For a valid plan, saved credentials are read before the provider
        // check so a fresh launch can still use its existing key.
        loadStoredSecretsIfNeeded()
        if useProvider, !canAskWithAI {
            phase = .stopped(
                reason: "No answer provider is configured.",
                hint: "Add a DeepSeek key in Connection, or switch on the local model endpoint."
            )
            connectionExpanded = true
            return
        }
        connectionExpanded = false
        let live: LiveQuickComposition.Live
        do {
            live = try makeLive(plan: plan)
        } catch {
            phase = .stopped(reason: "The live connection could not be prepared.", hint: "Check the connection settings. \(error)")
            connectionExpanded = true
            return
        }

        phase = .running
        selectedCitation = nil
        elapsed = 0
        isPaused = false
        pausedTotal = 0
        pauseStartedAt = nil
        startedAt = Date()
        pauseGate.setPaused(false)

        let providerName = live.providerName
        let label = live.label
        // Both News readings happen after the run: the ledger is empty until
        // discovery has executed, and a map captured here would be a snapshot of
        // nothing.
        let newsLedger = live.newsRecency
        let deadline = Date().addingTimeInterval(plan.policy.deadlineSeconds)
        let gate = pauseGate
        let pauseCheck: @Sendable () async -> Void = { await gate.wait() }

        runTask = Task { [weak self] in
            guard let self else { return }
            if useProvider {
                let outcome = await ResearchRunner.run(
                    plan: plan,
                    deadline: deadline,
                    search: live.search,
                    store: live.store,
                    fetch: live.fetch,
                    provider: live.provider,
                    label: label,
                    runID: "research-\(plan.mode.rawValue.lowercased())",
                    pauseCheck: pauseCheck
                )
                guard !Task.isCancelled else { return }
                self.readNewsLedger(newsLedger)
                self.finish(outcome, plan: plan, providerName: providerName)
            } else {
                let result = await self.retrieveOnly(plan: plan, live: live, deadline: deadline, pauseCheck: pauseCheck)
                guard !Task.isCancelled else { return }
                self.readNewsLedger(newsLedger)
                self.finishPreview(result)
            }
        }
    }

    /// Fills any empty credential field from the keychain, once. An environment
    /// variable is a fallback for a scripted run, and a field the user has typed
    /// into is never overwritten.
    func loadStoredSecretsIfNeeded() {
        var refusals: [String] = []
        func read(_ field: inout String, service: String, environment: String) {
            guard field.isEmpty else { return }
            switch SecretKeyStore.read(service: service) {
            case let .found(value):
                field = value
            case .absent:
                field = ProcessInfo.processInfo.environment[environment] ?? ""
            case .denied:
                // The item is there; macOS refused this binary permission to read
                // it. Saying "no key configured" would be false, and would send a
                // user to re-enter a key they already saved.
                field = ProcessInfo.processInfo.environment[environment] ?? ""
                refusals.append(service)
            }
        }
        read(&tavilyKey, service: "locallens-tavily-search", environment: "TAVILY_API_KEY")
        read(&braveKey, service: "locallens-brave-search", environment: "BRAVE_SEARCH_API_KEY")
        read(&providerKey, service: "locallens-deepseek", environment: "DEEPSEEK_API_KEY")
        if refusals.isEmpty {
            keychainMessage = ""
        } else {
            keychainMessage = "The keychain holds \(refusals.joined(separator: ", ")) but macOS refused this build access to it. Press Grant access and choose Always Allow, or paste the key again below. A rebuilt development app is a new binary to macOS, so this repeats after every rebuild."
        }
    }

    /// Makes the keychain prompt appear now instead of in the middle of a run.
    func requestKeychainAccess() {
        tavilyKey = ""
        braveKey = ""
        providerKey = ""
        loadStoredSecretsIfNeeded()
    }

    /// Builds the plan, using the edited dimension list only when it is switched
    /// on. Validation happens here so an invalid plan never reaches a run.
    func makePlan(_ question: String) throws -> ResearchPlan {
        let defaultPlan = ResearchPlanner.plan(question, mode: mode)
        guard usesCustomDimensions else { return defaultPlan }
        let edited = ResearchPlanner.splitDimensions(customDimensions)
        return try ResearchPlanner.plan(
            question,
            mode: mode,
            dimensions: edited
        )
    }

    /// Refills the editor with the mode's own scaffold, so switching it on
    /// starts from something valid.
    func resetDimensionsToDefault() {
        customDimensions = ResearchPlanner.dimensions(for: question.trimmingCharacters(in: .whitespacesAndNewlines), mode: mode)
            .joined(separator: ", ")
    }

    // MARK: Storage, privacy, and diagnostics

    /// Recomputes the on-disk footprint. Counts only: no path or content is
    /// shown, and nothing is transmitted anywhere.
    func refreshStorageSummary() {
        let fileManager = FileManager.default
        var bytes = 0
        var files = 0
        var directories: [URL] = []
        if let history = try? ResearchHistoryStore.applicationSupport() {
            directories.append(history.directory)
        }
        for directory in directories {
            guard let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.fileSizeKey]) else { continue }
            for case let url as URL in enumerator {
                let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                bytes += size
                files += 1
            }
        }
        storageSummary = "\(history.count) saved runs · \(files) history files · \(ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)) of history"
    }

    /// Removes every saved run. It asks first, and it says what it removed.
    func clearHistoryAndStorage() {
        guard let store = historyStore else {
            diagnosticsMessage = "The history store is unavailable, so nothing was removed."
            return
        }
        do {
            try store.clear()
            reloadHistory()
            phase = .idle
            refreshStorageSummary()
            diagnosticsMessage = "All saved runs were removed. Nothing left this machine."
        } catch {
            diagnosticsMessage = "The saved runs could not be removed: \(error)"
        }
    }

    /// Copies the diagnostics bundle to the pasteboard, for a support request.
    func copyDiagnostics() {
        do {
            let data = try makeDiagnostics().json()
            guard let text = String(data: data, encoding: .utf8) else {
                diagnosticsMessage = "The diagnostics bundle could not be encoded."
                return
            }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            let bytes = text.utf8.count
            diagnosticsMessage = "Diagnostics copied (\(bytes) bytes): versions, counts, and typed reasons only."
        } catch {
            diagnosticsMessage = "The diagnostics bundle could not be built: \(error)"
        }
    }

    /// Builds the diagnostics bundle. Counts, versions, and typed reasons only:
    /// no question, answer, quote, URL, or credential is included.
    func makeDiagnostics() -> DiagnosticsReport {
        let settings = DiagnosticsReport.Settings(
            mode: mode.rawValue,
            searchBackend: searchBackend.rawValue,
            usesLocalProvider: useLocalProvider,
            localEndpointHost: DiagnosticsReport.hostOnly(localEndpoint),
            localModel: useLocalProvider ? localModel : "",
            reasoningEffort: useLocalProvider ? nil : reasoningEffort,
            hasHostedKey: !providerKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            hasSearchKey: !tavilyKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )
        var failures: [DiagnosticsReport.RecentFailure] = []
        if case let .stopped(reason, hint) = phase {
            failures.append(DiagnosticsReport.RecentFailure(
                runIdentifier: StableIdentity.make("diagnostic", reason, hint ?? ""),
                mode: mode.rawValue,
                reason: reason,
                at: ISO8601DateFormatter().string(from: Date())
            ))
        }
        let storage = DiagnosticsReport.Storage(
            historyEntries: history.count,
            snapshots: history.reduce(0) { $0 + $1.citationCount },
            passages: history.reduce(0) { $0 + $1.citationCount },
            bytesOnDisk: 0
        )
        let info = Bundle.main.infoDictionary ?? [:]
        return DiagnosticsReport(
            appVersion: info["CFBundleShortVersionString"] as? String ?? "unknown",
            appBuild: info["CFBundleVersion"] as? String ?? "unknown",
            protocolVersion: ProtocolVersion.v1,
            operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
            architecture: "arm64",
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            storage: storage,
            settings: settings,
            recentFailures: failures
        )
    }

    /// The study card for a finished run. Generated from the report itself, so
    /// it cannot drift from what was cited.
    func learningCard(for report: ResearchReport) -> LearningCard? {
        LearningCard.make(
            plan: report.plan,
            outcome: .completed(report),
            stopReason: report.stopReason,
            coverage: report.dimensionCoverage,
            gapDimensions: report.gapDimensions
        )
    }

    /// Reads the News window ledger once discovery has finished.
    private func readNewsLedger(_ ledger: NewsRecencyLedger?) {
        guard let ledger else {
            newsRecencySummary = ""
            newsPublicationDates = [:]
            newsOffTopicCount = 0
            newsOffTopicDomains = []
            newsRelevanceStarved = false
            return
        }
        newsRecencySummary = ledger.summary
        newsPublicationDates = ledger.publicationDates
        newsOffTopicCount = ledger.offTopicCount
        newsOffTopicDomains = ledger.offTopicDomainsList
        newsRelevanceStarved = ledger.relevanceWasStarved
    }

    /// The no-AI path: search, safe fetch, extraction, storage, and lexical
    /// selection with zero provider calls. It returns the stored passages for
    /// inspection; it never fabricates an answer.
    private func retrieveOnly(
        plan: ResearchPlan,
        live: LiveQuickComposition.Live,
        deadline: Date,
        pauseCheck: @Sendable () async -> Void
    ) async -> Result<LiveRetrievalResult, LiveQuickOutcome> {
        await pauseCheck()
        return await LiveQuickRunner.retrieve(
            question: plan.question,
            queries: plan.searchQueries,
            retrievalQueries: plan.retrievalQueries,
            limits: LiveQuickLimits.forMode(plan.mode),
            deadline: deadline,
            search: live.search,
            store: live.store,
            fetch: live.fetch
        )
    }

    private func finishPreview(_ result: Result<LiveRetrievalResult, LiveQuickOutcome>) {
        elapsed = currentElapsed()
        switch result {
        case let .success(retrieval):
            selectedCitation = retrieval.passages.isEmpty ? nil : 1
            phase = .preview(retrieval)
        case let .failure(failure):
            switch failure {
            case let .abstained(reason):
                phase = .stopped(reason: reason, hint: "No passage was usable as evidence. Try a more specific question or another source.")
            case let .failed(reason):
                phase = .stopped(reason: reason, hint: reason == "cancelled" ? nil : "Check the connection settings before trying again.")
            case .completed:
                phase = .stopped(reason: "unexpected retrieval completion", hint: nil)
            }
        }
    }

    private func finish(_ outcome: ResearchOutcome, plan: ResearchPlan, providerName: String) {
        switch outcome {
        case let .completed(report):
            elapsed = currentElapsed()
            phase = .completed(report)
            selectedCitation = report.result.compilation.citations.first.map { _ in 1 }
            selectedDimension = plan.dimensions.first
            record(report: report, plan: plan, providerName: providerName)
        case let .abstained(reason):
            elapsed = currentElapsed()
            phase = .stopped(reason: reason, hint: "The run refused to invent an answer. Try a narrower question, another source, or Deep mode.")
        case let .failed(reason):
            elapsed = currentElapsed()
            phase = .stopped(reason: reason, hint: reason == "cancelled" ? nil : "Check the connection settings before trying again.")
        }
    }

    func cancel() {
        runTask?.cancel()
        runTask = nil
        isPaused = false
        pauseGate.setPaused(false)
        elapsed = currentElapsed()
        phase = .stopped(reason: "Cancelled. No partial answer is shown.", hint: nil)
    }

    func togglePause() {
        guard isRunning else { return }
        if isPaused {
            if let pauseStartedAt {
                pausedTotal += Date().timeIntervalSince(pauseStartedAt)
            }
            pauseStartedAt = nil
            isPaused = false
        } else {
            pauseStartedAt = Date()
            isPaused = true
        }
        pauseGate.setPaused(isPaused)
    }

    // MARK: History

    func reloadHistory() {
        history = (try? historyStore?.list()) ?? []
    }

    func open(_ entry: ResearchHistoryEntry) {
        question = entry.question
        mode = entry.mode
        phase = .recorded(entry)
        selectedCitation = entry.citations.first?.marker
        selectedDimension = nil
    }

    func delete(_ entry: ResearchHistoryEntry) {
        try? historyStore?.delete(id: entry.id)
        reloadHistory()
    }

    func clearHistory() {
        try? historyStore?.clear()
        reloadHistory()
    }

    private func record(report: ResearchReport, plan: ResearchPlan, providerName: String) {
        let stamp = ISO8601DateFormatter().string(from: Date())
        let artifact = LiveAnswerArtifact.make(
            from: report.result,
            provider: providerName,
            elapsedSeconds: elapsed,
            generatedAt: stamp
        )
        let entry = ResearchHistoryEntry(artifact: artifact, mode: plan.mode, completedAt: stamp)
        try? historyStore?.save(entry)
        reloadHistory()
    }

    // MARK: Research this gap

    func researchFirstGap() {
        guard case let .completed(report) = phase, let gap = report.gapDimensions.first else { return }
        question = "\(report.plan.question) \(gap)"
        mode = .deep
        askWithAI()
    }

    // MARK: Connection

    private func makeLive(plan: ResearchPlan) throws -> LiveQuickComposition.Live {
        let local: LocalProviderConfiguration?
        if useLocalProvider {
            guard let url = URL(string: localEndpoint),
                  let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
                  url.host != nil else {
                throw SearchError.invalidEndpoint(reason: "the local model endpoint is not an HTTP URL")
            }
            let model = localModel.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !model.isEmpty else {
                throw SearchError.invalidEndpoint(reason: "the local model name is empty")
            }
            local = LocalProviderConfiguration(baseURL: url, model: model)
        } else {
            local = nil
        }
        if plan.mode == .news {
            return try LiveQuickComposition.makeNews(
                tavilyKey: tavilyKey,
                apiKey: providerKey,
                local: local,
                question: plan.question
            )
        }
        if plan.mode == .academic {
            return try LiveQuickComposition.makeAcademic(
                apiKey: providerKey,
                mailto: nil,
                fallbackTavilyKey: tavilyKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : tavilyKey,
                local: local
            )
        }
        switch searchBackend {
        case .tavily:
            return try LiveQuickComposition.makeTavily(tavilyKey: tavilyKey, apiKey: providerKey, local: local)
        case .brave:
            return try LiveQuickComposition.makeBrave(braveKey: braveKey, apiKey: providerKey, local: local)
        case .searxng:
            guard let url = URL(string: endpoint) else {
                throw SearchError.invalidEndpoint(reason: "self-hosted endpoint is not a URL")
            }
            return try LiveQuickComposition.make(searxng: url, apiKey: providerKey, local: local)
        }
    }

    func saveProviderKey() {
        try? SecretKeyStore.save(providerKey, service: "locallens-deepseek")
    }

    func saveSearchKey() {
        switch searchBackend {
        case .tavily:
            try? SecretKeyStore.save(tavilyKey, service: "locallens-tavily-search")
        case .brave:
            try? SecretKeyStore.save(braveKey, service: "locallens-brave-search")
        case .searxng:
            break
        }
    }

    // MARK: Elapsed clock

    /// The elapsed wall time at `date`, excluding paused intervals. The views
    /// drive this from a SwiftUI timeline, so no background timer or wall-clock
    /// sleep exists in the app target.
    func elapsed(at date: Date) -> TimeInterval {
        guard let startedAt else { return 0 }
        var total = date.timeIntervalSince(startedAt) - pausedTotal
        if let pauseStartedAt {
            total -= date.timeIntervalSince(pauseStartedAt)
        }
        return max(0, total)
    }

    private func currentElapsed() -> TimeInterval { elapsed(at: Date()) }
}

/// An async gate that parks the runner between safe checkpoints while paused.
/// Resuming resolves every waiter; there is no polling and no clock sleep.
@MainActor
final class PauseGate {
    private var paused = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func setPaused(_ value: Bool) {
        paused = value
        guard !value else { return }
        let pending = waiters
        waiters = []
        for continuation in pending { continuation.resume() }
    }

    func wait() async {
        guard paused else { return }
        await withCheckedContinuation { continuation in
            if paused {
                waiters.append(continuation)
            } else {
                continuation.resume()
            }
        }
    }
}
