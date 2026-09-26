import Foundation
import XCTest
@testable import LocalLensCore

final class BenchmarkScorecardTests: XCTestCase {
    // MARK: Fixture compilation

    private func compilation() -> CitationCompilation {
        let passage = Passage(
            id: "p1",
            snapshotID: "s1",
            ordinal: 0,
            heading: "Heading",
            text: "Alpha reduces latency by 40 percent in the measured benchmark.",
            textHash: "h1"
        )
        let claim = Claim(id: "c1", dimension: "Answer", text: "Alpha reduces latency by 40 percent.")
        let foreign = Claim(id: "c2", dimension: "Answer", text: "A second claim.")
        let link = EvidenceLink(
            id: "e1",
            claimID: "c1",
            passageID: "p1",
            relation: .supports,
            quote: "Alpha reduces latency by 40 percent"
        )
        let citation = Citation(id: "cit1", claimID: "c1", evidenceLinkIDs: ["e1"])
        return CitationCompilation(
            claims: [claim, foreign],
            evidenceLinks: [link],
            citations: [citation],
            passages: [passage]
        )
    }

    // MARK: Corruption checks

    func testValidCompilationResolvesAndEveryCorruptionIsDetected() throws {
        let valid = compilation()
        XCTAssertNoThrow(try valid.validate())
        let findings = CitationBoundaryCheck.corruptions(of: valid)
        XCTAssertEqual(
            findings.map(\.kind),
            ["altered_quote", "missing_passage", "mismatched_claim", "unknown_citation"]
        )
        for finding in findings {
            XCTAssertTrue(finding.detected, "\(finding.kind) was not detected: \(finding.detail)")
        }
    }

    func testAnEmptyCompilationReportsThatItHasNothingToCorrupt() {
        let empty = CitationCompilation(claims: [], evidenceLinks: [], citations: [], passages: [])
        let findings = CitationBoundaryCheck.corruptions(of: empty)
        XCTAssertEqual(findings.map(\.kind), ["no_evidence"])
        XCTAssertTrue(findings[0].detected)
    }

    // MARK: Card parsing

    func testCardDecodingRefusesMalformedInput() throws {
        let valid = #"{"name":"frozen","questions":[{"id":"q1","question":"Why?","mode":"deep","checks":["a"]}]}"#
        let card = try BenchmarkCard.decode(Data(valid.utf8))
        XCTAssertEqual(card.name, "frozen")
        XCTAssertEqual(card.questions.first?.mode, .deep)
        XCTAssertEqual(card.questions.first?.checks, ["a"])

        XCTAssertThrowsError(try BenchmarkCard.decode(Data("[]".utf8)))
        XCTAssertThrowsError(try BenchmarkCard.decode(Data(#"{"questions":[]}"#.utf8))) { error in
            XCTAssertEqual(error as? BenchmarkCardError, .missingName)
        }
        XCTAssertThrowsError(try BenchmarkCard.decode(Data(#"{"name":"x","questions":[]}"#.utf8))) { error in
            XCTAssertEqual(error as? BenchmarkCardError, .missingQuestions)
        }
        XCTAssertThrowsError(
            try BenchmarkCard.decode(Data(#"{"name":"x","questions":[{"id":"q","question":"Q","mode":"sideways"}]}"#.utf8))
        ) { error in
            XCTAssertEqual(error as? BenchmarkCardError, .questionMissingField(index: 0, field: "mode"))
        }
    }

    // MARK: Scorecard arithmetic

    private func result(
        _ id: String,
        label: String = "local",
        citations: Int = 2,
        elapsed: Double,
        integrity: Bool = true,
        usefulness: Int? = nil
    ) -> BenchmarkQuestionResult {
        BenchmarkQuestionResult(
            questionID: id,
            mode: .quick,
            label: label,
            provider: "local/m",
            citations: citations,
            rejectedClaims: 0,
            acceptedClaims: citations,
            elapsedSeconds: elapsed,
            openedSources: 4,
            passages: 10,
            integrityPassed: integrity,
            stopReason: "follow_up_budget_exhausted",
            usefulness: usefulness
        )
    }

    func testScorecardKeepsTheMetricsApart() throws {
        let card = BenchmarkScorecard(
            card: "frozen",
            label: "local",
            provider: "local/m",
            results: [
                result("q1", elapsed: 10, usefulness: 2),
                result("q2", elapsed: 30, usefulness: 1),
                result("q3", elapsed: 20, integrity: false),
            ]
        )
        // Integrity is a share of questions whose citations all resolved.
        XCTAssertEqual(card.citationIntegrity, 2.0 / 3.0, accuracy: 0.0001)
        // Usefulness is only over scored questions, and an unscored card is not
        // a perfect one.
        XCTAssertEqual(card.scorableQuestions, 2)
        XCTAssertEqual(try XCTUnwrap(card.meanUsefulness), 1.5, accuracy: 0.0001)
        XCTAssertEqual(card.medianLatencySeconds, 20)
        XCTAssertTrue(card.summary.contains("usefulness 1.50 over 2/3 scored"))
        XCTAssertTrue(card.summary.contains("integrity 66%"))
        XCTAssertFalse(card.summary.contains("local · 1."), "local and hosted are never merged into one number")

        let unscored = BenchmarkScorecard(card: "frozen", label: "hosted", provider: "deepseek", results: [result("q1", elapsed: 5)])
        XCTAssertNil(unscored.meanUsefulness)
        XCTAssertTrue(unscored.summary.contains("usefulness unscored"))

        let data = try card.json()
        let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(root["label"] as? String, "local")
        XCTAssertEqual(root["scorable_questions"] as? Int, 2)
        XCTAssertNil(root["mean_usefulness_hosted"], "there is no combined scorecard document")
        let rows = try XCTUnwrap(root["results"] as? [[String: Any]])
        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(rows[2]["integrity_passed"] as? Bool, false)
        XCTAssertNil(rows[2]["usefulness"])
    }

    // MARK: Review workflow

    private func packet(usefulness: Int?, verdict: String?, reviewer: String = "owner") -> ReviewPacket {
        ReviewPacket(
            card: "frozen",
            label: "local",
            provider: "local/m",
            reviewer: reviewer,
            reviewedAt: "2026-09-26",
            questions: [
                ReviewPacket.Question(
                    questionID: "q1",
                    question: "Why?",
                    mode: "quick",
                    answer: "Because [1]",
                    usefulness: usefulness,
                    citations: [
                        ReviewPacket.Citation(
                            citationID: "cit1",
                            claim: "Because",
                            quote: "the exact quote",
                            passageHeading: "H",
                            sourceURL: "https://a.example.invalid/1",
                            verdict: verdict
                        )
                    ]
                )
            ]
        )
    }

    func testReviewKeepsUsefulnessAndIntegrityApartAndRefusesMalformedInput() throws {
        let card = BenchmarkScorecard(
            card: "frozen",
            label: "local",
            provider: "local/m",
            results: [result("q1", elapsed: 10)]
        )
        XCTAssertFalse(card.isReviewed, "a run with no human labels is not reviewed")

        let scored = try card.applying(packet(usefulness: 2, verdict: "supported"))
        XCTAssertTrue(scored.isReviewed)
        XCTAssertEqual(scored.reviewer, "owner")
        XCTAssertEqual(scored.reviewedCitations, 1)
        XCTAssertEqual(scored.supportedCitations, 1)
        XCTAssertEqual(scored.unsupportedCitations, 0)
        XCTAssertEqual(scored.citationIntegrity, 1.0, "integrity is still the compiler's verdict, not the reviewer's")
        XCTAssertEqual(try XCTUnwrap(scored.meanUsefulness), 2.0, accuracy: 0.0001)
        XCTAssertTrue(scored.summary.contains("citations 1 supported / 0 partial / 0 unsupported"))

        // An unsupported verdict is a reviewer finding and does not change
        // integrity, which measures quote exactness only.
        let unsupported = try card.applying(packet(usefulness: 0, verdict: "unsupported"))
        XCTAssertEqual(unsupported.citationIntegrity, 1.0)
        XCTAssertEqual(unsupported.unsupportedCitations, 1)

        // A partial review leaves the rest unscored instead of assuming a pass.
        let partial = try card.applying(packet(usefulness: nil, verdict: nil))
        XCTAssertEqual(partial.scorableQuestions, 0)
        XCTAssertEqual(partial.reviewedCitations, 0)
        XCTAssertNil(partial.meanUsefulness)

        XCTAssertThrowsError(try card.applying(packet(usefulness: 9, verdict: nil))) { error in
            XCTAssertEqual(
                error as? CitationReviewError,
                .usefulnessOutOfRange(questionID: "q1", value: 9, maximum: 2)
            )
        }
        XCTAssertThrowsError(try card.applying(packet(usefulness: 1, verdict: "maybe"))) { error in
            XCTAssertEqual(
                error as? CitationReviewError,
                .unknownVerdict(questionID: "q1", citationID: "cit1", verdict: "maybe")
            )
        }
        XCTAssertThrowsError(try card.applying(packet(usefulness: 1, verdict: nil, reviewer: "  "))) { error in
            XCTAssertEqual(error as? CitationReviewError, .needsReviewer)
        }

        var foreign = packet(usefulness: 1, verdict: nil)
        foreign.questions[0] = ReviewPacket.Question(
            questionID: "q-not-in-card",
            question: "x",
            mode: "quick",
            answer: "",
            citations: []
        )
        XCTAssertThrowsError(try card.applying(foreign)) { error in
            XCTAssertEqual(error as? CitationReviewError, .unknownQuestion("q-not-in-card"))
        }

        // A packet round-trips through JSON so a reviewer can fill it in a file.
        let data = try packet(usefulness: nil, verdict: nil).json()
        let decoded = try ReviewPacket.decode(data)
        XCTAssertEqual(decoded.questions.count, 1)
        XCTAssertEqual(decoded.questions[0].citations[0].quote, "the exact quote")
        XCTAssertThrowsError(try ReviewPacket.decode(Data("{}".utf8)))
    }
}
