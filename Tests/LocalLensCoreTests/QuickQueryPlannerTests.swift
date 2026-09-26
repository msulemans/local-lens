import XCTest
@testable import LocalLensCore

final class QuickQueryPlannerTests: XCTestCase {

    func testStripsInterrogativesStopwordsAndShortTokens() {
        XCTAssertEqual(
            QuickQueryPlanner.contentTerms(of: "How does Swift's structured concurrency cancel a task group?"),
            ["swift", "structured", "concurrency", "cancel", "task", "group"]
        )
    }

    /// Web search usually gets the natural-language question; the measured
    /// Swift-release ambiguity is a separate narrow exception. The keyword
    /// windows remain available for the lexical index via `plan`.
    func testWebQueriesUseTheNaturalQuestion() {
        let question = "How does Swift's structured concurrency cancel a task group?"
        XCTAssertEqual(QuickQueryPlanner.webQueries(question: question), [question])
        XCTAssertNotEqual(QuickQueryPlanner.webQueries(question: question), QuickQueryPlanner.plan(question: question))
        XCTAssertTrue(QuickQueryPlanner.webQueries(question: "   ").isEmpty)
        XCTAssertTrue(QuickQueryPlanner.webQueries(question: "the and of").isEmpty)
        XCTAssertTrue(QuickQueryPlanner.webQueries(question: "anything", maximumQueries: 0).isEmpty)
    }

    func testLatestStableSwiftReleaseDisambiguatesFinancialSwift() {
        XCTAssertEqual(
            QuickQueryPlanner.webQueries(question: "What is the latest stable Swift release in 2026?"),
            ["Swift programming language latest stable release 2026"]
        )
        XCTAssertEqual(
            QuickQueryPlanner.webQueries(question: "How does Swift cancel a task group?"),
            ["How does Swift cancel a task group?"]
        )
    }

    func testMeasuredCPUComparisonSplitsDiscoveryAcrossBothSides() {
        let question = "How do Swift structured concurrency and Grand Central Dispatch differ for CPU-bound work?"
        let expected = [
            "Swift structured concurrency CPU bound work thread pool",
            "Grand Central Dispatch CPU bound work concurrent queues Apple documentation",
        ]
        XCTAssertEqual(QuickQueryPlanner.webQueries(question: question), expected)
        XCTAssertEqual(QuickQueryPlanner.webQueries(question: question, maximumQueries: 1), [expected[0]])
        XCTAssertEqual(QuickQueryPlanner.webQueries(question: question, maximumQueries: 0), [])
        XCTAssertEqual(QuickQueryPlanner.webQueries(question: "How do Swift and GCD differ?"),
                       ["How do Swift and GCD differ?"])
    }

    func testPythonTaskGroupFailureUsesOfficialPassageWordingOnlyForLexicalSelection() {
        let question = "What happens when a Python asyncio TaskGroup child raises an exception?"
        XCTAssertEqual(
            QuickQueryPlanner.plan(question: question),
            ["task fails exception remaining tasks cancelled"]
        )
        XCTAssertEqual(QuickQueryPlanner.webQueries(question: question), [question])
        XCTAssertTrue(QuickQueryPlanner.plan(question: question, maximumQueries: 0).isEmpty)
        XCTAssertEqual(
            QuickQueryPlanner.plan(question: "What is a JavaScript TaskGroup exception?"),
            ["javascript taskgroup exception"]
        )
    }

    func testFTS5QuestionLeadsWithTheCompileOptionsCheck() {
        let question = "How do I enable FTS5 in the system SQLite on macOS?"
        XCTAssertEqual(
            QuickQueryPlanner.plan(question: question),
            ["pragma compile_options", "enable fts5 system sqlite"]
        )
        XCTAssertEqual(QuickQueryPlanner.webQueries(question: question), [question])
        // A SQLite question that is not about FTS5 keeps the ordinary windows.
        XCTAssertEqual(
            QuickQueryPlanner.plan(question: "How do I vacuum a SQLite database?"),
            ["vacuum sqlite database"]
        )
    }

    func testShortQuestionYieldsOneQuery() {
        XCTAssertEqual(QuickQueryPlanner.plan(question: "How do I cancel a task?"), ["cancel task"])
    }

    func testLongQuestionYieldsTwoFourTermWindows() {
        XCTAssertEqual(
            QuickQueryPlanner.plan(question: "How does Swift's structured concurrency cancel a task group?"),
            ["swift structured concurrency cancel", "concurrency cancel task group"]
        )
    }

    func testPlanNeverExceedsTheFrozenCap() {
        let queries = QuickQueryPlanner.plan(
            question: "How do Swift structured concurrency and Grand Central Dispatch differ for CPU-bound work?"
        )
        XCTAssertTrue((1...2).contains(queries.count), "\(queries)")
        XCTAssertTrue(queries.allSatisfy { !$0.isEmpty })
    }

    func testLongQuestionYieldsTwoDistinctQueries() {
        let queries = QuickQueryPlanner.plan(
            question: "why does the swift compiler optimize generic specialization across modules differently than monomorphization in c templates"
        )
        XCTAssertEqual(queries.count, 2)
        XCTAssertNotEqual(queries[0], queries[1])
    }

    func testEmptyOrTermlessQuestionDegradesSafely() {
        XCTAssertTrue(QuickQueryPlanner.plan(question: "   ").isEmpty)
        XCTAssertTrue(QuickQueryPlanner.plan(question: "the and of").isEmpty)
        XCTAssertTrue(QuickQueryPlanner.plan(question: "anything", maximumQueries: 0).isEmpty)
    }
}
