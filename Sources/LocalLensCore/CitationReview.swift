import Foundation

/// A review packet: everything a person needs to judge a run's answers, and the
/// place their judgement is recorded.
///
/// The benchmark runner writes one of these next to a run. A reviewer fills in
/// the fields; nothing else changes. Answer usefulness is recorded here and
/// nowhere else, and a question or citation left blank stays unscored rather
/// than defaulting to a pass.
public struct ReviewPacket: Codable, Equatable, Sendable {
    public struct Citation: Codable, Equatable, Sendable {
        public let citationID: String
        /// The claim as the answer stated it.
        public let claim: String
        /// The exact quote the answer cited.
        public let quote: String
        public let passageHeading: String
        public let sourceURL: String?
        /// `supported`, `partial`, `unsupported`, or `nil` when not yet judged.
        public var verdict: String?
        public var note: String

        public init(
            citationID: String,
            claim: String,
            quote: String,
            passageHeading: String,
            sourceURL: String?,
            verdict: String? = nil,
            note: String = ""
        ) {
            self.citationID = citationID
            self.claim = claim
            self.quote = quote
            self.passageHeading = passageHeading
            self.sourceURL = sourceURL
            self.verdict = verdict
            self.note = note
        }
    }

    public struct Question: Codable, Equatable, Sendable {
        /// The card's own identifier (`Q1`), which is what the scorecard row
        /// carries. Using the question text here would make the two files
        /// unlinkable.
        public let questionID: String
        public let question: String
        public let mode: String
        /// The card's human-authored checks, copied here so a reviewer can see
        /// what the question was meant to satisfy.
        public let checks: [String]
        public let answer: String
        /// Human 0...max score held next to the answer it describes.
        public var usefulness: Int?
        public let maxUsefulness: Int
        public var notes: String
        public var citations: [Citation]

        public init(
            questionID: String,
            question: String,
            mode: String,
            checks: [String] = [],
            answer: String,
            usefulness: Int? = nil,
            maxUsefulness: Int = 2,
            notes: String = "",
            citations: [Citation]
        ) {
            self.questionID = questionID
            self.question = question
            self.mode = mode
            self.checks = checks
            self.answer = answer
            self.usefulness = usefulness
            self.maxUsefulness = maxUsefulness
            self.notes = notes
            self.citations = citations
        }
    }

    public var card: String
    public var label: String
    public var provider: String
    public var reviewer: String
    public var reviewedAt: String
    public var questions: [Question]

    public init(
        card: String,
        label: String,
        provider: String,
        reviewer: String = "",
        reviewedAt: String = "",
        questions: [Question]
    ) {
        self.card = card
        self.label = label
        self.provider = provider
        self.reviewer = reviewer
        self.reviewedAt = reviewedAt
        self.questions = questions
    }

    public static func decode(_ data: Data) throws -> ReviewPacket {
        do {
            return try JSONDecoder().decode(ReviewPacket.self, from: data)
        } catch {
            throw CitationReviewError.malformedPacket(reason: String(describing: error))
        }
    }

    public func json() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    public var reviewedQuestions: Int { questions.filter { $0.usefulness != nil }.count }
    public var reviewedCitations: Int { questions.flatMap(\.citations).filter { $0.verdict != nil }.count }
}

public enum CitationReviewError: Error, Equatable, LocalizedError {
    case malformedPacket(reason: String)
    case unknownQuestion(String)
    case duplicateQuestion(String)
    case unknownVerdict(questionID: String, citationID: String, verdict: String)
    case usefulnessOutOfRange(questionID: String, value: Int, maximum: Int)
    case needsReviewer

    public var errorDescription: String? {
        switch self {
        case let .malformedPacket(reason): "the review packet could not be read: \(reason)"
        case let .unknownQuestion(id): "the review names question \(id), which is not in the card"
        case let .duplicateQuestion(id): "the review names question \(id) more than once"
        case let .unknownVerdict(questionID, citationID, verdict):
            "\(verdict) is not a verdict for citation \(citationID) in \(questionID)"
        case let .usefulnessOutOfRange(questionID, value, maximum):
            "\(questionID) was scored \(value) out of a maximum of \(maximum)"
        case .needsReviewer: "a review must name its reviewer"
        }
    }
}

public extension BenchmarkScorecard {
    /// The review packet for a run, with every judgement left blank.
    /// Builds the packet from a run.
    ///
    /// An abstention is included on purpose: "did it abstain when it should
    /// have?" is a judgement a reviewer has to make, and leaving those questions
    /// out of the packet would silently excuse them from review.
    static func reviewPacket(
        for runs: [(question: BenchmarkCard.Question, report: ResearchReport)],
        abstentions: [(question: BenchmarkCard.Question, reason: String)] = [],
        card: String,
        label: String,
        provider: String
    ) -> ReviewPacket {
        let completed = runs.map { run -> ReviewPacket.Question in
                let report = run.report
                return ReviewPacket.Question(
                    questionID: run.question.id,
                    question: report.plan.question,
                    mode: report.plan.mode.rawValue,
                    checks: run.question.checks,
                    answer: report.result.answer,
                    citations: report.result.compilation.citations.map { citation in
                        let resolved = try? report.result.compilation.resolve(citation.id)
                        return ReviewPacket.Citation(
                            citationID: citation.id,
                            claim: resolved?.claim.text ?? "",
                            quote: resolved?.evidenceLink.quote ?? "",
                            passageHeading: resolved?.passage.heading ?? "",
                            sourceURL: report.result.records
                                .first { $0.snapshot.id == resolved?.passage.snapshotID }?
                                .finalURL.absoluteString
                        )
                    }
                )
            }
        let abstained = abstentions.map { entry in
            ReviewPacket.Question(
                questionID: entry.question.id,
                question: entry.question.question,
                mode: entry.question.mode.rawValue,
                checks: entry.question.checks,
                answer: "(abstained: \(entry.reason))",
                citations: []
            )
        }
        return ReviewPacket(
            card: card,
            label: label,
            provider: provider,
            questions: (completed + abstained).sorted { $0.questionID < $1.questionID }
        )
    }

    /// Applies a review to a scorecard.
    ///
    /// A blank usefulness or verdict stays unscored. An unknown question, an
    /// unknown verdict word, and an out-of-range score are refused, so a review
    /// cannot silently mislabel a row it did not understand.
    func applying(_ review: ReviewPacket) throws -> BenchmarkScorecard {
        guard !review.reviewer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CitationReviewError.needsReviewer
        }
        var seenQuestions: Set<String> = []
        for question in review.questions {
            guard seenQuestions.insert(question.questionID).inserted else {
                throw CitationReviewError.duplicateQuestion(question.questionID)
            }
            guard results.contains(where: { $0.questionID == question.questionID }) else {
                throw CitationReviewError.unknownQuestion(question.questionID)
            }
            if let usefulness = question.usefulness {
                guard (0...question.maxUsefulness).contains(usefulness) else {
                    throw CitationReviewError.usefulnessOutOfRange(
                        questionID: question.questionID,
                        value: usefulness,
                        maximum: question.maxUsefulness
                    )
                }
            }
            for citation in question.citations {
                guard let verdict = citation.verdict else { continue }
                guard ReviewVerdict(rawValue: verdict) != nil else {
                    throw CitationReviewError.unknownVerdict(
                        questionID: question.questionID,
                        citationID: citation.citationID,
                        verdict: verdict
                    )
                }
            }
        }

        let merged = results.map { result -> BenchmarkQuestionResult in
            guard let reviewed = review.questions.first(where: { $0.questionID == result.questionID }) else {
                return result
            }
            let verdicts = reviewed.citations.compactMap { $0.verdict }.compactMap(ReviewVerdict.init(rawValue:))
            return BenchmarkQuestionResult(
                questionID: result.questionID,
                mode: result.mode,
                label: result.label,
                provider: result.provider,
                citations: result.citations,
                rejectedClaims: result.rejectedClaims,
                acceptedClaims: result.acceptedClaims,
                elapsedSeconds: result.elapsedSeconds,
                openedSources: result.openedSources,
                passages: result.passages,
                integrityPassed: result.integrityPassed,
                integrityFailure: result.integrityFailure,
                stopReason: result.stopReason,
                coveredDimensions: result.coveredDimensions,
                totalDimensions: result.totalDimensions,
                usefulness: reviewed.usefulness,
                maxUsefulness: reviewed.maxUsefulness,
                notes: reviewed.notes,
                reviewedCitations: verdicts.count,
                supportedCitations: verdicts.filter { $0 == .supported }.count,
                partialCitations: verdicts.filter { $0 == .partial }.count,
                unsupportedCitations: verdicts.filter { $0 == .unsupported }.count
            )
        }
        return BenchmarkScorecard(
            card: card,
            label: label,
            provider: provider,
            results: merged,
            reviewer: review.reviewer,
            reviewedAt: review.reviewedAt
        )
    }
}

/// A human verdict on one citation.
public enum ReviewVerdict: String, Codable, Equatable, Sendable, CaseIterable {
    case supported
    case partial
    case unsupported
}
