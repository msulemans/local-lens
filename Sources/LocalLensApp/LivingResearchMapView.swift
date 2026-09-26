import AppKit
import LocalLensCore
import SwiftUI

/// The product surface: the Living Research Map.
///
/// Layout, top to bottom:
///
/// 1. A header carrying the question, the mode, the provider boundary, the
///    elapsed time, and pause or cancel. The question field grows with the
///    text and owns the width it needs; the mode and status controls sit on
///    their own line so neither can squeeze the other.
/// 2. The brief: the answer, then whatever the mode adds — a comparison, a
///    paper matrix, a dated timeline — then what the evidence covers, what the
///    run stopped for, and what it could not address.
/// 3. The evidence map: every accepted claim grouped by the criterion it
///    answers, with the exact saved passage one click away.
///
/// Every number here is copied from the run. Nothing is inferred, and a
/// judgement the run did not make (how good a source is, which option is
/// better) is never rendered as if it had.
struct LivingResearchMapView: View {
    @StateObject private var model = ResearchWorkspaceModel()
    /// Below this width the evidence column would leave the brief too narrow to
    /// read, so the inspector moves into a sheet instead of being dropped.
    @State private var inspectorPresented = false

    var body: some View {
        VStack(spacing: 0) {
            WorkspaceHeader(model: model, showInspector: $inspectorPresented)
            Divider()
            GeometryReader { proxy in
                let narrow = proxy.size.width < 1080
                HStack(spacing: 0) {
                    if model.showsHistory {
                        HistorySidebar(model: model)
                            .frame(width: 232)
                        Divider()
                    }
                    BriefColumn(model: model)
                        .frame(minWidth: 420, maxWidth: .infinity)
                    if !narrow {
                        Divider()
                        EvidenceColumn(model: model)
                            .frame(width: 356)
                    }
                }
                .environment(\.lensNarrow, narrow)
            }
        }
        .frame(minWidth: 720, minHeight: 560)
        .background(Lens.Color.canvas)
        .sheet(isPresented: $model.launcherPresented) {
            GlobalLauncherView(model: model)
        }
        .sheet(isPresented: $inspectorPresented) {
            EvidenceColumn(model: model)
                .frame(minWidth: 420, minHeight: 460)
        }
        .confirmationDialog(
            "Delete every saved run?",
            isPresented: $model.confirmClearHistory,
            titleVisibility: .visible
        ) {
            Button("Delete saved runs", role: .destructive) { model.clearHistoryAndStorage() }
            Button("Keep saved runs", role: .cancel) {}
        } message: {
            Text("This removes local saved questions, citations, and answers. It cannot retract requests already sent to search or hosted answer services.")
        }
        .onReceive(NotificationCenter.default.publisher(for: .localLensOpenLauncher)) { _ in
            model.launcherPresented = true
        }
    }
}

// MARK: - Header

private struct WorkspaceHeader: View {
    @ObservedObject var model: ResearchWorkspaceModel
    @Binding var showInspector: Bool
    @Environment(\.lensNarrow) private var narrow
    /// Motion is decoration here. When the system asks for less of it, the
    /// running indicator stops pulsing and keeps its text.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Lens.Space.row) {
            HStack(alignment: .top, spacing: Lens.Space.group) {
                QuestionField(question: Binding(
                    get: { model.question },
                    set: { model.updateQuestion($0) }
                )) {
                    model.askWithAI()
                }
                .frame(minWidth: 300)
                .layoutPriority(1)
                .disabled(model.isRunning)

                primaryActions
                    .fixedSize()
            }
            controlRow
            DimensionPlanRow(model: model)
        }
        .padding(.horizontal, Lens.Space.page)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(Lens.Color.canvas)
    }

    @ViewBuilder
    private var primaryActions: some View {
        if model.isRunning {
            HStack(spacing: Lens.Space.tight) {
                Button {
                    model.togglePause()
                } label: {
                    Label(model.isPaused ? "Resume" : "Pause", systemImage: model.isPaused ? "play.fill" : "pause.fill")
                }
                .accessibilityIdentifier("researchPauseButton")

                Button(role: .destructive) {
                    model.cancel()
                } label: {
                    Label("Cancel", systemImage: "stop.fill")
                }
                .accessibilityIdentifier("researchCancelButton")
            }
            .controlSize(.large)
        } else {
            HStack(spacing: Lens.Space.tight) {
                Button {
                    model.findEvidenceOnly()
                } label: {
                    Label("Find evidence", systemImage: "doc.text.magnifyingglass")
                }
                .help("Search, fetch, and store source text. No AI key is used.")
                .disabled(model.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("researchFindEvidenceButton")

                Button {
                    model.askWithAI()
                } label: {
                    Label("Ask", systemImage: "arrow.up")
                }
                .buttonStyle(.borderedProminent)
                .help("Answer the question, citing only exact saved passages.")
                .disabled(model.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("researchAskButton")
            }
            .controlSize(.large)
        }
    }

    private var controlRow: some View {
        HStack(spacing: Lens.Space.row) {
            Picker("Mode", selection: $model.mode) {
                ForEach(ResearchMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 300)
            .accessibilityIdentifier("researchModePicker")

            Text(ModePolicy.policy(for: model.mode).boundarySummary)
                .font(Lens.Text.caption)
                .foregroundStyle(Lens.Color.muted)
                .lineLimit(1)
                .truncationMode(.tail)
                .help(ModePolicy.policy(for: model.mode).boundarySummary)

            Spacer(minLength: Lens.Space.row)

            if model.isRunning {
                TimelineView(.periodic(from: .now, by: 0.2)) { context in
                    Text(Self.clock(model.elapsed(at: context.date)))
                        .font(Lens.Text.data)
                        .foregroundStyle(Lens.Color.ink)
                }
            }
            providerChip
            if narrow {
                Button {
                    showInspector = true
                } label: {
                    Image(systemName: "doc.text.magnifyingglass")
                }
                .buttonStyle(.plain)
                .help("Show the exact saved passage")
                .accessibilityLabel("Exact saved passage")
            }
            Button {
                model.showsHistory.toggle()
            } label: {
                Image(systemName: model.showsHistory ? "clock.arrow.circlepath.circle.fill" : "clock.arrow.circlepath")
            }
            .buttonStyle(.plain)
            .help("Saved runs")
            .accessibilityLabel("History")
            Button {
                model.launcherPresented = true
            } label: {
                Image(systemName: "command")
            }
            .buttonStyle(.plain)
            .help("Global launcher (⌘⇧Space)")
            .accessibilityLabel("Global launcher")
        }
    }

    /// The boundary is the one thing a reader must never misread, so it keeps a
    /// label rather than an icon: a hosted answer and a local answer are not
    /// the same object.
    private var providerChip: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(model.useLocalProvider ? Lens.Color.evidence : Lens.Color.muted)
                .frame(width: 6, height: 6)
            Text(model.boundaryLabel)
                .font(Lens.Text.caption)
                .foregroundStyle(Lens.Color.muted)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Lens.Color.inset, in: Capsule())
        .help(model.useLocalProvider
              ? "A local model answers on this Mac. Nothing leaves it."
              : "A hosted model answers. Only the passages it needs are sent.")
    }

    private static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// The plan the next run will use. It is shown before the run, not after, and a
/// reader can replace it. Validation lives in the core, so an invalid plan is
/// refused with a stated reason rather than trimmed silently.
private struct DimensionPlanRow: View {
    @ObservedObject var model: ResearchWorkspaceModel

    private var defaultPlan: [String] {
        ResearchPlanner.dimensions(
            for: model.question.trimmingCharacters(in: .whitespacesAndNewlines),
            mode: model.mode
        )
    }

    private var validationMessage: String? {
        guard model.usesCustomDimensions else { return nil }
        let edited = ResearchPlanner.splitDimensions(model.customDimensions)
        do {
            _ = try ResearchPlanner.validatedDimensions(edited, mode: model.mode)
            return nil
        } catch {
            return (error as? ResearchPlanError)?.errorDescription ?? "\(error)"
        }
    }

    private var plan: [String] {
        if model.usesCustomDimensions, validationMessage == nil {
            let edited = ResearchPlanner.splitDimensions(model.customDimensions)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if !edited.isEmpty { return edited }
        }
        return defaultPlan
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Lens.Space.tight) {
            HStack(spacing: Lens.Space.tight) {
                Button {
                    model.planExpanded.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: model.planExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                        Text("Looking for")
                            .font(Lens.Text.caption)
                    }
                    .foregroundStyle(Lens.Color.muted)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("researchPlanDisclosure")

                Text(plan.joined(separator: " · "))
                    .font(Lens.Text.caption)
                    .foregroundStyle(model.usesCustomDimensions ? Lens.Color.evidence : Lens.Color.ink)
                    .lineLimit(1)
                    .accessibilityIdentifier("researchPlanDimensions")

                Spacer(minLength: Lens.Space.tight)
            }
            if model.planExpanded {
                VStack(alignment: .leading, spacing: Lens.Space.row) {
                    Toggle("Replace the mode's dimensions", isOn: $model.usesCustomDimensions)
                        .toggleStyle(.checkbox)
                        .font(Lens.Text.label)
                        .accessibilityIdentifier("researchPlanToggle")
                    HStack(spacing: Lens.Space.tight) {
                        TextField("Findings, Method, Limitations", text: $model.customDimensions)
                            .textFieldStyle(.roundedBorder)
                            .font(Lens.Text.label)
                            .disabled(!model.usesCustomDimensions)
                            .accessibilityIdentifier("researchDimensionField")
                        Button("Use the mode default") {
                            model.resetDimensionsToDefault()
                        }
                        .font(Lens.Text.label)
                        .disabled(!model.usesCustomDimensions)
                        .accessibilityIdentifier("researchDimensionDefault")
                    }
                    Text("At most \(ResearchPlanner.maximumDimensions(for: model.mode)) in \(model.mode.rawValue) mode, separated by commas. A follow-up round is spent only on a dimension the evidence has not touched.")
                        .font(Lens.Text.caption)
                        .foregroundStyle(Lens.Color.muted)
                    if let validationMessage {
                        Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(Lens.Text.caption)
                            .foregroundStyle(Lens.Color.caution)
                            .accessibilityIdentifier("researchPlanError")
                    }
                }
                .padding(Lens.Space.row)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lensCard()
            }
        }
    }
}

// MARK: - Brief

private struct BriefColumn: View {
    @ObservedObject var model: ResearchWorkspaceModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Lens.Space.section) {
                switch model.phase {
                case .idle:
                    IdleBrief(model: model)
                case .running:
                    RunningBrief(model: model)
                case let .completed(report):
                    CompletedBrief(model: model, report: report)
                case let .preview(result):
                    PreviewBrief(model: model, result: result)
                case let .recorded(entry):
                    RecordedBrief(model: model, entry: entry)
                case let .stopped(reason, hint):
                    StoppedBrief(model: model, reason: reason, hint: hint)
                }
            }
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Lens.Space.page)
            .padding(.vertical, 22)
        }
        .scrollIndicators(.automatic)
    }
}

private struct IdleBrief: View {
    @ObservedObject var model: ResearchWorkspaceModel

    var body: some View {
        VStack(alignment: .leading, spacing: Lens.Space.section) {

            VStack(alignment: .leading, spacing: Lens.Space.tight) {
                Text("Living Research Map")
                    .font(Lens.Text.display)
                    .foregroundStyle(Lens.Color.ink)
                Text("Ask a question. Each answer claim links to an exact passage from a fetched page, so you can judge the source yourself.")
                    .font(Lens.Text.body)
                    .foregroundStyle(Lens.Color.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            LensSection(title: "Pick how far to go", detail: model.mode.tagline) {
                HStack(alignment: .top, spacing: Lens.Space.row) {
                    ForEach(ResearchMode.allCases, id: \.self) { mode in
                        ModeCard(mode: mode, selected: model.mode == mode) {
                            model.mode = mode
                        }
                    }
                }
            }

            LensSection(title: "Start from one of these") {
                VStack(spacing: 0) {
                    ForEach(Array(Self.examples.enumerated()), id: \.offset) { index, example in
                        Button {
                            model.question = example.question
                            model.mode = example.mode
                        } label: {
                            HStack(spacing: Lens.Space.row) {
                                Image(systemName: "arrow.up.left")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Lens.Color.faint)
                                Text(example.question)
                                    .font(Lens.Text.body)
                                    .foregroundStyle(Lens.Color.ink)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: Lens.Space.row)
                                Text(example.mode.rawValue)
                                    .font(Lens.Text.caption)
                                    .foregroundStyle(Lens.Color.muted)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if index < Self.examples.count - 1 { Divider() }
                    }
                }
                .lensCard()
            }

            // This states what an answer needs, not what this Mac has: the
            // keychain is only read when a run starts or the panel is opened,
            // so a claim about the current state here could be false.
            HStack(alignment: .firstTextBaseline, spacing: Lens.Space.tight) {
                Image(systemName: "key.horizontal")
                    .font(.system(size: 11))
                    .foregroundStyle(Lens.Color.muted)
                Text("Answers are written by a hosted model or one running on this Mac; both are set up under Connection. Find evidence needs no AI key at all.")
                    .font(Lens.Text.label)
                    .foregroundStyle(Lens.Color.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if model.history.isEmpty {
                FirstRunCard(model: model)
            }
        }
    }

    private static let examples: [(question: String, mode: ResearchMode)] = [
        ("How does SQLite WAL mode handle readers and writers?", .quick),
        ("Compare SQLite WAL mode and the default rollback journal for a small app", .deep),
        ("What do studies report about retrieval practice and long-term retention?", .academic),
        ("What changed in the EU AI Act enforcement this month?", .news),
    ]
}

private struct ModeCard: View {
    let mode: ResearchMode
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Lens.Space.tight) {
                HStack(spacing: 5) {
                    Text(mode.rawValue)
                        .font(Lens.Text.body.weight(.semibold))
                        .foregroundStyle(Lens.Color.ink)
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Lens.Color.evidence)
                    }
                }
                Text(ModePolicy.policy(for: mode).boundarySummary)
                    .font(Lens.Text.caption)
                    .foregroundStyle(Lens.Color.muted)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Lens.Space.row)
        }
        .buttonStyle(.plain)
        .lensCard(highlighted: selected)
        .accessibilityIdentifier("modeCard\(mode.rawValue)")
    }
}

private struct FirstRunCard: View {
    @ObservedObject var model: ResearchWorkspaceModel

    var body: some View {
        LensSection(title: "Your first run", detail: "Three steps, and the fourth is optional.") {
            VStack(alignment: .leading, spacing: Lens.Space.row) {
                Step(1, "Pick a mode. Quick answers in one bounded pass; Deep adds follow-up rounds.")
                Step(2, "Open Connection to add a search key, or point at a local model on this Mac.")
                Step(3, "Press Ask for a cited answer, or Find evidence for source text with no AI at all.")
                Step(4, "Open Storage & privacy to see exactly what is kept, and to delete it.")
            }
            .padding(Lens.Space.group)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lensCard(inset: true)
            .accessibilityIdentifier("researchFirstRun")
        }
    }

    private func Step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Lens.Space.row) {
            Text("\(number)")
                .font(Lens.Text.data)
                .foregroundStyle(Lens.Color.evidence)
                .frame(width: 14, alignment: .trailing)
            Text(text)
                .font(Lens.Text.body)
                .foregroundStyle(Lens.Color.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct RunningBrief: View {
    @ObservedObject var model: ResearchWorkspaceModel

    var body: some View {
        VStack(alignment: .leading, spacing: Lens.Space.group) {
            HStack(spacing: Lens.Space.row) {
                ProgressView().controlSize(.small)
                Text(model.isPaused ? "Paused between rounds. The deadline keeps counting." : "Searching, opening pages, and checking every passage before it is cited.")
                    .font(Lens.Text.body)
                    .foregroundStyle(Lens.Color.muted)
            }
            Text(model.question)
                .font(Lens.Text.display)
                .foregroundStyle(Lens.Color.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier("researchRunning")
    }
}

private struct CompletedBrief: View {
    @ObservedObject var model: ResearchWorkspaceModel
    let report: ResearchReport

    var body: some View {
        VStack(alignment: .leading, spacing: Lens.Space.section) {

            // What was asked, and what came back. The question is repeated here
            // because the header scrolls out of view and a saved answer without
            // its question is not readable.
            VStack(alignment: .leading, spacing: Lens.Space.row) {
                Text(report.plan.question)
                    .font(Lens.Text.display)
                    .foregroundStyle(Lens.Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: Lens.Space.group) {
                    LensMetric(value: "\(report.result.compilation.citations.count)", label: "passages")
                    LensMetric(value: "\(report.result.observation.openedSources)", label: "sources")
                    LensMetric(value: "\(report.rounds)", label: report.rounds == 1 ? "round" : "rounds")
                    LensMetric(value: String(format: "%.1f", model.elapsed), label: "seconds")
                    Spacer(minLength: 0)
                }
            }

            SummarySection(report: report)
            ContrastPanel(contradictions: report.contradictions)

            switch report.plan.mode {
            case .deep: DeepSections(report: report)
            case .academic: AcademicSection(report: report)
            case .news: NewsSections(model: model, report: report)
            case .quick: EmptyView()
            }

            CoverageSection(report: report)
            OpenQuestionSection(model: model, report: report)
            LearnSection(model: model, report: report)
            ExportSection(model: model, report: report)
            RunNotesSection(model: model, report: report)
        }
    }
}

/// The answer itself. One block of prose, at the largest body size on the
/// screen, with the model and provider named underneath so a reader never has
/// to guess who wrote it.
private struct SummarySection: View {
    let report: ResearchReport

    var body: some View {
        LensSection(title: "Summary", detail: "Each claim links to fetched text. A citation shows what a source says; it does not independently verify the fact.") {
            VStack(alignment: .leading, spacing: Lens.Space.row) {
                Text(report.result.answer.isEmpty ? "No accepted claim was compiled." : readableAnswer(report.result.answer))
                    .font(Lens.Text.reading)
                    .lineSpacing(5)
                    .foregroundStyle(Lens.Color.ink)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("researchAnswer")
                if !report.result.rejected.isEmpty {
                    Text("\(report.result.rejected.count) proposed \(report.result.rejected.count == 1 ? "claim was" : "claims were") dropped because no exact saved passage supported \(report.result.rejected.count == 1 ? "it" : "them"). See the study card below.")
                        .font(Lens.Text.caption)
                        .foregroundStyle(Lens.Color.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Deep's comparison. Rows are the question's criteria; columns are the two
/// sides the planner found. A cell counts stored passages that satisfy the
/// criterion *and* mention that side, so a cell is a fact about retrieved text
/// rather than a rating the run never made.
///
/// The first version counted a passage whenever it matched the criterion, which
/// produced numbers that looked like findings and were not: a row could report
/// 211 matches for a side it never checked. A criterion that only restates a
/// side is not a row, because the side already has a column.
private struct DeepSections: View {
    let report: ResearchReport

    private var sides: [String] { Array(report.plan.dimensions.prefix(2)) }

    /// Criteria that are not one of the sides.
    private var criteria: [String] {
        report.plan.dimensions.filter { !sides.contains($0) }
    }

    private var passages: [(heading: String, text: String)] {
        report.result.records.flatMap(\.passages).map { ($0.heading, $0.text) }
    }

    var body: some View {
        if sides.count == 2, !criteria.isEmpty {
            LensSection(
                title: "Comparison at a glance",
                detail: "How many stored passages match each criterion on each side. These are counts of retrieved text, not a rating."
            ) {
                VStack(spacing: 0) {
                    HStack(alignment: .bottom, spacing: 0) {
                        Text("Criterion")
                            .font(Lens.Text.caption)
                            .foregroundStyle(Lens.Color.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ForEach(sides, id: \.self) { side in
                            Text(Self.shortLabel(side))
                                .font(Lens.Text.caption)
                                .foregroundStyle(Lens.Color.muted)
                                .lineLimit(2)
                                .help(side)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Lens.Color.inset)

                    ForEach(Array(criteria.enumerated()), id: \.offset) { _, criterion in
                        Divider()
                        HStack(alignment: .top, spacing: 0) {
                            Text(criterion)
                                .font(Lens.Text.body)
                                .foregroundStyle(Lens.Color.ink)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            ForEach(sides, id: \.self) { side in
                                Cell(count: matches(criterion: criterion, side: side))
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                    }
                }
                .lensCard()
            }
        }
    }

    /// Passages that satisfy the criterion and mention the side, by the same
    /// whole-word rule the coverage check uses.
    private func matches(criterion: String, side: String) -> Int {
        let sideTerms = QuickQueryPlanner.contentTerms(of: side)
        return passages.filter { passage in
            let text = passage.heading + " " + passage.text
            guard DimensionLexicon.covers(criterion, text: text) else { return false }
            guard !sideTerms.isEmpty else { return true }
            return sideTerms.contains { DimensionLexicon.wordMatch($0, in: text.lowercased()) }
        }.count
    }

    private func Cell(count: Int) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(count > 0 ? Lens.Color.evidence : Lens.Color.line)
                .frame(width: 6, height: 6)
            Text(count > 0 ? "\(count) passage\(count == 1 ? "" : "s")" : "none")
                .font(Lens.Text.caption)
                .foregroundStyle(count > 0 ? Lens.Color.ink : Lens.Color.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A side is a phrase, and a phrase is a poor column header.
    static func shortLabel(_ side: String) -> String {
        let words = side.split(separator: " ")
        guard words.count > 5 else { return side }
        return words.prefix(5).joined(separator: " ") + "…"
    }
}

/// Academic's paper matrix: each cited work and the claim it supports.
private struct AcademicSection: View {
    let report: ResearchReport

    var body: some View {
        LensSection(title: "Papers and what they support", detail: "Each row is one cited work and the single claim it backs.") {
            VStack(spacing: 0) {
                ForEach(Array(report.result.compilation.citations.enumerated()), id: \.element.id) { index, citation in
                    if let resolved = try? report.result.compilation.resolve(citation.id) {
                        HStack(alignment: .top, spacing: Lens.Space.row) {
                            Text("[\(index + 1)]")
                                .font(Lens.Text.data)
                                .foregroundStyle(Lens.Color.evidence)
                                .frame(width: 26, alignment: .leading)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(resolved.passage.heading)
                                    .font(Lens.Text.label.weight(.semibold))
                                    .foregroundStyle(Lens.Color.ink)
                                    .lineLimit(2)
                                Text(resolved.claim.text)
                                    .font(Lens.Text.body)
                                    .foregroundStyle(Lens.Color.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        if index < report.result.compilation.citations.count - 1 { Divider() }
                    }
                }
            }
            .lensCard()
        }
    }
}

/// News: independence first, then the dated timeline, then what the window and
/// the topical filter removed.
private struct NewsSections: View {
    @ObservedObject var model: ResearchWorkspaceModel
    let report: ResearchReport

    private var timeline: [NewsIndependence.NewsTimelineEntry] {
        NewsIndependence.timeline(
            passages: report.result.records.flatMap(\.passages),
            records: report.result.records,
            publicationDates: model.newsPublicationDates
        )
    }

    private static let stamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: Lens.Space.section) {

            if let depth = report.newsClaimDepth {
                LensSection(
                    title: "How well confirmed this is",
                    detail: "A claim is confirmed when a second independent outlet carries the same report, not when a second URL exists."
                ) {
                    VStack(alignment: .leading, spacing: Lens.Space.row) {
                        Label(depth.summary, systemImage: depth.isThin ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                            .font(Lens.Text.body)
                            .foregroundStyle(depth.isThin ? Lens.Color.caution : Lens.Color.evidence)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("researchIndependence")
                        HStack(spacing: Lens.Space.group) {
                            LensMetric(value: "\(report.independentSourceCount)", label: "domains")
                            LensMetric(value: "\(report.newsVoices.count)", label: "independent voices")
                            LensMetric(value: "\(depth.claimCount)", label: "claims")
                            LensMetric(value: "\(depth.confirmedClaimCount)", label: "confirmed")
                            Spacer(minLength: 0)
                        }
                        if !model.newsRecencySummary.isEmpty {
                            LensNote(
                                systemImage: "calendar",
                                text: "Kept from the last \(ModePolicy.policy(for: .news).timeWindowDays ?? 14) days: \(model.newsRecencySummary)."
                            )
                            .accessibilityIdentifier("researchWindow")
                        }
                    }
                    .padding(Lens.Space.group)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lensCard(inset: true)
                }
            }

            if !timeline.isEmpty {
                LensSection(title: "Timeline", detail: "Newest first. An entry without a reported date is marked rather than dated.") {
                    VStack(spacing: 0) {
                        ForEach(Array(timeline.enumerated()), id: \.element.id) { index, entry in
                            HStack(alignment: .firstTextBaseline, spacing: Lens.Space.row) {
                                Text(entry.publishedAt.map { Self.stamp.string(from: $0) } ?? "—")
                                    .font(Lens.Text.data)
                                    .foregroundStyle(entry.publishedAt == nil ? Lens.Color.caution : Lens.Color.muted)
                                    .frame(width: 52, alignment: .leading)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.headline.isEmpty ? entry.domains.joined(separator: ", ") : entry.headline)
                                        .font(Lens.Text.body)
                                        .foregroundStyle(Lens.Color.ink)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    if !entry.domains.isEmpty {
                                        Text(entry.domains.joined(separator: ", "))
                                            .font(Lens.Text.caption)
                                            .foregroundStyle(Lens.Color.muted)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            if index < timeline.count - 1 { Divider() }
                        }
                    }
                    .lensCard()
                }
            }

            if model.newsOffTopicCount > 0 {
                LensNote(
                    systemImage: model.newsRelevanceStarved ? "questionmark.circle" : "line.3.horizontal.decrease.circle",
                    tint: model.newsRelevanceStarved ? Lens.Color.caution : Lens.Color.muted,
                    text: relevanceNote
                )
            }
        }
    }

    private var relevanceNote: String {
        let count = model.newsOffTopicCount
        let domains = model.newsOffTopicDomains.prefix(3).joined(separator: ", ")
        if model.newsRelevanceStarved {
            return "\(count) recent result\(count == 1 ? "" : "s") did not share a term with the question, so the filter was not applied: the list may be off topic."
        }
        return "\(count) recent result\(count == 1 ? "" : "s") were dropped at discovery for not mentioning the question's subject\(domains.isEmpty ? "" : " (for example \(domains))"). They were never fetched or stored."
    }
}

/// What the evidence covers, per criterion, including what it does not.
private struct CoverageSection: View {
    let report: ResearchReport

    var body: some View {
        LensSection(title: "What the evidence covers", detail: "A criterion is covered when a stored passage uses its vocabulary, not when the word appears by coincidence.") {
            VStack(spacing: 0) {
                ForEach(Array(report.plan.dimensions.enumerated()), id: \.offset) { index, dimension in
                    let count = report.dimensionCoverage[dimension] ?? 0
                    HStack(spacing: Lens.Space.row) {
                        Circle()
                            .fill(count > 0 ? Lens.Color.evidence : Lens.Color.caution)
                            .frame(width: 7, height: 7)
                        Text(dimension)
                            .font(Lens.Text.body)
                            .foregroundStyle(Lens.Color.ink)
                        Spacer(minLength: Lens.Space.row)
                        Text(count > 0 ? "\(count) passage\(count == 1 ? "" : "s")" : "not addressed")
                            .font(Lens.Text.data)
                            .foregroundStyle(count > 0 ? Lens.Color.muted : Lens.Color.caution)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    if index < report.plan.dimensions.count - 1 { Divider() }
                }
            }
            .lensCard()
        }
    }
}

/// The gap the run could not close, with the one action that would. This is the
/// mockup's "open question" card, and it is only rendered when a dimension
/// really has no evidence.
private struct OpenQuestionSection: View {
    @ObservedObject var model: ResearchWorkspaceModel
    let report: ResearchReport

    var body: some View {
        if let gap = report.gapDimensions.first {
            LensSection(title: "Open question") {
                HStack(alignment: .top, spacing: Lens.Space.row) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Lens.Color.caution)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Nothing in the saved passages addresses \(gap).")
                            .font(Lens.Text.body)
                            .foregroundStyle(Lens.Color.ink)
                        Text("A follow-up run spends one bounded round looking for it. \(remainingGaps)")
                            .font(Lens.Text.caption)
                            .foregroundStyle(Lens.Color.muted)
                    }
                    Spacer(minLength: Lens.Space.row)
                    Button {
                        model.researchFirstGap()
                    } label: {
                        Text("Look into this")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Lens.Color.caution)
                    .controlSize(.regular)
                    .accessibilityIdentifier("researchGapButton")
                }
                .padding(Lens.Space.group)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lensCard(inset: true)
            }
        }
    }

    private var remainingGaps: String {
        let others = report.gapDimensions.dropFirst()
        guard !others.isEmpty else { return "It is the only criterion without evidence." }
        return "\(others.count) other criterion without evidence: \(others.joined(separator: ", "))."
    }
}

/// The study card: explain-back prompts, and the claims the boundary refused.
private struct LearnSection: View {
    @ObservedObject var model: ResearchWorkspaceModel
    let report: ResearchReport

    @State private var expanded = false

    private var prompts: [LearningCard.Prompt] {
        model.learningCard(for: report)?.prompts ?? []
    }

    var body: some View {
        if !prompts.isEmpty || !report.result.rejected.isEmpty {
            LensSection(
                title: "Study card",
                detail: "Explain-back prompts written from the citations, and every claim the boundary refused."
            ) {
                VStack(alignment: .leading, spacing: 0) {
                    Button {
                        expanded.toggle()
                    } label: {
                        HStack(spacing: Lens.Space.tight) {
                            Image(systemName: expanded ? "chevron.down" : "chevron.right")
                                .font(.system(size: 9, weight: .semibold))
                            Text(expanded ? "Hide" : "Show \(prompts.count) prompt\(prompts.count == 1 ? "" : "s")\(report.result.rejected.isEmpty ? "" : " and \(report.result.rejected.count) refused claim\(report.result.rejected.count == 1 ? "" : "s")")")
                                .font(Lens.Text.label)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("researchLearnToggle")

                    if expanded {
                        VStack(alignment: .leading, spacing: Lens.Space.group) {
                            ForEach(Array(prompts.enumerated()), id: \.offset) { index, prompt in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(index + 1). \(prompt.question)")
                                        .font(Lens.Text.body.weight(.semibold))
                                        .foregroundStyle(Lens.Color.ink)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text(prompt.answer)
                                        .font(Lens.Text.body)
                                        .foregroundStyle(Lens.Color.muted)
                                        .textSelection(.enabled)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(Lens.Space.row)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .lensCard(inset: true)
                            }
                            if !report.result.rejected.isEmpty {
                                VStack(alignment: .leading, spacing: Lens.Space.tight) {
                                    Text("Refused by the citation boundary")
                                        .font(Lens.Text.label.weight(.semibold))
                                        .foregroundStyle(Lens.Color.ink)
                                    ForEach(Array(report.result.rejected.prefix(5).enumerated()), id: \.offset) { _, rejected in
                                        Text("“\(rejected.proposal.text.prefix(150))” — \(rejected.reason)")
                                            .font(Lens.Text.caption)
                                            .foregroundStyle(Lens.Color.muted)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                        .padding([.horizontal, .bottom], 12)
                    }
                }
                .lensCard()
            }
            .accessibilityIdentifier("researchLearnPanel")
        }
    }
}

/// Numbers two stored pages state differently. Shown side by side; neither is
/// preferred, because the product has no basis to prefer one.
private struct ContrastPanel: View {
    let contradictions: [EvidenceContradiction]

    var body: some View {
        if !contradictions.isEmpty {
            LensSection(
                title: "Two pages disagree",
                detail: "These numbers are stated differently in two stored passages. Neither is preferred here; check the sources."
            ) {
                VStack(alignment: .leading, spacing: Lens.Space.row) {
                    ForEach(contradictions.prefix(5)) { contradiction in
                        VStack(alignment: .leading, spacing: Lens.Space.tight) {
                            Text(contradiction.context)
                                .font(Lens.Text.caption)
                                .foregroundStyle(Lens.Color.muted)
                            ValueRow(value: contradiction.leftValue, sentence: contradiction.leftSentence)
                            ValueRow(value: contradiction.rightValue, sentence: contradiction.rightSentence)
                        }
                        .padding(Lens.Space.row)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lensCard(inset: true)
                    }
                }
            }
            .accessibilityIdentifier("researchContrastHeading")
            .accessibilityIdentifier("researchContrastPanel")
        }
    }

    private func ValueRow(value: String, sentence: String) -> some View {
        HStack(alignment: .top, spacing: Lens.Space.row) {
            Text(value)
                .font(Lens.Text.data.weight(.bold))
                .foregroundStyle(Lens.Color.conflict)
                .frame(width: 62, alignment: .leading)
            Text(sentence)
                .font(Lens.Text.body)
                .foregroundStyle(Lens.Color.ink)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The run's own account of itself: why it stopped, and how to take the answer
/// out of the app.
private struct RunNotesSection: View {
    @ObservedObject var model: ResearchWorkspaceModel
    let report: ResearchReport

    var body: some View {
        LensSection(title: "This run") {
            VStack(alignment: .leading, spacing: Lens.Space.row) {
                LensNote(systemImage: "stop.circle", text: report.stopReason.explanation)
                    .accessibilityIdentifier("researchStopReason")
                Text(roundSummary)
                    .font(Lens.Text.caption)
                    .foregroundStyle(Lens.Color.muted)
            }
            .padding(Lens.Space.group)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lensCard(inset: true)
        }
    }

    private var roundSummary: String {
        let rounds = report.roundLog
        guard !rounds.isEmpty else { return "\(report.rounds) round(s)." }
        return rounds.map { "round \($0.index + 1): \($0.reason.explanation)" }.joined(separator: " ")
    }
}

/// Where the answer goes next. Export is a menu, not four buttons of equal
/// priority, and each item names the format it produces.
private struct ExportSection: View {
    @ObservedObject var model: ResearchWorkspaceModel
    let report: ResearchReport

    @State private var copied: String?

    var body: some View {
        LensSection(
            title: "Take it with you",
            detail: "Copied to the clipboard, from the citations in this run only."
        ) {
            HStack(spacing: Lens.Space.row) {
                Button("Answer and sources") { copy(CitationExport.markdown(artifact), label: "the answer and its sources") }
                Menu("Cite") {
                    Button("BibTeX") { copy(CitationExport.bibTeX(artifact), label: "BibTeX") }
                    Button("RIS") { copy(CitationExport.ris(artifact), label: "RIS") }
                }
                .fixedSize()
                if let lesson = model.learningCard(for: report)?.markdown() {
                    Button("Study card") { copy(lesson, label: "the study card") }
                        .accessibilityIdentifier("researchLessonExport")
                }
                if let copied {
                    Label("Copied \(copied).", systemImage: "checkmark")
                        .font(Lens.Text.caption)
                        .foregroundStyle(Lens.Color.evidence)
                }
                Spacer(minLength: 0)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .font(Lens.Text.label)
            .accessibilityIdentifier("researchExportRow")
        }
    }

    private var artifact: LiveAnswerArtifact {
        LiveAnswerArtifact.make(
            from: report.result,
            provider: model.providerName,
            elapsedSeconds: model.elapsed,
            generatedAt: ""
        )
    }

    private func copy(_ text: String, label: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        copied = label
    }
}

// MARK: - Evidence map

/// The map: every claim filed under the criterion it answers. A claim that
/// matches no criterion is shown under "Other evidence" rather than filed under
/// a wrong one, and a criterion with no claim is not rendered at all — its
/// emptiness is already stated under "What the evidence covers".
private struct EvidenceMapList: View {
    @ObservedObject var model: ResearchWorkspaceModel
    let report: ResearchReport

    private var citations: [LiveAnswerArtifact.Citation] { report.citations(provider: model.providerName) }

    var body: some View {
        VStack(alignment: .leading, spacing: Lens.Space.group) {
            ForEach(groups(), id: \.dimension) { group in
                VStack(alignment: .leading, spacing: Lens.Space.tight) {
                    HStack(spacing: Lens.Space.tight) {
                        Text(group.dimension)
                            .font(Lens.Text.label.weight(.semibold))
                            .foregroundStyle(Lens.Color.ink)
                        Text("\(group.citations.count)")
                            .font(Lens.Text.data)
                            .foregroundStyle(Lens.Color.muted)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Lens.Color.inset, in: Capsule())
                    }
                    VStack(spacing: 0) {
                        ForEach(Array(group.citations.enumerated()), id: \.element.marker) { index, citation in
                            ClaimRow(
                                citation: citation,
                                selected: model.selectedCitation == citation.marker,
                                support: report.newsSnapshotSupport[citation.snapshotID]
                            ) {
                                model.selectedCitation = citation.marker
                            }
                            if index < group.citations.count - 1 { Divider() }
                        }
                    }
                    .lensCard()
                }
            }
        }
    }

    private func groups() -> [(dimension: String, citations: [LiveAnswerArtifact.Citation])] {
        let dimensions = report.plan.dimensions.isEmpty ? ["Answer"] : report.plan.dimensions
        var grouped: [String: [LiveAnswerArtifact.Citation]] = [:]
        var unmatched: [LiveAnswerArtifact.Citation] = []
        for citation in citations {
            let haystack = citation.claimText + " " + (citation.passageText ?? citation.quote)
            if let match = dimensions.first(where: { DimensionLexicon.covers($0, text: haystack) }) {
                grouped[match, default: []].append(citation)
            } else {
                unmatched.append(citation)
            }
        }
        var result = dimensions.compactMap { dimension -> (String, [LiveAnswerArtifact.Citation])? in
            guard let items = grouped[dimension], !items.isEmpty else { return nil }
            return (dimension, items)
        }
        if !unmatched.isEmpty {
            result.append((dimensions.count == 1 ? dimensions[0] : "Other evidence", unmatched))
        }
        return result
    }
}

/// One claim: a coloured rail, the claim, the source it came from, and how many
/// independent voices carry it.
private struct ClaimRow: View {
    let citation: LiveAnswerArtifact.Citation
    let selected: Bool
    var support: Int?
    let action: () -> Void

    @State private var hovering = false

    private var verdict: SupportVerdict {
        guard let support, support > 0 else { return .singleSource }
        return support >= 2 ? .supports(support) : .singleSource
    }

    private var domain: String {
        guard let url = citation.sourceURL, let host = url.host else { return citation.heading }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: Lens.Space.row) {
                Rectangle()
                    .fill(selected ? Lens.Color.evidence : Lens.Color.evidence.opacity(0.35))
                    .frame(width: 3)
                VStack(alignment: .leading, spacing: 4) {
                    Text("[\(citation.marker)] \(citation.claimText)")
                        .font(Lens.Text.body)
                        .foregroundStyle(Lens.Color.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: Lens.Space.tight) {
                        Text(domain)
                            .font(Lens.Text.caption)
                            .foregroundStyle(Lens.Color.muted)
                            .lineLimit(1)
                        if support != nil {
                            VerdictChip(verdict: verdict, compact: true)
                        }
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: selected ? "chevron.right.circle.fill" : "chevron.right.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(selected ? Lens.Color.evidence : Lens.Color.faint)
                    .padding(.top, 1)
            }
            .padding(.vertical, 10)
            .padding(.leading, 0)
            .padding(.trailing, 11)
            .background(selected ? Lens.Color.evidence.opacity(0.07) : (hovering ? Lens.Color.inset.opacity(0.6) : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel("Claim \(citation.marker): \(citation.claimText), source \(domain)")
    }
}

// MARK: - Evidence column

private struct EvidenceColumn: View {
    @ObservedObject var model: ResearchWorkspaceModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Lens.Space.tight) {
                Text("Evidence")
                    .font(Lens.Text.label.weight(.semibold))
                    .foregroundStyle(Lens.Color.ink)
                Spacer(minLength: 0)
                Image(systemName: "link")
                    .font(.system(size: 11))
                    .foregroundStyle(Lens.Color.evidence)
                    .help("Citations link to stored passages. Claims are not independently fact-checked.")
                    .accessibilityLabel("Citations linked to stored passages; facts not independently verified")
            }
            .padding(.horizontal, Lens.Space.group)
            .padding(.vertical, 12)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: Lens.Space.group) {
                    evidenceMap
                    inspectorBody
                }
                .padding(Lens.Space.group)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.automatic)
            Divider()
            ConnectionPanel(model: model)
        }
        .background(Lens.Color.canvas)
    }

    /// The map first, the selected passage under it: the sidebar answers "which
    /// claim rests on what", and then shows the passage the reader picked.
    @ViewBuilder
    private var evidenceMap: some View {
        if case let .completed(report) = model.phase {
            EvidenceMapList(model: model, report: report)
        }
    }

    @ViewBuilder
    private var inspectorBody: some View {
        switch model.phase {
        case let .completed(report):
            CitationInspector(
                citations: report.citations(provider: model.providerName),
                selected: model.selectedCitation,
                support: report.newsSnapshotSupport
            )
        case let .preview(result):
            if let index = model.selectedCitation, result.passages.indices.contains(index - 1) {
                let passage = result.passages[index - 1]
                PassageInspector(
                    heading: passage.heading,
                    text: passage.text,
                    quote: nil,
                    passageID: passage.id,
                    snapshotID: passage.snapshotID,
                    sourceURL: result.records.first { $0.snapshot.id == passage.snapshotID }?.finalURL
                )
            } else {
                Placeholder("Select a saved passage to read it here.")
            }
        case let .recorded(entry):
            CitationInspector(citations: entry.citations, selected: model.selectedCitation)
        default:
            Placeholder("The exact passage behind a claim appears here the moment you select the claim.")
        }
    }
}

private struct Placeholder: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(Lens.Text.label)
            .foregroundStyle(Lens.Color.muted)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct CitationInspector: View {
    let citations: [LiveAnswerArtifact.Citation]
    let selected: Int?
    var support: [String: Int] = [:]

    var body: some View {
        if let citation = citations.first(where: { $0.marker == selected }) ?? citations.first {
            PassageInspector(
                heading: citation.heading,
                text: citation.passageText ?? citation.quote,
                quote: citation.quote,
                passageID: citation.passageID,
                snapshotID: citation.snapshotID,
                sourceURL: citation.sourceURL,
                support: support[citation.snapshotID]
            )
        } else {
            Placeholder("No citation resolved.")
        }
    }
}

/// One stored passage. The quote is the exact span the claim used; the passage
/// is the wider block it came from.
private struct PassageInspector: View {
    let heading: String
    let text: String
    let quote: String?
    let passageID: String
    let snapshotID: String
    let sourceURL: URL?
    var support: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Lens.Space.group) {

            VStack(alignment: .leading, spacing: Lens.Space.tight) {
                Text(heading)
                    .font(Lens.Text.label.weight(.semibold))
                    .foregroundStyle(Lens.Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let sourceURL {
                    Link(destination: sourceURL) {
                        HStack(spacing: 4) {
                            Text(host(sourceURL))
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 9))
                        }
                        .font(Lens.Text.caption)
                        .foregroundStyle(Lens.Color.evidence)
                    }
                }
                if let support, support > 0 {
                    VerdictChip(verdict: support >= 2 ? .supports(support) : .singleSource)
                        .accessibilityIdentifier("researchClaimSupport")
                }
            }

            if let quote {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cited quote")
                        .font(Lens.Text.caption)
                        .foregroundStyle(Lens.Color.muted)
                    Text(quote)
                        .font(Lens.Text.body)
                        .foregroundStyle(Lens.Color.ink)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Lens.Space.row)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lensCard(inset: true)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Stored passage")
                    .font(Lens.Text.caption)
                    .foregroundStyle(Lens.Color.muted)
                Text(text)
                    .font(Lens.Text.body)
                    .lineSpacing(3)
                    .foregroundStyle(Lens.Color.ink)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("\(passageID.prefix(12))… · \(snapshotID.prefix(12))…")
                .font(Lens.Text.caption)
                .foregroundStyle(Lens.Color.faint)
                .textSelection(.enabled)
                .help("Passage and snapshot identifiers, so the same stored text can be found again.")
        }
    }

    private func host(_ url: URL) -> String {
        guard let host = url.host else { return url.absoluteString }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}

/// Storage and connection live at the bottom of the evidence column: they are
/// about what the app keeps and who answers, not about the current answer.
private struct ConnectionPanel: View {
    @ObservedObject var model: ResearchWorkspaceModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DisclosureGroup("Storage and privacy", isExpanded: $model.privacyExpanded) {
                StorageBody(model: model)
            }
            Divider()
            DisclosureGroup("Connection", isExpanded: $model.connectionExpanded) {
                // Reading the keychain is what makes macOS ask for permission,
                // so it happens when the panel is opened or a run starts.
                EmptyView().onAppear { model.loadStoredSecretsIfNeeded() }
                ConnectionBody(model: model)
            }
            .accessibilityIdentifier("researchConnection")
        }
        .font(Lens.Text.label)
        .padding(.horizontal, Lens.Space.group)
        .padding(.vertical, 12)
    }
}

private struct StorageBody: View {
    @ObservedObject var model: ResearchWorkspaceModel

    var body: some View {
        VStack(alignment: .leading, spacing: Lens.Space.row) {
            Text(model.storageSummary.isEmpty ? "Counting what is on disk…" : model.storageSummary)
                .font(Lens.Text.label)
                .foregroundStyle(Lens.Color.ink)
                .accessibilityIdentifier("researchStorageSummary")
            Text("Saved runs stay on this Mac. Searches send the question to the chosen search service. A hosted answer sends the question and selected passages to DeepSeek; Find evidence does not call an answer model.")
                .font(Lens.Text.caption)
                .foregroundStyle(Lens.Color.muted)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Lens.Space.tight) {
                Button("Refresh") { model.refreshStorageSummary() }
                Button("Copy diagnostics") { model.copyDiagnostics() }
                    .accessibilityIdentifier("researchCopyDiagnostics")
                Button("Delete saved runs", role: .destructive) {
                    model.confirmClearHistory = true
                }
                .accessibilityIdentifier("researchClearHistory")
            }
            .controlSize(.small)
            if !model.diagnosticsMessage.isEmpty {
                Text(model.diagnosticsMessage)
                    .font(Lens.Text.caption)
                    .foregroundStyle(Lens.Color.evidence)
                    .accessibilityIdentifier("researchPrivacyMessage")
            }
        }
        .padding(.top, Lens.Space.tight)
        .onAppear { model.refreshStorageSummary() }
    }
}

private struct ConnectionBody: View {
    @ObservedObject var model: ResearchWorkspaceModel

    var body: some View {
        VStack(alignment: .leading, spacing: Lens.Space.row) {
            if !model.keychainMessage.isEmpty {
                VStack(alignment: .leading, spacing: Lens.Space.tight) {
                    Label(model.keychainMessage, systemImage: "lock.trianglebadge.exclamationmark")
                        .font(Lens.Text.caption)
                        .foregroundStyle(Lens.Color.caution)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("researchKeychainMessage")
                    Button("Grant access") { model.requestKeychainAccess() }
                        .controlSize(.small)
                        .accessibilityIdentifier("researchGrantKeychain")
                }
            }

            Picker("Search", selection: $model.searchBackend) {
                ForEach(ResearchWorkspaceModel.SearchBackend.allCases) { backend in
                    Text(backend.label).tag(backend)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch model.searchBackend {
            case .tavily:
                SecureField("Tavily key", text: $model.tavilyKey).textFieldStyle(.roundedBorder)
            case .brave:
                SecureField("Brave key", text: $model.braveKey).textFieldStyle(.roundedBorder)
            case .searxng:
                TextField("SearXNG endpoint", text: $model.endpoint).textFieldStyle(.roundedBorder)
            }
            Button("Save search key") { model.saveSearchKey() }.controlSize(.small)

            Divider()

            SecureField("DeepSeek key", text: $model.providerKey).textFieldStyle(.roundedBorder)
            Button("Save answer key") { model.saveProviderKey() }.controlSize(.small)

            Divider()

            Toggle("Answer with a local model", isOn: $model.useLocalProvider)
                .toggleStyle(.checkbox)
            if model.useLocalProvider {
                TextField("Endpoint", text: $model.localEndpoint).textFieldStyle(.roundedBorder)
                TextField("Model", text: $model.localModel).textFieldStyle(.roundedBorder)
            }
            Text(model.useLocalProvider
                 ? "A loopback OpenAI-compatible server (Ollama, llama.cpp, LM Studio). No key, no cloud call, and every artifact is labelled local."
                 : "Academic mode discovers through OpenAlex, which needs no key. A saved answer key is still needed for a hosted written answer.")
                .font(Lens.Text.caption)
                .foregroundStyle(Lens.Color.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, Lens.Space.tight)
    }
}

// MARK: - History

private struct HistorySidebar: View {
    @ObservedObject var model: ResearchWorkspaceModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Saved runs")
                    .font(Lens.Text.label.weight(.semibold))
                    .foregroundStyle(Lens.Color.ink)
                Spacer()
                if !model.history.isEmpty {
                    Button("Delete all") { model.confirmClearHistory = true }
                        .buttonStyle(.plain)
                        .font(Lens.Text.caption)
                        .foregroundStyle(Lens.Color.conflict)
                }
            }
            .padding(.horizontal, Lens.Space.group)
            .padding(.vertical, 12)
            Divider()
            if model.history.isEmpty {
                Text("Completed runs are listed here. Nothing else is kept.")
                    .font(Lens.Text.caption)
                    .foregroundStyle(Lens.Color.muted)
                    .padding(Lens.Space.group)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(model.history) { entry in
                            Button {
                                model.open(entry)
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(entry.question)
                                        .font(Lens.Text.label)
                                        .foregroundStyle(Lens.Color.ink)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    Text("\(entry.mode.rawValue) · \(entry.citationCount) cited · \(Self.displayDate(entry.completedAt))")
                                        .font(Lens.Text.caption)
                                        .foregroundStyle(Lens.Color.muted)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, Lens.Space.group)
                                .padding(.vertical, Lens.Space.row)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .background(isSelected(entry) ? Lens.Color.evidence.opacity(0.09) : Color.clear)
                            .contextMenu {
                                Button("Delete", role: .destructive) { model.delete(entry) }
                            }
                            Divider()
                        }
                    }
                }
            }
        }
        .background(Lens.Color.canvas)
    }

    private func isSelected(_ entry: ResearchHistoryEntry) -> Bool {
        if case let .recorded(open) = model.phase { return open.id == entry.id }
        return false
    }

    private static func displayDate(_ timestamp: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: timestamp) else { return timestamp }
        if Calendar.current.isDateInToday(date) {
            return "Today \(date.formatted(date: .omitted, time: .shortened))"
        }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

// MARK: - Preview, recorded, stopped

private struct PreviewBrief: View {
    @ObservedObject var model: ResearchWorkspaceModel
    let result: LiveRetrievalResult

    var body: some View {
        VStack(alignment: .leading, spacing: Lens.Space.section) {
            VStack(alignment: .leading, spacing: Lens.Space.tight) {
                Text("Saved passages")
                    .font(Lens.Text.display)
                    .foregroundStyle(Lens.Color.ink)
                Text("\(result.passages.count) matching passages from \(result.openedSources) opened sources. This is source text, not a generated answer: no AI was used and nothing here is a verified citation.")
                    .font(Lens.Text.body)
                    .foregroundStyle(Lens.Color.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Array(result.passages.enumerated()), id: \.element.id) { index, passage in
                Button {
                    model.selectedCitation = index + 1
                } label: {
                    VStack(alignment: .leading, spacing: Lens.Space.tight) {
                        HStack {
                            Text("Passage \(index + 1)")
                                .font(Lens.Text.caption)
                                .foregroundStyle(Lens.Color.muted)
                            Spacer(minLength: 0)
                            if let host = result.records.first(where: { $0.snapshot.id == passage.snapshotID })?.finalURL.host {
                                Text(host)
                                    .font(Lens.Text.caption)
                                    .foregroundStyle(Lens.Color.muted)
                            }
                        }
                        Text(passage.heading)
                            .font(Lens.Text.label.weight(.semibold))
                            .foregroundStyle(Lens.Color.ink)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Text(passage.text)
                            .font(Lens.Text.body)
                            .foregroundStyle(Lens.Color.ink)
                            .lineLimit(6)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Lens.Space.group)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .lensCard(highlighted: model.selectedCitation == index + 1)
            }
        }
    }
}

private struct RecordedBrief: View {
    @ObservedObject var model: ResearchWorkspaceModel
    let entry: ResearchHistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: Lens.Space.section) {
            VStack(alignment: .leading, spacing: Lens.Space.tight) {
                Text(entry.question)
                    .font(Lens.Text.display)
                    .foregroundStyle(Lens.Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("A saved \(entry.mode.rawValue) run from \(entry.citationCount) cited passages, replayed without a network call. This compact replay keeps the answer and citations, not the original mode panels. A citation shows what a source said, not whether it is true.")
                    .font(Lens.Text.body)
                    .foregroundStyle(Lens.Color.muted)
                    .fixedSize(horizontal: false, vertical: true)
                if entry.mode == .news {
                    Label("Time-sensitive claims may be outdated or single-source. Check the linked pages before relying on them.", systemImage: "clock.badge.exclamationmark")
                        .font(Lens.Text.label)
                        .foregroundStyle(Lens.Color.caution)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            SummaryCard(text: entry.answer)
            ExportSectionRecorded(entry: entry)
        }
    }
}

private struct SummaryCard: View {
    let text: String

    var body: some View {
        Text(readableAnswer(text))
            .font(Lens.Text.reading)
            .lineSpacing(5)
            .foregroundStyle(Lens.Color.ink)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Add breathing room between compiled citation-marked claims without changing
/// the saved or exported answer text.
private func readableAnswer(_ answer: String) -> String {
    answer.replacingOccurrences(
        of: #"(\[\d+\])\s+(?=\S)"#,
        with: "$1\n\n",
        options: .regularExpression
    )
}

private struct ExportSectionRecorded: View {
    let entry: ResearchHistoryEntry

    @State private var copied: String?

    var body: some View {
        LensSection(title: "Take it with you", detail: "From the citations in this saved run only.") {
            HStack(spacing: Lens.Space.row) {
                Button("Answer and sources") { copy(CitationExport.markdown(entry.artifact), label: "the answer and its sources") }
                Menu("Cite") {
                    Button("BibTeX") { copy(CitationExport.bibTeX(entry.artifact), label: "BibTeX") }
                    Button("RIS") { copy(CitationExport.ris(entry.artifact), label: "RIS") }
                }
                .fixedSize()
                if let copied {
                    Label("Copied \(copied).", systemImage: "checkmark")
                        .font(Lens.Text.caption)
                        .foregroundStyle(Lens.Color.evidence)
                }
                Spacer(minLength: 0)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .font(Lens.Text.label)
        }
    }

    private func copy(_ text: String, label: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        copied = label
    }
}

private struct StoppedBrief: View {
    @ObservedObject var model: ResearchWorkspaceModel
    let reason: String
    let hint: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Lens.Space.group) {
            Label("Research stopped", systemImage: "exclamationmark.circle")
                .font(Lens.Text.display)
                .foregroundStyle(Lens.Color.ink)
            Text(reason)
                .font(Lens.Text.body)
                .foregroundStyle(Lens.Color.muted)
                .fixedSize(horizontal: false, vertical: true)
            if let hint {
                Text(hint)
                    .font(Lens.Text.caption)
                    .foregroundStyle(Lens.Color.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityIdentifier("researchStopped")
    }
}

// MARK: - Global launcher

private struct GlobalLauncherView: View {
    @ObservedObject var model: ResearchWorkspaceModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Lens.Space.group) {
            Text("Ask from anywhere")
                .font(Lens.Text.section)
                .foregroundStyle(Lens.Color.ink)

            QuestionField(question: $query) { launch() }

            Picker("Mode", selection: $model.mode) {
                ForEach(ResearchMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            HStack {
                Text(ModePolicy.policy(for: model.mode).boundarySummary)
                    .font(Lens.Text.caption)
                    .foregroundStyle(Lens.Color.muted)
                Spacer()
                Button("Ask") { launch() }
                    .buttonStyle(.borderedProminent)
                    .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .controlSize(.large)

            if !model.history.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(model.history.prefix(4).enumerated()), id: \.element.id) { index, entry in
                        Button {
                            query = entry.question
                            model.mode = entry.mode
                        } label: {
                            HStack {
                                Text(entry.question)
                                    .font(Lens.Text.body)
                                    .foregroundStyle(Lens.Color.ink)
                                    .lineLimit(1)
                                Spacer()
                                Text(entry.mode.rawValue)
                                    .font(Lens.Text.caption)
                                    .foregroundStyle(Lens.Color.muted)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if index < min(model.history.count, 4) - 1 { Divider() }
                    }
                }
                .lensCard()
            }
        }
        .padding(Lens.Space.page)
        .frame(width: 620)
        .background(Lens.Color.canvas)
    }

    private func launch() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        model.question = trimmed
        dismiss()
        model.askWithAI()
    }
}

// MARK: - Narrow layout

private struct LensNarrowKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True when the window is too narrow for a side column. The inspector then
    /// moves into a sheet instead of being dropped.
    var lensNarrow: Bool {
        get { self[LensNarrowKey.self] }
        set { self[LensNarrowKey.self] = newValue }
    }
}

// MARK: - Report conveniences

private extension ResearchReport {
    /// The citation list the artifact carries, built the same way everywhere so
    /// the map, the inspector, and the exports cannot disagree.
    func citations(provider: String) -> [LiveAnswerArtifact.Citation] {
        LiveAnswerArtifact.make(from: result, provider: provider, elapsedSeconds: 0, generatedAt: "").citations
    }
}

private extension ResearchMode {
    var tagline: String {
        switch self {
        case .quick: "One bounded pass: answer first, evidence second."
        case .deep: "Compare and investigate with bounded follow-up rounds."
        case .academic: "Scholarly metadata first, then exact passages from the paper page."
        case .news: "Time-bounded, with visible source independence."
        }
    }
}
