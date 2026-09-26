import Foundation

/// A deterministic answer evaluator.
///
/// It exists so a run's quality can be tracked without a model in the loop and
/// without a person re-reading every answer. It is a heuristic over measurable
/// features and it says so: its output is a prediction, and a prediction is only
/// worth anything once it has been compared with human labels
/// (`EvaluatorCalibration`).
///
/// It never sees, and never scores, whether a claim is *true*. Citation
/// integrity stays the compiler's job: an exact stored passage.
public enum AnswerEvaluator {
    /// Features the score is built from. Each is counted, not guessed.
    public struct Features: Equatable, Sendable {
        public let citations: Int
        public let unsupportedCitations: Int
        public let partialCitations: Int
        public let rejectedClaims: Int
        public let acceptedClaims: Int
        public let coveredDimensions: Int
        public let totalDimensions: Int
        public let abstained: Bool
        public let integrityPassed: Bool

        public init(
            citations: Int,
            unsupportedCitations: Int,
            partialCitations: Int,
            rejectedClaims: Int,
            acceptedClaims: Int,
            coveredDimensions: Int,
            totalDimensions: Int,
            abstained: Bool,
            integrityPassed: Bool
        ) {
            self.citations = citations
            self.unsupportedCitations = unsupportedCitations
            self.partialCitations = partialCitations
            self.rejectedClaims = rejectedClaims
            self.acceptedClaims = acceptedClaims
            self.coveredDimensions = coveredDimensions
            self.totalDimensions = totalDimensions
            self.abstained = abstained
            self.integrityPassed = integrityPassed
        }
    }

    public struct Prediction: Equatable, Sendable {
        public let score: Int
        public let maximum: Int
        /// Short, ordered reasons, so a score can be argued with.
        public let reasons: [String]

        public var normalized: Double { maximum == 0 ? 0 : Double(score) / Double(maximum) }
    }

    public static let maximumScore = 2

    /// Scores one answer out of two.
    ///
    /// Rule, in order:
    ///
    /// - integrity failure scores 0, because nothing else can be trusted;
    /// - a run that abstained with no citations scores 2 when the plan declared
    ///   a dimension the evidence could not cover and 1 otherwise, since an
    ///   unnecessary abstention is not a wrong answer but a wasted run;
    /// - an answer with no citations scores 0;
    /// - otherwise start at 1 and add 1 when the answer carries at least two
    ///   citations, covers most dimensions, and holds no unsupported citation.
    public static func predict(_ features: Features) -> Prediction {
        guard features.integrityPassed else {
            return Prediction(score: 0, maximum: maximumScore, reasons: ["a citation failed to resolve"])
        }
        if features.abstained {
            let unansweredDimensions = features.totalDimensions - features.coveredDimensions
            if unansweredDimensions > 0 {
                return Prediction(
                    score: 2,
                    maximum: maximumScore,
                    reasons: ["abstained while \(unansweredDimensions) declared dimension(s) had no evidence"]
                )
            }
            return Prediction(
                score: 1,
                maximum: maximumScore,
                reasons: ["abstained although the plan's dimensions had evidence"]
            )
        }
        guard features.citations > 0 else {
            return Prediction(score: 0, maximum: maximumScore, reasons: ["no citation"])
        }
        var reasons = ["cited \(features.citations) exact passage(s)"]
        var score = 1
        let coverage = features.totalDimensions == 0 ? 1 : Double(features.coveredDimensions) / Double(features.totalDimensions)
        if features.unsupportedCitations > 0 {
            reasons.append("\(features.unsupportedCitations) reviewer-unsupported citation(s) cap the score")
            return Prediction(score: 1, maximum: maximumScore, reasons: reasons)
        }
        if features.citations >= 2, coverage >= 0.6 {
            score = 2
            reasons.append("at least two citations and \(Int(coverage * 100))% dimension coverage")
        } else if features.citations < 2 {
            reasons.append("a single citation")
        } else {
            reasons.append("dimension coverage \(Int(coverage * 100))%")
        }
        if features.partialCitations > 0 {
            reasons.append("\(features.partialCitations) reviewer-partial citation(s)")
        }
        return Prediction(score: score, maximum: maximumScore, reasons: reasons)
    }
}

/// Compares evaluator predictions with human labels.
///
/// A calibration is a measurement, not a promotion: it reports agreement and
/// error, and it refuses to call itself calibrated on too few samples.
public enum EvaluatorCalibration {
    public struct Sample: Equatable, Sendable {
        public let questionID: String
        public let human: Int
        public let predicted: Int

        public init(questionID: String, human: Int, predicted: Int) {
            self.questionID = questionID
            self.human = human
            self.predicted = predicted
        }
    }

    public struct Report: Equatable, Sendable {
        public let samples: [Sample]
        public let exactAgreement: Double
        public let meanAbsoluteError: Double
        public let worstError: Int
        /// The evaluator only claims calibration once there are enough samples
        /// and the error is small. Below that it reports its own insufficiency.
        public let isCalibrated: Bool
        public let verdict: String
    }

    /// The minimum sample count this repository will accept before calling an
    /// evaluator calibrated. Five labels cannot calibrate anything.
    public static let minimumSamples = 20

    public static func report(_ samples: [Sample]) -> Report {
        guard !samples.isEmpty else {
            return Report(
                samples: [],
                exactAgreement: 0,
                meanAbsoluteError: 0,
                worstError: 0,
                isCalibrated: false,
                verdict: "no labels: nothing to calibrate"
            )
        }
        let exact = samples.filter { $0.human == $0.predicted }.count
        let errors = samples.map { abs($0.human - $0.predicted) }
        let mean = Double(errors.reduce(0, +)) / Double(errors.count)
        let worst = errors.max() ?? 0
        let enough = samples.count >= minimumSamples
        let calibrated = enough && mean <= 0.5 && worst <= 1
        let verdict: String
        if !enough {
            verdict = "not calibrated: \(samples.count) label(s), \(minimumSamples) are required"
        } else if calibrated {
            verdict = "calibrated on \(samples.count) labels: mean error \(String(format: "%.2f", mean))"
        } else {
            verdict = "not calibrated: mean error \(String(format: "%.2f", mean)), worst \(worst)"
        }
        return Report(
            samples: samples,
            exactAgreement: Double(exact) / Double(samples.count),
            meanAbsoluteError: mean,
            worstError: worst,
            isCalibrated: calibrated,
            verdict: verdict
        )
    }
}

/// A lesson generated from one finished run.
///
/// Everything in it is copied from the run: the exact quotes, the rejected
/// claims with their typed reasons, the dimensions that stayed empty. The
/// explain-back prompts are deterministic restatements of that material, not
/// generated prose.
public struct LearningCard: Equatable, Sendable {
    public struct Explained: Equatable, Sendable {
        public let claim: String
        public let quote: String
        public let heading: String
        /// The final URL of the page the quote came from, as text.
        public let sourceURL: String?
        public let citationMarker: Int
    }

    public struct Rejected: Equatable, Sendable {
        public let claim: String
        public let reason: String
    }

    public struct Prompt: Equatable, Sendable {
        public let question: String
        public let answer: String
    }

    public let researchQuestion: String
    public let mode: ResearchMode
    public let answer: String
    public let label: String
    public let stopReason: ResearchLoopReason
    public let explained: [Explained]
    public let rejected: [Rejected]
    public let gapDimensions: [String]
    public let coverage: [String: Int]
    public let prompts: [Prompt]

    /// Builds the card. An abstained run produces a card too: "why was there
    /// nothing to cite" is the lesson.
    public static func make(
        plan: ResearchPlan,
        outcome: ResearchOutcome,
        stopReason: ResearchLoopReason,
        coverage: [String: Int],
        gapDimensions: [String]
    ) -> LearningCard? {
        switch outcome {
        case let .completed(report):
            let explained: [Explained] = report.result.compilation.citations.compactMap { citation in
                guard let resolved = try? report.result.compilation.resolve(citation.id) else { return nil }
                return Explained(
                    claim: resolved.claim.text,
                    quote: resolved.evidenceLink.quote,
                    heading: resolved.passage.heading,
                    sourceURL: report.result.records
                        .first { $0.snapshot.id == resolved.passage.snapshotID }?
                        .finalURL
                        .absoluteString,
                    citationMarker: citationMarker(citation.id, in: report.result.compilation.citations)
                )
            }
            let rejected = report.result.rejected.map { Rejected(claim: $0.proposal.text, reason: $0.reason) }
            var prompts: [Prompt] = []
            if !explained.isEmpty {
                prompts.append(Prompt(
                    question: "Without looking, state the exact sentence that supports the first claim.",
                    answer: "\"\(explained[0].quote)\" — \(explained[0].heading)"
                ))
            }
            for dimension in gapDimensions {
                prompts.append(Prompt(
                    question: "Why did \(dimension) stay empty in \(plan.mode.rawValue) mode?",
                    answer: "No stored passage and no accepted claim matched \(dimension). The run stopped because: \(stopReason.explanation)."
                ))
            }
            if !rejected.isEmpty {
                prompts.append(Prompt(
                    question: "Why was a claim with a quote rejected here?",
                    answer: "The claim \(rejected[0].claim.prefix(120)) was rejected: \(rejected[0].reason). A quote must exist exactly in the stored passage and must be attached to the claim it supports."
                ))
            }
            return LearningCard(
                researchQuestion: plan.question,
                mode: plan.mode,
                answer: report.result.answer,
                label: report.result.label,
                stopReason: stopReason,
                explained: explained,
                rejected: rejected,
                gapDimensions: gapDimensions,
                coverage: coverage,
                prompts: prompts
            )
        case let .abstained(reason):
            return LearningCard(
                researchQuestion: plan.question,
                mode: plan.mode,
                answer: "(abstained: \(reason))",
                label: "none",
                stopReason: stopReason,
                explained: [],
                rejected: [],
                gapDimensions: gapDimensions,
                coverage: coverage,
                prompts: [
                    Prompt(
                        question: "Why did this run produce no answer?",
                        answer: "It abstained because \(reason). An abstention is a result: nothing verifiable was stored, so nothing could be cited."
                    ),
                    Prompt(
                        question: "What would have made an answer possible?",
                        answer: "A stored passage from a reachable page containing an exact sentence that supports a claim."
                    ),
                ]
            )
        case .failed:
            return nil
        }
    }

    private static func citationMarker(_ id: String, in citations: [Citation]) -> Int {
        (citations.firstIndex { $0.id == id } ?? 0) + 1
    }

    /// Markdown for a study note, written from the card's own fields.
    public func markdown() -> String {
        var lines: [String] = []
        lines.append("# Learning card")
        lines.append("")
        lines.append("**Question** (\(mode.rawValue)): \(researchQuestion)")
        lines.append("")
        lines.append("**Answer recorded** (\(label)): \(answer)")
        lines.append("")
        lines.append("**Why the run stopped:** `\(stopReason.rawValue)` — \(stopReason.explanation)")
        lines.append("")
        lines.append("## Exact evidence")
        if explained.isEmpty {
            lines.append("- none: the run cited nothing")
        }
        for item in explained {
            lines.append("- **[\(item.citationMarker)]** \(item.claim)")
            if let url = item.sourceURL {
                lines.append("  - quote: \"\(item.quote)\" — \(item.heading) <\(url)>")
            } else {
                lines.append("  - quote: \"\(item.quote)\" — \(item.heading)")
            }
        }
        lines.append("")
        lines.append("## Rejected claims")
        if rejected.isEmpty {
            lines.append("- none")
        }
        for item in rejected {
            lines.append("- \(item.claim.prefix(160)) — \(item.reason)")
        }
        lines.append("")
        lines.append("## Coverage")
        for (dimension, count) in coverage.sorted(by: { $0.key < $1.key }) {
            lines.append("- \(dimension): \(count)")
        }
        if !gapDimensions.isEmpty {
            lines.append("- gaps: \(gapDimensions.joined(separator: ", "))")
        }
        lines.append("")
        lines.append("## Explain back")
        for (index, prompt) in prompts.enumerated() {
            lines.append("\(index + 1). \(prompt.question)")
            lines.append("   - reference answer: \(prompt.answer)")
        }
        return lines.joined(separator: "\n")
    }
}
