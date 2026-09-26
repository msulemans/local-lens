import Foundation
import PDFKit

/// Page-aware extraction for open-access PDFs.
///
/// PDFKit is the macOS system framework for PDF text: it needs no download, no
/// third-party dependency, and no model, and it exposes text per page, which is
/// exactly what a paper citation needs. The product need is recorded in D038:
/// M005.1 could reach open-access papers only when an HTML landing page existed.
///
/// Every passage keeps the exact page text PDFKit reports and carries its page
/// number in the block heading (`Page N`), because the frozen `Passage` entity
/// has no page field and must not change. A scanned or textless PDF refuses as
/// `no_readable_text` rather than inventing anything from metadata.
public enum PDFExtraction {
    public static let supportedContentTypes: Set<String> = ["application/pdf"]
    public static let extractorVersion = "pdfkit-extractor-1"

    /// One block per paragraph, so a citation can quote a paragraph rather than
    /// a whole page. A paragraph longer than `maximumBlockCharacters` is split
    /// on single newlines, which is how a two-column paper renders lines.
    static let maximumBlockCharacters = 1_200

    public static func extract(
        _ response: AcquisitionResult,
        sourceID: String,
        policy: ExtractionPolicy = .default
    ) throws -> ExtractedPage {
        let url = response.finalURL.absoluteString
        let mediaType = HTMLExtraction.mediaType(of: response.contentType)
        guard supportedContentTypes.contains(mediaType) else {
            throw ExtractionError.unsupportedContentType(contentType: mediaType, url: url)
        }
        guard !sourceID.isEmpty else {
            throw ExtractionError.missingSourceIdentifier(url: url)
        }
        guard response.body.count <= policy.maximumBytes else {
            throw ExtractionError.documentTooLarge(byteCount: response.body.count, limit: policy.maximumBytes, url: url)
        }
        guard !response.body.isEmpty else {
            throw ExtractionError.emptyDocument(url: url)
        }
        guard let document = PDFDocument(data: response.body) else {
            throw ExtractionError.malformedMarkup(url: url, reason: "the body is not a readable PDF")
        }

        var blocks: [ExtractionBlock] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index), let raw = page.string else { continue }
            let heading = "Page \(index + 1)"
            for paragraph in paragraphs(in: raw) {
                blocks.append(ExtractionBlock(ordinal: blocks.count, heading: heading, text: paragraph))
            }
        }
        guard !blocks.isEmpty else {
            throw ExtractionError.noReadableText(url: url)
        }

        let text = blocks.map(\.text).joined(separator: "\n\n")
        let contentHash = StableIdentity.digest(text)
        let snapshot = Snapshot(
            id: StableIdentity.make("snapshot", sourceID, contentHash),
            sourceID: sourceID,
            contentHash: contentHash,
            extractedText: text,
            extractorVersion: extractorVersion
        )
        let passages = blocks.map { block in
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

        return ExtractedPage(
            sourceID: sourceID,
            requestedURL: response.requestedURL,
            finalURL: response.finalURL,
            title: title(of: document) ?? blocks.first?.text.split(separator: "\n").first.map(String.init) ?? "PDF document",
            text: text,
            contentHash: contentHash,
            extractorVersion: extractorVersion,
            blocks: blocks,
            snapshot: snapshot,
            passages: passages
        )
    }

    /// Paragraph splitting is whitespace normalization only: it never edits a
    /// word. Lines are kept in order and joined with a space, because a PDF line
    /// break is a layout fact, not a sentence boundary.
    static func paragraphs(in raw: String) -> [String] {
        let normalized = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        var paragraphs: [String] = []
        for chunk in normalized.components(separatedBy: "\n\n") {
            let collapsed = chunk
                .split(separator: "\n", omittingEmptySubsequences: true)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            guard !collapsed.isEmpty else { continue }
            if collapsed.count <= maximumBlockCharacters {
                paragraphs.append(collapsed)
            } else {
                // A long unbroken run is split on its own line boundaries in
                // order; the text of each part is untouched.
                var current = ""
                for line in chunk.split(separator: "\n", omittingEmptySubsequences: true) {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { continue }
                    if current.isEmpty {
                        current = trimmed
                    } else if current.count + trimmed.count + 1 <= maximumBlockCharacters {
                        current += " " + trimmed
                    } else {
                        paragraphs.append(current)
                        current = trimmed
                    }
                }
                if !current.isEmpty { paragraphs.append(current) }
            }
        }
        return paragraphs
    }

    private static func title(of document: PDFDocument) -> String? {
        let attributes = document.documentAttributes
        guard let raw = attributes?[PDFDocumentAttribute.titleAttribute] as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// Routes a policy-checked response to the extractor for its declared media
/// type. Acquisition already decides what may be read; this decides how it
/// becomes text. An unhandled type still refuses as
/// `unsupported_content_type`, so no body silently becomes an empty document.
public enum DocumentExtraction {
    public static func extract(
        _ response: AcquisitionResult,
        sourceID: String,
        policy: ExtractionPolicy = .default
    ) throws -> ExtractedPage {
        switch HTMLExtraction.mediaType(of: response.contentType) {
        case let mediaType where PDFExtraction.supportedContentTypes.contains(mediaType):
            return try PDFExtraction.extract(response, sourceID: sourceID, policy: policy)
        default:
            return try HTMLExtraction.extract(response, sourceID: sourceID, policy: policy)
        }
    }
}
