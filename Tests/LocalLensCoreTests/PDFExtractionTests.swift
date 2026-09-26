import CoreGraphics
import CoreText
import Foundation
import XCTest
@testable import LocalLensCore

/// Builds a small, uncompressed PDF in memory with the given lines per page.
/// No fixture binary is committed; the test constructs the document it reads.
private func makePDF(pages: [[String]]) -> Data {
    let data = NSMutableData()
    var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
    guard let consumer = CGDataConsumer(data: data as CFMutableData),
          let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return Data() }
    let font = CTFontCreateWithName("Helvetica" as CFString, 14, nil)
    for lines in pages {
        context.beginPDFPage(nil)
        for (index, line) in lines.enumerated() {
            let attributes = [kCTFontAttributeName: font] as CFDictionary
            guard let attributed = CFAttributedStringCreate(nil, line as CFString, attributes) else { continue }
            let lineRef = CTLineCreateWithAttributedString(attributed)
            context.textPosition = CGPoint(x: 72, y: 720 - CGFloat(index) * 22)
            CTLineDraw(lineRef, context)
        }
        context.endPDFPage()
    }
    context.closePDF()
    return data as Data
}

private func acquisition(_ body: Data, contentType: String) -> AcquisitionResult {
    AcquisitionResult(
        requestedURL: URL(string: "https://oa.example.invalid/paper.pdf")!,
        finalURL: URL(string: "https://oa.example.invalid/paper.pdf")!,
        statusCode: 200,
        contentType: contentType,
        body: body,
        redirects: []
    )
}

final class PDFExtractionTests: XCTestCase {

    func testPageTextBecomesPageHeadedPassagesWithExactText() throws {
        let body = makePDF(pages: [
            ["Spaced repetition improves long-term retention.", "Retrieval practice strengthens memory."],
            ["Method: a two-week interval schedule.", "Limitations: one undergraduate sample."],
        ])
        let page = try PDFExtraction.extract(acquisition(body, contentType: "application/pdf"), sourceID: "src-pdf")

        XCTAssertEqual(page.extractorVersion, "pdfkit-extractor-1")
        XCTAssertEqual(Set(page.blocks.map(\.heading)), ["Page 1", "Page 2"])
        XCTAssertEqual(page.blocks.map(\.ordinal), Array(0..<page.blocks.count))
        XCTAssertEqual(page.passages.count, page.blocks.count, "every block is a bound passage")
        XCTAssertEqual(page.snapshot.extractedText, page.blocks.map(\.text).joined(separator: "\n\n"))
        XCTAssertEqual(page.snapshot.extractorVersion, "pdfkit-extractor-1")
        for (index, passage) in page.passages.enumerated() {
            XCTAssertEqual(passage.ordinal, index)
            XCTAssertEqual(passage.snapshotID, page.snapshot.id)
            XCTAssertEqual(passage.textHash, StableIdentity.digest(passage.text))
        }
        XCTAssertTrue(page.text.contains("Spaced repetition improves long-term retention"), "page text is untouched: \(page.text)")
        XCTAssertTrue(page.text.contains("Limitations: one undergraduate sample"))
    }

    func testDocumentExtractionRoutesPDFAndHTMLToTheirExtractors() throws {
        let pdf = try DocumentExtraction.extract(acquisition(makePDF(pages: [["Alpha."]]), contentType: "application/pdf"), sourceID: "s")
        XCTAssertEqual(pdf.extractorVersion, "pdfkit-extractor-1")
        let html = try DocumentExtraction.extract(
            acquisition(Data("<html><body><p>Beta</p></body></html>".utf8), contentType: "text/html; charset=utf-8"),
            sourceID: "s"
        )
        XCTAssertEqual(html.extractorVersion, ExtractionPolicy.default.extractorVersion)
    }

    func testUnreadableOrTextlessPDFsFailClosed() {
        XCTAssertThrowsError(try PDFExtraction.extract(acquisition(Data("not a pdf".utf8), contentType: "application/pdf"), sourceID: "s")) { error in
            XCTAssertEqual((error as? ExtractionError)?.kind, "malformed_markup")
        }
        XCTAssertThrowsError(try PDFExtraction.extract(acquisition(Data("{}".utf8), contentType: "text/html"), sourceID: "s")) { error in
            XCTAssertEqual((error as? ExtractionError)?.kind, "unsupported_content_type")
        }
        XCTAssertThrowsError(try PDFExtraction.extract(acquisition(makePDF(pages: [[]]), contentType: "application/pdf"), sourceID: "s")) { error in
            XCTAssertEqual((error as? ExtractionError)?.kind, "no_readable_text", "a page with no extractable text is not evidence")
        }
    }

    func testParagraphSplittingIsWhitespaceNormalizationOnly() {
        let raw = "First line of a paragraph\ncontinues here.\n\nSecond paragraph.\n\n\nThird."
        let paragraphs = PDFExtraction.paragraphs(in: raw)
        XCTAssertEqual(paragraphs, ["First line of a paragraph continues here.", "Second paragraph.", "Third."])
    }
}
