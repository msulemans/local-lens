import Foundation

// MARK: - Where a decision was made

/// The boundary that decided an extraction outcome.
///
/// A stage is a name, not a sentence: it survives serialization without
/// whitespace so a diagnostic can be read by the same conventions as the rest
/// of the fixture data. Every refusal kind maps to exactly one stage and every
/// stage is reachable, because a stage that no refusal could name would be
/// decoration rather than information.
public enum ExtractionStage: String, Sendable, CaseIterable {
    /// Decided by the policy itself, before any document was read.
    case policy
    /// Decided before the media type, the size, or the encoding was considered.
    case sourceIdentifier = "source_identifier"
    case contentType = "content_type"
    case size
    case charset
    case markup
    case text
}

public extension ExtractionError {
    /// The boundary that produced this refusal. Total by construction: a new
    /// refusal case cannot be added without deciding which boundary owns it.
    var stage: ExtractionStage {
        switch self {
        case .invalidPolicy: .policy
        case .missingSourceIdentifier: .sourceIdentifier
        case .unsupportedContentType: .contentType
        case .documentTooLarge: .size
        case .unsupportedCharset: .charset
        case .emptyDocument: .markup
        case .malformedMarkup: .markup
        case .noReadableText: .text
        }
    }
}

// MARK: - Which encoding was believed

/// How the extractor decided to read a body's bytes.
public enum CharsetDecision: Equatable, Sendable {
    /// The run stopped before an encoding was chosen.
    case undecided
    /// The transport's content type declared it.
    case fromHeader(String)
    /// The document's own `<meta>` declared it, because the transport did not.
    case fromMeta(String)
    /// Nothing declared it, so the document is read as UTF-8.
    case assumedUTF8

    public init(contentType: String, body: Data) {
        if let declared = HTMLExtraction.charset(in: contentType) {
            self = .fromHeader(declared)
        } else if let declared = HTMLExtraction.declaredCharset(inBody: body) {
            self = .fromMeta(declared)
        } else {
            self = .assumedUTF8
        }
    }

    /// The name a reader should see. `undecided` is a word rather than an empty
    /// string so a serialized record never reads as a missing value.
    public var name: String {
        switch self {
        case .undecided: "undecided"
        case let .fromHeader(name), let .fromMeta(name): name
        case .assumedUTF8: "utf-8"
        }
    }

    public var source: CharsetSource {
        switch self {
        case .undecided: .undecided
        case .fromHeader: .header
        case .fromMeta: .meta
        case .assumedUTF8: .assumed
        }
    }

    /// What the decoder should be handed. `nil` means "nothing declared", which
    /// the decoder reads as UTF-8 - the same value, not a second opinion.
    var requested: String? {
        switch self {
        case .undecided, .assumedUTF8: nil
        case let .fromHeader(name), let .fromMeta(name): name
        }
    }
}

/// Which statement about the bytes was believed.
public enum CharsetSource: String, Sendable, CaseIterable {
    case header
    case meta
    case assumed
    case undecided
}

// MARK: - Measurable facts

/// The facts a run produced, all of them already in hand.
///
/// Nothing here is fetched, timed, or estimated: every field is a count over
/// bytes that were already read, so two runs over identical bytes report
/// identical numbers and a record can be compared across machines.
public struct ExtractionMetrics: Equatable, Sendable {
    /// The media type with parameters removed and case folded.
    public let mediaType: String
    /// The bytes the extractor was handed, before any ceiling was applied.
    public let bytesOffered: Int
    /// The extraction ceiling this run was held to.
    public let byteCeiling: Int
    public let withinByteCeiling: Bool
    /// Characters after decoding, or `nil` if the run refused before the body
    /// became text.
    public let charactersDecoded: Int?
    /// The digest of the characters that were decoded, or `nil` if the run
    /// refused before the body became text. It is the same digest function the
    /// snapshot uses, so a diagnostic identifies the characters it read and two
    /// different bodies cannot report the same record.
    public let decodedDigest: String?
    public let charactersKept: Int
    public let blocksKept: Int
    public let headingsFound: Int
    public let titleCharacters: Int
    /// Text runs that held characters but no readable character.
    public let runsDropped: Int
    /// Non-prose elements whose content was never read, such as scripts.
    public let nonProseElementsSkipped: Int
    public let commentsSkipped: Int
    public let declarationsSkipped: Int
    public let charset: String
    public let charsetSource: CharsetSource
    public let extractorVersion: String

    public init(
        mediaType: String,
        bytesOffered: Int,
        byteCeiling: Int,
        withinByteCeiling: Bool,
        charactersDecoded: Int?,
        decodedDigest: String?,
        charactersKept: Int,
        blocksKept: Int,
        headingsFound: Int,
        titleCharacters: Int,
        runsDropped: Int,
        nonProseElementsSkipped: Int,
        commentsSkipped: Int,
        declarationsSkipped: Int,
        charset: String,
        charsetSource: CharsetSource,
        extractorVersion: String
    ) {
        self.mediaType = mediaType
        self.bytesOffered = bytesOffered
        self.byteCeiling = byteCeiling
        self.withinByteCeiling = withinByteCeiling
        self.charactersDecoded = charactersDecoded
        self.decodedDigest = decodedDigest
        self.charactersKept = charactersKept
        self.blocksKept = blocksKept
        self.headingsFound = headingsFound
        self.titleCharacters = titleCharacters
        self.runsDropped = runsDropped
        self.nonProseElementsSkipped = nonProseElementsSkipped
        self.commentsSkipped = commentsSkipped
        self.declarationsSkipped = declarationsSkipped
        self.charset = charset
        self.charsetSource = charsetSource
        self.extractorVersion = extractorVersion
    }
}

// MARK: - The record

public enum ExtractionDecision: String, Sendable, CaseIterable {
    case extracted
    case refused
}

/// What a run produced and why.
///
/// It is derived, never authored: every field comes from the same run that
/// produced the page or the refusal, so a diagnostic cannot describe an
/// extraction that did not happen.
public struct ExtractionDiagnostic: Equatable, Sendable {
    public let outcome: ExtractionDecision
    public let stage: ExtractionStage
    public let kind: String
    public let url: String
    public let reason: String
    public let metrics: ExtractionMetrics
    /// A ten-byte digest over the serialized record, so two runs can be
    /// compared by one value and a changed fact cannot pass unnoticed.
    public let fingerprint: String

    public init(
        outcome: ExtractionDecision,
        stage: ExtractionStage,
        kind: String,
        url: String,
        reason: String,
        metrics: ExtractionMetrics
    ) {
        self.outcome = outcome
        self.stage = stage
        self.kind = kind
        self.url = url
        self.reason = reason
        self.metrics = metrics
        self.fingerprint = StableIdentity.make("extraction-diagnostic", Self.body(outcome, stage, kind, url, reason, metrics).joined(separator: "\n"))
    }

    /// The frozen field order. The fingerprint is taken over exactly these
    /// lines, so a reader can strip the last line of `serialized()` and hash the
    /// rest to check the record itself.
    private static func body(
        _ outcome: ExtractionDecision,
        _ stage: ExtractionStage,
        _ kind: String,
        _ url: String,
        _ reason: String,
        _ metrics: ExtractionMetrics
    ) -> [String] {
        [
            "outcome=\(outcome.rawValue)",
            "stage=\(stage.rawValue)",
            "kind=\(kind)",
            "url=\(url)",
            "media_type=\(metrics.mediaType)",
            "bytes_offered=\(metrics.bytesOffered)",
            "byte_ceiling=\(metrics.byteCeiling)",
            "within_byte_ceiling=\(metrics.withinByteCeiling)",
            "characters_decoded=\(metrics.charactersDecoded.map(String.init) ?? "-")",
            "decoded_digest=\(metrics.decodedDigest ?? "undecided")",
            "characters_kept=\(metrics.charactersKept)",
            "blocks_kept=\(metrics.blocksKept)",
            "headings_found=\(metrics.headingsFound)",
            "title_characters=\(metrics.titleCharacters)",
            "runs_dropped=\(metrics.runsDropped)",
            "non_prose_elements_skipped=\(metrics.nonProseElementsSkipped)",
            "comments_skipped=\(metrics.commentsSkipped)",
            "declarations_skipped=\(metrics.declarationsSkipped)",
            "charset=\(metrics.charset)",
            "charset_source=\(metrics.charsetSource.rawValue)",
            "extractor_version=\(metrics.extractorVersion)",
            "reason=\(reason)",
        ]
    }

    private var bodyLines: [String] {
        Self.body(outcome, stage, kind, url, reason, metrics)
    }

    /// The record as text, one fact per line, with the fingerprint last.
    public func serialized() -> String {
        (bodyLines + ["fingerprint=\(fingerprint)"]).joined(separator: "\n")
    }
}

// MARK: - The outcome

/// Either a page or the refusal that stopped it, each with its own diagnostic.
///
/// An outcome is a value, so a caller that wants to inspect every document in a
/// batch does not have to catch to find out what happened. `extract` throws the
/// same refusal this carries, so the two entry points cannot disagree.
public enum ExtractionOutcome: Equatable, Sendable {
    case extracted(ExtractedPage, ExtractionDiagnostic)
    case refused(ExtractionError, ExtractionDiagnostic)

    public var page: ExtractedPage? {
        guard case let .extracted(page, _) = self else { return nil }
        return page
    }

    public var refusal: ExtractionError? {
        guard case let .refused(error, _) = self else { return nil }
        return error
    }

    public var diagnostic: ExtractionDiagnostic {
        switch self {
        case let .extracted(_, diagnostic), let .refused(_, diagnostic): diagnostic
        }
    }
}

// MARK: - The run

/// The extraction pipeline, reported.
///
/// It is the same sequence of decisions the boundary always made - source
/// identifier, media type, size, encoding, markup, readable text - but each
/// decision now records what it saw. The refusal family is unchanged and no new
/// kind is introduced: the diagnostic explains an existing refusal rather than
/// adding one.
enum ExtractionDiagnostics {
    static func run(
        _ response: AcquisitionResult,
        sourceID: String,
        policy: ExtractionPolicy
    ) -> ExtractionOutcome {
        let url = response.finalURL.absoluteString
        let mediaType = HTMLExtraction.mediaType(of: response.contentType)
        let body = response.body

        var charset = CharsetDecision.undecided
        var decodedText: String?
        var stats = HTMLTokenizer.Stats()

        /// Builds a refusal from the facts gathered so far. The stage comes from
        /// the refusal itself, so a diagnostic can never name a boundary other
        /// than the one that decided.
        func refusal(_ error: ExtractionError) -> ExtractionOutcome {
            .refused(
                error,
                ExtractionDiagnostic(
                    outcome: .refused,
                    stage: error.stage,
                    kind: error.kind,
                    url: url,
                    reason: error.reason,
                    metrics: metrics(
                        mediaType: mediaType,
                        body: body,
                        policy: policy,
                        charset: charset,
                        decodedText: decodedText,
                        charactersKept: 0,
                        blocksKept: 0,
                        stats: stats
                    )
                )
            )
        }

        guard !sourceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return refusal(.missingSourceIdentifier(url: url))
        }
        guard HTMLExtraction.supportedContentTypes.contains(mediaType) else {
            return refusal(.unsupportedContentType(contentType: mediaType, url: url))
        }
        guard body.count <= policy.maximumBytes else {
            return refusal(
                .documentTooLarge(byteCount: body.count, limit: policy.maximumBytes, url: url)
            )
        }

        // The header wins. A document that declares its own character set in
        // `<meta>` is believed only when the header said nothing, because the
        // header is the transport's statement about the bytes and `<meta>` is
        // the document's statement about itself.
        charset = CharsetDecision(contentType: response.contentType, body: body)

        let html: String
        do {
            html = try HTMLExtraction.decode(body, charset: charset.requested, url: url)
        } catch let error as ExtractionError {
            return refusal(error)
        } catch {
            return refusal(.malformedMarkup(url: url, reason: String(describing: error)))
        }
        decodedText = html

        guard !html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return refusal(.emptyDocument(url: url))
        }
        guard html.contains("<") else {
            return refusal(.malformedMarkup(url: url, reason: "the body contained no markup"))
        }

        let document: HTMLTokenizer.Document
        do {
            document = try HTMLTokenizer.tokenize(html, url: url)
        } catch let error as ExtractionError {
            return refusal(error)
        } catch {
            return refusal(.malformedMarkup(url: url, reason: String(describing: error)))
        }
        stats = document.stats

        guard !document.blocks.isEmpty else {
            return refusal(.noReadableText(url: url))
        }

        let text = document.blocks.map(\.text).joined(separator: "\n\n")
        let contentHash = StableIdentity.digest(text)
        let snapshot = Snapshot(
            id: StableIdentity.make("snapshot", sourceID, contentHash),
            sourceID: sourceID,
            contentHash: contentHash,
            extractedText: text,
            extractorVersion: policy.extractorVersion
        )
        let passages = document.blocks.map { block in
            Passage(
                id: StableIdentity.make(
                    "passage",
                    snapshot.id,
                    String(block.ordinal),
                    StableIdentity.digest(block.text)
                ),
                snapshotID: snapshot.id,
                ordinal: block.ordinal,
                heading: block.heading,
                text: block.text,
                textHash: StableIdentity.digest(block.text)
            )
        }

        let page = ExtractedPage(
            sourceID: sourceID,
            requestedURL: response.requestedURL,
            finalURL: response.finalURL,
            title: document.title,
            text: text,
            contentHash: contentHash,
            extractorVersion: policy.extractorVersion,
            blocks: document.blocks,
            snapshot: snapshot,
            passages: passages
        )

        return .extracted(
            page,
            ExtractionDiagnostic(
                outcome: .extracted,
                stage: .text,
                kind: "extracted",
                url: url,
                reason: "\(url) yielded readable text",
                metrics: metrics(
                    mediaType: mediaType,
                    body: body,
                    policy: policy,
                    charset: charset,
                    decodedText: decodedText,
                    charactersKept: text.count,
                    blocksKept: document.blocks.count,
                    stats: stats
                )
            )
        )
    }

    private static func metrics(
        mediaType: String,
        body: Data,
        policy: ExtractionPolicy,
        charset: CharsetDecision,
        decodedText: String?,
        charactersKept: Int,
        blocksKept: Int,
        stats: HTMLTokenizer.Stats
    ) -> ExtractionMetrics {
        // A run that never decoded has no encoding to report and no characters
        // to identify, whatever the headers asked for: the requested encoding
        // belongs in the refusal's reason, not in a fact about what was used.
        let reported = decodedText == nil ? CharsetDecision.undecided : charset

        return ExtractionMetrics(
            mediaType: mediaType,
            bytesOffered: body.count,
            byteCeiling: policy.maximumBytes,
            withinByteCeiling: body.count <= policy.maximumBytes,
            charactersDecoded: decodedText?.count,
            decodedDigest: decodedText.map { StableIdentity.digest($0) },
            charactersKept: charactersKept,
            blocksKept: blocksKept,
            headingsFound: stats.headingsFound,
            titleCharacters: stats.titleCharacters,
            runsDropped: stats.runsDropped,
            nonProseElementsSkipped: stats.nonProseElementsSkipped,
            commentsSkipped: stats.commentsSkipped,
            declarationsSkipped: stats.declarationsSkipped,
            charset: reported.name,
            charsetSource: reported.source,
            extractorVersion: policy.extractorVersion
        )
    }
}
