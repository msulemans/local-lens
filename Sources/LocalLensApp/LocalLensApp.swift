import LocalLensCore
import SwiftUI

@main
struct LocalLensApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// Selects the rendered view: the M001 deterministic fixture by default, the
/// M003.4 deterministic Quick view when asked. `quick-map` and `map` start on
/// the evidence map instead of the citation list.
struct RootView: View {
    private let startView = ProcessInfo.processInfo.environment["LOCAL_LENS_START_VIEW"]

    var body: some View {
        switch startView {
        case "quick", "quick-map":
            QuickRunView()
        default:
            FixtureRunView()
        }
    }
}

private enum LoadState {
    case loading
    case loaded(PersistedRun, [CitationInspection], EvidenceMap)
    case failed(String)
}

/// The M001 deterministic fixture view. It is unchanged in behavior: the same
/// fixture, the same persisted run id, the same rendering.
struct FixtureRunView: View {
    @State private var state: LoadState = .loading
    @State private var selectedCitationID: String?
    @State private var showsMap = ProcessInfo.processInfo.environment["LOCAL_LENS_START_VIEW"] == "map"

    var body: some View {
        RunScaffold(
            state: state,
            selectedCitationID: $selectedCitationID,
            showsMap: $showsMap,
            loadingMessage: "Running the deterministic fixture…",
            failureTitle: "Fixture run failed",
            failureHint: "Start the app from the repository root so Fixtures/deterministic/quick-coffee.json is found."
        )
        .task { await load() }
    }

    @MainActor
    private func load() async {
        do {
            let repositoryRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            let fixtureURL = repositoryRoot.appendingPathComponent("Fixtures/deterministic/quick-coffee.json")
            let corpus = try FixtureWorkspace.loadFixture(from: fixtureURL)
            let store = try makeRunStore()

            let persisted: PersistedRun
            if let existing = try? store.load(runID: "fixture-run") {
                persisted = existing
            } else {
                persisted = try await DeterministicPipeline.run(corpus)
                try store.save(persisted)
            }

            let inspections = try FixtureWorkspace.inspections(in: persisted.result)
            let map = try FixtureWorkspace.evidenceMap(in: persisted.result)
            selectedCitationID = inspections.first?.citation.id
            state = .loaded(persisted, inspections, map)
        } catch {
            state = .failed(String(describing: error))
        }
    }
}

/// The M003.4 deterministic Quick view. It runs the M003.3 pipeline over the
/// frozen Quick view fixture through a real store and lexical index, persists
/// the run under its own id, and renders retrieval-backed citations and the
/// evidence map. No model, network, or clock is involved.
struct QuickRunView: View {
    @State private var state: LoadState = .loading
    @State private var selectedCitationID: String?
    @State private var showsMap = ProcessInfo.processInfo.environment["LOCAL_LENS_START_VIEW"] == "quick-map"

    var body: some View {
        RunScaffold(
            state: state,
            selectedCitationID: $selectedCitationID,
            showsMap: $showsMap,
            loadingMessage: "Running the deterministic Quick pipeline…",
            failureTitle: "Quick run failed",
            failureHint: "Start the app from the repository root so Fixtures/retrieval/quick-view.json is found."
        )
        .task { await load() }
    }

    @MainActor
    private func load() async {
        do {
            let repositoryRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            let fixtureURL = repositoryRoot.appendingPathComponent("Fixtures/retrieval/quick-view.json")
            let corpus = try QuickCorpus.load(from: fixtureURL)
            let runStore = try makeRunStore()

            let persisted: PersistedRun
            if let existing = try? runStore.load(runID: "quick-run") {
                persisted = existing
            } else {
                guard let question = corpus.questions.first else {
                    state = .failed("The Quick view fixture contains no question.")
                    return
                }
                let indexed = try await corpus.makeIndexedStore()
                persisted = try await QuickPipeline.run(
                    corpus.plan(for: question),
                    store: indexed.store,
                    index: indexed.index,
                    runID: "quick-run"
                )
                try runStore.save(persisted)
            }

            let inspections = try FixtureWorkspace.inspections(in: persisted.result)
            let map = try FixtureWorkspace.evidenceMap(in: persisted.result)
            selectedCitationID = inspections.first?.citation.id
            state = .loaded(persisted, inspections, map)
        } catch {
            state = .failed(String(describing: error))
        }
    }
}

// MARK: - Shared scaffold

private struct RunScaffold: View {
    let state: LoadState
    @Binding var selectedCitationID: String?
    @Binding var showsMap: Bool
    let loadingMessage: String
    let failureTitle: String
    let failureHint: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
        }
        .frame(minWidth: 940, minHeight: 600)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Local Lens")
                .font(.largeTitle.weight(.semibold))
            Text("Evidence-native search for Mac")
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            Spacer()
            ProgressView(loadingMessage)
                .frame(maxWidth: .infinity)
            Spacer()
        case let .failed(message):
            VStack(alignment: .leading, spacing: 8) {
                Text(failureTitle)
                    .font(.headline)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.red)
                Text(failureHint)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            Spacer()
        case let .loaded(persisted, inspections, map):
            RunDetailView(
                persisted: persisted,
                inspections: inspections,
                map: map,
                selectedCitationID: $selectedCitationID,
                showsMap: $showsMap
            )
        }
    }
}

private struct RunDetailView: View {
    let persisted: PersistedRun
    let inspections: [CitationInspection]
    let map: EvidenceMap
    @Binding var selectedCitationID: String?
    @Binding var showsMap: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            leftPane
                .frame(minWidth: 340, idealWidth: 400, maxWidth: 480)
            Divider()
            inspector
        }
    }

    private var leftPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(persisted.result.run.question)
                .font(.headline)
            Text("\(persisted.result.run.mode.rawValue) · \(persisted.result.run.status.rawValue) · \(persisted.result.citations.count) citations")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(persisted.result.summary)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Picker("View", selection: $showsMap) {
                Text("Citations").tag(false)
                Text("Map").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if showsMap {
                mapGrid
            } else {
                citationListBody
            }
        }
        .padding(16)
    }

    private var citationListBody: some View {
        List(inspections, id: \.citation.id, selection: $selectedCitationID) { inspection in
            VStack(alignment: .leading, spacing: 4) {
                Text(inspection.claim.dimension)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(inspection.claim.text)
                    .font(.body)
            }
            .tag(inspection.citation.id)
        }
        .listStyle(.sidebar)
    }

    private var mapGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(map.nodes) { node in
                    Button {
                        selectedCitationID = node.citationID
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(node.claim.dimension)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                relationBadge(node.relation)
                            }
                            Text(node.claim.text)
                                .font(.callout)
                                .multilineTextAlignment(.leading)
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(relationColor(node.relation))
                                    .frame(width: 8, height: 8)
                                Text(node.source.title)
                                    .font(.caption)
                                    .lineLimit(1)
                                Spacer()
                                Text(relationLabel(node.relation))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            selectedCitationID == node.citationID
                                ? Color.accentColor.opacity(0.18)
                                : Color.secondary.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(node.claim.dimension): \(node.claim.text), relation \(relationLabel(node.relation)), source \(node.source.title)")
                }
                Text("\(map.nodes.count) claims · \(map.sources.count) sources · relations shown as colour and text")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func relationLabel(_ relation: EvidenceRelation) -> String {
        relation.rawValue.replacingOccurrences(of: "_", with: " ")
    }

    private func relationColor(_ relation: EvidenceRelation) -> Color {
        switch relation {
        case .supports:
            .green
        case .partiallySupports:
            .orange
        case .conflicts:
            .red
        }
    }

    private func relationBadge(_ relation: EvidenceRelation) -> some View {
        Text(relationLabel(relation))
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(relationColor(relation).opacity(0.15), in: Capsule())
            .foregroundStyle(relationColor(relation))
    }

    private var inspector: some View {
        Group {
            if let id = selectedCitationID, let inspection = inspections.first(where: { $0.citation.id == id }) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(inspection.source.title)
                            .font(.headline)
                        Text("\(inspection.source.publisher) · \(inspection.source.canonicalURL.absoluteString)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(inspection.passage.heading)
                            .font(.subheadline.weight(.semibold))
                        Text(inspection.passage.text)
                            .font(.body)
                            .textSelection(.enabled)
                        Divider()
                        Text("Exact saved passage · text hash \(String(inspection.passage.textHash.prefix(12)))…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                }
            } else {
                Text("Select a citation to open its exact saved passage")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private func makeRunStore() throws -> RunStore {
    let base = try FileManager.default.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
    )
    return RunStore(directory: base.appendingPathComponent("LocalLens/runs", isDirectory: true))
}
