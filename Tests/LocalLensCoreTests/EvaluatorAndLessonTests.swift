import Foundation
import XCTest
@testable import LocalLensCore

final class EvaluatorAndLessonTests: XCTestCase {
    private func features(
        citations: Int,
        unsupported: Int = 0,
        partial: Int = 0,
        covered: Int = 3,
        total: Int = 3,
        abstained: Bool = false,
        integrity: Bool = true
    ) -> AnswerEvaluator.Features {
        AnswerEvaluator.Features(
            citations: citations,
            unsupportedCitations: unsupported,
            partialCitations: partial,
            rejectedClaims: 0,
            acceptedClaims: citations,
            coveredDimensions: covered,
            totalDimensions: total,
            abstained: abstained,
            integrityPassed: integrity
        )
    }

    func testEvaluatorScoresFromCountedFeaturesOnly() {
        XCTAssertEqual(AnswerEvaluator.predict(features(citations: 3)).score, 2)
        XCTAssertEqual(AnswerEvaluator.predict(features(citations: 1)).score, 1)
        XCTAssertEqual(AnswerEvaluator.predict(features(citations: 0)).score, 0)
        // An integrity failure cannot be scored above zero, whatever else is true.
        XCTAssertEqual(AnswerEvaluator.predict(features(citations: 5, integrity: false)).score, 0)
        // A reviewer-unsupported citation caps the score and says so.
        let capped = AnswerEvaluator.predict(features(citations: 4, unsupported: 1))
        XCTAssertEqual(capped.score, 1)
        XCTAssertTrue(capped.reasons.contains { $0.contains("unsupported") })
        // Two citations with thin coverage is not a full score.
        XCTAssertEqual(AnswerEvaluator.predict(features(citations: 3, covered: 1, total: 4)).score, 1)
        // An abstention where dimensions had no evidence is the wanted outcome.
        XCTAssertEqual(AnswerEvaluator.predict(features(citations: 0, covered: 0, total: 3, abstained: true)).score, 2)
        XCTAssertEqual(AnswerEvaluator.predict(features(citations: 0, covered: 3, total: 3, abstained: true)).score, 1)
        XCTAssertFalse(AnswerEvaluator.predict(features(citations: 2)).reasons.isEmpty)
    }

    func testCalibrationReportsItsOwnInsufficiency() {
        let few = EvaluatorCalibration.report([
            .init(questionID: "q1", human: 1, predicted: 1),
            .init(questionID: "q2", human: 2, predicted: 1),
        ])
        XCTAssertFalse(few.isCalibrated)
        XCTAssertTrue(few.verdict.contains("2 label(s)"))
        XCTAssertEqual(few.exactAgreement, 0.5, accuracy: 0.0001)
        XCTAssertEqual(few.meanAbsoluteError, 0.5, accuracy: 0.0001)
        XCTAssertEqual(few.worstError, 1)

        let empty = EvaluatorCalibration.report([])
        XCTAssertFalse(empty.isCalibrated)
        XCTAssertTrue(empty.verdict.contains("no labels"))

        // Enough samples and small error is the only path to "calibrated".
        let many = (0..<EvaluatorCalibration.minimumSamples).map {
            EvaluatorCalibration.Sample(questionID: "q\($0)", human: $0 % 3, predicted: $0 % 3)
        }
        let good = EvaluatorCalibration.report(many)
        XCTAssertTrue(good.isCalibrated)
        XCTAssertEqual(good.meanAbsoluteError, 0)

        let skewed = EvaluatorCalibration.report(many.map {
            EvaluatorCalibration.Sample(questionID: $0.questionID, human: $0.human, predicted: ($0.human + 2) % 3)
        })
        XCTAssertFalse(skewed.isCalibrated, "a two-point miss is never calibrated")
    }

    func testLearningCardIsBuiltFromTheRunAndFromAnAbstention() async throws {
        let base = "https://docs.example.invalid/alpha"
        let store = SnapshotStore()
        let plan = ResearchPlanner.plan("how does alpha work", mode: .quick, now: Date(timeIntervalSince1970: 0))
        let search: @Sendable (String) async throws -> SearchOutcome = { query in
            .hits([SearchHit(id: query, query: query, rank: 0, url: URL(string: base)!, title: "T", snippet: "")])
        }
        let searchAPI = SearchAdapterBox(search: search)
        let outcome = await ResearchRunner.run(
            plan: plan,
            deadline: Date().addingTimeInterval(30),
            search: searchAPI.search,
            store: store,
            fetch: FixtureFetch.make([base: "Alpha works by doing beta and gamma."], store: store),
            provider: LessonProvider(),
            label: "hosted"
        )
        let coverage = ["Answer": 1]
        let card = try XCTUnwrap(LearningCard.make(
            plan: plan,
            outcome: outcome,
            stopReason: .evidenceSaturated,
            coverage: coverage,
            gapDimensions: []
        ))
        XCTAssertEqual(card.explained.count, 1)
        XCTAssertEqual(card.explained[0].quote, "Alpha works by doing beta and gamma.")
        XCTAssertEqual(card.explained[0].citationMarker, 1)
        XCTAssertEqual(card.label, "hosted")
        let markdown = card.markdown()
        XCTAssertTrue(markdown.contains("Alpha works by doing beta and gamma."))
        XCTAssertTrue(markdown.contains("stop") || markdown.contains("Why the run stopped"))
        XCTAssertTrue(markdown.contains("## Explain back"))
        XCTAssertTrue(card.prompts.contains { $0.question.contains("exact sentence") })

        // An abstention produces a lesson about the abstention.
        let abstained = try XCTUnwrap(LearningCard.make(
            plan: plan,
            outcome: .abstained(reason: "no usable retrieved evidence"),
            stopReason: .noEvidence,
            coverage: ["Answer": 0],
            gapDimensions: ["Answer"]
        ))
        XCTAssertTrue(abstained.explained.isEmpty)
        XCTAssertTrue(abstained.answer.contains("abstained"))
        XCTAssertTrue(abstained.prompts.contains { $0.question.contains("no answer") })
        XCTAssertTrue(abstained.markdown().contains("## Coverage"))

        // A failed run has no lesson to teach.
        XCTAssertNil(LearningCard.make(
            plan: plan,
            outcome: .failed(reason: "cancelled"),
            stopReason: .cancelled,
            coverage: [:],
            gapDimensions: []
        ))
    }
}

private struct SearchAdapterBox: Sendable {
    let search: @Sendable (String) async throws -> SearchOutcome
}

private enum FixtureFetch {
    static func make(_ bodies: [String: String], store: SnapshotStore) -> @Sendable ([FetchTarget]) async throws -> [FetchResult] {
        { targets in
            var results: [FetchResult] = []
            for target in targets {
                guard let body = bodies[target.url.absoluteString] else { continue }
                let acquisition = AcquisitionResult(
                    requestedURL: target.url,
                    finalURL: target.url,
                    statusCode: 200,
                    contentType: "text/html",
                    body: Data("<html><body><h1>Heading</h1><p>\(body)</p></body></html>".utf8),
                    redirects: []
                )
                let page = try HTMLExtraction.extract(acquisition, sourceID: target.sourceID)
                let stored = try await store.store(page)
                results.append(FetchResult(
                    sourceID: target.sourceID,
                    url: target.url,
                    outcome: .stored(stored.record),
                    attempt: 1,
                    attempts: 1
                ))
            }
            return results
        }
    }
}

private final class LessonProvider: QuickAnswerProvider, @unchecked Sendable {
    func answer(_ request: AnswerRequest) async throws -> AnswerProposal {
        guard let passage = request.passages.first else {
            return AnswerProposal(answer: "No passage.", claims: [])
        }
        return AnswerProposal(
            answer: "Grounded answer.",
            claims: [ProposedClaim(text: "Alpha works.", passageID: passage.id, quote: passage.text)]
        )
    }
}
