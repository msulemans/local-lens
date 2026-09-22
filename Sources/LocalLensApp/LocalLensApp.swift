import LocalLensCore
import SwiftUI

@main
struct LocalLensApp: App {
    var body: some Scene {
        WindowGroup {
            FixtureRunView()
        }
    }
}

private enum LoadState {
    case loading
    case loaded(PersistedRun, [CitationInspection], EvidenceMap)
    case failed(String)
}

struct FixtureRunView: View {
    @State private var state: LoadState = .loading
    @State private var selectedCitationID: String?
    @State private var showsMap = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
        }
        .frame(minWidth: 940, minHeight: 600)
        .task { await load() }
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
            ProgressView("Running the deterministic fixture…")
                .frame(maxWidth: .infinity)
            Spacer()
        case let .failed(message):
            VStack(alignment: .leading, spacing: 8) {
                Text("Fixture run failed")
                    .font(.headline)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.red)
                Text("Start the app from the repository root so Fixtures/deterministic/quick-coffee.json is found.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            Spacer()
        case let .loaded(persisted, inspections, map):
            HStack(alignment: .top, spacing: 0) {
                leftPane(persisted: persisted, inspections: inspections, map: map)
                    .frame(minWidth: 340, idealWidth: 400, maxWidth: 480)
                Divider()
                inspector(inspections: inspections)
            }
        }
    }

    private func leftPane(persisted: PersistedRun, inspections: [CitationInspection], map: EvidenceMap) -> some View {
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
                mapGrid(map: map)
            } else {
                citationListBody(inspections: inspections)
            }
        }
        .padding(16)
    }

    private func citationListBody(inspections: [CitationInspection]) -> some View {
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

    private func mapGrid(map: EvidenceMap) -> some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(map.nodes) { node in
                    Button {
                        selectedCitationID = node.citationID
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(node.claim.dimension)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(node.claim.text)
                                .font(.callout)
                                .multilineTextAlignment(.leading)
                            Divider()
                            Text("\(node.relation.rawValue.replacingOccurrences(of: "_", with: " ")) · \(node.source.publisher)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
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
                    .accessibilityLabel("\(node.claim.dimension): \(node.claim.text), relation \(node.relation.rawValue), source \(node.source.title)")
                }
            }
        }
    }

    private func inspector(inspections: [CitationInspection]) -> some View {
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

    @MainActor
    private func load() async {
        do {
            let repositoryRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            let fixtureURL = repositoryRoot.appendingPathComponent("Fixtures/deterministic/quick-coffee.json")
            let corpus = try FixtureWorkspace.loadFixture(from: fixtureURL)
            let store = try makeStore()

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

    private func makeStore() throws -> RunStore {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return RunStore(directory: base.appendingPathComponent("LocalLens/runs", isDirectory: true))
    }
}
