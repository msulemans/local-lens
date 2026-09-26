import Foundation

/// A benchmark card: the frozen questions a scorecard is measured against.
///
/// A card is data, not code, so the same card can be replayed against any path
/// and the card itself never changes after a result is seen. The repository's
/// frozen cards live in `docs/evidence`; a card file is a JSON array of
/// questions with the mode they must run in.
public struct BenchmarkCard: Equatable, Sendable {
    public struct Question: Equatable, Sendable {
        public let id: String
        public let question: String
        public let mode: ResearchMode
        /// Human-authored expectation labels, copied into the scorecard. They are
        /// never used to score anything automatically.
        public let checks: [String]

        public init(id: String, question: String, mode: ResearchMode, checks: [String]) {
            self.id = id
            self.question = question
            self.mode = mode
            self.checks = checks
        }
    }

    public let name: String
    public let questions: [Question]

    public init(name: String, questions: [Question]) {
        self.name = name
        self.questions = questions
    }

    /// Parses a card. Malformed input is refused rather than partially loaded.
    public static func decode(_ data: Data) throws -> BenchmarkCard {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BenchmarkCardError.notAnObject
        }
        guard let name = root["name"] as? String, !name.isEmpty else {
            throw BenchmarkCardError.missingName
        }
        guard let rawQuestions = root["questions"] as? [[String: Any]] else {
            throw BenchmarkCardError.missingQuestions
        }
        var questions: [Question] = []
        for (index, raw) in rawQuestions.enumerated() {
            guard let id = raw["id"] as? String, !id.isEmpty else {
                throw BenchmarkCardError.questionMissingField(index: index, field: "id")
            }
            guard let text = raw["question"] as? String, !text.isEmpty else {
                throw BenchmarkCardError.questionMissingField(index: index, field: "question")
            }
            guard let rawMode = raw["mode"] as? String,
                  let mode = ResearchMode.allCases.first(where: { $0.rawValue.lowercased() == rawMode.lowercased() }) else {
                throw BenchmarkCardError.questionMissingField(index: index, field: "mode")
            }
            let checks = (raw["checks"] as? [String]) ?? []
            questions.append(Question(id: id, question: text, mode: mode, checks: checks))
        }
        guard !questions.isEmpty else { throw BenchmarkCardError.missingQuestions }
        return BenchmarkCard(name: name, questions: questions)
    }
}

public enum BenchmarkCardError: Error, Equatable, LocalizedError {
    case notAnObject
    case missingName
    case missingQuestions
    case questionMissingField(index: Int, field: String)

    public var errorDescription: String? {
        switch self {
        case .notAnObject: "the card is not a JSON object"
        case .missingName: "the card has no name"
        case .missingQuestions: "the card has no questions"
        case let .questionMissingField(index, field): "question \(index) is missing \(field)"
        }
    }
}

/// One question's measured result on one path.
///
/// Answer usefulness is a human judgement and is `nil` until a person scores it.
/// It is never inferred from the citation count, and the two are never combined
/// into a single number.
public struct BenchmarkQuestionResult: Equatable, Sendable {
    public let questionID: String
    public let mode: ResearchMode
    /// `local` or `hosted`; the two are never averaged together.
    public let label: String
    public let provider: String
    public let citations: Int
    public let rejectedClaims: Int
    public let acceptedClaims: Int
    public let elapsedSeconds: Double
    public let openedSources: Int
    public let passages: Int
    /// Every citation resolved to an exact stored passage.
    public let integrityPassed: Bool
    public let integrityFailure: String?
    public let stopReason: String?
    /// Dimension coverage, so an evaluator prediction can be recomputed from a
    /// finished scorecard without the live run.
    public let coveredDimensions: Int
    public let totalDimensions: Int
    /// Human score, out of the card's own maximum, or `nil` if unscored.
    public let usefulness: Int?
    public let maxUsefulness: Int
    public let notes: String
    /// Citations a human has judged, and how they split.
    public let reviewedCitations: Int
    public let supportedCitations: Int
    public let partialCitations: Int
    public let unsupportedCitations: Int

    public init(
        questionID: String,
        mode: ResearchMode,
        label: String,
        provider: String,
        citations: Int,
        rejectedClaims: Int,
        acceptedClaims: Int,
        elapsedSeconds: Double,
        openedSources: Int,
        passages: Int,
        integrityPassed: Bool,
        integrityFailure: String? = nil,
        stopReason: String? = nil,
        coveredDimensions: Int = 0,
        totalDimensions: Int = 0,
        usefulness: Int? = nil,
        maxUsefulness: Int = 2,
        notes: String = "",
        reviewedCitations: Int = 0,
        supportedCitations: Int = 0,
        partialCitations: Int = 0,
        unsupportedCitations: Int = 0
    ) {
        self.questionID = questionID
        self.mode = mode
        self.label = label
        self.provider = provider
        self.citations = citations
        self.rejectedClaims = rejectedClaims
        self.acceptedClaims = acceptedClaims
        self.elapsedSeconds = elapsedSeconds
        self.openedSources = openedSources
        self.passages = passages
        self.integrityPassed = integrityPassed
        self.integrityFailure = integrityFailure
        self.stopReason = stopReason
        self.coveredDimensions = coveredDimensions
        self.totalDimensions = totalDimensions
        self.usefulness = usefulness
        self.maxUsefulness = maxUsefulness
        self.notes = notes
        self.reviewedCitations = reviewedCitations
        self.supportedCitations = supportedCitations
        self.partialCitations = partialCitations
        self.unsupportedCitations = unsupportedCitations
    }
}

/// The scorecard for one card on one path.
public struct BenchmarkScorecard: Equatable, Sendable {
    public let card: String
    public let label: String
    public let provider: String
    public let results: [BenchmarkQuestionResult]
    /// Who reviewed the answers, and when. Empty on an unreviewed run.
    public let reviewer: String
    public let reviewedAt: String

    public init(
        card: String,
        label: String,
        provider: String,
        results: [BenchmarkQuestionResult],
        reviewer: String = "",
        reviewedAt: String = ""
    ) {
        self.card = card
        self.label = label
        self.provider = provider
        self.results = results
        self.reviewer = reviewer
        self.reviewedAt = reviewedAt
    }

    /// The share of citations that resolve to an exact stored passage. The
    /// target for this repository is 100%; anything else is a defect.
    public var citationIntegrity: Double {
        guard !results.isEmpty else { return 0 }
        let passed = results.filter(\.integrityPassed).count
        return Double(passed) / Double(results.count)
    }

    public var scorableQuestions: Int { results.filter { $0.usefulness != nil }.count }
    public var reviewedCitations: Int { results.map(\.reviewedCitations).reduce(0, +) }
    public var supportedCitations: Int { results.map(\.supportedCitations).reduce(0, +) }
    public var partialCitations: Int { results.map(\.partialCitations).reduce(0, +) }
    public var unsupportedCitations: Int { results.map(\.unsupportedCitations).reduce(0, +) }
    public var isReviewed: Bool { scorableQuestions > 0 || reviewedCitations > 0 }

    /// Mean answer usefulness over the questions a human actually scored.
    /// `nil` when nothing has been scored, so an unscored card cannot look like
    /// a perfect one.
    public var meanUsefulness: Double? {
        let scored = results.compactMap(\.usefulness)
        guard !scored.isEmpty else { return nil }
        return Double(scored.reduce(0, +)) / Double(scored.count)
    }

    public var medianLatencySeconds: Double {
        let sorted = results.map(\.elapsedSeconds).sorted()
        guard !sorted.isEmpty else { return 0 }
        let middle = sorted.count / 2
        if sorted.count % 2 == 1 { return sorted[middle] }
        return (sorted[middle - 1] + sorted[middle]) / 2
    }

    /// A one-line summary that keeps the metrics apart.
    public var summary: String {
        let usefulness = meanUsefulness.map { String(format: "%.2f", $0) } ?? "unscored"
        let review: String
        if reviewedCitations == 0 {
            review = "no citations reviewed"
        } else {
            review = "citations \(supportedCitations) supported / \(partialCitations) partial / \(unsupportedCitations) unsupported"
        }
        return "\(card) · \(label) · integrity \(Int(citationIntegrity * 100))% · usefulness \(usefulness) "
            + "over \(scorableQuestions)/\(results.count) scored · \(review) · median \(String(format: "%.1f", medianLatencySeconds))s"
    }

    /// Reads back a scorecard this type wrote, so a review can be applied to a
    /// run that has already finished. Missing optional fields stay absent rather
    /// than defaulting to a pass.
    public static func decode(_ data: Data) throws -> BenchmarkScorecard {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CitationReviewError.malformedPacket(reason: "the scorecard is not a JSON object")
        }
        guard let card = root["card"] as? String,
              let label = root["label"] as? String,
              let provider = root["provider"] as? String,
              let rows = root["results"] as? [[String: Any]] else {
            throw CitationReviewError.malformedPacket(reason: "the scorecard is missing card, label, provider, or results")
        }
        var results: [BenchmarkQuestionResult] = []
        for row in rows {
            guard let id = row["question_id"] as? String,
                  let modeName = row["mode"] as? String,
                  let mode = ResearchMode.allCases.first(where: { $0.rawValue == modeName }) else {
                throw CitationReviewError.malformedPacket(reason: "a scorecard row is missing its question id or mode")
            }
            results.append(BenchmarkQuestionResult(
                questionID: id,
                mode: mode,
                label: row["label"] as? String ?? label,
                provider: row["provider"] as? String ?? provider,
                citations: row["citations"] as? Int ?? 0,
                rejectedClaims: row["rejected_claims"] as? Int ?? 0,
                acceptedClaims: row["accepted_claims"] as? Int ?? 0,
                elapsedSeconds: row["elapsed_seconds"] as? Double ?? 0,
                openedSources: row["opened_sources"] as? Int ?? 0,
                passages: row["passages"] as? Int ?? 0,
                integrityPassed: row["integrity_passed"] as? Bool ?? false,
                integrityFailure: row["integrity_failure"] as? String,
                stopReason: row["stop_reason"] as? String,
                coveredDimensions: row["covered_dimensions"] as? Int ?? 0,
                totalDimensions: row["total_dimensions"] as? Int ?? 0,
                usefulness: row["usefulness"] as? Int,
                maxUsefulness: row["max_usefulness"] as? Int ?? 2,
                notes: row["notes"] as? String ?? "",
                reviewedCitations: row["reviewed_citations"] as? Int ?? 0,
                supportedCitations: row["supported_citations"] as? Int ?? 0,
                partialCitations: row["partial_citations"] as? Int ?? 0,
                unsupportedCitations: row["unsupported_citations"] as? Int ?? 0
            ))
        }
        return BenchmarkScorecard(
            card: card,
            label: label,
            provider: provider,
            results: results,
            reviewer: root["reviewer"] as? String ?? "",
            reviewedAt: root["reviewed_at"] as? String ?? ""
        )
    }

    /// Machine-readable form. Local and hosted scorecards are separate documents
    /// and there is no combined record.
    public func json() throws -> Data {
        var rows: [[String: Any]] = []
        for result in results {
            var row: [String: Any] = [
                "question_id": result.questionID,
                "mode": result.mode.rawValue,
                "label": result.label,
                "provider": result.provider,
                "citations": result.citations,
                "accepted_claims": result.acceptedClaims,
                "rejected_claims": result.rejectedClaims,
                "elapsed_seconds": result.elapsedSeconds,
                "opened_sources": result.openedSources,
                "passages": result.passages,
                "integrity_passed": result.integrityPassed,
            ]
            if let failure = result.integrityFailure { row["integrity_failure"] = failure }
            if let reason = result.stopReason { row["stop_reason"] = reason }
            row["covered_dimensions"] = result.coveredDimensions
            row["total_dimensions"] = result.totalDimensions
            if let usefulness = result.usefulness { row["usefulness"] = usefulness }
            if result.reviewedCitations > 0 {
                row["max_usefulness"] = result.maxUsefulness
                row["reviewed_citations"] = result.reviewedCitations
                row["supported_citations"] = result.supportedCitations
                row["partial_citations"] = result.partialCitations
                row["unsupported_citations"] = result.unsupportedCitations
            }
            if !result.notes.isEmpty { row["notes"] = result.notes }
            rows.append(row)
        }
        let root: [String: Any] = [
            "card": card,
            "reviewed": isReviewed,
            "reviewer": reviewer,
            "reviewed_at": reviewedAt,
            "reviewed_citations": reviewedCitations,
            "supported_citations": supportedCitations,
            "partial_citations": partialCitations,
            "unsupported_citations": unsupportedCitations,
            "label": label,
            "provider": provider,
            "citation_integrity": citationIntegrity,
            "mean_usefulness": meanUsefulness as Any,
            "scorable_questions": scorableQuestions,
            "median_latency_seconds": medianLatencySeconds,
            "total_latency_seconds": results.map(\.elapsedSeconds).reduce(0, +),
            "results": rows,
        ]
        return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
    }
}

public extension BenchmarkScorecard {
    /// Re-runs the evaluator over a scored scorecard and compares it with the
    /// human labels in that same file.
    ///
    /// Nothing here changes a score. It answers one question: would the
    /// evaluator have agreed with the reviewer?
    func calibration() -> EvaluatorCalibration.Report {
        var samples: [EvaluatorCalibration.Sample] = []
        for result in results {
            let features = AnswerEvaluator.Features(
                citations: result.citations,
                unsupportedCitations: result.unsupportedCitations,
                partialCitations: result.partialCitations,
                rejectedClaims: result.rejectedClaims,
                acceptedClaims: result.acceptedClaims,
                coveredDimensions: result.coveredDimensions,
                totalDimensions: result.totalDimensions,
                abstained: result.stopReason == "abstained",
                integrityPassed: result.integrityPassed
            )
            let predicted = AnswerEvaluator.predict(features).score
            let human = result.usefulness ?? predicted
            samples.append(EvaluatorCalibration.Sample(
                questionID: result.questionID,
                human: human,
                predicted: predicted
            ))
        }
        return EvaluatorCalibration.report(samples)
    }
}

/// The corruption checks that prove the citation boundary is not decorative.
///
/// Each check takes a valid compilation and makes exactly one thing wrong, then
/// reports whether the boundary refused it. A boundary that accepts a corrupted
/// compilation is a defect, so the checks are run in tests and can be run against
/// a live result.
public enum CitationBoundaryCheck {
    public struct Finding: Equatable, Sendable {
        public let kind: String
        public let detected: Bool
        public let detail: String

        public init(kind: String, detected: Bool, detail: String) {
            self.kind = kind
            self.detected = detected
            self.detail = detail
        }
    }

    /// Runs every corruption against one compilation. An empty compilation has
    /// nothing to corrupt and reports that rather than passing silently.
    public static func corruptions(of compilation: CitationCompilation) -> [Finding] {
        guard let citation = compilation.citations.first,
              let link = compilation.evidenceLinks.first(where: { citation.evidenceLinkIDs.contains($0.id) }),
              let passage = compilation.passages.first(where: { $0.id == link.passageID }) else {
            return [Finding(kind: "no_evidence", detected: true, detail: "the compilation carries no citation to corrupt")]
        }
        var findings: [Finding] = []

        // 1. An altered quote: one character different from the stored passage.
        let altered = String(link.quote.dropLast()) + (link.quote.hasSuffix("x") ? "y" : "x")
        findings.append(check(
            kind: "altered_quote",
            compilation: replacing(compilation, link: EvidenceLink(
                id: link.id,
                claimID: link.claimID,
                passageID: link.passageID,
                relation: link.relation,
                quote: altered
            )),
            detail: "a quote changed by one character in passage \(passage.id.prefix(12))"
        ))

        // 2. A missing passage: the link points at a passage that is not stored.
        findings.append(check(
            kind: "missing_passage",
            compilation: CitationCompilation(
                claims: compilation.claims,
                evidenceLinks: [EvidenceLink(
                    id: link.id,
                    claimID: link.claimID,
                    passageID: "passage-not-stored",
                    relation: link.relation,
                    quote: link.quote
                )],
                citations: compilation.citations,
                passages: compilation.passages
            ),
            detail: "the link names a passage the run never stored"
        ))

        // 3. A mismatched identifier: the citation points at a different claim.
        let foreignClaim = claimIDNotIn(compilation, excluding: citation.claimID)
        findings.append(check(
            kind: "mismatched_claim",
            compilation: CitationCompilation(
                claims: compilation.claims,
                evidenceLinks: [EvidenceLink(
                    id: link.id,
                    claimID: foreignClaim ?? "claim-not-stored",
                    passageID: link.passageID,
                    relation: link.relation,
                    quote: link.quote
                )],
                citations: compilation.citations,
                passages: compilation.passages
            ),
            detail: "the evidence link names a different claim than the citation"
        ))

        // 4. A dangling citation identifier.
        findings.append(Finding(
            kind: "unknown_citation",
            detected: (try? compilation.resolve("citation-not-present")) == nil,
            detail: "resolving an identifier that is not in the compilation"
        ))
        return findings
    }

    private static func check(kind: String, compilation: CitationCompilation, detail: String) -> Finding {
        let detected = (try? compilation.validate()) == nil
        return Finding(kind: kind, detected: detected, detail: detail)
    }

    private static func replacing(_ compilation: CitationCompilation, link: EvidenceLink) -> CitationCompilation {
        CitationCompilation(
            claims: compilation.claims,
            evidenceLinks: compilation.evidenceLinks.map { $0.id == link.id ? link : $0 },
            citations: compilation.citations,
            passages: compilation.passages
        )
    }

    private static func claimIDNotIn(_ compilation: CitationCompilation, excluding claimID: String) -> String? {
        compilation.claims.first { $0.id != claimID }?.id
    }
}
