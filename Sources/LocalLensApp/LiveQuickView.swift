import Foundation
import LocalLensCore
import Security
import SwiftUI

/// The live workspace. No network operation starts until the person asks a
/// question or explicitly inspects a supplied page.
struct LiveQuickView: View {
    @State private var question = ""
    @State private var endpoint = "http://127.0.0.1:8888"
    @State private var providedPage = ""
    @State private var providerKey = SecretKeyStore.load(service: "locallens-deepseek") ?? ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"] ?? ""
    @State private var tavilyKey = SecretKeyStore.load(service: "locallens-tavily-search") ?? ProcessInfo.processInfo.environment["TAVILY_API_KEY"] ?? ""
    @State private var braveKey = SecretKeyStore.load(service: "locallens-brave-search") ?? ProcessInfo.processInfo.environment["BRAVE_SEARCH_API_KEY"] ?? ""
    @State private var searchBackend: SearchBackend = .tavily
    @State private var previewRequested = false
    @State private var phase: Phase = .idle
    @State private var selectedMarker = 1
    @State private var connectionExpanded = false
    @FocusState private var questionFocused: Bool

    private enum Phase {
        case idle
        case running
        case preview(LiveRetrievalResult)
        case completed(LiveAnswerArtifact)
        case stopped(message: String, hint: String?)
    }

    private enum SearchBackend: String, CaseIterable, Identifiable {
        case tavily
        case brave
        case searxng

        var id: Self { self }
    }

    private enum Palette {
        static let ink = Color(red: 0.10, green: 0.15, blue: 0.19)
        static let muted = Color(red: 0.37, green: 0.44, blue: 0.47)
        static let sea = Color(red: 0.09, green: 0.43, blue: 0.46)
        static let paper = Color(red: 0.96, green: 0.97, blue: 0.96)
        static let line = Color(red: 0.83, green: 0.87, blue: 0.85)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Rectangle().fill(Palette.line).frame(height: 1)
            HStack(spacing: 0) {
                mainPane
                    .frame(minWidth: 480, maxWidth: .infinity)
                Rectangle().fill(Palette.line).frame(width: 1)
                evidencePane
                    .frame(width: 340)
            }
        }
        .frame(minWidth: 920, minHeight: 680)
        .background(Palette.paper)
        .preferredColorScheme(.light)
        .task { autoRunEvidenceQuestionIfConfigured() }
    }

    /// Evidence-only automation, gated by an explicit environment variable and
    /// off for every normal launch. It mirrors the `LOCAL_LENS_START_VIEW`
    /// capture precedent (D014): a live ask can be reproduced for a recorded
    /// result without faking keystrokes. `LOCAL_LENS_LIVE_QUESTION` supplies the
    /// question, `LOCAL_LENS_LIVE_SOURCE_URL` an optional page, and
    /// `LOCAL_LENS_LIVE_OUT` a path to write the completed artifact to.
    private func autoRunEvidenceQuestionIfConfigured() {
        guard case .idle = phase else { return }
        let environment = ProcessInfo.processInfo.environment
        guard let autoQuestion = environment["LOCAL_LENS_LIVE_QUESTION"]?
            .trimmingCharacters(in: .whitespacesAndNewlines), !autoQuestion.isEmpty else { return }
        question = autoQuestion
        if let page = environment["LOCAL_LENS_LIVE_SOURCE_URL"]?
            .trimmingCharacters(in: .whitespacesAndNewlines), !page.isEmpty {
            providedPage = page
        }
        ask()
    }

    /// Writes the completed artifact only when the evidence hook asked for it.
    private func writeEvidenceArtifactIfRequested(_ artifact: LiveAnswerArtifact) {
        guard let out = ProcessInfo.processInfo.environment["LOCAL_LENS_LIVE_OUT"]?
            .trimmingCharacters(in: .whitespacesAndNewlines), !out.isEmpty else { return }
        try? artifact.write(to: URL(fileURLWithPath: out))
    }

    private var topBar: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Palette.sea)
                    .frame(width: 36, height: 36)
                Image(systemName: "text.book.closed.fill")
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("Local Lens")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                Text("QUICK / LIVE RESEARCH")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(Palette.muted)
            }
            Spacer()
            Text(runDisclosure)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(Palette.sea)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Palette.sea.opacity(0.10), in: Capsule())
                .accessibilityLabel(runDisclosure)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
    }

    private var mainPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Ask the web. Inspect the proof.")
                .font(.system(size: 31, weight: .semibold, design: .rounded))
                .tracking(-1)
                .foregroundStyle(Palette.ink)
                .padding(.bottom, 7)
            Text("Every answer claim must point to a saved passage, not a search snippet.")
                .font(.system(size: 13))
                .foregroundStyle(Palette.muted)
            .padding(.bottom, 26)

            Text("Search the web with a free Tavily key, or paste one public page to research it directly.")
                .font(.system(size: 12))
                .foregroundStyle(Palette.muted)
                .padding(.bottom, 12)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Palette.sea)
                TextField("Ask a question…", text: $question)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .focused($questionFocused)
                    .onSubmit { ask() }
                    .accessibilityIdentifier("liveQuestionField")
                Button(action: ask) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.borderedProminent)
                .tint(Palette.sea)
                .disabled(isRunning || question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Ask question")
                .accessibilityIdentifier("liveAskButton")
            }
            .padding(12)
            .background(.white, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.line))

            Button {
                inspectSources()
            } label: {
                Label(providedPage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "Find evidence without AI" : "Inspect page without AI",
                      systemImage: "doc.text.magnifyingglass")
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Palette.sea)
            .padding(.top, 12)
            .disabled(isRunning || question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("liveInspectPageButton")

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    resultBody
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 30)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 34)
        .padding(.top, 38)
        .padding(.bottom, 22)
    }

    @ViewBuilder
    private var resultBody: some View {
        switch phase {
        case .idle:
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .foregroundStyle(Palette.sea)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Start with a question")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                        Text("Local Lens opens public pages, saves the relevant passages, then builds an answer you can check.")
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.muted)
                    }
                }
                if providerKey.isEmpty || (searchBackend == .tavily && tavilyKey.isEmpty && providedPage.isEmpty) || (searchBackend == .brave && braveKey.isEmpty && providedPage.isEmpty) {
                    Button {
                        connectionExpanded = true
                    } label: {
                        Label("Set up web search and answers", systemImage: "key.horizontal")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Palette.sea)
                    .accessibilityIdentifier("liveOpenConnection")
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("TRY A QUESTION")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(Palette.muted)
                    exampleQuestion("How does SQLite WAL mode handle readers and writers?")
                    exampleQuestion("What happens when a Python TaskGroup child fails?")
                }
                Text("No AI key? Find evidence with free search, or paste a public page. Neither path calls a model.")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
            }
            .accessibilityIdentifier("liveIdleHelp")
        case .running:
            HStack(spacing: 12) {
                ProgressView()
                    .controlSize(.small)
                Text("Opening sources and checking saved passages…")
                    .foregroundStyle(Palette.muted)
            }
            .accessibilityIdentifier("liveRunning")
        case let .preview(result):
            VStack(alignment: .leading, spacing: 14) {
                Text("SAVED PASSAGES · NO AI USED")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(Palette.sea)
                Text("\(result.passages.count) matching passages from \(result.openedSources) opened sources. These are source text, not a generated answer or verified citations.")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.muted)
                if result.passages.isEmpty {
                    Text("No saved passage matched your question. Try a more specific question or a different source.")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.ink)
                }
                ForEach(result.passages.indices, id: \.self) { index in
                    Button {
                        selectedMarker = index + 1
                    } label: {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("PASSAGE \(index + 1) · \(result.passages[index].heading)")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(Palette.sea)
                                .lineLimit(1)
                            Text(result.passages[index].text)
                                .font(.system(size: 15, design: .serif))
                                .foregroundStyle(Palette.ink)
                                .multilineTextAlignment(.leading)
                                .lineLimit(5)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(.white, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("livePassage\(index + 1)")
                }
            }
            .accessibilityIdentifier("livePreview")
        case let .stopped(reason, hint):
            VStack(alignment: .leading, spacing: 7) {
                Label("No supported answer yet", systemImage: "exclamationmark.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Text(reason)
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.muted)
                if let hint {
                    Text(hint)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.muted)
                }
            }
            .accessibilityIdentifier("liveStopped")
        case let .completed(artifact):
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("ANSWER")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(1.3)
                        .foregroundStyle(Palette.sea)
                    Spacer()
                    Text("\(artifact.citations.count) exact passages · \(String(format: "%.1f", artifact.elapsedSeconds))s")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Palette.muted)
                }
                Text(artifact.answer)
                    .font(.system(size: 19, weight: .regular, design: .serif))
                    .lineSpacing(6)
                    .foregroundStyle(Palette.ink)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("liveAnswer")
                Text("Only accepted claims appear above. Exact quotes are available in the evidence rail.")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
            }
        }
    }

    private func exampleQuestion(_ example: String) -> some View {
        Button {
            question = example
            questionFocused = true
        } label: {
            HStack(spacing: 10) {
                Text(example)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "arrow.up.left")
            }
            .font(.system(size: 13))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(.white, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.line))
        }
        .buttonStyle(.plain)
    }

    private var evidencePane: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("EVIDENCE")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(Palette.muted)
                Spacer()
                Image(systemName: "checkmark.seal")
                    .foregroundStyle(Palette.sea)
            }
            Rectangle().fill(Palette.line).frame(height: 1)
            if case let .preview(result) = phase {
                VStack(alignment: .leading, spacing: 12) {
                    Text("SOURCE PREVIEW")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(Palette.sea)
                    Text("Fetched and stored locally. No passage has been promoted to a citation or sent to DeepSeek.")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.muted)
                    if result.passages.indices.contains(selectedMarker - 1) {
                        let passage = result.passages[selectedMarker - 1]
                        ScrollView {
                            Text(passage.text)
                                .font(.system(size: 14, design: .serif))
                                .foregroundStyle(Palette.ink)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if let source = result.records.first(where: { $0.snapshot.id == passage.snapshotID })?.finalURL {
                            Link(destination: source) {
                                Label("Open fetched page", systemImage: "arrow.up.right.square")
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Palette.sea)
                        }
                    }
                }
            } else if case let .completed(artifact) = phase {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(artifact.citations, id: \.marker) { citation in
                            Button {
                                selectedMarker = citation.marker
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("[\(citation.marker)]  \(citation.heading)")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Palette.ink)
                                        .lineLimit(2)
                                    Text(citation.claimText)
                                        .font(.system(size: 12))
                                        .foregroundStyle(Palette.muted)
                                        .lineLimit(2)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(selectedMarker == citation.marker ? Palette.sea.opacity(0.11) : .white,
                                            in: RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Citation \(citation.marker): \(citation.heading)")
                        }
                        if let selected = artifact.citations.first(where: { $0.marker == selectedMarker }) {
                            Rectangle().fill(Palette.line).frame(height: 1).padding(.vertical, 4)
                            Text("EXACT SAVED PASSAGE")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .tracking(1)
                                .foregroundStyle(Palette.sea)
                            Text(selected.passageText ?? selected.quote)
                                .font(.system(size: 14, design: .serif))
                                .lineSpacing(4)
                                .foregroundStyle(Palette.ink)
                                .textSelection(.enabled)
                            Text("Cited quote: “\(selected.quote)”")
                                .font(.system(size: 11))
                                .foregroundStyle(Palette.sea)
                                .textSelection(.enabled)
                            if let url = selected.sourceURL {
                                Link(destination: url) {
                                    Label("Open fetched source", systemImage: "arrow.up.right.square")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundStyle(Palette.sea)
                            }
                            Text("Passage \(selected.passageID.prefix(14))… · Snapshot \(selected.snapshotID.prefix(14))…")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(Palette.muted)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            } else {
                Text("The evidence trail appears when a question produces a supported answer.")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.muted)
                Spacer()
            }
            Rectangle().fill(Palette.line).frame(height: 1)
            DisclosureGroup("Connection", isExpanded: $connectionExpanded) {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Web search", selection: $searchBackend) {
                        Text("Tavily · free").tag(SearchBackend.tavily)
                        Text("Brave API").tag(SearchBackend.brave)
                        Text("Self-hosted").tag(SearchBackend.searxng)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("liveSearchBackend")
                    if searchBackend == .tavily {
                        SecureField("Tavily API key", text: $tavilyKey)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("liveTavilyKey")
                        Button("Save Tavily key in Keychain") {
                            do { try SecretKeyStore.save(tavilyKey, service: "locallens-tavily-search") }
                            catch {
                                phase = .stopped(message: "The Tavily key could not be saved in macOS Keychain.", hint: "You can still use it for this session.")
                            }
                        }
                        .disabled(tavilyKey.isEmpty)
                        Link("Get a free Tavily key (no card)", destination: URL(string: "https://app.tavily.com/home")!)
                            .font(.system(size: 11, weight: .semibold))
                    } else if searchBackend == .brave {
                        SecureField("Brave Search API key", text: $braveKey)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("liveBraveKey")
                        Button("Save Brave key in Keychain") {
                            do { try SecretKeyStore.save(braveKey, service: "locallens-brave-search") }
                            catch {
                                phase = .stopped(message: "The Brave key could not be saved in macOS Keychain.", hint: "You can still use it for this session.")
                            }
                        }
                        .disabled(braveKey.isEmpty)
                    } else {
                        TextField("SearXNG search endpoint", text: $endpoint)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("liveSearchEndpoint")
                    }
                    TextField("One source URL (optional; skips search)", text: $providedPage)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("liveProvidedPage")
                    SecureField("DeepSeek API key", text: $providerKey)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("liveProviderKey")
                    Button("Save key in Keychain") {
                        do { try SecretKeyStore.save(providerKey, service: "locallens-deepseek") }
                        catch {
                            phase = .stopped(
                                message: "The key could not be saved in macOS Keychain.",
                                hint: "You can still use the key for this session without saving it."
                            )
                        }
                    }
                    .disabled(providerKey.isEmpty)
                    Text("Your chosen search service receives the query; DeepSeek receives selected saved passages. A pasted page skips web search. Self-hosted search is for contributors.")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.muted)
                }
                .padding(.top, 7)
            }
            .font(.system(size: 12))
        }
        .padding(24)
        .background(.white.opacity(0.55))
    }

    private var isRunning: Bool {
        if case .running = phase { return true }
        return false
    }

    private var runDisclosure: String {
        if case .idle = phase { return "WEB · AI OPTIONAL" }
        return previewRequested ? "WEB SOURCES · NO AI" : "HOSTED · DEEPSEEK"
    }

    private func inspectSources() {
        guard !isRunning else { return }
        let asked = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !asked.isEmpty else { return }
        let pageText = providedPage.trimmingCharacters(in: .whitespacesAndNewlines)
        let pageURL = pageText.isEmpty ? nil : URL(string: pageText)
        guard pageText.isEmpty || pageURL.flatMap({ try? LiveQuickComposition.providedPageSearch(url: $0) }) != nil else {
            phase = .stopped(
                message: "Enter a valid public HTTP or HTTPS page URL in Connection.",
                hint: "A page URL must not include embedded credentials."
            )
            connectionExpanded = true
            return
        }
        if pageURL == nil && searchBackend == .tavily && tavilyKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            phase = .stopped(message: "Add a free Tavily key in Connection to search the web.",
                             hint: "Or paste one public page URL to inspect it without any API key.")
            connectionExpanded = true
            return
        }
        if pageURL == nil && searchBackend == .brave && braveKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            phase = .stopped(message: "Add a Brave key in Connection to search the web.",
                             hint: "Switch to Tavily for a no-card free tier, or paste one public page URL.")
            connectionExpanded = true
            return
        }
        let queries = QuickQueryPlanner.webQueries(question: asked)
        let retrievalQueries = QuickQueryPlanner.plan(question: asked)
        guard !queries.isEmpty, !retrievalQueries.isEmpty else {
            phase = .stopped(message: "Use a more specific question to inspect this page.", hint: nil)
            return
        }
        phase = .running
        connectionExpanded = false
        previewRequested = true
        selectedMarker = 1
        Task {
            do {
                let live: LiveQuickComposition.Live
                if pageURL != nil {
                    live = try LiveQuickComposition.make(apiKey: "")
                } else {
                    switch searchBackend {
                    case .tavily:
                        live = try LiveQuickComposition.makeTavily(tavilyKey: tavilyKey, apiKey: "")
                    case .brave:
                        live = try LiveQuickComposition.makeBrave(braveKey: braveKey, apiKey: "")
                    case .searxng:
                        guard let searxngURL = URL(string: endpoint) else {
                            throw SearchError.invalidEndpoint(reason: "search endpoint is not a URL")
                        }
                        live = try LiveQuickComposition.make(searxng: searxngURL, apiKey: "")
                    }
                }
                let sourceSearch = try pageURL.map { try LiveQuickComposition.providedPageSearch(url: $0) } ?? live.search
                let outcome = await LiveQuickRunner.retrieve(
                    question: asked,
                    queries: queries,
                    retrievalQueries: retrievalQueries,
                    deadline: Date().addingTimeInterval(LiveQuickLimits.quick.deadlineSeconds),
                    search: sourceSearch,
                    store: live.store,
                    fetch: live.fetch
                )
                switch outcome {
                case let .success(result):
                    phase = .preview(result)
                case let .failure(.abstained(reason)):
                    phase = .stopped(message: reason, hint: "Try another question or source; no AI request was made.")
                case let .failure(.failed(reason)):
                    phase = .stopped(message: reason, hint: "Check the search connection or page URL; no AI request was made.")
                case .failure(.completed):
                    phase = .stopped(message: "Page inspection could not finish.", hint: nil)
                }
            } catch {
                phase = .stopped(message: "Evidence search could not start: \(error)", hint: nil)
            }
        }
    }

    private func ask() {
        guard !isRunning else { return }
        let asked = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !asked.isEmpty else { return }
        let pageText = providedPage.trimmingCharacters(in: .whitespacesAndNewlines)
        let pageURL = pageText.isEmpty ? nil : URL(string: pageText)
        let validPage = pageURL.flatMap { try? LiveQuickComposition.providedPageSearch(url: $0) } != nil
        guard pageText.isEmpty || validPage else {
            phase = .stopped(
                message: "Enter a valid source URL in Connection, or leave it blank to search the web.",
                hint: "Use an HTTP or HTTPS page that is public and does not contain embedded credentials."
            )
            connectionExpanded = true
            return
        }
        var searxngURL = URL(string: "http://127.0.0.1:8888")!
        if pageURL == nil && searchBackend == .searxng {
            guard let endpointURL = URL(string: endpoint),
                  ["http", "https"].contains(endpointURL.scheme?.lowercased() ?? ""),
                  endpointURL.host != nil else {
                phase = .stopped(
                    message: "Enter a valid HTTP or HTTPS search endpoint in Connection.",
                    hint: "A supplied source URL can skip the search server."
                )
                connectionExpanded = true
                return
            }
            searxngURL = endpointURL
        }
        if pageURL == nil && searchBackend == .brave && braveKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            phase = .stopped(
                message: "Add a Brave Search API key in Connection to search the web.",
                hint: "You can also paste one public page URL to research it without a search key."
            )
            connectionExpanded = true
            return
        }
        if pageURL == nil && searchBackend == .tavily && tavilyKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            phase = .stopped(
                message: "Add a free Tavily API key in Connection to search the web.",
                hint: "No card is required. You can also paste a public page URL to skip search."
            )
            connectionExpanded = true
            return
        }
        guard !providerKey.isEmpty else {
            phase = .stopped(
                message: "Add a DeepSeek API key in Connection before asking a live question.",
                hint: "The key stays in this app; saving it in macOS Keychain is optional."
            )
            connectionExpanded = true
            return
        }
        let queries = QuickQueryPlanner.webQueries(question: asked)
        let retrievalQueries = QuickQueryPlanner.plan(question: asked)
        guard !queries.isEmpty, !retrievalQueries.isEmpty else {
            phase = .stopped(
                message: "Use a more specific question so a search query can be formed.",
                hint: "Name the topic or product you want to research."
            )
            return
        }
        phase = .running
        connectionExpanded = false
        previewRequested = false
        selectedMarker = 1
        Task {
            do {
                let live: LiveQuickComposition.Live
                if pageURL != nil || searchBackend == .searxng {
                    live = try LiveQuickComposition.make(searxng: searxngURL, apiKey: providerKey)
                } else if searchBackend == .tavily {
                    live = try LiveQuickComposition.makeTavily(tavilyKey: tavilyKey, apiKey: providerKey)
                } else {
                    live = try LiveQuickComposition.makeBrave(braveKey: braveKey, apiKey: providerKey)
                }
                let search = try pageURL.map { try LiveQuickComposition.providedPageSearch(url: $0) } ?? live.search
                let started = Date()
                let outcome = await LiveQuickRunner.run(
                    question: asked,
                    queries: queries,
                    retrievalQueries: retrievalQueries,
                    deadline: started.addingTimeInterval(LiveQuickLimits.quick.deadlineSeconds),
                    search: search,
                    store: live.store,
                    fetch: live.fetch,
                    provider: live.provider,
                    label: live.label
                )
                switch outcome {
                case let .completed(result):
                    let artifact = LiveAnswerArtifact.make(
                        from: result,
                        provider: live.providerName,
                        elapsedSeconds: Date().timeIntervalSince(started),
                        generatedAt: ISO8601DateFormatter().string(from: Date())
                    )
                    writeEvidenceArtifactIfRequested(artifact)
                    phase = .completed(artifact)
                case let .abstained(reason):
                    phase = .stopped(
                        message: reason,
                        hint: "Try a narrower question or a different public page. No answer is shown without stored evidence."
                    )
                case let .failed(reason):
                    phase = .stopped(
                        message: reason,
                        hint: reason.contains("the answer provider returned no content")
                            ? "The model returned no usable answer. Inspect the saved page passages; this app will not retry the provider automatically."
                            : "Check the connection settings before trying again."
                    )
                }
            } catch {
                phase = .stopped(
                    message: "The live connection could not be prepared: \(error)",
                    hint: "Check the source URL or search settings in Connection."
                )
            }
        }
    }
}

/// A deliberately small, explicit credential store. The key is never placed
/// in an artifact, log, or user default; saving happens only on button press.
enum SecretKeyStore {
    private static let account = "api-key"

    /// The outcome of a read, so a refusal is not confused with an empty slot.
    enum ReadResult: Equatable {
        case found(String)
        case absent
        case denied(OSStatus)
    }

    static func read(service: String) -> ReadResult {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data, let text = String(data: data, encoding: .utf8) else {
                return .denied(status)
            }
            return .found(text)
        case errSecItemNotFound:
            return .absent
        default:
            return .denied(status)
        }
    }

    static func load(service: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func save(_ key: String, service: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let data = Data(key.utf8)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var insertion = query
            insertion[kSecValueData as String] = data
            guard SecItemAdd(insertion as CFDictionary, nil) == errSecSuccess else {
                throw CocoaError(.fileWriteUnknown)
            }
        } else if status != errSecSuccess {
            throw CocoaError(.fileWriteUnknown)
        }
    }
}
