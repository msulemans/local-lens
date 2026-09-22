import Foundation

// MARK: - Extraction limits

/// Limits and version stamp for HTML extraction.
///
/// The byte ceiling here is deliberately separate from the acquisition
/// ceiling: acquisition decides how much of an origin's body we are willing to
/// read off the wire, extraction decides how much of an already-accepted body
/// we are willing to turn into text. Extraction only ever sees a body the
/// acquisition ceiling already capped, so this ceiling can be lower but can
/// never admit more bytes than acquisition did.
public struct ExtractionPolicy: Equatable, Sendable {
    public let maximumBytes: Int
    public let extractorVersion: String

    /// The shipped policy. It is built through the unchecked initializer
    /// because a static constant cannot throw; the values are the same ones the
    /// checked initializer validates by default.
    public static let `default` = ExtractionPolicy(
        uncheckedMaximumBytes: 5_000_000,
        extractorVersion: "html-extractor-1"
    )

    private init(uncheckedMaximumBytes: Int, extractorVersion: String) {
        self.maximumBytes = uncheckedMaximumBytes
        self.extractorVersion = extractorVersion
    }

    public init(
        maximumBytes: Int = 5_000_000,
        extractorVersion: String = "html-extractor-1"
    ) throws {
        guard maximumBytes > 0 else {
            throw ExtractionError.invalidPolicy(reason: "maximumBytes must be positive")
        }
        guard !extractorVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ExtractionError.invalidPolicy(reason: "extractorVersion must not be empty")
        }
        self.maximumBytes = maximumBytes
        self.extractorVersion = extractorVersion
    }
}

// MARK: - Typed refusals

/// Why a document could not become text.
///
/// Every case is a different fact about the document, because every case is a
/// different thing to show a user: an unsupported type is not a broken page,
/// and an empty page is not a malformed one. Nothing here is silent: extraction
/// either returns text or throws one of these.
public enum ExtractionError: Error, Equatable, Sendable {
    /// The response declared a media type this extractor does not read.
    case unsupportedContentType(contentType: String, url: String)
    /// The body exceeded the extraction ceiling.
    case documentTooLarge(byteCount: Int, limit: Int, url: String)
    /// The body was empty, or nothing but whitespace.
    case emptyDocument(url: String)
    /// The declared character set is not one this extractor decodes.
    case unsupportedCharset(charset: String, url: String)
    /// The body could not be decoded, or did not contain usable markup.
    case malformedMarkup(url: String, reason: String)
    /// The markup was readable but contained no text a reader could use.
    case noReadableText(url: String)
    /// The document cannot be attributed to a source, so nothing it contains
    /// could ever be cited.
    case missingSourceIdentifier(url: String)
    /// The policy itself is unusable.
    case invalidPolicy(reason: String)

    public var kind: String {
        switch self {
        case .unsupportedContentType: "unsupported_content_type"
        case .documentTooLarge: "document_too_large"
        case .emptyDocument: "empty_document"
        case .unsupportedCharset: "unsupported_charset"
        case .malformedMarkup: "malformed_markup"
        case .noReadableText: "no_readable_text"
        case .missingSourceIdentifier: "missing_source_identifier"
        case .invalidPolicy: "invalid_policy"
        }
    }

    public var reason: String {
        switch self {
        case let .unsupportedContentType(contentType, url):
            "\(url) declared \(contentType), which is not an HTML document"
        case let .documentTooLarge(byteCount, limit, url):
            "\(url) returned \(byteCount) bytes, above the extraction ceiling of \(limit)"
        case let .emptyDocument(url):
            "\(url) returned an empty document"
        case let .unsupportedCharset(charset, url):
            "\(url) declared the unsupported character set \(charset)"
        case let .malformedMarkup(url, reason):
            "\(url) could not be read as HTML: \(reason)"
        case let .noReadableText(url):
            "\(url) contained no readable text"
        case let .missingSourceIdentifier(url):
            "\(url) was extracted without a source identifier, so nothing it contains could be cited"
        case let .invalidPolicy(reason):
            "the extraction policy is unusable: \(reason)"
        }
    }
}

// MARK: - Extracted shape

/// One readable block of a document, attributed to the heading it sits under.
public struct ExtractionBlock: Equatable, Sendable {
    public let ordinal: Int
    public let heading: String
    public let text: String

    public init(ordinal: Int, heading: String, text: String) {
        self.ordinal = ordinal
        self.heading = heading
        self.text = text
    }
}

/// An extracted document, already bound to the frozen `Snapshot` and `Passage`
/// entities so the caller cannot invent a different identity scheme.
public struct ExtractedPage: Equatable, Sendable {
    public let sourceID: String
    public let requestedURL: URL
    public let finalURL: URL
    public let title: String
    /// Blocks joined by a blank line. Headings live on their block, not in here.
    public let text: String
    public let contentHash: String
    public let extractorVersion: String
    public let blocks: [ExtractionBlock]
    public let snapshot: Snapshot
    public let passages: [Passage]
}

// MARK: - Extraction

/// Turns a policy-checked HTML response into readable text and the frozen
/// snapshot/passage entities, or throws a typed refusal.
///
/// Identity is derived from content, not position, and follows the same part
/// ordering the M001 deterministic slice uses, so a snapshot taken from a live
/// page and a snapshot taken from the fixture slice describe themselves the
/// same way.
public enum HTMLExtraction {
    /// The media types this extractor reads. PDF and plain text are accepted by
    /// the acquisition boundary but are not HTML, so they are refused here
    /// rather than being half-parsed.
    public static let supportedContentTypes: Set<String> = [
        "text/html",
        "application/xhtml+xml",
    ]

    public static func extract(
        _ response: AcquisitionResult,
        sourceID: String,
        policy: ExtractionPolicy = .default
    ) throws -> ExtractedPage {
        let url = response.finalURL.absoluteString

        guard !sourceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ExtractionError.missingSourceIdentifier(url: url)
        }

        let mediaType = Self.mediaType(of: response.contentType)
        guard supportedContentTypes.contains(mediaType) else {
            throw ExtractionError.unsupportedContentType(contentType: mediaType, url: url)
        }

        guard response.body.count <= policy.maximumBytes else {
            throw ExtractionError.documentTooLarge(
                byteCount: response.body.count,
                limit: policy.maximumBytes,
                url: url
            )
        }

        // The header wins. A document that declares its own character set in
        // `<meta>` is believed only when the header said nothing, because the
        // header is the transport's statement about the bytes and `<meta>` is
        // the document's statement about itself.
        let charset = Self.charset(in: response.contentType)
            ?? Self.declaredCharset(inBody: response.body)
        let html = try Self.decode(response.body, charset: charset, url: url)

        guard !html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ExtractionError.emptyDocument(url: url)
        }
        guard html.contains("<") else {
            throw ExtractionError.malformedMarkup(url: url, reason: "the body contained no markup")
        }

        let document = try HTMLTokenizer.tokenize(html, url: url)
        guard !document.blocks.isEmpty else {
            throw ExtractionError.noReadableText(url: url)
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

        return ExtractedPage(
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
    }

    /// The media type with parameters removed and case folded, so
    /// `Text/HTML; charset=UTF-8` and `text/html` name the same document type.
    static func mediaType(of contentType: String) -> String {
        contentType
            .split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() } ?? ""
    }

    /// Reads the `charset` parameter of a content type. Absent means the
    /// document's own declaration decides, and a document that declares nothing
    /// is read as UTF-8.
    static func charset(in contentType: String) -> String? {
        let parts = contentType.split(separator: ";", omittingEmptySubsequences: true).dropFirst()
        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            guard let separator = trimmed.firstIndex(of: "=") else { continue }
            let name = trimmed[..<separator].trimmingCharacters(in: .whitespaces).lowercased()
            guard name == "charset" else { continue }
            let value = trimmed[trimmed.index(after: separator)...]
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            if !value.isEmpty {
                return value.lowercased()
            }
        }
        return nil
    }

    /// `<meta charset="...">` and `<meta http-equiv="content-type"
    /// content="...; charset=...">`, read from the ASCII prefix of the body
    /// where the format requires the declaration to appear.
    ///
    /// This is a scan, not a parser: it finds the first `charset` token whose
    /// value is a bare identifier, and ignores everything it does not
    /// understand. A declaration it cannot read leaves the document to the
    /// UTF-8 default rather than guessing.
    static func declaredCharset(inBody body: Data) -> String? {
        let prefix = Data(body.prefix(2048))
        guard let head = String(data: prefix, encoding: .isoLatin1) else { return nil }
        let characters = Array(head.lowercased())
        let needle = Array("charset")
        var searchFrom = 0

        while let start = Self.find(characters, from: searchFrom, needle) {
            searchFrom = start + needle.count

            // `charset` has to be a token of its own: the `charset` inside
            // `charsetless` names nothing, so it must not decide the encoding.
            if start > 0, Self.isIdentifierCharacter(characters[start - 1]) { continue }

            var cursor = searchFrom
            while cursor < characters.count, characters[cursor] == " " { cursor += 1 }
            if cursor < characters.count, Self.isIdentifierCharacter(characters[cursor]) { continue }

            if cursor < characters.count, characters[cursor] == "=" {
                cursor += 1
                while cursor < characters.count, characters[cursor] == " " { cursor += 1 }
            }
            var quote: Character?
            if cursor < characters.count, characters[cursor] == "\"" || characters[cursor] == "'" {
                quote = characters[cursor]
                cursor += 1
            }
            let valueStart = cursor
            while cursor < characters.count {
                let character = characters[cursor]
                if let quote, character == quote { break }
                if quote == nil, !Self.isIdentifierCharacter(character) { break }
                cursor += 1
            }
            let value = String(characters[valueStart..<cursor]).trimmingCharacters(in: .whitespaces)
            if !value.isEmpty { return value }
        }
        return nil
    }

    /// The characters that may appear inside a bare content-type token, used to
    /// tell `charset` from `charsetless`.
    private static func isIdentifierCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "-" || character == "_"
    }

    /// Finds the first occurrence of `needle` at or after `index`. Returns
    /// `nil` when it does not fit, so a caller never has to reason about an
    /// empty or impossible range.
    static func find(_ characters: [Character], from index: Int, _ needle: [Character]) -> Int? {
        guard !needle.isEmpty,
              characters.count >= needle.count,
              index >= 0,
              index <= characters.count - needle.count
        else { return nil }

        for start in index...(characters.count - needle.count) where Self.matches(characters, at: start, needle) {
            return start
        }
        return nil
    }

    static func matches(_ characters: [Character], at index: Int, _ needle: [Character]) -> Bool {
        guard index >= 0, index + needle.count <= characters.count else { return false }
        for offset in 0..<needle.count where characters[index + offset] != needle[offset] {
            return false
        }
        return true
    }

    static func decode(_ body: Data, charset: String?, url: String) throws -> String {
        guard !body.contains(0) else {
            throw ExtractionError.malformedMarkup(url: url, reason: "the body contained a NUL byte")
        }

        let encoding: String.Encoding
        switch charset {
        case nil, "utf-8", "utf8":
            encoding = .utf8
        case "us-ascii", "ascii":
            encoding = .ascii
        case "iso-8859-1", "latin1", "latin-1", "iso8859-1":
            encoding = .isoLatin1
        default:
            throw ExtractionError.unsupportedCharset(charset: charset ?? "", url: url)
        }

        guard let decoded = String(data: body, encoding: encoding) else {
            throw ExtractionError.malformedMarkup(
                url: url,
                reason: "the body was not valid \(charset ?? "utf-8")"
            )
        }
        return decoded
    }
}

// MARK: - Tokenizer

/// A small, deliberately narrow HTML reader.
///
/// It is not a browser and does not try to be one: it understands elements,
/// attributes it skips, comments, and the entities a document actually uses,
/// and it refuses markup it cannot read rather than guessing at it.
private enum HTMLTokenizer {
    struct Document {
        let title: String
        let blocks: [ExtractionBlock]
    }

    /// Elements whose text content is never readable prose.
    private static let skipElements: Set<String> = [
        "script", "style", "noscript", "template", "svg", "iframe", "noframes", "canvas",
    ]

    /// Elements that end whatever text run was open.
    private static let blockElements: Set<String> = [
        "address", "article", "aside", "blockquote", "br", "dd", "div", "dl", "dt",
        "fieldset", "figcaption", "figure", "footer", "form", "h1", "h2", "h3", "h4",
        "h5", "h6", "header", "hr", "li", "main", "nav", "ol", "p", "pre", "section",
        "table", "tbody", "td", "tfoot", "th", "thead", "tr", "ul",
    ]

    private static let headingElements: Set<String> = ["h1", "h2", "h3", "h4", "h5", "h6"]

    private static let commentOpen: [Character] = Array("<!--")
    private static let commentClose: [Character] = Array("-->")
    private static let declarationOpen: [Character] = Array("<!")
    private static let processingOpen: [Character] = Array("<?")
    private static let tagClose: [Character] = Array(">")

    static func tokenize(_ html: String, url: String) throws -> Document {
        let characters = Array(html)
        var index = 0

        var titleBuffer = ""
        var headingBuffer = ""
        var buffer = ""
        var currentHeading = ""
        var inHeading = false
        var blocks: [ExtractionBlock] = []

        // Text is routed to whichever run is open. A heading is not body text:
        // leaving it in `buffer` is what makes a heading read like an ordinary
        // paragraph. The title is captured whole, not character by character.
        func append(_ character: Character) {
            if inHeading {
                headingBuffer.append(character)
            } else {
                buffer.append(character)
            }
        }

        func flushBuffer() {
            let text = HTMLText.normalized(buffer)
            buffer = ""
            guard !text.isEmpty else { return }
            blocks.append(ExtractionBlock(ordinal: blocks.count, heading: currentHeading, text: text))
        }

        while index < characters.count {
            let character = characters[index]

            guard character == "<" else {
                append(character)
                index += 1
                continue
            }

            if HTMLExtraction.matches(characters, at: index, Self.commentOpen) {
                guard let end = HTMLExtraction.find(
                    characters,
                    from: index + Self.commentOpen.count,
                    Self.commentClose
                ) else {
                    throw ExtractionError.malformedMarkup(url: url, reason: "a comment was never closed")
                }
                index = end + Self.commentClose.count
                continue
            }

            if HTMLExtraction.matches(characters, at: index, Self.declarationOpen)
                || HTMLExtraction.matches(characters, at: index, Self.processingOpen) {
                guard let end = HTMLExtraction.find(characters, from: index + 2, Self.tagClose) else {
                    throw ExtractionError.malformedMarkup(url: url, reason: "a declaration was never closed")
                }
                index = end + 1
                continue
            }

            guard let end = HTMLExtraction.find(characters, from: index + 1, Self.tagClose) else {
                throw ExtractionError.malformedMarkup(url: url, reason: "a tag was never closed")
            }
            let rawTag = String(characters[(index + 1)..<end])
            index = end + 1

            let isClosing = rawTag.hasPrefix("/")
            let body = isClosing ? String(rawTag.dropFirst()) : rawTag
            let name = body.prefix { $0.isLetter || $0.isNumber }
                .lowercased()
            guard !name.isEmpty else { continue }

            if Self.skipElements.contains(name) {
                guard !isClosing else { continue }
                let swallowed = "an unclosed <\(name)> element swallowed the rest of the document"
                guard let closing = HTMLExtraction.find(characters, from: index, Array("</\(name)")) else {
                    throw ExtractionError.malformedMarkup(url: url, reason: swallowed)
                }
                guard let closingEnd = HTMLExtraction.find(characters, from: closing, Self.tagClose) else {
                    throw ExtractionError.malformedMarkup(url: url, reason: swallowed)
                }
                index = closingEnd + 1
                continue
            }

            if name == "title" {
                guard !isClosing else { continue }
                guard let closing = HTMLExtraction.find(characters, from: index, Array("</title")) else {
                    throw ExtractionError.malformedMarkup(
                        url: url,
                        reason: "an unclosed <title> element swallowed the rest of the document"
                    )
                }
                // The title's characters are captured directly from the source
                // rather than tokenized, so a `<` inside a title cannot be read
                // as markup and the title cannot leak into the prose.
                titleBuffer = String(characters[index..<closing])
                index = closing
                continue
            }

            if Self.headingElements.contains(name) {
                if isClosing {
                    let heading = HTMLText.normalized(headingBuffer)
                    headingBuffer = ""
                    inHeading = false
                    if !heading.isEmpty {
                        currentHeading = heading
                        // A heading is emitted as its own block so a document
                        // that is nothing but headings is still readable, and
                        // the blocks that follow carry the same heading.
                        blocks.append(
                            ExtractionBlock(ordinal: blocks.count, heading: currentHeading, text: heading)
                        )
                    }
                } else {
                    flushBuffer()
                    headingBuffer = ""
                    inHeading = true
                }
                continue
            }

            if Self.blockElements.contains(name) {
                flushBuffer()
            }
        }

        flushBuffer()
        return Document(title: HTMLText.normalized(titleBuffer), blocks: blocks)
    }
}

// MARK: - Text

/// Turns a run of raw text into the text a passage can be built from.
///
/// Character references are resolved *before* whitespace is collapsed, so
/// `&nbsp;` becomes an ordinary space instead of surviving as an invisible
/// non-breaking character inside a passage, and `&amp;nbsp;` stays the literal
/// text a reader sees rather than being decoded twice.
enum HTMLText {
    static func normalized(_ raw: String) -> String {
        var result = ""
        var pendingSpace = false
        for character in decodeEntities(raw) {
            if character.isWhitespace {
                pendingSpace = !result.isEmpty
                continue
            }
            if pendingSpace {
                result.append(" ")
                pendingSpace = false
            }
            result.append(character)
        }
        return result
    }

    /// Resolves one pass of character references. An entity this table does not
    /// know, or a numeric reference that is not a valid character, is left
    /// exactly as written: an unknown entity is text, not a markup failure.
    static func decodeEntities(_ raw: String) -> String {
        guard raw.contains("&") else { return raw }

        var result = ""
        var index = raw.startIndex
        while index < raw.endIndex {
            guard raw[index] == "&" else {
                result.append(raw[index])
                index = raw.index(after: index)
                continue
            }
            guard let semicolon = raw[index...].prefix(34).firstIndex(of: ";") else {
                result.append("&")
                index = raw.index(after: index)
                continue
            }
            let name = String(raw[raw.index(after: index)..<semicolon])
            if let resolved = Self.resolved(name) {
                result.append(resolved)
            } else {
                result.append(contentsOf: raw[index...semicolon])
            }
            index = raw.index(after: semicolon)
        }
        return result
    }

    private static let namedEntities: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": "\u{00a0}",
        "ndash": "\u{2013}", "mdash": "\u{2014}", "hellip": "\u{2026}",
        "lsquo": "\u{2018}", "rsquo": "\u{2019}", "ldquo": "\u{201c}", "rdquo": "\u{201d}",
        "laquo": "\u{00ab}", "raquo": "\u{00bb}", "bull": "\u{2022}", "middot": "\u{00b7}",
        "dagger": "\u{2020}", "prime": "\u{2032}", "Prime": "\u{2033}", "minus": "\u{2212}",
        "copy": "\u{00a9}", "reg": "\u{00ae}", "trade": "\u{2122}", "sect": "\u{00a7}",
        "para": "\u{00b6}", "deg": "\u{00b0}", "plusmn": "\u{00b1}", "times": "\u{00d7}",
        "divide": "\u{00f7}", "frac12": "\u{00bd}", "micro": "\u{00b5}",
        "euro": "\u{20ac}", "pound": "\u{00a3}", "yen": "\u{00a5}", "cent": "\u{00a2}",
        "agrave": "\u{00e0}", "eacute": "\u{00e9}", "egrave": "\u{00e8}", "ccedil": "\u{00e7}",
        "auml": "\u{00e4}", "ouml": "\u{00f6}", "uuml": "\u{00fc}", "szlig": "\u{00df}",
        "ntilde": "\u{00f1}", "thinsp": "\u{2009}", "ensp": "\u{2002}", "emsp": "\u{2003}",
    ]

    private static func resolved(_ name: String) -> String? {
        if let named = namedEntities[name] { return named }
        guard name.hasPrefix("#") else { return nil }

        let body = name.dropFirst()
        let value: UInt32?
        if body.hasPrefix("x") || body.hasPrefix("X") {
            value = UInt32(body.dropFirst(), radix: 16)
        } else {
            value = UInt32(body, radix: 10)
        }
        guard let value, let scalar = Unicode.Scalar(value) else { return nil }
        // A control character has no place in readable text and is not what a
        // reader sees, so a reference to one is left as written.
        guard scalar.value >= 0x20 || scalar == "\t" || scalar == "\n" || scalar == "\r" else {
            return nil
        }
        return String(Character(scalar))
    }
}
