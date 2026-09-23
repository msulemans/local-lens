import Foundation
import XCTest
@testable import LocalLensCore

// MARK: - Frozen diagnostic fixture

/// The diagnostic table lives in `Fixtures/html/diagnostic-scenarios.json` so
/// the facts a diagnostic must report are reviewable as data rather than as
/// scattered assertions. It is hand-authored, synthetic, and contains no
/// captured page, no live host, and no measured response.
private struct DiagnosticFixture: Decodable, Sendable {
    struct Meta: Decodable, Sendable {
        let synthetic: Bool
        let license: String
        let shape: String
        let note: String
    }

    struct Metrics: Decodable, Sendable {
        let media_type: String
        let bytes_offered: Int
        let byte_ceiling: Int
        let within_byte_ceiling: Bool
        let characters_decoded: Int?
        let characters_kept: Int
        let blocks_kept: Int
        let headings_found: Int
        let title_characters: Int
        let runs_dropped: Int
        let non_prose_elements_skipped: Int
        let comments_skipped: Int
        let declarations_skipped: Int
        let charset: String
        let charset_source: String
    }

    struct Block: Decodable, Sendable, Equatable {
        let heading: String
        let text: String
    }

    struct Expected: Decodable, Sendable {
        let title: String
        let text: String
        let blocks: [Block]
        let metrics: Metrics
    }

    struct Case: Decodable, Sendable {
        let id: String
        let why: String
        let url: String
        let requested_url: String
        let content_type: String
        let body: String?
        let body_base64: String?
        let expected: Expected
    }

    struct Refusal: Decodable, Sendable {
        let id: String
        let why: String
        let url: String
        let content_type: String
        let body: String?
        let body_base64: String?
        let source_id: String?
        let maximum_bytes: Int?
        let expected_kind: String
        let expected_stage: String
        let expected_metrics: Metrics
    }

    struct Policy: Decodable, Sendable {
        let maximum_bytes: Int
        let extractor_version: String
    }

    let _fixture: Meta
    let source_id: String
    let policy: Policy
    let cases: [Case]
    let refusals: [Refusal]
}

final class ExtractionDiagnosticsTests: XCTestCase {

    // MARK: Helpers

    private var fixtureURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/html/diagnostic-scenarios.json")
    }

    private var extractionFixtureURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/html/extraction-scenarios.json")
    }

    private func fixtureData() throws -> Data {
        try Data(contentsOf: fixtureURL)
    }

    private func loadFixture() throws -> DiagnosticFixture {
        try JSONDecoder().decode(DiagnosticFixture.self, from: try fixtureData())
    }

    private func bodyData(body: String?, base64: String?) throws -> Data {
        if let base64 {
            return try XCTUnwrap(Data(base64Encoded: base64), "the fixture body_base64 must decode")
        }
        return Data((body ?? "").utf8)
    }

    /// Builds the response the acquisition boundary would have produced. No
    /// transport, resolver, or socket is involved: extraction and its
    /// diagnostic are pure functions of the bytes they are handed.
    private func response(
        requested: String,
        final: String,
        contentType: String,
        body: Data
    ) throws -> AcquisitionResult {
        let requestedURL = try XCTUnwrap(URL(string: requested))
        let finalURL = try XCTUnwrap(URL(string: final))
        return AcquisitionResult(
            requestedURL: requestedURL,
            finalURL: finalURL,
            statusCode: 200,
            contentType: contentType,
            body: body,
            redirects: requested == final ? [] : [finalURL]
        )
    }

    private func policy(_ fixture: DiagnosticFixture, maximumBytes: Int? = nil) throws -> ExtractionPolicy {
        try ExtractionPolicy(
            maximumBytes: maximumBytes ?? fixture.policy.maximum_bytes,
            extractorVersion: fixture.policy.extractor_version
        )
    }

    private func caseOutcome(
        _ entry: DiagnosticFixture.Case,
        _ fixture: DiagnosticFixture
    ) throws -> ExtractionOutcome {
        HTMLExtraction.diagnose(
            try response(
                requested: entry.requested_url,
                final: entry.url,
                contentType: entry.content_type,
                body: try bodyData(body: entry.body, base64: entry.body_base64)
            ),
            sourceID: fixture.source_id,
            policy: try policy(fixture)
        )
    }

    private func refusalOutcome(
        _ entry: DiagnosticFixture.Refusal,
        _ fixture: DiagnosticFixture
    ) throws -> ExtractionOutcome {
        HTMLExtraction.diagnose(
            try response(
                requested: entry.url,
                final: entry.url,
                contentType: entry.content_type,
                body: try bodyData(body: entry.body, base64: entry.body_base64)
            ),
            sourceID: entry.source_id ?? fixture.source_id,
            policy: try policy(fixture, maximumBytes: entry.maximum_bytes)
        )
    }

    /// Asserts every frozen fact of one metrics block. Every field is checked,
    /// so a diagnostic that stops counting something cannot pass by reporting
    /// less than the fixture expects.
    private func assertMetrics(
        _ metrics: ExtractionMetrics,
        matches expected: DiagnosticFixture.Metrics,
        _ label: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(metrics.mediaType, expected.media_type, "\(label): media type", file: file, line: line)
        XCTAssertEqual(metrics.bytesOffered, expected.bytes_offered, "\(label): bytes", file: file, line: line)
        XCTAssertEqual(metrics.byteCeiling, expected.byte_ceiling, "\(label): ceiling", file: file, line: line)
        XCTAssertEqual(
            metrics.withinByteCeiling,
            expected.within_byte_ceiling,
            "\(label): ceiling verdict",
            file: file,
            line: line
        )
        XCTAssertEqual(
            metrics.charactersDecoded,
            expected.characters_decoded,
            "\(label): decoded characters",
            file: file,
            line: line
        )
        XCTAssertEqual(
            metrics.charactersKept,
            expected.characters_kept,
            "\(label): kept characters",
            file: file,
            line: line
        )
        XCTAssertEqual(metrics.blocksKept, expected.blocks_kept, "\(label): blocks", file: file, line: line)
        XCTAssertEqual(
            metrics.headingsFound,
            expected.headings_found,
            "\(label): headings",
            file: file,
            line: line
        )
        XCTAssertEqual(
            metrics.titleCharacters,
            expected.title_characters,
            "\(label): title characters",
            file: file,
            line: line
        )
        XCTAssertEqual(metrics.runsDropped, expected.runs_dropped, "\(label): dropped runs", file: file, line: line)
        XCTAssertEqual(
            metrics.nonProseElementsSkipped,
            expected.non_prose_elements_skipped,
            "\(label): skipped elements",
            file: file,
            line: line
        )
        XCTAssertEqual(
            metrics.commentsSkipped,
            expected.comments_skipped,
            "\(label): comments",
            file: file,
            line: line
        )
        XCTAssertEqual(
            metrics.declarationsSkipped,
            expected.declarations_skipped,
            "\(label): declarations",
            file: file,
            line: line
        )
        XCTAssertEqual(metrics.charset, expected.charset, "\(label): charset", file: file, line: line)
        XCTAssertEqual(
            metrics.charsetSource.rawValue,
            expected.charset_source,
            "\(label): charset source",
            file: file,
            line: line
        )
    }

    // MARK: Fixture integrity

    func testFixtureIsSyntheticOfflineAndExplained() throws {
        let root = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: try fixtureData()) as? [String: Any]
        )
        let meta = try XCTUnwrap(root["_fixture"] as? [String: Any])
        XCTAssertEqual(meta["synthetic"] as? Bool, true)
        XCTAssertEqual(meta["license"] as? String, "redistributable")
        XCTAssertFalse((meta["note"] as? String ?? "").isEmpty)

        let fixture = try loadFixture()
        XCTAssertEqual(fixture._fixture.shape, "DiagnosticFixture")
        XCTAssertEqual(fixture.source_id, "diagnostics-fixture")
        XCTAssertEqual(fixture.policy.extractor_version, "html-extractor-1")
        XCTAssertEqual(fixture.cases.count, 4)
        XCTAssertEqual(fixture.refusals.count, 6)

        for entry in fixture.cases {
            XCTAssertFalse(entry.why.isEmpty, "\(entry.id) must say why it exists")
            XCTAssertEqual(entry.url, entry.requested_url, "\(entry.id): a diagnostic case follows no redirect")
            XCTAssertEqual(try bodyData(body: entry.body, base64: entry.body_base64).count,
                           entry.expected.metrics.bytes_offered,
                           "\(entry.id): the frozen byte count must match the frozen body")
        }
        for entry in fixture.refusals {
            XCTAssertFalse(entry.why.isEmpty, "\(entry.id) must say why it exists")
            XCTAssertEqual(try bodyData(body: entry.body, base64: entry.body_base64).count,
                           entry.expected_metrics.bytes_offered,
                           "\(entry.id): the frozen byte count must match the frozen body")
        }

        for raw in fixture.cases.map(\.url) + fixture.refusals.map(\.url) {
            let url = try XCTUnwrap(URL(string: raw))
            XCTAssertEqual(
                url.host?.hasSuffix(".invalid"),
                true,
                "\(raw) must stay on a non-resolvable host"
            )
        }
    }

    // MARK: One diagnostic per outcome

    func testEveryExtractedCaseCarriesExactlyOneDiagnostic() throws {
        let fixture = try loadFixture()

        for entry in fixture.cases {
            let outcome = try caseOutcome(entry, fixture)
            guard case let .extracted(page, diagnostic) = outcome else {
                return XCTFail("\(entry.id): expected an extracted outcome")
            }
            XCTAssertNil(outcome.refusal, "\(entry.id): an extracted outcome carries no refusal")
            XCTAssertEqual(outcome.diagnostic, diagnostic, "\(entry.id): the outcome has one diagnostic")

            XCTAssertEqual(diagnostic.outcome, .extracted, "\(entry.id): decision")
            XCTAssertEqual(diagnostic.stage, .text, "\(entry.id): the text boundary is what accepted the page")
            XCTAssertEqual(diagnostic.kind, "extracted", "\(entry.id): an extracted page has no refusal kind")
            XCTAssertEqual(diagnostic.metrics.extractorVersion, fixture.policy.extractor_version)
            XCTAssertEqual(page.text, entry.expected.text, "\(entry.id): frozen text")
            XCTAssertEqual(page.title, entry.expected.title, "\(entry.id): frozen title")
            XCTAssertEqual(
                page.blocks.map { DiagnosticFixture.Block(heading: $0.heading, text: $0.text) },
                entry.expected.blocks,
                "\(entry.id): frozen blocks"
            )
        }
    }

    func testEveryRefusalCarriesExactlyOneTypedDiagnostic() throws {
        let fixture = try loadFixture()

        for entry in fixture.refusals {
            let outcome = try refusalOutcome(entry, fixture)
            guard case let .refused(error, diagnostic) = outcome else {
                return XCTFail("\(entry.id): expected a refused outcome")
            }
            XCTAssertNil(outcome.page, "\(entry.id): a refusal carries no page")
            XCTAssertEqual(outcome.diagnostic, diagnostic, "\(entry.id): the outcome has one diagnostic")

            XCTAssertEqual(error.kind, entry.expected_kind, "\(entry.id): frozen refusal kind")
            XCTAssertEqual(diagnostic.outcome, .refused, "\(entry.id): decision")
            XCTAssertEqual(diagnostic.kind, error.kind, "\(entry.id): the diagnostic names the refusal")
            XCTAssertEqual(diagnostic.stage.rawValue, entry.expected_stage, "\(entry.id): frozen stage")
            XCTAssertEqual(diagnostic.stage, error.stage, "\(entry.id): the stage is derived from the refusal")
            XCTAssertFalse(diagnostic.reason.isEmpty, "\(entry.id): a refusal always says why")
            XCTAssertFalse(
                diagnostic.reason.contains("ExtractionError"),
                "\(entry.id): the reason must read as prose, not as a Swift type name"
            )
            XCTAssertEqual(
                diagnostic.reason,
                error.reason,
                "\(entry.id): a refused diagnostic repeats the refusal verbatim rather than paraphrasing it"
            )
        }
    }

    func testTheStageMappingIsTotalAndNamesTheDecidingBoundary() throws {
        // Every refusal kind maps to exactly one stage, every stage is
        // reachable, and no stage is a catch-all: the point of the stage is
        // that it names which boundary decided, so an unmapped kind would be a
        // silent loss of information.
        let mapping: [(ExtractionError, ExtractionStage)] = [
            (.invalidPolicy(reason: "x"), .policy),
            (.missingSourceIdentifier(url: "u"), .sourceIdentifier),
            (.unsupportedContentType(contentType: "t", url: "u"), .contentType),
            (.documentTooLarge(byteCount: 1, limit: 1, url: "u"), .size),
            (.unsupportedCharset(charset: "c", url: "u"), .charset),
            (.emptyDocument(url: "u"), .markup),
            (.malformedMarkup(url: "u", reason: "r"), .markup),
            (.noReadableText(url: "u"), .text),
        ]

        for (error, stage) in mapping {
            XCTAssertEqual(error.stage, stage, "\(error.kind) must name \(stage.rawValue)")
        }
        XCTAssertEqual(Set(mapping.map { $0.0.kind }).count, 8, "the refusal family is frozen at eight kinds")
        XCTAssertEqual(
            Set(mapping.map { $0.1 }),
            Set(ExtractionStage.allCases),
            "every stage must be reachable, so none of them is decorative"
        )
        XCTAssertEqual(ExtractionStage.allCases.count, 7)
        XCTAssertEqual(Set(ExtractionStage.allCases.map(\.rawValue)).count, 7)

        // A stage is a name, not a sentence: it must survive serialization
        // without whitespace, because the serialized diagnostic is parsed by
        // the same convention as the rest of the fixture data.
        for stage in ExtractionStage.allCases {
            XCTAssertFalse(stage.rawValue.contains(" "), "\(stage.rawValue) must be a token")
            XCTAssertEqual(stage.rawValue, stage.rawValue.lowercased())
        }
    }

    // MARK: Measured facts

    func testMeasuredFactsMatchTheFrozenExpectation() throws {
        let fixture = try loadFixture()

        for entry in fixture.cases {
            let outcome = try caseOutcome(entry, fixture)
            assertMetrics(outcome.diagnostic.metrics, matches: entry.expected.metrics, entry.id)
        }
    }

    func testRefusedMetricsReportWhatWasInHandAndNothingMore() throws {
        let fixture = try loadFixture()

        for entry in fixture.refusals {
            let outcome = try refusalOutcome(entry, fixture)
            assertMetrics(outcome.diagnostic.metrics, matches: entry.expected_metrics, entry.id)
        }

        // A run that stopped before decoding must not claim characters it never
        // produced, and a run that stopped after decoding must account for them.
        let beforeDecoding = try ["refused-before-anything-was-decoded",
                                  "refused-on-media-type",
                                  "refused-on-size-before-decoding",
                                  "refused-on-charset"]
            .map { id in try XCTUnwrap(fixture.refusals.first { $0.id == id }) }
        for entry in beforeDecoding {
            let outcome = try refusalOutcome(entry, fixture)
            XCTAssertNil(
                outcome.diagnostic.metrics.charactersDecoded,
                "\(entry.id): nothing was decoded, so the diagnostic must not report characters"
            )
            XCTAssertEqual(outcome.diagnostic.metrics.charset, "undecided", "\(entry.id): no encoding was chosen")
            XCTAssertEqual(outcome.diagnostic.metrics.charsetSource, .undecided, "\(entry.id): charset source")
        }

        let afterDecoding = try ["refused-on-markup-after-decoding", "refused-on-text-after-tokenizing"]
            .map { id in try XCTUnwrap(fixture.refusals.first { $0.id == id }) }
        for entry in afterDecoding {
            let outcome = try refusalOutcome(entry, fixture)
            XCTAssertNotNil(
                outcome.diagnostic.metrics.charactersDecoded,
                "\(entry.id): the body became characters before the refusal"
            )
            XCTAssertEqual(outcome.diagnostic.metrics.charactersKept, 0, "\(entry.id): nothing was kept")
        }
    }

    func testCharsetDecisionRecordsWhichStatementWasBelieved() throws {
        let fixture = try loadFixture()

        var sources: [String: [String]] = [:]
        for entry in fixture.cases {
            let outcome = try caseOutcome(entry, fixture)
            sources[outcome.diagnostic.metrics.charsetSource.rawValue, default: []].append(entry.id)
            XCTAssertFalse(
                outcome.diagnostic.metrics.charset.isEmpty,
                "\(entry.id): an extracted page always knows how it was read"
            )
        }

        XCTAssertEqual(
            Set(sources.keys),
            ["header", "meta", "assumed"],
            "the fixture must exercise all three ways an extracted page can learn its encoding"
        )
        XCTAssertEqual(
            sources["header"],
            ["headings-script-comment-and-blank-run",
             "header-declared-charset-beats-the-meta-declaration"],
            "a transport declaration is believed over a document declaration"
        )
        XCTAssertEqual(
            try XCTUnwrap(sources["meta"]).count, 1,
            "a document declaration decides only when the transport said nothing"
        )
        XCTAssertEqual(
            try XCTUnwrap(sources["assumed"]).count, 1,
            "a document that declares nothing is read as UTF-8"
        )
    }

    // MARK: Determinism

    func testDiagnosticsAreByteIdenticalAcrossRuns() throws {
        let fixture = try loadFixture()

        for entry in fixture.cases {
            let first = try caseOutcome(entry, fixture).diagnostic
            let second = try caseOutcome(entry, fixture).diagnostic
            XCTAssertEqual(first, second, "\(entry.id): the same bytes must produce the same diagnostic")
            XCTAssertEqual(first.serialized(), second.serialized(), "\(entry.id): serialization")
            XCTAssertEqual(first.fingerprint, second.fingerprint, "\(entry.id): fingerprint")
        }
        for entry in fixture.refusals {
            let first = try refusalOutcome(entry, fixture).diagnostic
            let second = try refusalOutcome(entry, fixture).diagnostic
            XCTAssertEqual(first, second, "\(entry.id): the same bytes must produce the same diagnostic")
            XCTAssertEqual(first.serialized(), second.serialized(), "\(entry.id): serialization")
            XCTAssertEqual(first.fingerprint, second.fingerprint, "\(entry.id): fingerprint")
        }
    }

    func testFingerprintSeparatesDocumentsAndRefusals() throws {
        let fixture = try loadFixture()
        var fingerprints: Set<String> = []

        for entry in fixture.cases {
            fingerprints.insert(try caseOutcome(entry, fixture).diagnostic.fingerprint)
        }
        for entry in fixture.refusals {
            fingerprints.insert(try refusalOutcome(entry, fixture).diagnostic.fingerprint)
        }
        XCTAssertEqual(
            fingerprints.count,
            fixture.cases.count + fixture.refusals.count,
            "two different outcomes must not share a fingerprint"
        )

        for fingerprint in fingerprints {
            XCTAssertEqual(fingerprint.count, 20, "a fingerprint is a ten-byte digest")
            XCTAssertTrue(
                fingerprint.allSatisfy { $0.isHexDigit && !$0.isUppercase },
                "\(fingerprint) must be lowercase hexadecimal"
            )
        }

        // A single changed character is a different outcome, because the
        // fingerprint is taken over the measured facts and not over the URL.
        let entry = try XCTUnwrap(fixture.cases.first)
        let original = try caseOutcome(entry, fixture).diagnostic
        let mutated = HTMLExtraction.diagnose(
            try response(
                requested: entry.requested_url,
                final: entry.url,
                contentType: entry.content_type,
                body: Data((entry.body ?? "").replacingOccurrences(of: "tastes", with: "tastez").utf8)
            ),
            sourceID: fixture.source_id,
            policy: try policy(fixture)
        ).diagnostic
        XCTAssertNotEqual(original.fingerprint, mutated.fingerprint, "different text must fingerprint differently")
        XCTAssertNotEqual(original.serialized(), mutated.serialized(), "different text must serialize differently")
    }

    func testSerializationHasAFrozenFieldOrder() throws {
        let fixture = try loadFixture()
        let entry = try XCTUnwrap(fixture.cases.first { $0.id == "utf8-characters-are-not-bytes" })
        let diagnostic = try caseOutcome(entry, fixture).diagnostic

        var lines = diagnostic.serialized().components(separatedBy: "\n")
        let fingerprintLine = lines.removeLast()
        XCTAssertTrue(
            fingerprintLine.hasPrefix("fingerprint="),
            "the fingerprint must be the last line, so a reader can strip it and hash the rest"
        )

        XCTAssertEqual(lines, [
            "outcome=extracted",
            "stage=text",
            "kind=extracted",
            "url=https://example.invalid/menu/cafe",
            "media_type=text/html",
            "bytes_offered=90",
            "byte_ceiling=4096",
            "within_byte_ceiling=true",
            "characters_decoded=87",
            "decoded_digest=241eb14b137b292c2369281ce7d6b691c854c6df20e2a02dec50c42916cc6c3d",
            "characters_kept=22",
            "blocks_kept=1",
            "headings_found=0",
            "title_characters=4",
            "runs_dropped=0",
            "non_prose_elements_skipped=0",
            "comments_skipped=0",
            "declarations_skipped=0",
            "charset=utf-8",
            "charset_source=assumed",
            "extractor_version=html-extractor-1",
            "reason=https://example.invalid/menu/cafe yielded readable text",
        ])
        XCTAssertEqual(fingerprintLine, "fingerprint=\(diagnostic.fingerprint)")
        XCTAssertEqual(
            diagnostic.metrics.decodedDigest,
            StableIdentity.digest(try XCTUnwrap(entry.body)),
            "the digest must identify the characters that were decoded, not merely count them"
        )
        XCTAssertEqual(
            diagnostic.fingerprint,
            StableIdentity.make("extraction-diagnostic", lines.joined(separator: "\n")),
            "the fingerprint is taken over the frozen field order and nothing else"
        )
    }

    func testEveryReportedFactHasAFrozenKeyAndNoFactIsSilentlyDropped() throws {
        let fixture = try loadFixture()
        let keys = Set(
            try caseOutcome(try XCTUnwrap(fixture.cases.first), fixture)
                .diagnostic.serialized()
                .components(separatedBy: "\n")
                .map { String($0.prefix { $0 != "=" }) }
        )
        XCTAssertEqual(keys, [
            "outcome", "stage", "kind", "url", "media_type", "bytes_offered", "byte_ceiling",
            "within_byte_ceiling", "characters_decoded", "decoded_digest", "characters_kept", "blocks_kept",
            "headings_found", "title_characters", "runs_dropped", "non_prose_elements_skipped",
            "comments_skipped", "declarations_skipped", "charset", "charset_source",
            "extractor_version", "reason", "fingerprint",
        ])
        XCTAssertEqual(keys.count, 23, "the serialized record is frozen at twenty-three keys")
        for forbidden in ["timestamp", "date", "time", "duration", "truncated"] {
            XCTAssertFalse(
                keys.contains(forbidden),
                "\(forbidden) is not a measurable fact of extraction and must not be reported"
            )
        }
    }

    // MARK: The diagnostic cannot diverge from the refusal it explains

    func testExtractAndDiagnoseCannotDiverge() throws {
        let fixture = try loadFixture()

        for entry in fixture.cases {
            let response = try response(
                requested: entry.requested_url,
                final: entry.url,
                contentType: entry.content_type,
                body: try bodyData(body: entry.body, base64: entry.body_base64)
            )
            let thrown = try HTMLExtraction.extract(response, sourceID: fixture.source_id, policy: try policy(fixture))
            let diagnosed = HTMLExtraction.diagnose(response, sourceID: fixture.source_id, policy: try policy(fixture))
            XCTAssertEqual(diagnosed.page, thrown, "\(entry.id): both entry points must agree")
        }

        for entry in fixture.refusals {
            let response = try response(
                requested: entry.url,
                final: entry.url,
                contentType: entry.content_type,
                body: try bodyData(body: entry.body, base64: entry.body_base64)
            )
            let sourceID = entry.source_id ?? fixture.source_id
            let policy = try policy(fixture, maximumBytes: entry.maximum_bytes)

            var thrown: ExtractionError?
            do {
                _ = try HTMLExtraction.extract(response, sourceID: sourceID, policy: policy)
            } catch let error as ExtractionError {
                thrown = error
            }
            let diagnosed = HTMLExtraction.diagnose(response, sourceID: sourceID, policy: policy)
            XCTAssertEqual(diagnosed.refusal, thrown, "\(entry.id): the thrown error and the diagnostic must agree")
            XCTAssertEqual(diagnosed.diagnostic.reason, thrown?.reason, "\(entry.id): the reason must be the same words")
        }
    }

    func testTheExtractionFixtureAgreesWithItsDiagnostics() throws {
        // The M002.4 fixture freezes the refusal kinds and reason fragments.
        // Running it through the diagnostic path proves the new entry point
        // reports the same boundary for the same bytes rather than a second,
        // parallel opinion.
        let root = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: try Data(contentsOf: extractionFixtureURL))
                as? [String: Any]
        )
        let refusals = try XCTUnwrap(root["refusals"] as? [[String: Any]])
        XCTAssertFalse(refusals.isEmpty)

        var seenKinds: Set<String> = []
        for entry in refusals {
            let id = try XCTUnwrap(entry["id"] as? String)
            let contentType = try XCTUnwrap(entry["content_type"] as? String)
            let body = try bodyData(
                body: entry["body"] as? String,
                base64: entry["body_base64"] as? String
            )
            let maximumBytes = entry["maximum_bytes"] as? Int
            let sourceID = entry["source_id"] as? String ?? "extraction-fixture"
            let response = try response(
                requested: "https://example.invalid/research/coffee",
                final: "https://example.invalid/research/coffee",
                contentType: contentType,
                body: body
            )
            let policy = try ExtractionPolicy(
                maximumBytes: maximumBytes ?? 5_000_000,
                extractorVersion: "html-extractor-1"
            )
            let outcome = HTMLExtraction.diagnose(response, sourceID: sourceID, policy: policy)
            guard case let .refused(error, diagnostic) = outcome else {
                return XCTFail("\(id): the M002.4 fixture expects a refusal")
            }
            XCTAssertEqual(error.kind, entry["expected_kind"] as? String, "\(id): frozen kind")
            XCTAssertEqual(diagnostic.kind, error.kind, "\(id): the diagnostic names the same kind")
            XCTAssertEqual(diagnostic.stage, error.stage, "\(id): the stage is the boundary that decided")
            XCTAssertFalse(diagnostic.reason.isEmpty, "\(id): a refusal always says why")
            seenKinds.insert(error.kind)
        }

        XCTAssertEqual(
            seenKinds,
            ["empty_document", "unsupported_content_type", "document_too_large", "malformed_markup",
             "no_readable_text", "unsupported_charset", "missing_source_identifier"],
            "the frozen extraction fixture must still cover every stage-decidable kind"
        )
        XCTAssertFalse(
            seenKinds.contains("invalid_policy"),
            "an unusable policy is refused by the policy itself, before any document is read"
        )
    }

    // MARK: Boundary guard

    func testDiagnosticSourceHasNoNetworkFilesystemOrClockDependency() throws {
        // A diagnostic explains a document that is already in memory. It must
        // never fetch, never touch the disk, and never read a clock, because a
        // record that depended on wall time could not be compared across runs.
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/LocalLensCore/ExtractionDiagnostics.swift")
        let text = try String(contentsOf: source, encoding: .utf8)

        for forbidden in [
            "URL" + "Session",
            "URL" + "(string:",
            "getaddr" + "info",
            "File" + "Manager",
            "Data(contents" + "Of",
            "Task" + ".sleep",
            "Date(",
        ] {
            XCTAssertFalse(text.contains(forbidden), "ExtractionDiagnostics must not reach for \(forbidden)")
        }
        XCTAssertEqual(
            text.components(separatedBy: "\n").filter { $0.hasPrefix("import ") },
            ["import Foundation"],
            "the diagnostic must not grow a dependency it does not need"
        )
    }
}
