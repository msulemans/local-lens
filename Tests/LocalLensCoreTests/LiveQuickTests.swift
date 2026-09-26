import Foundation
import XCTest
@testable import LocalLensCore

/// A provider that counts calls and, by default, quotes the first selected
/// passage exactly. It is a class so the test can observe the call count.
private final class ProviderSpy: QuickAnswerProvider, @unchecked Sendable {
    enum Mode {
        case quoteFirstPassage
        case paraphrasingAndExact
        case ambiguousAndUnique
        case fixed(AnswerProposal)
        case failing
    }

    private let lock = NSLock()
    private var calls = 0
    private let mode: Mode

    init(mode: Mode) {
        self.mode = mode
    }

    var callCount: Int {
        lock.withLock { calls }
    }

    func answer(_ request: AnswerRequest) async throws -> AnswerProposal {
        lock.withLock { calls += 1 }

        switch mode {
        case .quoteFirstPassage:
            guard let passage = request.passages.first else {
                return AnswerProposal(answer: "No passage.", claims: [])
            }
            return AnswerProposal(
                answer: "Answer grounded in \(passage.id).",
                claims: [ProposedClaim(text: "A supported claim.", passageID: passage.id, quote: passage.text)]
            )
        case let .fixed(proposal):
            return proposal
        case .paraphrasingAndExact:
            guard let passage = request.passages.first else {
                return AnswerProposal(answer: "No passage.", claims: [])
            }
            return AnswerProposal(
                answer: "PARAPHRASED PROSE.",
                claims: [
                    ProposedClaim(text: "exact claim", passageID: passage.id, quote: passage.text),
                    ProposedClaim(text: "paraphrased claim", passageID: passage.id, quote: "a paraphrase that is not present"),
                ]
            )
        case .ambiguousAndUnique:
            guard let repeated = request.passages.first(where: { $0.text == "Cancellation may take time." }),
                  let unique = request.passages.first(where: { $0.text.contains("requires tasks to check") }) else {
                return AnswerProposal(answer: "No matching evidence.", claims: [])
            }
            return AnswerProposal(answer: "Two claims.", claims: [
                ProposedClaim(text: "Cancellation may take time.", passageID: repeated.id, quote: repeated.text),
                ProposedClaim(text: "Cancellation is cooperative.", passageID: unique.id, quote: unique.text),
            ])
        case .failing:
            throw QuickProviderError.emptyAnswer
        }
    }
}

final class LiveQuickTests: XCTestCase {

    func testQuestionOnlyPassageIsNotAnswerEvidence() {
        XCTAssertFalse(EvidenceText.isUsable("Is cancellation cooperative?"))
        XCTAssertTrue(EvidenceText.isUsable("Cancellation is cooperative and child tasks must react to it."))
        XCTAssertFalse(EvidenceText.isUsable("Cancellation is cooperative. Why might a task continue?"))
        XCTAssertTrue(EvidenceText.isUsable("Why might a task continue? Cancellation is cooperative."))
    }

    func testAmbiguousClaimDoesNotEraseUniqueCitedClaim() async throws {
        let url = "https://forum.example.invalid/duplicate-reply"
        let store = SnapshotStore()
        let outcome = await LiveQuickRunner.run(
            question: "How does cancellation work?",
            queries: ["cancellation"],
            deadline: Date().addingTimeInterval(30),
            search: search(["cancellation": [hit(url, query: "cancellation", rank: 0)]]),
            store: store,
            fetch: boundedFetchHTML(
                [url: "<html><body><h1>Cancellation</h1><p>Cancellation may take time.</p><p>Cancellation may take time.</p><p>Cancellation is cooperative and requires tasks to check.</p></body></html>"],
                store: store
            ),
            provider: ProviderSpy(mode: .ambiguousAndUnique),
            label: "hosted"
        )
        guard case let .completed(result) = outcome else {
            return XCTFail("expected unique cited claim to survive, got \(outcome)")
        }
        XCTAssertEqual(result.compilation.citations.count, 1)
        XCTAssertEqual(result.accepted.count, 1)
        XCTAssertTrue(result.answer.contains("Cancellation is cooperative."))
        XCTAssertTrue(result.rejected.contains { $0.reason.contains("ambiguous_quote") })
    }

    func testProvidedPageIsOnlyADiscoveryHitWithNoSnippet() async throws {
        let url = URL(string: "https://docs.example.invalid/swift/task-groups")!
        let search = try LiveQuickComposition.providedPageSearch(url: url)
        let outcome = try await search("swift task group cancellation")
        guard case let .hits(hits) = outcome else { return XCTFail("expected a discovery hit") }
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits[0].url, url)
        XCTAssertEqual(hits[0].snippet, "", "a supplied URL must not become citation evidence")
        XCTAssertEqual(hits[0].query, "swift task group cancellation")
    }

    func testProvidedPageRejectsNonWebAndCredentialURLs() {
        XCTAssertThrowsError(try LiveQuickComposition.providedPageSearch(url: URL(fileURLWithPath: "/tmp/page.html")))
        XCTAssertThrowsError(try LiveQuickComposition.providedPageSearch(url: URL(string: "https://user:password@example.invalid/page")!))
    }

    func testProvidedPageRunsThroughStoredPassageAndCitationPipeline() async throws {
        let page = "https://docs.example.invalid/cancellation"
        let store = SnapshotStore()
        let outcome = await LiveQuickRunner.run(
            question: "How does cancellation work?",
            queries: ["cancellation"],
            deadline: Date().addingTimeInterval(30),
            search: try LiveQuickComposition.providedPageSearch(url: URL(string: page)!),
            store: store,
            fetch: boundedFetch([page: "Cancellation is cooperative and must be checked by each task."], store: store),
            provider: ProviderSpy(mode: .quoteFirstPassage),
            label: "hosted"
        )
        guard case let .completed(result) = outcome else {
            return XCTFail("expected a cited answer from the stored page, got \(outcome)")
        }
        XCTAssertEqual(result.compilation.citations.count, 1)
        let cited = try result.compilation.resolve(result.compilation.citations[0].id)
        XCTAssertTrue(cited.passage.text.contains("Cancellation is cooperative"))
        XCTAssertEqual(result.observation.openedSources, 1)
        let artifact = LiveAnswerArtifact.make(
            from: result,
            provider: "fixture-provider",
            elapsedSeconds: 0,
            generatedAt: "fixture"
        )
        XCTAssertEqual(artifact.citations.first?.sourceURL, URL(string: page))
        XCTAssertEqual(artifact.citations.first?.snapshotID, cited.snapshotID)
        XCTAssertEqual(artifact.citations.first?.quote, cited.evidenceLink.quote)
        XCTAssertEqual(artifact.citations.first?.passageText, cited.passage.text)
    }

    private func hit(_ url: String, query: String, rank: Int, snippet: String = "SNIPPET-ONLY") -> SearchHit {
        SearchHit(
            id: StableIdentity.make("hit", query, url, String(rank)),
            query: query,
            rank: rank,
            url: URL(string: url)!,
            title: "Title",
            snippet: snippet
        )
    }

    private func search(
        _ byQuery: [String: [SearchHit]]
    ) -> @Sendable (String) async throws -> SearchOutcome {
        { query in
            let hits = byQuery[query] ?? []
            return hits.isEmpty ? .noResults(query: query) : .hits(hits)
        }
    }

    /// A bounded-fetch stand-in that extracts and stores each target's body, so
    /// the runner indexes the same store the scheduler would fill.
    private func boundedFetch(
        _ byURL: [String: String],
        store: SnapshotStore
    ) -> @Sendable ([FetchTarget]) async throws -> [FetchResult] {
        let bodies = byURL
        return { targets in
            var results: [FetchResult] = []
            for target in targets {
                guard let body = bodies[target.url.absoluteString] else {
                    results.append(
                        FetchResult(
                            sourceID: target.sourceID,
                            url: target.url,
                            outcome: .refused(FetchRefusal(stage: .acquisition, kind: "transport_failure", reason: "no fixture body")),
                            attempt: 1,
                            attempts: 1
                        )
                    )
                    continue
                }
                let acquisition = AcquisitionResult(
                    requestedURL: target.url,
                    finalURL: target.url,
                    statusCode: 200,
                    contentType: "text/html",
                    body: Data("<html><body><h1>Heading</h1><p>\(body)</p></body></html>".utf8),
                    redirects: []
                )
                let page = try HTMLExtraction.extract(acquisition, sourceID: target.sourceID)
                let outcome = try await store.store(page)
                results.append(
                    FetchResult(
                        sourceID: target.sourceID,
                        url: target.url,
                        outcome: .stored(outcome.record),
                        attempt: 1,
                        attempts: 1
                    )
                )
            }
            return results
        }
    }

    // MARK: Completed

    func testRunnerCompletesWithVerifiedRetrievalBackedCitations() async throws {
        let first = "https://one.example.invalid/first"
        let second = "https://two.example.invalid/second"
        let store = SnapshotStore()
        let provider = ProviderSpy(mode: .quoteFirstPassage)

        let outcome = await LiveQuickRunner.run(
            question: "first mechanism",
            queries: ["first", "second"],
            deadline: Date().addingTimeInterval(30),
            search: search([
                "first": [hit(first, query: "first", rank: 0), hit(second, query: "first", rank: 1)],
                "second": [hit(first, query: "second", rank: 0)],
            ]),
            store: store,
            fetch: boundedFetch([
                first: "Alpha explains the first mechanism in detail.",
                second: "Beta explains the second mechanism in detail.",
            ], store: store),
            provider: provider,
            label: "hosted"
        )

        guard case let .completed(result) = outcome else {
            return XCTFail("expected completion, got \(outcome)")
        }
        XCTAssertEqual(provider.callCount, 1)
        XCTAssertEqual(result.label, "hosted")
        XCTAssertEqual(result.observation.searchQueries, 2)
        XCTAssertEqual(result.observation.openedSources, 2)
        XCTAssertFalse(result.compilation.citations.isEmpty)
        for accepted in result.accepted {
            XCTAssertEqual(accepted.passage.text, accepted.proposal.quote)
        }
        XCTAssertFalse(result.rejected.contains { $0.reason.contains("empty quote") })
    }

    /// Web search and lexical retrieval receive different query shapes. The
    /// search closure can only return a hit for the natural-language question,
    /// and the index can only match the passage through the keyword windows, so
    /// this fails if the runner reuses one list for both.
    func testWebSearchQueryIsSeparateFromRetrievalQuery() async throws {
        let url = "https://split.example.invalid/page"
        let store = SnapshotStore()
        let webQuery = "How do Swift structured concurrency and Grand Central Dispatch differ?"
        let outcome = await LiveQuickRunner.run(
            question: webQuery,
            queries: [webQuery],
            retrievalQueries: ["structured concurrency", "grand central dispatch"],
            deadline: Date().addingTimeInterval(30),
            search: search([webQuery: [hit(url, query: webQuery, rank: 0)]]),
            store: store,
            fetch: boundedFetch(
                [url: "Structured concurrency and Grand Central Dispatch differ in how they schedule work."],
                store: store
            ),
            provider: ProviderSpy(mode: .quoteFirstPassage),
            label: "hosted"
        )
        guard case let .completed(result) = outcome else {
            return XCTFail("expected completion, got \(outcome)")
        }
        XCTAssertEqual(result.observation.searchQueries, 1)
        XCTAssertEqual(result.compilation.citations.count, 1)
    }

    func testSnippetNeverBecomesEvidence() async throws {
        let url = "https://snippet.example.invalid/page"
        let store = SnapshotStore()
        let outcome = await LiveQuickRunner.run(
            question: "snippet",
            queries: ["snippet"],
            deadline: Date().addingTimeInterval(30),
            search: search(["snippet": [hit(url, query: "snippet", rank: 0, snippet: "SNIPPET-ONLY")]]),
            store: store,
            fetch: boundedFetch([url: "The body never contains the snippet marker."], store: store),
            provider: ProviderSpy(mode: .quoteFirstPassage),
            label: "hosted"
        )
        guard case let .completed(result) = outcome else {
            return XCTFail("expected completion, got \(outcome)")
        }
        XCTAssertFalse(result.accepted.contains { $0.passage.text.contains("SNIPPET-ONLY") })
        XCTAssertFalse(result.compilation.passages.contains { $0.text.contains("SNIPPET-ONLY") })
    }

    // MARK: Abstention and failure

    func testNoProviderCallWithoutReadableEvidence() async throws {
        let url = "https://broken.example.invalid/page"
        let store = SnapshotStore()
        let provider = ProviderSpy(mode: .quoteFirstPassage)
        let outcome = await LiveQuickRunner.run(
            question: "anything",
            queries: ["anything"],
            deadline: Date().addingTimeInterval(30),
            search: search(["anything": [hit(url, query: "anything", rank: 0)]]),
            store: store,
            fetch: boundedFetch([:], store: store), // every fetch fails
            provider: provider,
            label: "hosted"
        )
        guard case let .abstained(reason) = outcome else {
            return XCTFail("expected abstention, got \(outcome)")
        }
        XCTAssertEqual(reason, "no readable evidence")
        XCTAssertEqual(provider.callCount, 0)
    }

    func testDeadlineExpiredAbstainsWithoutCallingTheProvider() async throws {
        let store = SnapshotStore()
        let provider = ProviderSpy(mode: .quoteFirstPassage)
        let outcome = await LiveQuickRunner.run(
            question: "anything",
            queries: ["anything"],
            deadline: .distantPast,
            search: search([:]),
            store: store,
            fetch: boundedFetch([:], store: store),
            provider: provider,
            label: "hosted"
        )
        guard case let .abstained(reason) = outcome else {
            return XCTFail("expected abstention, got \(outcome)")
        }
        XCTAssertTrue(reason.contains("deadline"))
        XCTAssertEqual(provider.callCount, 0)
    }

    func testLimitsOutsideTheFrozenCapsFailBeforeRunning() async throws {
        let store = SnapshotStore()
        let provider = ProviderSpy(mode: .quoteFirstPassage)
        let outcome = await LiveQuickRunner.run(
            question: "anything",
            queries: ["a", "b", "c"],
            limits: LiveQuickLimits(searchQueries: 3, openedSources: 6, synthesisPassages: 12, deadlineSeconds: 60),
            deadline: Date().addingTimeInterval(30),
            search: search([:]),
            store: store,
            fetch: boundedFetch([:], store: store),
            provider: provider,
            label: "hosted"
        )
        guard case let .failed(reason) = outcome else {
            return XCTFail("expected failure, got \(outcome)")
        }
        XCTAssertTrue(reason.contains("caps"))
        XCTAssertEqual(provider.callCount, 0)
        XCTAssertFalse(LiveQuickLimits(searchQueries: 3, openedSources: 6, synthesisPassages: 12, deadlineSeconds: 60).isWithinQuickCaps)
        XCTAssertTrue(LiveQuickLimits.quick.isWithinQuickCaps)
    }

    func testProviderFailureIsTyped() async throws {
        let url = "https://provider.example.invalid/page"
        let store = SnapshotStore()
        let outcome = await LiveQuickRunner.run(
            question: "anything",
            queries: ["anything"],
            deadline: Date().addingTimeInterval(30),
            search: search(["anything": [hit(url, query: "anything", rank: 0)]]),
            store: store,
            fetch: boundedFetch([url: "Some readable body about anything."], store: store),
            provider: ProviderSpy(mode: .failing),
            label: "hosted"
        )
        guard case let .failed(reason) = outcome else {
            return XCTFail("expected failure, got \(outcome)")
        }
        XCTAssertTrue(reason.contains("provider failed"), reason)
    }

    // MARK: Trust validation

    func testUntrustedQuotesAndUnknownPassagesAreRejected() throws {
        let body = "Only this sentence is stored."
        let passage = Passage(
            id: StableIdentity.make("passage", "snap", "0", StableIdentity.digest(body)),
            snapshotID: "snap",
            ordinal: 0,
            heading: "h",
            text: body,
            textHash: StableIdentity.digest(body)
        )
        let proposal = AnswerProposal(
            answer: "An answer.",
            claims: [
                ProposedClaim(text: "ok", passageID: passage.id, quote: body),
                ProposedClaim(text: "wrong quote", passageID: passage.id, quote: "not stored"),
                ProposedClaim(text: "unknown", passageID: "missing", quote: body),
                ProposedClaim(text: "blank", passageID: passage.id, quote: "   "),
            ]
        )
        let validation = AnswerTrust.validate(proposal, passages: [passage])
        XCTAssertEqual(validation.accepted.count, 1)
        XCTAssertEqual(validation.rejected.count, 3)
        XCTAssertTrue(validation.rejected.contains { $0.reason.contains("exact") })
        XCTAssertTrue(validation.rejected.contains { $0.reason.contains("unknown passage") })
        XCTAssertTrue(validation.rejected.contains { $0.reason.contains("empty quote") })

        let candidates = AnswerTrust.candidates(from: validation)
        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates[0].quote, body)
        XCTAssertEqual(candidates[0].expectedSnapshotID, "snap")
    }

    /// An exact quote of a question is still a question, not support for a
    /// factual claim. This is the Q2 failure shape: a retrieved forum question
    /// must never be presented as if it answered the question.
    func testQuestionShapedQuoteIsRejected() throws {
        let body = "Would the task pool cause starvation? The pool is bounded."
        let passage = Passage(
            id: StableIdentity.make("passage", "snap", "0", StableIdentity.digest(body)),
            snapshotID: "snap",
            ordinal: 0,
            heading: "h",
            text: body,
            textHash: StableIdentity.digest(body)
        )
        let proposal = AnswerProposal(
            answer: "An answer.",
            claims: [ProposedClaim(text: "asks a question", passageID: passage.id, quote: "Would the task pool cause starvation?")]
        )
        let validation = AnswerTrust.validate(proposal, passages: [passage])
        XCTAssertTrue(validation.accepted.isEmpty)
        XCTAssertTrue(validation.rejected.contains { $0.reason.contains("question") })
    }

    func testPunctuationOnlyQuoteIsRejected() throws {
        let body = "Real text · more real text."
        let passage = Passage(
            id: StableIdentity.make("passage", "snap", "0", StableIdentity.digest(body)),
            snapshotID: "snap",
            ordinal: 0,
            heading: "h",
            text: body,
            textHash: StableIdentity.digest(body)
        )
        let proposal = AnswerProposal(
            answer: "An answer.",
            claims: [ProposedClaim(text: "separator", passageID: passage.id, quote: "·")]
        )
        let validation = AnswerTrust.validate(proposal, passages: [passage])
        XCTAssertTrue(validation.accepted.isEmpty)
        XCTAssertTrue(validation.rejected.contains { $0.reason.contains("no readable content") })
    }

    func testProviderWithNoVerifiableClaimAbstains() async throws {
        let url = "https://unverified.example.invalid/page"
        let store = SnapshotStore()
        let proposal = AnswerProposal(
            answer: "Ungrounded.",
            claims: [ProposedClaim(text: "bad", passageID: "missing", quote: "nope")]
        )
        let outcome = await LiveQuickRunner.run(
            question: "anything",
            queries: ["anything"],
            deadline: Date().addingTimeInterval(30),
            search: search(["anything": [hit(url, query: "anything", rank: 0)]]),
            store: store,
            fetch: boundedFetch([url: "A grounded body about anything."], store: store),
            provider: ProviderSpy(mode: .fixed(proposal)),
            label: "hosted"
        )
        guard case let .abstained(reason) = outcome else {
            return XCTFail("expected abstention, got \(outcome)")
        }
        XCTAssertEqual(reason, "the provider proposed no verifiable claim")
    }

    // MARK: Evidence-text selection

    /// A bounded-fetch stand-in that stores the given HTML verbatim, so a test
    /// can reproduce a real page shape (a rich heading over a junk body)
    /// instead of the single templated paragraph the other helper builds.
    private func boundedFetchHTML(
        _ byURL: [String: String],
        store: SnapshotStore
    ) -> @Sendable ([FetchTarget]) async throws -> [FetchResult] {
        let bodies = byURL
        return { targets in
            var results: [FetchResult] = []
            for target in targets {
                guard let html = bodies[target.url.absoluteString] else {
                    results.append(
                        FetchResult(
                            sourceID: target.sourceID,
                            url: target.url,
                            outcome: .refused(FetchRefusal(stage: .acquisition, kind: "transport_failure", reason: "no fixture body")),
                            attempt: 1,
                            attempts: 1
                        )
                    )
                    continue
                }
                let acquisition = AcquisitionResult(
                    requestedURL: target.url,
                    finalURL: target.url,
                    statusCode: 200,
                    contentType: "text/html",
                    body: Data(html.utf8),
                    redirects: []
                )
                let page = try HTMLExtraction.extract(acquisition, sourceID: target.sourceID)
                let outcome = try await store.store(page)
                results.append(
                    FetchResult(
                        sourceID: target.sourceID,
                        url: target.url,
                        outcome: .stored(outcome.record),
                        attempt: 1,
                        attempts: 1
                    )
                )
            }
            return results
        }
    }

    func testEvidenceTextRejectsChromeAndKeepsProse() {
        XCTAssertFalse(EvidenceText.isUsable("·"))
        XCTAssertFalse(EvidenceText.isUsable("--"))
        XCTAssertFalse(EvidenceText.isUsable("\u{2022}\u{2022}\u{2022}"))
        XCTAssertFalse(EvidenceText.isUsable("   "))
        XCTAssertFalse(EvidenceText.isUsable("Using Swift"))
        XCTAssertFalse(EvidenceText.isUsable("Concurrency and CPU-bound tasks", heading: "Concurrency and CPU-bound tasks"))
        XCTAssertFalse(EvidenceText.isUsable(" latest swift news ", heading: "Latest Swift News"))
        XCTAssertTrue(EvidenceText.isUsable("September 15, 2026", heading: "Swift 6.4 Released"))
        XCTAssertTrue(EvidenceText.isUsable("When the group is finished, cancel all the other tasks."))
        XCTAssertTrue(EvidenceText.isUsable("The --enable-fts5 option is passed to the configure script to build FTS5."))
    }

    /// A page whose only blocks are a navigation label and separators must
    /// contribute no passage, rather than answering from chrome.
    func testChromeOnlyDocumentYieldsNoSelectedPassage() async throws {
        let url = "https://chrome.example.invalid/page"
        let store = SnapshotStore()
        let outcome = await LiveQuickRunner.retrieve(
            question: "Using Swift",
            queries: ["Using Swift"],
            deadline: Date().addingTimeInterval(30),
            search: search(["Using Swift": [hit(url, query: "Using Swift", rank: 0)]]),
            store: store,
            fetch: boundedFetchHTML(
                [url: "<html><body><h1>Using Swift</h1><p>·</p><p>--</p></body></html>"],
                store: store
            )
        )
        guard case let .success(result) = outcome else {
            return XCTFail("expected retrieval success, got \(outcome)")
        }
        XCTAssertTrue(result.passages.isEmpty, "chrome must not be selected: \(result.passages.map(\.text))")
    }

    func testSingleSourceCanSelectAnswerBehindQuestionParagraphs() async throws {
        let url = "https://forum.example.invalid/cancellation"
        let store = SnapshotStore()
        let outcome = await LiveQuickRunner.retrieve(
            question: "How does cancellation work?",
            queries: ["cancellation"],
            deadline: Date().addingTimeInterval(30),
            search: search(["cancellation": [hit(url, query: "cancellation", rank: 0)]]),
            store: store,
            fetch: boundedFetchHTML(
                [url: "<html><body><h1>Cancellation</h1><p>How does cancellation work?</p><p>Why is cancellation delayed?</p><p>Cancellation is cooperative and tasks must check for it.</p></body></html>"],
                store: store
            )
        )
        guard case let .success(result) = outcome else {
            return XCTFail("expected retrieval success, got \(outcome)")
        }
        XCTAssertTrue(result.passages.contains { $0.text.contains("Cancellation is cooperative") })
        XCTAssertFalse(result.passages.contains { $0.text == "How does cancellation work?" })
        XCTAssertFalse(result.passages.contains { $0.text == "Why is cancellation delayed?" })
    }

    /// A relevant heading over a punctuation-only body must not take a slot in
    /// the synthesis budget, and a real passage from another source must still
    /// be selected alongside it.
    func testPunctuationOnlyBlockCannotConsumeTheSynthesisBudget() async throws {
        let chrome = "https://chrome.example.invalid/a"
        let real = "https://real.example.invalid/b"
        let store = SnapshotStore()
        let outcome = await LiveQuickRunner.retrieve(
            question: "How do structured concurrency and GCD differ?",
            queries: ["structured concurrency vs gcd"],
            deadline: Date().addingTimeInterval(30),
            search: search([
                "structured concurrency vs gcd": [
                    hit(chrome, query: "structured concurrency vs gcd", rank: 0),
                    hit(real, query: "structured concurrency vs gcd", rank: 1),
                ],
            ]),
            store: store,
            fetch: boundedFetchHTML(
                [
                    chrome: "<html><body><h1>Structured concurrency vs GCD</h1><p>·</p></body></html>",
                    real: "<html><body><h1>Structured concurrency vs GCD</h1><p>Structured concurrency models tasks; GCD dispatches queues.</p></body></html>",
                ],
                store: store
            )
        )
        guard case let .success(result) = outcome else {
            return XCTFail("expected retrieval success, got \(outcome)")
        }
        XCTAssertFalse(result.passages.contains { $0.text == "·" }, "a punctuation-only block must not be selected")
        XCTAssertTrue(
            result.passages.contains { $0.text.contains("dispatches queues") },
            "the real passage must survive: \(result.passages.map(\.text))"
        )
    }

    // MARK: Displayed answer

    /// The displayed answer must be assembled from accepted claims with visible
    /// markers; the model's free prose must never leak in as if it were sourced.
    func testDisplayedAnswerIsAssembledFromAcceptedClaimsWithMarkers() async throws {
        let url = "https://display.example.invalid/page"
        let store = SnapshotStore()
        let outcome = await LiveQuickRunner.run(
            question: "fact",
            queries: ["fact"],
            deadline: Date().addingTimeInterval(30),
            search: search(["fact": [hit(url, query: "fact", rank: 0)]]),
            store: store,
            fetch: boundedFetch([url: "The stored passage states the exact fact."], store: store),
            provider: ProviderSpy(mode: .quoteFirstPassage),
            label: "hosted"
        )
        guard case let .completed(result) = outcome else {
            return XCTFail("expected completion, got \(outcome)")
        }
        XCTAssertFalse(result.answer.contains("Answer grounded in"), "unsupported prose must not be displayed: \(result.answer)")
        XCTAssertTrue(result.answer.contains("A supported claim. [1]"), "\(result.answer)")
        XCTAssertTrue(result.answer.contains("[1]"), "a visible citation marker is required: \(result.answer)")
        XCTAssertEqual(result.compilation.citations.count, 1)
        XCTAssertEqual(try result.compilation.resolve(result.compilation.citations[0].id).claim.text, "A supported claim.")
    }

    /// A paraphrase that is not an exact substring is rejected, and neither the
    /// rejected claim nor the model's prose reaches the displayed answer.
    func testOnlyExactQuotesReachTheDisplayedAnswer() async throws {
        let url = "https://exact.example.invalid/page"
        let store = SnapshotStore()
        let outcome = await LiveQuickRunner.run(
            question: "cancellation",
            queries: ["cancellation"],
            deadline: Date().addingTimeInterval(30),
            search: search(["cancellation": [hit(url, query: "cancellation", rank: 0)]]),
            store: store,
            fetch: boundedFetch([url: "Cancellation is cooperative and not automatic."], store: store),
            provider: ProviderSpy(mode: .paraphrasingAndExact),
            label: "hosted"
        )
        guard case let .completed(result) = outcome else {
            return XCTFail("expected completion, got \(outcome)")
        }
        XCTAssertTrue(result.answer.contains("exact claim [1]"))
        XCTAssertFalse(result.answer.contains("paraphrased claim"))
        XCTAssertFalse(result.answer.contains("PARAPHRASED PROSE"))
        XCTAssertEqual(result.rejected.count, 1)
        XCTAssertTrue(result.rejected.contains { $0.reason.contains("exact") })
    }

    // MARK: Source authority

    /// Official documentation and project forums are tier 0; personal blogs and
    /// aggregators are tier 1. This is source-type discovery ordering, not a
    /// citation rule.
    func testSourceAuthorityTiers() {
        XCTAssertEqual(SourceAuthority.tier(for: URL(string: "https://docs.swift.org/swift-book/")!), 0)
        XCTAssertEqual(SourceAuthority.tier(for: URL(string: "https://developer.apple.com/documentation/swift")!), 0)
        XCTAssertEqual(SourceAuthority.tier(for: URL(string: "https://forums.swift.org/t/thread")!), 0)
        XCTAssertEqual(SourceAuthority.tier(for: URL(string: "https://www.sqlite.org/fts5.html")!), 0)
        XCTAssertEqual(SourceAuthority.tier(for: URL(string: "https://sqlite.org/fts5.html")!), 0)
        XCTAssertEqual(SourceAuthority.tier(for: URL(string: "https://github.com/swiftlang/swift-evolution")!), 0)
        XCTAssertEqual(SourceAuthority.tier(for: URL(string: "https://medium.com/@author/post")!), 1)
        XCTAssertEqual(SourceAuthority.tier(for: URL(string: "https://swiftwithmajid.com/post")!), 1)
        XCTAssertEqual(SourceAuthority.tier(for: URL(string: "https://github.com/other/repo")!), 1)
        XCTAssertEqual(SourceAuthority.tier(for: URL(string: "https://docs.untrusted.example.com/swift")!), 1)
        XCTAssertEqual(SourceAuthority.tier(for: URL(string: "https://developer.untrusted.net/swift")!), 1)
        XCTAssertEqual(SourceAuthority.tier(for: URL(string: "https://docs.python.org/3/library/asyncio-task.html")!), 0)
    }

    /// Ordering is stable inside a tier: the search engine's own order is kept
    /// for non-authoritative results.
    func testOfficialSourcesAreOpenedBeforeBlogsAndOrderIsStable() {
        func hit(_ string: String) -> SearchHit {
            SearchHit(id: string, query: "q", rank: 0, url: URL(string: string)!, title: "", snippet: "")
        }
        let ordered = SourceAuthority.ordered([
            hit("https://medium.com/a"),
            hit("https://docs.swift.org/b"),
            hit("https://blog.example.invalid/c"),
            hit("https://forums.swift.org/d"),
        ])
        XCTAssertEqual(
            ordered.map(\.url.absoluteString),
            [
                "https://docs.swift.org/b",
                "https://forums.swift.org/d",
                "https://medium.com/a",
                "https://blog.example.invalid/c",
            ]
        )
    }
}
