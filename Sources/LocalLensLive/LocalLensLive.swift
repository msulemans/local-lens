import Foundation
import LocalLensCore

/// The smallest separate live Quick entry point. It is deliberately not the
/// app and not a test: `make gate` and the native app stay offline, and a live
/// run is an explicit, opted-in command.
///
/// Usage:
///   swift run LocalLensLive --question "..." --tavily --mode retrieve
///   swift run LocalLensLive --question "..." --queries "q1,q2" --mode answer
///
/// `retrieve` runs search, bounded safe fetch (robots + per-host politeness +
/// redirect validation), extraction, snapshot storage, indexing, and lexical
/// retrieval, and prints the retrieved passages. `answer` adds the selected
/// answer provider and requires `DEEPSEEK_API_KEY`.
@main
struct LocalLensLive {
    static func main() async {
        do {
            try await run()
        } catch {
            writeError("live run failed: \(error)")
            exit(2)
        }
    }

    static func run() async throws {
        let options = Options(arguments: CommandLine.arguments)
        if options.mode == "benchmark" {
            // A benchmark supplies its own questions in the card.
            try await runBenchmark(options: options)
            return
        }
        if options.mode == "review" {
            try runReview(options: options)
            return
        }
        if options.mode == "calibrate" {
            try runCalibration(options: options)
            return
        }
        if options.mode != "ping" {
            guard !options.question.isEmpty else {
                writeError("""
                usage: swift run LocalLensLive --question "..." [--queries "q1,q2"] \
                [--queries "web q1,web q2"] [--retrieval-queries "kw1,kw2"] \
                [--tavily | --brave | --searxng http://127.0.0.1:8888] [--source-url https://public.example/page] [--language en] [--mode retrieve|answer|propose|ping|dump]
                """)
                exit(2)
            }
            guard !options.queries.isEmpty else {
                writeError("the question yields no search query; pass --queries")
                exit(2)
            }
        }

        let transport = URLSessionSearchTransport()
        if options.mode == "research" {
            try await runResearch(options: options)
            return
        }
        if options.mode == "benchmark" {
            try await runBenchmark(options: options)
            return
        }
        if options.mode == "research-answer" {
            try await runResearchAnswer(options: options)
            return
        }
        let fetcher = BoundedFetcher(
            transport: transport,
            resolver: SystemHostResolver(),
            userAgent: "LocalLens/0.1 (M003.5 development; contact: repository owner)",
            store: SnapshotStore()
        )

        let search: @Sendable (String) async throws -> SearchOutcome
        if let sourceURLText = options.sourceURLText {
            guard let sourceURL = URL(string: sourceURLText) else {
                throw SearchError.invalidEndpoint(reason: "--source-url is not a URL")
            }
            search = try LiveQuickComposition.providedPageSearch(url: sourceURL)
        } else if options.tavily {
            guard let key = ProcessInfo.processInfo.environment["TAVILY_API_KEY"], !key.isEmpty else {
                writeError("TAVILY_API_KEY is not set; --tavily cannot search")
                exit(3)
            }
            let configuration = try TavilySearchConfiguration(apiKey: key)
            let adapter = TavilySearchAdapter(configuration: configuration, transport: transport)
            search = { try await adapter.search($0) }
        } else if options.brave {
            guard let key = ProcessInfo.processInfo.environment["BRAVE_SEARCH_API_KEY"], !key.isEmpty else {
                writeError("BRAVE_SEARCH_API_KEY is not set; --brave cannot search")
                exit(3)
            }
            let configuration = try BraveSearchConfiguration(apiKey: key, language: options.language)
            let adapter = BraveSearchAdapter(configuration: configuration, transport: transport)
            search = { try await adapter.search($0) }
        } else {
            let configuration = try SearXNGConfiguration(
                endpoint: options.searxng,
                language: options.language
            )
            let adapter = SearXNGSearchAdapter(configuration: configuration, transport: transport)
            search = { try await adapter.search($0) }
        }
        let fetch: @Sendable ([FetchTarget]) async throws -> [FetchResult] = { try await fetcher.fetch($0) }
        let store = fetcher.snapshotStore
        let deadline = Date().addingTimeInterval(LiveQuickLimits.quick.deadlineSeconds)
        let started = Date()

        switch options.mode {
        case "retrieve":
            let outcome = await LiveQuickRunner.retrieve(
                question: options.question,
                queries: options.queries,
                retrievalQueries: options.retrievalQueries,
                deadline: deadline,
                search: search,
                store: store,
                fetch: fetch
            )
            let elapsed = Date().timeIntervalSince(started)
            switch outcome {
            case let .success(result):
                print("mode=retrieve elapsed_s=\(format(elapsed))")
                print("question=\(result.question)")
                print("search_queries=\(result.searchQueries) opened_sources=\(result.openedSources) passages=\(result.passages.count)")
                for fetch in result.fetchResults {
                    let stage = fetch.outcome.refusal?.stage.rawValue ?? "-"
                    let kind = fetch.outcome.refusal?.kind ?? "-"
                    print("fetch \(fetch.kind) stage=\(stage) kind=\(kind) url=\(fetch.url.absoluteString)")
                }
                for (index, passage) in result.passages.enumerated() {
                    print("[\(index)] passage=\(passage.id) snapshot=\(passage.snapshotID) heading=\(passage.heading)")
                    print("    \(passage.text.prefix(200))")
                }
                if options.dump {
                    print("--- all stored passages (\(result.records.count) records) ---")
                    for record in result.records {
                        print("snapshot=\(record.snapshot.id) source=\(record.snapshot.sourceID)")
                        for passage in record.passages {
                            print("  passage=\(passage.id) heading=\(passage.heading)")
                            print("    \(passage.text.prefix(240))")
                        }
                    }
                }
            case let .failure(reason):
                print("retrieve_stopped: \(reason)")
                exit(1)
            }

        case "answer":
            let provider: any QuickAnswerProvider
            let label: String
            let providerModel: String
            if options.local {
                guard let endpoint = URL(string: options.localEndpoint) else {
                    writeError("--local-endpoint is not a URL")
                    exit(3)
                }
                let configuration = LocalProviderConfiguration(baseURL: endpoint, model: options.localModel)
                provider = LocalAnswerProvider(configuration: configuration, transport: transport)
                label = "local"
                providerModel = configuration.label
            } else {
                guard let key = ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"], !key.isEmpty else {
                    writeError("DEEPSEEK_API_KEY is not set; answer mode cannot run")
                    exit(3)
                }
                let configuration = DeepSeekConfiguration(apiKey: key)
                provider = DeepSeekAnswerProvider(configuration: configuration, transport: transport)
                label = "hosted"
                providerModel = configuration.model
            }
            let outcome = await LiveQuickRunner.run(
                question: options.question,
                queries: options.queries,
                retrievalQueries: options.retrievalQueries,
                deadline: deadline,
                search: search,
                store: store,
                fetch: fetch,
                provider: provider,
                label: label
            )
            let elapsed = Date().timeIntervalSince(started)
            switch outcome {
            case let .completed(result):
                print("mode=answer label=\(result.label) elapsed_s=\(format(elapsed))")
                print("answer=\(result.answer)")
                print("citations=\(result.compilation.citations.count) accepted=\(result.accepted.count) rejected=\(result.rejected.count)")
                let promptTokens = result.observation.providerPromptTokens.map(String.init) ?? "?"
                let completionTokens = result.observation.providerCompletionTokens.map(String.init) ?? "?"
                print("tokens=prompt:\(promptTokens) completion:\(completionTokens)")
                if let out = options.out {
                    let artifact = LiveAnswerArtifact.make(
                        from: result,
                        provider: providerModel,
                        elapsedSeconds: elapsed,
                        generatedAt: ISO8601DateFormatter().string(from: Date())
                    )
                    try artifact.write(to: out)
                    print("artifact=\(out.path)")
                }
                for citation in result.compilation.citations {
                    if let resolved = try? result.compilation.resolve(citation.id) {
                        print("citation \(citation.id) -> passage \(resolved.passage.id) quote=\(resolved.evidenceLink.quote)")
                    }
                }
            case let .abstained(reason):
                print("answer_abstained: \(reason)")
                exit(1)
            case let .failed(reason):
                print("answer_failed: \(reason)")
                exit(1)
            }

        case "propose":
            let retrieval = await LiveQuickRunner.retrieve(
                question: options.question,
                queries: options.queries,
                retrievalQueries: options.retrievalQueries,
                deadline: deadline,
                search: search,
                store: store,
                fetch: fetch
            )
            guard case let .success(prepared) = retrieval else {
                print("retrieve_failed")
                exit(1)
            }
            guard let key = ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"], !key.isEmpty else {
                writeError("DEEPSEEK_API_KEY is not set")
                exit(3)
            }
            let provider = DeepSeekAnswerProvider(
                configuration: DeepSeekConfiguration(apiKey: key),
                transport: transport
            )
            print("passages=\(prepared.passages.count)")
            for passage in prepared.passages {
                print("passage \(passage.id) heading=\(passage.heading)")
                print("   text=\(passage.text)")
            }
            do {
                let proposal = try await provider.answer(
                    AnswerRequest(question: options.question, passages: prepared.passages)
                )
                print("answer=\(proposal.answer)")
                print("tokens=prompt:\(proposal.promptTokens.map(String.init) ?? "?") completion:\(proposal.completionTokens.map(String.init) ?? "?")")
                for claim in proposal.claims {
                    let bound = prepared.passages.first { $0.id == claim.passageID }
                    let exact = bound.map { $0.text.contains(claim.quote) } ?? false
                    print("claim bound=\(bound != nil) exact=\(exact) passage=\(claim.passageID)")
                    print("   text=\(claim.text)")
                    print("   quote=\(claim.quote)")
                }
            } catch {
                print("provider_error=\(error)")
                exit(1)
            }

        case "ping":
            guard let key = ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"], !key.isEmpty else {
                writeError("DEEPSEEK_API_KEY is not set; ping mode cannot run")
                exit(3)
            }
            let configuration = DeepSeekConfiguration(apiKey: key)
            let system = "You answer from supplied passages only. Return one JSON object: {\"answer\": \"concise answer\", \"claims\": [{\"text\": \"atomic claim\", \"passage_id\": \"id\", \"quote\": \"exact substring\"}]}"
            var question = "What happens when the group is finished?"
            var passagesText = "\n[passage-ping] Sample\nWhen the group is finished, cancel all the other tasks.\n"
            if !options.question.isEmpty {
                question = options.question
                let retrieval = await LiveQuickRunner.retrieve(
                    question: options.question,
                    queries: options.queries,
                    retrievalQueries: options.retrievalQueries,
                    deadline: deadline,
                    search: search,
                    store: store,
                    fetch: fetch
                )
                if case let .success(prepared) = retrieval {
                    print("ping_passages=\(prepared.passages.count)")
                    passagesText = prepared.passages.map { "\n[\($0.id)] \($0.heading)\n\($0.text)\n" }.joined()
                } else {
                    print("ping_retrieval_failed=true")
                }
            }
            let user = "Question: \(question)\nPassages:\(passagesText)"
            let wire: [String: Any] = [
                "model": configuration.model,
                "messages": [
                    ["role": "system", "content": system],
                    ["role": "user", "content": user],
                ],
                "response_format": ["type": "json_object"],
                "max_tokens": configuration.maximumOutputTokens,
                "temperature": 0,
            ]
            let body = try JSONSerialization.data(withJSONObject: wire, options: [.sortedKeys])
            let request = SearchRequest(
                url: configuration.baseURL.appendingPathComponent("chat/completions"),
                method: "POST",
                headers: [
                    "Content-Type": "application/json",
                    "Accept": "application/json",
                    "Authorization": "Bearer \(key)",
                ],
                timeoutSeconds: configuration.timeoutSeconds,
                body: body
            )
            let response = try await transport.send(request)
            print("http_status=\(response.statusCode)")
            let root = (try? JSONSerialization.jsonObject(with: response.body)) as? [String: Any]
            if let root {
                if let choices = root["choices"] as? [[String: Any]], let first = choices.first {
                    print("finish_reason=\(first["finish_reason"] ?? "nil")")
                    if let message = first["message"] as? [String: Any] {
                        let content = message["content"]
                        let contentString = content as? String
                        print("content_present=\(content != nil) content_null=\(content is NSNull) content_empty=\(contentString?.isEmpty ?? false) content_length=\(contentString?.count ?? -1)")
                        if let reasoning = message["reasoning_content"] as? String {
                            print("reasoning_content_present=true reasoning_length=\(reasoning.count)")
                        } else {
                            print("reasoning_content_present=false")
                        }
                    } else {
                        print("message_missing=true")
                    }
                } else {
                    print("choices_missing=true keys=\(root.keys.sorted())")
                }
                if let usage = root["usage"] as? [String: Any] {
                    print("prompt_tokens=\(usage["prompt_tokens"] ?? "?") completion_tokens=\(usage["completion_tokens"] ?? "?")")
                }
            }
            if let proposal = try? DeepSeekAnswerProvider.decode(response.body) {
                print("decoded_ok=true claims=\(proposal.claims.count) answer_length=\(proposal.answer.count)")
            } else {
                print("decoded_ok=false")
            }

        default:
            writeError("unknown --mode \(options.mode)")
            exit(2)
        }
    }

    // MARK: Helpers

    /// Retrieval-only run of one mode plan, with every fetch outcome printed so
    /// a zero-passage result can be attributed to discovery, fetch, or the
    /// lexical selection instead of guessed at.
    private static func runResearch(options: Options) async throws {
        let mode = ResearchMode.allCases.first { $0.rawValue.lowercased() == options.modeName.lowercased() } ?? .quick
        let plan: ResearchPlan
        do {
            plan = try makePlan(options, mode: mode)
        } catch {
            writeError("plan refused: \((error as? ResearchPlanError)?.errorDescription ?? "\(error)")")
            exit(2)
        }
        let providerKey = ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"] ?? ""
        let tavilyKey = ProcessInfo.processInfo.environment["TAVILY_API_KEY"]
        let live: LiveQuickComposition.Live
        if mode == .news {
            live = try LiveQuickComposition.makeNews(
                tavilyKey: tavilyKey ?? "",
                apiKey: providerKey,
                question: options.question
            )
        } else if mode == .academic {
            live = try LiveQuickComposition.makeAcademic(apiKey: providerKey, mailto: nil, fallbackTavilyKey: tavilyKey)
        } else if options.brave {
            live = try LiveQuickComposition.makeBrave(
                braveKey: ProcessInfo.processInfo.environment["BRAVE_SEARCH_API_KEY"] ?? "",
                apiKey: providerKey
            )
        } else if options.tavily {
            live = try LiveQuickComposition.makeTavily(tavilyKey: tavilyKey ?? "", apiKey: providerKey)
        } else {
            live = try LiveQuickComposition.make(searxng: options.searxng, language: options.language, apiKey: providerKey)
        }
        let deadline = Date().addingTimeInterval(plan.policy.deadlineSeconds)
        let started = Date()
        let outcome = await LiveQuickRunner.retrieve(
            question: plan.question,
            queries: plan.searchQueries,
            retrievalQueries: plan.retrievalQueries,
            limits: LiveQuickLimits.forMode(mode),
            deadline: deadline,
            search: live.search,
            store: live.store,
            fetch: live.fetch
        )
        let elapsed = Date().timeIntervalSince(started)
        switch outcome {
        case let .success(result):
            print("mode=research plan=\(mode.rawValue) elapsed_s=\(format(elapsed))")
            print("dimensions=\(plan.dimensions.joined(separator: ", "))")
            print("search_queries=\(plan.searchQueries.joined(separator: " | "))")
            print("opened_sources=\(result.openedSources) passages=\(result.passages.count)")
            if let recency = live.newsRecency, !recency.summary.isEmpty {
                print("news_window=\(recency.summary)")
            }
            for entry in NewsIndependence.timeline(
                passages: result.passages,
                records: result.records,
                publicationDates: live.newsRecency?.publicationDates ?? [:]
            ) {
                let stamp = entry.publishedAt.map { ISO8601DateFormatter().string(from: $0) } ?? "undated"
                print("timeline \(stamp) domains=\(entry.domains.joined(separator: ",")) headline=\(entry.headline.prefix(60))")
            }
            let voices = NewsIndependence.voices(passages: result.passages, records: result.records)
            if !voices.isEmpty {
                let domains = NewsIndependence.independentDomainCount(passages: result.passages, records: result.records)
                print("news_voices=\(voices.count) domains=\(domains)")
                for voice in voices {
                    print("voice domains=\(voice.domains.joined(separator: ",")) headline=\(voice.headline.prefix(70))")
                }
            }
            for fetch in result.fetchResults {
                let kind = fetch.outcome.refusal?.kind ?? "stored"
                print("fetch \(fetch.kind) kind=\(kind) url=\(fetch.url.absoluteString)")
            }
            print("coverage=\(ResearchRunner.coverage(for: plan.dimensions, passages: result.passages))")
            // The retrieval-only path has no answer and no loop, so the contrast
            // scan runs directly over the selected passages.
            for contradiction in ContradictionScan.contradictions(passages: result.passages, records: result.records) {
                print("contrast context=\"\(contradiction.context)\" left=\(contradiction.leftValue) right=\(contradiction.rightValue)")
            }
            for (index, passage) in result.passages.enumerated() {
                print("[\(index)] \(passage.heading) :: \(passage.text.prefix(160))")
            }
        case let .failure(reason):
            print("research_stopped: \(reason)")
            exit(1)
        }
    }

    /// Runs one mode plan end to end with an answer provider, so a held-out
    /// answer card can be measured with the local model at US$0.
    private static func runResearchAnswer(options: Options) async throws {
        let mode = ResearchMode.allCases.first { $0.rawValue.lowercased() == options.modeName.lowercased() } ?? .quick
        let plan: ResearchPlan
        do {
            plan = try makePlan(options, mode: mode)
        } catch {
            writeError("plan refused: \((error as? ResearchPlanError)?.errorDescription ?? "\(error)")")
            exit(2)
        }
        let providerKey = ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"] ?? ""
        let tavilyKey = ProcessInfo.processInfo.environment["TAVILY_API_KEY"]
        let local: LocalProviderConfiguration?
        if options.local {
            guard let endpoint = URL(string: options.localEndpoint) else {
                writeError("--local-endpoint is not a URL")
                exit(3)
            }
            local = LocalProviderConfiguration(baseURL: endpoint, model: options.localModel)
        } else {
            local = nil
        }
        let live: LiveQuickComposition.Live
        if mode == .news {
            live = try LiveQuickComposition.makeNews(
                tavilyKey: tavilyKey ?? "",
                apiKey: providerKey,
                local: local,
                question: options.question
            )
        } else if mode == .academic {
            live = try LiveQuickComposition.makeAcademic(apiKey: providerKey, mailto: nil, fallbackTavilyKey: tavilyKey, local: local)
        } else if options.brave {
            live = try LiveQuickComposition.makeBrave(
                braveKey: ProcessInfo.processInfo.environment["BRAVE_SEARCH_API_KEY"] ?? "",
                apiKey: providerKey,
                local: local
            )
        } else if options.tavily {
            live = try LiveQuickComposition.makeTavily(tavilyKey: tavilyKey ?? "", apiKey: providerKey, local: local)
        } else {
            live = try LiveQuickComposition.make(searxng: options.searxng, language: options.language, apiKey: providerKey, local: local)
        }
        let started = Date()
        let deadline = started.addingTimeInterval(plan.policy.deadlineSeconds)
        let outcome = await ResearchRunner.run(
            plan: plan,
            deadline: deadline,
            search: live.search,
            store: live.store,
            fetch: live.fetch,
            provider: live.provider,
            label: live.label
        )
        let elapsed = Date().timeIntervalSince(started)
        switch outcome {
        case let .completed(report):
            print("mode=research-answer plan=\(mode.rawValue) label=\(report.result.label) elapsed_s=\(format(elapsed))")
            print("answer=\(report.result.answer)")
            print("citations=\(report.result.compilation.citations.count) accepted=\(report.result.accepted.count) rounds=\(report.rounds)")
            print("coverage=\(report.dimensionCoverage) gaps=\(report.gapDimensions)")
            print("stop_reason=\(report.stopReason.rawValue) rounds=\(report.roundLog.map { "\($0.index):\($0.reason.rawValue):\($0.addedPassages)" }.joined(separator: " "))")
            for contradiction in report.contradictions {
                print("contrast context=\"\(contradiction.context)\" left=\(contradiction.leftValue) right=\(contradiction.rightValue)")
            }
            if let recency = live.newsRecency, !recency.summary.isEmpty {
                print("news_window=\(recency.summary)")
            }
            // The passages the report already selected, in report order.
            let reportPassages = report.result.records.flatMap(\.passages)
            for entry in NewsIndependence.timeline(
                passages: reportPassages,
                records: report.result.records,
                publicationDates: live.newsRecency?.publicationDates ?? [:]
            ) {
                let stamp = entry.publishedAt.map { ISO8601DateFormatter().string(from: $0) } ?? "undated"
                print("timeline \(stamp) domains=\(entry.domains.joined(separator: ",")) headline=\(entry.headline.prefix(60))")
            }
            if !report.newsVoices.isEmpty {
                print("news_voices=\(report.newsVoices.count) domains=\(report.independentSourceCount)")
                for voice in report.newsVoices {
                    print("voice domains=\(voice.domains.joined(separator: ",")) headline=\(voice.headline.prefix(70))")
                }
            }
            for citation in report.result.compilation.citations {
                guard let resolved = try? report.result.compilation.resolve(citation.id) else { continue }
                let host = resolved.passage.snapshotID
                print("citation claim=\(resolved.claim.text.prefix(90)) heading=\(resolved.passage.heading.prefix(60)) snapshot=\(host.prefix(12))")
            }
        case let .abstained(reason):
            print("mode=research-answer plan=\(mode.rawValue) label=\(live.label) elapsed_s=\(format(elapsed))")
            print("answer_abstained: \(reason)")
        case let .failed(reason):
            print("mode=research-answer plan=\(mode.rawValue) failed: \(reason)")
            exit(1)
        }
    }

    /// Reports how the deterministic evaluator would have scored a reviewed run.
    private static func runCalibration(options: Options) throws {
        guard let scorecardPath = options.scorecard else {
            writeError("--scorecard is required for --mode calibrate")
            exit(2)
        }
        let scorecard: BenchmarkScorecard
        do {
            scorecard = try BenchmarkScorecard.decode(try Data(contentsOf: URL(fileURLWithPath: scorecardPath)))
        } catch {
            writeError("refused: \(error)")
            exit(2)
        }
        let report = scorecard.calibration()
        for sample in report.samples {
            print("calibrate \(sample.questionID) human=\(sample.human) predicted=\(sample.predicted)")
        }
        print(String(
            format: "calibration agreement=%.2f mean_abs_error=%.2f worst=%d calibrated=%@",
            report.exactAgreement,
            report.meanAbsoluteError,
            report.worstError,
            report.isCalibrated ? "yes" : "no"
        ))
        print(report.verdict)
    }

    /// Applies a filled-in review packet to a finished run.
    private static func runReview(options: Options) throws {
        guard let reviewPath = options.review else {
            writeError("--review is required for --mode review")
            exit(2)
        }
        guard let scorecardPath = options.scorecard else {
            writeError("--scorecard is required for --mode review")
            exit(2)
        }
        let scorecard: BenchmarkScorecard
        let packet: ReviewPacket
        do {
            scorecard = try BenchmarkScorecard.decode(try Data(contentsOf: URL(fileURLWithPath: scorecardPath)))
            packet = try ReviewPacket.decode(try Data(contentsOf: URL(fileURLWithPath: reviewPath)))
        } catch {
            writeError("refused: \(error)")
            exit(2)
        }
        let scored: BenchmarkScorecard
        do {
            scored = try scorecard.applying(packet)
        } catch {
            writeError("review refused: \(error)")
            exit(2)
        }
        let data = try scored.json()
        if let out = options.out {
            try data.write(to: out)
            print("scored scorecard written to \(out.path)")
        }
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
        print(scored.summary)
    }

    /// Replays a frozen card against one path and writes a scorecard.
    ///
    /// Answer usefulness is never inferred: it is `null` unless a human scores
    /// it, so an unscored card cannot look like a good one.
    private static func runBenchmark(options: Options) async throws {
        guard let cardPath = options.card else {
            writeError("--card is required for --mode benchmark")
            exit(2)
        }
        let card: BenchmarkCard
        do {
            card = try BenchmarkCard.decode(try Data(contentsOf: URL(fileURLWithPath: cardPath)))
        } catch {
            writeError("card refused: \(error)")
            exit(2)
        }
        let local: LocalProviderConfiguration?
        if options.local {
            guard let endpoint = URL(string: options.localEndpoint) else {
                writeError("--local-endpoint is not a URL")
                exit(3)
            }
            local = LocalProviderConfiguration(baseURL: endpoint, model: options.localModel)
        } else {
            local = nil
        }
        // Fail before spending any provider call: the plan for every question
        // must be valid for its mode.
        var plans: [String: ResearchPlan] = [:]
        for question in card.questions {
            do {
                let edited = options.dimensions.isEmpty ? [] : ResearchPlanner.splitDimensions(options.dimensions)
                plans[question.id] = edited.isEmpty
                    ? ResearchPlanner.plan(question.question, mode: question.mode)
                    : try ResearchPlanner.plan(question.question, mode: question.mode, dimensions: edited)
            } catch {
                // A card question the planner cannot plan is a card defect, not a
                // run failure, and the whole replay is refused.
                writeError("card refused at \(question.id): \(error)")
                exit(2)
            }
        }
        let providerKey = ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"] ?? ""
        let tavilyKey = ProcessInfo.processInfo.environment["TAVILY_API_KEY"]
        var results: [BenchmarkQuestionResult] = []
        var reports: [(question: BenchmarkCard.Question, report: ResearchReport)] = []
        var abstentions: [(question: BenchmarkCard.Question, reason: String)] = []
        var label = local == nil ? "hosted" : "local"
        var providerName = local?.label ?? "unknown"
        for question in card.questions {
            guard let plan = plans[question.id] else { continue }
            let autoDimensions: [String] = []
            let live: LiveQuickComposition.Live
            do {
                if options.dimensions.isEmpty, !autoDimensions.isEmpty {
                    fatalError("unreachable")
                }
                live = try composition(
                    for: question.mode,
                    options: options,
                    tavilyKey: tavilyKey,
                    providerKey: providerKey,
                    local: local,
                    dimensions: autoDimensions
                )
            } catch {
                writeError("connection refused at \(question.id): \(error)")
                exit(3)
            }
            label = live.label
            providerName = live.providerName
            let started = Date()
            let outcome = await ResearchRunner.run(
                plan: plan,
                deadline: started.addingTimeInterval(plan.policy.deadlineSeconds),
                search: live.search,
                store: live.store,
                fetch: live.fetch,
                provider: live.provider,
                label: live.label
            )
            let elapsed = Date().timeIntervalSince(started)
            switch outcome {
            case let .completed(report):
                reports.append((question, report))
                var integrityFailure: String?
                do {
                    try report.result.compilation.validate()
                } catch {
                    integrityFailure = "\(error)"
                }
                results.append(BenchmarkQuestionResult(
                    questionID: question.id,
                    mode: question.mode,
                    label: report.result.label,
                    provider: live.providerName,
                    citations: report.result.compilation.citations.count,
                    rejectedClaims: report.result.rejected.count,
                    acceptedClaims: report.result.accepted.count,
                    elapsedSeconds: elapsed,
                    openedSources: report.result.observation.openedSources,
                    passages: report.result.records.flatMap(\.passages).count,
                    integrityPassed: integrityFailure == nil,
                    integrityFailure: integrityFailure,
                    stopReason: report.stopReason.rawValue,
                    coveredDimensions: report.dimensionCoverage.values.filter { $0 > 0 }.count,
                    totalDimensions: plan.dimensions.count
                ))
                print("bench \(question.id) \(question.mode.rawValue) citations=\(report.result.compilation.citations.count) accepted=\(report.result.accepted.count) rejected=\(report.result.rejected.count) elapsed_s=\(format(elapsed)) stop=\(report.stopReason.rawValue)")
            case let .abstained(reason):
                abstentions.append((question, reason))
                results.append(BenchmarkQuestionResult(
                    questionID: question.id,
                    mode: question.mode,
                    label: live.label,
                    provider: live.providerName,
                    citations: 0,
                    rejectedClaims: 0,
                    acceptedClaims: 0,
                    elapsedSeconds: elapsed,
                    openedSources: 0,
                    passages: 0,
                    integrityPassed: true,
                    stopReason: "abstained",
                    coveredDimensions: 0,
                    totalDimensions: plan.dimensions.count,
                    notes: reason
                ))
                print("bench \(question.id) \(question.mode.rawValue) abstained=\(reason) elapsed_s=\(format(elapsed))")
            case let .failed(reason):
                print("bench \(question.id) failed=\(reason)")
                exit(1)
            }
        }
        let scorecard = BenchmarkScorecard(card: card.name, label: label, provider: providerName, results: results)
        if let lessonsOut = options.lessonsOut {
            try FileManager.default.createDirectory(at: lessonsOut, withIntermediateDirectories: true)
            var written = 0
            for entry in reports {
                let name = entry.question.id.replacingOccurrences(of: "/", with: "-")
                let plan = try ResearchPlanner.plan(entry.question.question, mode: entry.question.mode)
                if let card = LearningCard.make(
                    plan: plan,
                    outcome: .completed(entry.report),
                    stopReason: entry.report.stopReason,
                    coverage: entry.report.dimensionCoverage,
                    gapDimensions: entry.report.gapDimensions
                ) {
                    try Data(card.markdown().utf8).write(to: lessonsOut.appendingPathComponent("\(name).md"))
                    written += 1
                }
            }
            print("learning cards written: \(written) to \(lessonsOut.path)")
        }
        if let reviewOut = options.reviewOut {
            let packet = BenchmarkScorecard.reviewPacket(
                for: reports,
                abstentions: abstentions,
                card: card.name,
                label: label,
                provider: providerName
            )
            try packet.json().write(to: reviewOut)
            print("review packet written to \(reviewOut.path) (\(packet.questions.count) questions, \(packet.questions.flatMap(\.citations).count) citations)")
        }
        let data = try scorecard.json()
        if let out = options.out {
            try data.write(to: out)
            print("scorecard written to \(out.path)")
        }
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
        print(scorecard.summary)
    }

    /// Picks the composition for a mode, matching what the app uses.
    private static func composition(
        for mode: ResearchMode,
        options: Options,
        tavilyKey: String?,
        providerKey: String,
        local: LocalProviderConfiguration?,
        dimensions: [String]
    ) throws -> LiveQuickComposition.Live {
        let question = options.question
        switch mode {
        case .news:
            return try LiveQuickComposition.makeNews(
                tavilyKey: tavilyKey ?? "",
                apiKey: providerKey,
                local: local,
                question: question
            )
        case .academic:
            return try LiveQuickComposition.makeAcademic(
                apiKey: providerKey,
                mailto: nil,
                fallbackTavilyKey: tavilyKey,
                local: local
            )
        default:
            return try LiveQuickComposition.makeTavily(tavilyKey: tavilyKey ?? "", apiKey: providerKey, local: local)
        }
    }

    private static func makePlan(_ options: Options, mode: ResearchMode) throws -> ResearchPlan {
        let edited = options.dimensions.isEmpty ? [] : ResearchPlanner.splitDimensions(options.dimensions)
        if edited.isEmpty {
            return ResearchPlanner.plan(options.question, mode: mode)
        }
        return try ResearchPlanner.plan(options.question, mode: mode, dimensions: edited)
    }

    private struct Options {
        let question: String
        let queries: [String]
        /// Keyword windows for the local lexical index. Kept separate from the
        /// web-search queries so the index can keep its strict-match windows
        /// while search receives the natural-language question.
        let retrievalQueries: [String]
        let searxng: URL
        let sourceURLText: String?
        let tavily: Bool
        let brave: Bool
        let language: String
        let mode: String
        let modeName: String
        let dimensions: String
        let card: String?
        let review: String?
        let reviewOut: URL?
        let lessonsOut: URL?
        let scorecard: String?
        let academic: Bool
        let local: Bool
        let localEndpoint: String
        let localModel: String
        let dump: Bool
        let out: URL?

        init(arguments: [String]) {
            func value(_ flag: String) -> String? {
                guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
                return arguments[index + 1]
            }
            question = value("--question") ?? ""
            let explicit = (value("--queries") ?? "")
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            // With no explicit queries, derive them from the question exactly as
            // the app does, so a card rerun measures the current pipeline rather
            // than the hand-written queries the M003.5 baseline used. Web search
            // gets the natural-language question; the lexical index gets the
            // keyword windows via `plan`.
            queries = explicit.isEmpty ? QuickQueryPlanner.webQueries(question: question) : explicit
            let explicitRetrieval = (value("--retrieval-queries") ?? "")
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            retrievalQueries = explicitRetrieval.isEmpty
                ? QuickQueryPlanner.plan(question: question)
                : explicitRetrieval
            searxng = URL(string: value("--searxng") ?? "http://127.0.0.1:8888")!
            sourceURLText = value("--source-url")
            tavily = arguments.contains("--tavily")
            brave = arguments.contains("--brave")
            // Pin the search language: without it SearXNG falls back to the
            // client's `Accept-Language` (the machine locale, `en-AU` here),
            // and Google then returns region junk instead of primary docs.
            language = value("--language") ?? "en"
            mode = value("--mode") ?? "retrieve"
            modeName = value("--plan") ?? "quick"
            dimensions = value("--dimensions") ?? ""
            card = value("--card")
            review = value("--review")
            reviewOut = value("--review-out").map { URL(fileURLWithPath: $0) }
            scorecard = value("--scorecard")
            lessonsOut = value("--lessons-out").map { URL(fileURLWithPath: $0) }
            academic = arguments.contains("--academic")
            local = arguments.contains("--local")
            localEndpoint = value("--local-endpoint") ?? "http://127.0.0.1:11434"
            localModel = value("--local-model") ?? "qwen2.5-coder:14b-instruct-q4_K_M"
            dump = arguments.contains("--dump")
            out = value("--out").map { URL(fileURLWithPath: $0) }
        }
    }

    private static func format(_ seconds: Double) -> String {
        String(format: "%.2f", seconds)
    }

    private static func writeError(_ message: String) {
        FileHandle.standardError.write(Data((message + "\n").utf8))
    }
}
