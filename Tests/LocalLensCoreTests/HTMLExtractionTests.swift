import Foundation
import XCTest
@testable import LocalLensCore

// MARK: - Frozen scenario fixture

/// The extraction table lives in `Fixtures/html/extraction-scenarios.json` so
/// the readable text, the heading attribution, and every refusal are reviewable
/// as data rather than as scattered assertions. It is hand-authored, synthetic,
/// and contains no captured page, no live host, and no measured response.
private struct ExtractionFixture: Decodable, Sendable {
    struct Meta: Decodable, Sendable {
        let synthetic: Bool
        let license: String
        let note: String
        let shape: String
    }

    struct Block: Decodable, Sendable {
        let heading: String
        let text: String
    }

    struct Expected: Decodable, Sendable {
        let outcome: String
        let title: String
        let text: String
        let blocks: [Block]
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
        let expected_reason_contains: String
    }

    let _fixture: Meta
    let source_id: String
    let cases: [Case]
    let refusals: [Refusal]
}

final class HTMLExtractionTests: XCTestCase {

    // MARK: Helpers

    private var fixtureURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/html/extraction-scenarios.json")
    }

    private func fixtureData() throws -> Data {
        try Data(contentsOf: fixtureURL)
    }

    private func loadFixture() throws -> ExtractionFixture {
        try JSONDecoder().decode(ExtractionFixture.self, from: try fixtureData())
    }

    private func bodyData(
        body: String?,
        base64: String?
    ) throws -> Data {
        if let base64 {
            return try XCTUnwrap(Data(base64Encoded: base64), "the fixture body_base64 must decode")
        }
        return Data((body ?? "").utf8)
    }

    /// Builds the response the acquisition boundary would have produced. No
    /// transport, resolver, or socket is involved: extraction is a pure
    /// function of the bytes it is handed.
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

    private func extractionPolicy(maximumBytes: Int?) throws -> ExtractionPolicy {
        try ExtractionPolicy(
            maximumBytes: maximumBytes ?? 5_000_000,
            extractorVersion: "html-extractor-1"
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
        XCTAssertEqual(fixture._fixture.shape, "ExtractionFixture")
        XCTAssertFalse(fixture.source_id.trimmingCharacters(in: .whitespaces).isEmpty)

        var urls: [String] = []
        for entry in try XCTUnwrap(root["cases"] as? [[String: Any]]) {
            urls.append(try XCTUnwrap(entry["url"] as? String))
            urls.append(try XCTUnwrap(entry["requested_url"] as? String))
            XCTAssertFalse((entry["why"] as? String ?? "").isEmpty)
            let expected = try XCTUnwrap(entry["expected"] as? [String: Any])
            XCTAssertEqual(
                expected["outcome"] as? String,
                "extracted",
                "an unknown expected outcome would be skipped silently"
            )
        }
        for entry in try XCTUnwrap(root["refusals"] as? [[String: Any]]) {
            urls.append(try XCTUnwrap(entry["url"] as? String))
            XCTAssertFalse((entry["why"] as? String ?? "").isEmpty)
        }

        for raw in urls {
            let url = try XCTUnwrap(URL(string: raw))
            XCTAssertEqual(
                url.host?.hasSuffix(".invalid"),
                true,
                "\(raw) must stay on a non-resolvable host"
            )
        }
        XCTAssertEqual(fixture.cases.count, 7)
        XCTAssertEqual(fixture.refusals.count, 17)
    }

    // MARK: Extraction

    func testExtractedCasesProduceFrozenTextAndHeadings() throws {
        let fixture = try loadFixture()

        for entry in fixture.cases {
            let page = try HTMLExtraction.extract(
                try response(
                    requested: entry.requested_url,
                    final: entry.url,
                    contentType: entry.content_type,
                    body: try bodyData(body: entry.body, base64: entry.body_base64)
                ),
                sourceID: fixture.source_id
            )

            let context = "\(entry.id): \(entry.why)"
            XCTAssertEqual(page.title, entry.expected.title, context)
            XCTAssertEqual(page.text, entry.expected.text, context)
            XCTAssertEqual(
                page.blocks.map(\.heading),
                entry.expected.blocks.map(\.heading),
                context
            )
            XCTAssertEqual(
                page.blocks.map(\.text),
                entry.expected.blocks.map(\.text),
                context
            )
            XCTAssertEqual(page.blocks.map(\.ordinal), Array(0..<entry.expected.blocks.count), context)
            XCTAssertEqual(page.requestedURL.absoluteString, entry.requested_url, context)
            XCTAssertEqual(page.finalURL.absoluteString, entry.url, context)
            XCTAssertEqual(page.extractorVersion, "html-extractor-1", context)
        }
    }

    func testExtractionIsDeterministicAcrossRuns() throws {
        let fixture = try loadFixture()

        for entry in fixture.cases {
            let body = try bodyData(body: entry.body, base64: entry.body_base64)
            var pages: [ExtractedPage] = []
            for _ in 0..<3 {
                pages.append(
                    try HTMLExtraction.extract(
                        try response(
                            requested: entry.requested_url,
                            final: entry.url,
                            contentType: entry.content_type,
                            body: body
                        ),
                        sourceID: fixture.source_id
                    )
                )
            }

            XCTAssertEqual(pages[0], pages[1], entry.id)
            XCTAssertEqual(pages[1], pages[2], entry.id)
            XCTAssertEqual(pages[0].contentHash, pages[2].contentHash, entry.id)
            XCTAssertEqual(pages[0].snapshot, pages[2].snapshot, entry.id)
        }
    }

    func testSnapshotAndPassageIdentityFollowTheFrozenPartOrdering() throws {
        let fixture = try loadFixture()
        let entry = try XCTUnwrap(fixture.cases.first)

        let page = try HTMLExtraction.extract(
            try response(
                requested: entry.requested_url,
                final: entry.url,
                contentType: entry.content_type,
                body: try bodyData(body: entry.body, base64: entry.body_base64)
            ),
            sourceID: fixture.source_id
        )

        // The same parts the M001 deterministic slice hashes, in the same
        // order, so a live snapshot and a fixture snapshot describe themselves
        // the same way.
        XCTAssertEqual(page.contentHash, StableIdentity.digest(page.text))
        XCTAssertEqual(
            page.snapshot.id,
            StableIdentity.make("snapshot", fixture.source_id, page.contentHash)
        )
        XCTAssertEqual(page.snapshot.sourceID, fixture.source_id)
        XCTAssertEqual(page.snapshot.contentHash, page.contentHash)
        XCTAssertEqual(page.snapshot.extractedText, page.text)
        XCTAssertEqual(page.snapshot.extractorVersion, page.extractorVersion)

        for passage in page.passages {
            XCTAssertEqual(passage.textHash, StableIdentity.digest(passage.text))
            XCTAssertEqual(
                passage.id,
                StableIdentity.make(
                    "passage",
                    page.snapshot.id,
                    String(passage.ordinal),
                    passage.textHash
                )
            )
        }
    }

    func testPassagesAreOrderedAttributedAndResolveBackToTheirSnapshot() throws {
        let fixture = try loadFixture()
        let entry = try XCTUnwrap(fixture.cases.first)

        let page = try HTMLExtraction.extract(
            try response(
                requested: entry.requested_url,
                final: entry.url,
                contentType: entry.content_type,
                body: try bodyData(body: entry.body, base64: entry.body_base64)
            ),
            sourceID: fixture.source_id
        )

        XCTAssertEqual(page.passages.count, page.blocks.count)
        XCTAssertEqual(page.passages.map(\.ordinal), Array(0..<page.passages.count))
        XCTAssertEqual(Set(page.passages.map(\.id)).count, page.passages.count)

        for (passage, block) in zip(page.passages, page.blocks) {
            XCTAssertEqual(passage.snapshotID, page.snapshot.id)
            XCTAssertEqual(passage.heading, block.heading)
            XCTAssertEqual(passage.text, block.text)
            XCTAssertEqual(passage.ordinal, block.ordinal)
        }

        // Every passage resolves to the snapshot it came from, and the
        // snapshot's text is exactly the passages joined the same way.
        XCTAssertEqual(page.text, page.passages.map(\.text).joined(separator: "\n\n"))
    }

    func testDifferentBytesAndDifferentSourcesProduceDifferentIdentity() throws {
        let fixture = try loadFixture()
        let first = try XCTUnwrap(fixture.cases.first)
        let second = try XCTUnwrap(fixture.cases.dropFirst().first)

        let pageOne = try HTMLExtraction.extract(
            try response(
                requested: first.requested_url,
                final: first.url,
                contentType: first.content_type,
                body: try bodyData(body: first.body, base64: first.body_base64)
            ),
            sourceID: fixture.source_id
        )
        let pageTwo = try HTMLExtraction.extract(
            try response(
                requested: second.requested_url,
                final: second.url,
                contentType: second.content_type,
                body: try bodyData(body: second.body, base64: second.body_base64)
            ),
            sourceID: fixture.source_id
        )
        let sameBytesOtherSource = try HTMLExtraction.extract(
            try response(
                requested: first.requested_url,
                final: first.url,
                contentType: first.content_type,
                body: try bodyData(body: first.body, base64: first.body_base64)
            ),
            sourceID: "fixture-source-other"
        )

        XCTAssertNotEqual(pageOne.contentHash, pageTwo.contentHash)
        XCTAssertNotEqual(pageOne.snapshot.id, pageTwo.snapshot.id)
        XCTAssertEqual(pageOne.contentHash, sameBytesOtherSource.contentHash)
        XCTAssertNotEqual(pageOne.snapshot.id, sameBytesOtherSource.snapshot.id)
        XCTAssertNotEqual(pageOne.passages[0].id, sameBytesOtherSource.passages[0].id)
    }

    // MARK: Refusals

    func testRefusalCasesProduceTypedOutcomes() throws {
        let fixture = try loadFixture()

        for refusal in fixture.refusals {
            let url = try XCTUnwrap(URL(string: refusal.url))
            let result = AcquisitionResult(
                requestedURL: url,
                finalURL: url,
                statusCode: 200,
                contentType: refusal.content_type,
                body: try bodyData(body: refusal.body, base64: refusal.body_base64),
                redirects: []
            )
            let policy = try extractionPolicy(maximumBytes: refusal.maximum_bytes)

            XCTAssertThrowsError(
                try HTMLExtraction.extract(
                    result,
                    sourceID: refusal.source_id ?? fixture.source_id,
                    policy: policy
                ),
                "\(refusal.id): \(refusal.why)"
            ) { error in
                guard let extractionError = error as? ExtractionError else {
                    return XCTFail("\(refusal.id): expected ExtractionError, got \(error)")
                }
                XCTAssertEqual(extractionError.kind, refusal.expected_kind, "\(refusal.id): \(refusal.why)")
                XCTAssertTrue(
                    extractionError.reason.contains(refusal.expected_reason_contains),
                    "\(refusal.id): expected the reason to explain itself, got \(extractionError.reason)"
                )
            }
        }
    }

    func testTypedOutcomeFamilyIsEnumerated() {
        let family: [ExtractionError] = [
            .unsupportedContentType(contentType: "application/pdf", url: "https://example.invalid/a"),
            .documentTooLarge(byteCount: 10, limit: 5, url: "https://example.invalid/a"),
            .emptyDocument(url: "https://example.invalid/a"),
            .unsupportedCharset(charset: "shift_jis", url: "https://example.invalid/a"),
            .malformedMarkup(url: "https://example.invalid/a", reason: "why"),
            .noReadableText(url: "https://example.invalid/a"),
            .missingSourceIdentifier(url: "https://example.invalid/a"),
            .invalidPolicy(reason: "why"),
        ]

        XCTAssertEqual(
            family.map(\.kind),
            [
                "unsupported_content_type",
                "document_too_large",
                "empty_document",
                "unsupported_charset",
                "malformed_markup",
                "no_readable_text",
                "missing_source_identifier",
                "invalid_policy",
            ]
        )
        for error in family {
            XCTAssertFalse(error.reason.isEmpty)
            XCTAssertFalse(error.reason.contains("ExtractionError"))
        }
    }

    func testRefusalOrderIsMediaTypeThenSizeThenCharset() throws {
        // A PDF above the ceiling is still a PDF: the media type is the first
        // fact the extractor establishes.
        let pdf = try response(
            requested: "https://example.invalid/big.pdf",
            final: "https://example.invalid/big.pdf",
            contentType: "application/pdf",
            body: Data(repeating: 0x41, count: 4096)
        )
        XCTAssertThrowsError(try HTMLExtraction.extract(pdf, sourceID: "s", policy: try extractionPolicy(maximumBytes: 16))) { error in
            XCTAssertEqual((error as? ExtractionError)?.kind, "unsupported_content_type")
        }

        // An HTML document above the ceiling is refused for its size before its
        // character set is even considered.
        let oversized = try response(
            requested: "https://example.invalid/big.html",
            final: "https://example.invalid/big.html",
            contentType: "text/html; charset=shift_jis",
            body: Data(repeating: 0x41, count: 4096)
        )
        XCTAssertThrowsError(try HTMLExtraction.extract(oversized, sourceID: "s", policy: try extractionPolicy(maximumBytes: 16))) { error in
            XCTAssertEqual((error as? ExtractionError)?.kind, "document_too_large")
        }

        // Within the ceiling, the character set is refused next.
        let charset = try response(
            requested: "https://example.invalid/charset.html",
            final: "https://example.invalid/charset.html",
            contentType: "text/html; charset=shift_jis",
            body: Data("<p>short</p>".utf8)
        )
        XCTAssertThrowsError(try HTMLExtraction.extract(charset, sourceID: "s", policy: try extractionPolicy(maximumBytes: 4096))) { error in
            XCTAssertEqual((error as? ExtractionError)?.kind, "unsupported_charset")
        }
    }

    func testPolicyValidationFailsClosed() throws {
        XCTAssertThrowsError(try ExtractionPolicy(maximumBytes: 0)) { error in
            XCTAssertEqual((error as? ExtractionError)?.kind, "invalid_policy")
        }
        XCTAssertThrowsError(try ExtractionPolicy(maximumBytes: -1)) { error in
            XCTAssertEqual((error as? ExtractionError)?.kind, "invalid_policy")
        }
        XCTAssertThrowsError(try ExtractionPolicy(extractorVersion: "   ")) { error in
            XCTAssertEqual((error as? ExtractionError)?.kind, "invalid_policy")
        }

        XCTAssertEqual(ExtractionPolicy.default.maximumBytes, 5_000_000)
        XCTAssertEqual(ExtractionPolicy.default.extractorVersion, "html-extractor-1")
        XCTAssertEqual(try extractionPolicy(maximumBytes: nil), .default)
    }

    // MARK: Parsing helpers

    func testMediaTypeParsing() {
        XCTAssertEqual(HTMLExtraction.mediaType(of: "text/html"), "text/html")
        XCTAssertEqual(HTMLExtraction.mediaType(of: "Text/HTML; charset=UTF-8"), "text/html")
        XCTAssertEqual(HTMLExtraction.mediaType(of: "text/html;charset=utf-8"), "text/html")
        XCTAssertEqual(HTMLExtraction.mediaType(of: "  text/html  "), "text/html")
        XCTAssertEqual(HTMLExtraction.mediaType(of: ""), "")
        XCTAssertEqual(HTMLExtraction.mediaType(of: "; charset=utf-8"), "")
    }

    func testCharsetParameterParsing() {
        XCTAssertNil(HTMLExtraction.charset(in: "text/html"))
        XCTAssertEqual(HTMLExtraction.charset(in: "text/html; charset=utf-8"), "utf-8")
        XCTAssertEqual(HTMLExtraction.charset(in: "text/html; CHARSET=UTF-8"), "utf-8")
        XCTAssertEqual(HTMLExtraction.charset(in: "text/html; charset=\"iso-8859-1\""), "iso-8859-1")
        XCTAssertEqual(HTMLExtraction.charset(in: "text/html; charset='latin1'"), "latin1")
        XCTAssertNil(HTMLExtraction.charset(in: "text/html; charset="))
        XCTAssertNil(HTMLExtraction.charset(in: "text/html; boundary=something"))
    }

    func testDeclaredCharsetScanning() {
        func scan(_ html: String) -> String? {
            HTMLExtraction.declaredCharset(inBody: Data(html.utf8))
        }

        XCTAssertEqual(scan("<meta charset=\"utf-8\">"), "utf-8")
        XCTAssertEqual(scan("<meta charset='latin1'>"), "latin1")
        XCTAssertEqual(scan("<meta charset=utf-8>"), "utf-8")
        XCTAssertEqual(scan("<meta charset=\"ISO-8859-1\" />"), "iso-8859-1")
        XCTAssertEqual(
            scan("<meta http-equiv=\"content-type\" content=\"text/html; charset=windows-1252\">"),
            "windows-1252"
        )
        XCTAssertNil(scan("<html><body><p>no declaration</p></body></html>"))
        XCTAssertNil(scan("<meta name=\"charsetless\">"))

        // The declaration is only honoured where the format requires it.
        let padded = String(repeating: "<p>padding</p>", count: 200) + "<meta charset=\"latin1\">"
        XCTAssertNil(scan(padded))
    }

    func testTextNormalizationAndEntityDecoding() {
        XCTAssertEqual(HTMLText.normalized("  a \n\t b  "), "a b")
        XCTAssertEqual(HTMLText.normalized("a&nbsp;b"), "a b")
        XCTAssertEqual(HTMLText.normalized("5&deg;C"), "5°C")
        XCTAssertEqual(HTMLText.decodeEntities("&amp;"), "&")
        XCTAssertEqual(HTMLText.decodeEntities("&#8217;"), "\u{2019}")
        XCTAssertEqual(HTMLText.decodeEntities("&#x2014;"), "\u{2014}")
        XCTAssertEqual(HTMLText.decodeEntities("&#233;"), "é")
        // One pass only: a double-escaped reference stays the text a reader sees.
        XCTAssertEqual(HTMLText.decodeEntities("&amp;lt;"), "&lt;")
        // Unknown or malformed references are text, not markup failures.
        XCTAssertEqual(HTMLText.decodeEntities("&bogus;"), "&bogus;")
        XCTAssertEqual(HTMLText.decodeEntities("&amp"), "&amp")
        XCTAssertEqual(HTMLText.decodeEntities("&#xZZ;"), "&#xZZ;")
        XCTAssertEqual(HTMLText.decodeEntities("&#0;"), "&#0;")
        XCTAssertEqual(HTMLText.decodeEntities("&"), "&")
    }

    // MARK: Boundary guarantees

    func testExtractionSourceHasNoNetworkOrFilesystemDependency() throws {
        // Extraction must be a pure function of the bytes acquisition already
        // approved: no socket, no DNS, no file read, no clock. This guard keeps
        // that property from regressing silently.
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/LocalLensCore/HTMLExtraction.swift")
        let text = try String(contentsOf: source, encoding: .utf8)

        for forbidden in [
            "URL" + "Session",
            "URL" + "(string:",
            "getaddr" + "info",
            "File" + "Manager",
            "Data(contents" + "Of",
            "Pro" + "cess(",
        ] {
            XCTAssertFalse(text.contains(forbidden), "HTMLExtraction must not reach for \(forbidden)")
        }
        XCTAssertEqual(
            text.components(separatedBy: "\n").filter { $0.hasPrefix("import ") },
            ["import Foundation"],
            "extraction must not grow a dependency it does not need"
        )
    }
}
