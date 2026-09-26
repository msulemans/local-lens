import XCTest

@testable import LocalLensCore

/// The three mode defects a live four-mode run measured on 2026-09-26. Each
/// test states the measured failure in its name so a future change that
/// reintroduces it fails here.
final class NewsRelevanceTests: XCTestCase {

    private func item(_ title: String, snippet: String = "", domain: String = "example.com") -> NewsRelevantItem {
        NewsRelevantItem(id: "https://\(domain)/\(title.hashValue)", title: title, snippet: snippet, domain: domain)
    }

    // MARK: - Relevance

    /// a stablecoin approval is not evidence about the EU AI Act
    func testOffTopicResultsAreDropped() {
        let question = "What changed in the EU AI Act enforcement this month?"
        let items = [
            item("EU AI Act literacy changes may complicate compliance", domain: "iapp.org"),
            item("Stablecoin provider Bastion lands conditional OCC trust bank approval", domain: "fintechfutures.com"),
            item("Government publishes guidance on biodiversity net gain", domain: "osborneclarke.com"),
            item("British EUDR? UK government to introduce anti-deforestation rules", domain: "foodnavigator.com"),
            item("Commercial Vehicle Intelligence Brief", domain: "automotiveworld.com"),
        ]
        let decision = NewsRelevance.apply(items, question: question)
        XCTAssertEqual(decision.kept.map(\.domain), ["iapp.org"])
        XCTAssertEqual(decision.droppedCount, 4)
        XCTAssertFalse(decision.isStarved)
        // EUDR must not match EU: the term matches whole words only.
        XCTAssertFalse(NewsRelevance.containsTerm("eu", in: "British EUDR rules"))
        XCTAssertTrue(NewsRelevance.containsTerm("eu", in: "the EU rules"))
    }

    /// relevance refuses to starve a run and says it did not apply
    func testRelevanceNeverStarvesARun() {
        let items = [
            item("Quarterly notebook", domain: "a.com"),
            item("Seasonal produce report", domain: "b.com"),
        ]
        let decision = NewsRelevance.apply(items, question: "What changed in the EU AI Act this month?")
        XCTAssertEqual(decision.kept.count, 2)
        XCTAssertTrue(decision.isStarved)
        XCTAssertTrue(decision.droppedCount == 2)
    }

    /// a headline shares the question's subject or it does not
    func testSnippetCountsTowardsRelevance() {
        let decision = NewsRelevance.apply(
            [item("Markets open higher", snippet: "Regulators discussed the AI Act timeline today.", domain: "c.com")],
            question: "What changed in the EU AI Act enforcement this month?"
        )
        XCTAssertEqual(decision.kept.count, 1)
    }

    /// question terms keep acronyms and drop filler
    func testQuestionTermsAreContentBearing() {
        let terms = NewsRelevance.questionTerms(of: "What changed in the EU AI Act enforcement this month?")
        XCTAssertTrue(terms.contains("eu"))
        XCTAssertTrue(terms.contains("ai"))
        XCTAssertTrue(terms.contains("enforcement"))
        XCTAssertFalse(terms.contains("what"))
        XCTAssertFalse(terms.contains("this"))
        // A shouted two-letter word that is not an acronym is not topic.
        XCTAssertFalse(NewsRelevance.questionTerms(of: "What is up with the EU AI Act?").contains("up"))
    }

    /// an empty question leaves discovery untouched
    func testEmptyQuestionKeepsEverything() {
        let decision = NewsRelevance.apply([item("Anything")], question: "   ")
        XCTAssertEqual(decision.kept.count, 1)
        XCTAssertTrue(decision.terms.isEmpty)
    }

    // MARK: - Claim depth

    /// three claims and one confirmed voice is a thin claim set
    func testThinClaimSetIsNamed() {
        let depth = NewsClaimDepth.evaluate(support: [1, 2, 1])
        XCTAssertEqual(depth.claimCount, 3)
        XCTAssertEqual(depth.confirmedClaimCount, 1)
        XCTAssertFalse(depth.isThin)
        XCTAssertTrue(depth.summary.contains("1 of 3"))
    }

    /// a claim set no second voice carries is thin and says so
    func testSingleSourceClaimSetIsThin() {
        let depth = NewsClaimDepth.evaluate(support: [1, 1, 1])
        XCTAssertTrue(depth.isThin)
        XCTAssertEqual(depth.maximumSupport, 1)
        XCTAssertTrue(depth.summary.contains("single-source throughout"))
    }

    /// no accepted claims is not a claim set
    func testEmptyClaimSetIsNotThin() {
        let depth = NewsClaimDepth.evaluate(support: [])
        XCTAssertFalse(depth.isThin)
        XCTAssertTrue(depth.summary.contains("No claim survived"))
    }

    // MARK: - Coverage precision

    /// a year is not timeline evidence and one 'however' is not a gap
    func testCoverageNoLongerCountsKeywordCoincidence() {
        // The measured failure: `20` in the term list matched every year, so a
        // Deep run reported `Timeline · 16`, and a single `however` reported
        // `Gaps · 2` for a gap that had not been addressed.
        let passage = Passage(
            id: "p1",
            snapshotID: "s1",
            ordinal: 0,
            heading: "1. INTRODUCTION",
            text: "The rollback journal was replaced in 2026, however the checkpoint behaviour differs.",
            textHash: "h1"
        )
        let coverage = ResearchRunner.coverage(
            for: ["Timeline", "Gaps", "Tradeoffs"],
            passages: [passage],
            claims: []
        )
        XCTAssertEqual(coverage["Timeline"], 0)
        XCTAssertEqual(coverage["Gaps"], 0)
        XCTAssertEqual(coverage["Tradeoffs"], 0)
    }

    /// real dimension vocabulary still counts as coverage
    func testRealCoverageStillCounts() {
        let gap = Passage(
            id: "p1",
            snapshotID: "s1",
            ordinal: 0,
            heading: "Discussion",
            text: "It remains an open question whether the effect generalises.",
            textHash: "h1"
        )
        let tradeoff = Passage(
            id: "p2",
            snapshotID: "s1",
            ordinal: 1,
            heading: "Benchmarks",
            text: "The tradeoff is write latency against reader concurrency.",
            textHash: "h2"
        )
        let coverage = ResearchRunner.coverage(for: ["Gaps", "Tradeoffs"], passages: [gap, tradeoff], claims: [])
        XCTAssertEqual(coverage["Gaps"], 1)
        XCTAssertEqual(coverage["Tradeoffs"], 1)
    }

    /// a custom dimension still matches its own words
    func testCustomDimensionStillMatches() {
        XCTAssertTrue(DimensionLexicon.covers("Cost", text: "The cost of the write path grows."))
        XCTAssertFalse(DimensionLexicon.covers("Cost", text: "Nothing relevant here."))
    }

    /// substring matching cannot mark a dimension covered
    func testSubstringMatchingIsGone() {
        // `cost` used to match `costly`, and `20` used to match `2026`.
        XCTAssertFalse(DimensionLexicon.covers("Cost", text: "The costly migration."))
        XCTAssertFalse(DimensionLexicon.covers("Timeline", text: "Published in 2026."))
    }
}


/// A regression guard for a fixture the app's contrast panel depends on, and a
/// check that the measured pair the panel would show is a real one.
///
/// The wiring itself - a scan result reaching `ResearchReport.contradictions` -
/// is verified by a live run in `docs/evidence/M009/m0093-*.md`, not here: the
/// report needs a compiled citation set to construct, and a hand-built one
/// would test the fixture rather than the pipeline.
final class ResearchReportWiringTests: XCTestCase {

    func testScanFindsARealPairWhenTwoPagesDisagree() {
        let passages = [
            Passage(
                id: "p1",
                snapshotID: "s1",
                ordinal: 0,
                heading: "Benchmarks",
                text: "SQLite wrote 400 transactions per second in the benchmark.",
                textHash: "h1"
            ),
            Passage(
                id: "p2",
                snapshotID: "s2",
                ordinal: 0,
                heading: "Benchmarks",
                text: "SQLite wrote 1200 transactions per second in the benchmark.",
                textHash: "h2"
            ),
        ]
        let records = [
            SnapshotRecord(
                snapshot: Snapshot(
                    id: "s1",
                    sourceID: "a.example",
                    contentHash: "h1",
                    extractedText: passages[0].text,
                    extractorVersion: "test"
                ),
                passages: [passages[0]],
                sourceIDs: ["a.example"],
                requestedURLs: [URL(string: "https://a.example/x")!],
                finalURL: URL(string: "https://a.example/x")!,
                attempt: 1,
                duplicateAttempts: 0
            ),
            SnapshotRecord(
                snapshot: Snapshot(
                    id: "s2",
                    sourceID: "b.example",
                    contentHash: "h2",
                    extractedText: passages[1].text,
                    extractorVersion: "test"
                ),
                passages: [passages[1]],
                sourceIDs: ["b.example"],
                requestedURLs: [URL(string: "https://b.example/y")!],
                finalURL: URL(string: "https://b.example/y")!,
                attempt: 1,
                duplicateAttempts: 0
            ),
        ]
        let found = ContradictionScan.contradictions(passages: passages, records: records)
        XCTAssertEqual(found.count, 1, "the fixture is a real pair, so the wiring test above is meaningful")
        XCTAssertEqual(found.first?.leftValue, "400")
        XCTAssertEqual(found.first?.rightValue, "1200")
    }
}

/// The second correction to the filter, measured instead of assumed: the first
/// version kept anything sharing one question word, and a live run dropped
/// nothing because "month" and "act" are ordinary headline words.
final class NewsRelevancePrecisionTests: XCTestCase {

    private func item(_ title: String, snippet: String = "", domain: String = "e.com") -> NewsRelevantItem {
        NewsRelevantItem(id: title, title: title, snippet: snippet, domain: domain)
    }

    private let question = "What changed in the EU AI Act enforcement this month?"

    func testOneOrdinaryWordIsNotATopic() {
        let decision = NewsRelevance.apply([
            item("Content of the Month 📚📺🎧", domain: "cdt.org"),
            item("Jim Cramer recaps what he heard from leaders in the AI space", domain: "cnbc.com"),
        ], question: question)
        XCTAssertEqual(decision.droppedCount, 2, "month and ai alone are not the subject")
        XCTAssertTrue(decision.isStarved)
    }

    func testTwoWordsOrAPhraseKeepAResult() {
        XCTAssertTrue(NewsRelevance.matches(
            title: "The EU AI Act's Costs to American Innovation",
            snippet: "",
            terms: NewsRelevance.questionTerms(of: question)
        ))
        XCTAssertTrue(NewsRelevance.matches(
            title: "EU AI Act literacy changes may complicate compliance",
            snippet: "",
            terms: NewsRelevance.questionTerms(of: question)
        ))
    }

    func testOneDistinctiveWordIsEnough() {
        let terms = NewsRelevance.questionTerms(of: "How does SQLite WAL mode handle readers and writers?")
        XCTAssertTrue(NewsRelevance.matches(title: "SQLite explained for small apps", snippet: "", terms: terms))
        XCTAssertFalse(NewsRelevance.isDistinctive("wal"))
        XCTAssertTrue(NewsRelevance.isDistinctive("sqlite"))
    }
}
