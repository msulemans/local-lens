import Foundation

// MARK: - Approval

/// The record that lets an entry run.
///
/// A corpus entry is a claim about the world - that a page exists, that it may
/// be fetched, and that its licence permits what we do with it. An
/// implementation cannot make that claim, so an entry without this record is
/// never planned for a run.
public struct CorpusApproval: Equatable, Sendable {
    public let recordedBy: String
    public let reference: String

    public init(recordedBy: String, reference: String) {
        self.recordedBy = recordedBy
        self.reference = reference
    }
}

// MARK: - Expectation

/// What an entry is expected to produce.
///
/// It reuses the frozen outcome vocabulary rather than inventing one: a corpus
/// entry expects either an extraction or a refusal at a named boundary, which
/// is the same shape every other M002 boundary already reports.
public enum CorpusExpectation: Equatable, Sendable {
    case extracted(extractorVersion: String)
    case refused(stage: FetchStage, kind: String)

    public var summary: String {
        switch self {
        case let .extracted(version): "an extraction with \(version)"
        case let .refused(stage, kind): "a refusal at \(stage.rawValue)/\(kind)"
        }
    }
}

// MARK: - Entry

public struct CorpusEntry: Equatable, Sendable {
    public let id: String
    public let url: URL
    /// The licence name and a reference to its text.
    public let licence: String
    public let licenceReference: String
    public let expectation: CorpusExpectation
    /// Absent until someone records an approval. Absent means "not run".
    public let approval: CorpusApproval?

    public var isApproved: Bool { approval != nil }

    public init(
        id: String,
        url: URL,
        licence: String,
        licenceReference: String,
        expectation: CorpusExpectation,
        approval: CorpusApproval?
    ) {
        self.id = id
        self.url = url
        self.licence = licence
        self.licenceReference = licenceReference
        self.expectation = expectation
        self.approval = approval
    }
}

// MARK: - Manifest refusals

/// Why a manifest could not be read.
///
/// Every case is a fact about the record rather than about a page, so a
/// malformed manifest is refused before anything could be fetched.
public enum CorpusManifestError: Error, Equatable, LocalizedError, Sendable {
    case unreadableJSON(reason: String)
    case missingManifestIdentifier
    case missingIdentifier(index: Int)
    case duplicateIdentifier(id: String)
    case unrecordedLicence(id: String)
    case unrecordedLicenceReference(id: String)
    case missingExpectation(id: String)
    case unknownExpectation(id: String, value: String)
    case insecureURL(id: String, url: String)
    case incompleteApproval(id: String)

    public var kind: String {
        switch self {
        case .unreadableJSON: "unreadable_json"
        case .missingManifestIdentifier: "missing_manifest_identifier"
        case .missingIdentifier: "missing_identifier"
        case .duplicateIdentifier: "duplicate_identifier"
        case .unrecordedLicence: "unrecorded_licence"
        case .unrecordedLicenceReference: "unrecorded_licence_reference"
        case .missingExpectation: "missing_expectation"
        case .unknownExpectation: "unknown_expectation"
        case .insecureURL: "insecure_url"
        case .incompleteApproval: "incomplete_approval"
        }
    }

    public var reason: String {
        switch self {
        case let .unreadableJSON(reason):
            "the manifest is not readable JSON: \(reason)"
        case .missingManifestIdentifier:
            "the manifest does not name itself"
        case let .missingIdentifier(index):
            "the entry at index \(index) has no identifier, so it could not be reported on"
        case let .duplicateIdentifier(id):
            "two entries share the identifier \(id), so a verdict could not be attributed"
        case let .unrecordedLicence(id):
            "\(id) does not record a licence, so nothing is known about what may be done with the page"
        case let .unrecordedLicenceReference(id):
            "\(id) records a licence but no reference to its text, so the claim cannot be checked"
        case let .missingExpectation(id):
            "\(id) does not record what it is expected to produce, so a run could not fail"
        case let .unknownExpectation(id, value):
            "\(id) expects an outcome this vocabulary does not have: \(value)"
        case let .insecureURL(id, url):
            "\(id) must be reached over https; \(url.isEmpty ? "the url is missing" : url) is not an https url"
        case let .incompleteApproval(id):
            "\(id) carries an approval that names no approver or no record, which is not an approval"
        }
    }

    public var errorDescription: String? { reason }
}

// MARK: - Manifest

/// A frozen list of pages that a live run may fetch, once approved.
///
/// Decoding is strict and total: a missing licence, a missing expectation, or
/// an insecure URL is a typed refusal rather than a default. An empty manifest
/// is valid - "no corpus is approved yet" is a real state - but it can never be
/// run.
public struct CorpusManifest: Equatable, Sendable {
    public let id: String
    public let entries: [CorpusEntry]

    public init(id: String, entries: [CorpusEntry]) {
        self.id = id
        self.entries = entries
    }

    public static func decode(_ data: Data) throws -> CorpusManifest {
        let raw: RawManifest
        do {
            raw = try JSONDecoder().decode(RawManifest.self, from: data)
        } catch {
            throw CorpusManifestError.unreadableJSON(reason: String(describing: error))
        }

        guard let id = Self.nonBlank(raw.id) else {
            throw CorpusManifestError.missingManifestIdentifier
        }

        var entries: [CorpusEntry] = []
        var identifiers: Set<String> = []
        for (index, entry) in (raw.entries ?? []).enumerated() {
            guard let entryID = Self.nonBlank(entry.id) else {
                throw CorpusManifestError.missingIdentifier(index: index)
            }
            guard identifiers.insert(entryID).inserted else {
                throw CorpusManifestError.duplicateIdentifier(id: entryID)
            }
            guard let licence = Self.nonBlank(entry.licence) else {
                throw CorpusManifestError.unrecordedLicence(id: entryID)
            }
            guard let licenceReference = Self.nonBlank(entry.licenceReference) else {
                throw CorpusManifestError.unrecordedLicenceReference(id: entryID)
            }
            guard let rawExpectation = entry.expectation else {
                throw CorpusManifestError.missingExpectation(id: entryID)
            }
            let expectation = try Self.expectation(from: rawExpectation, id: entryID)

            let rawURL = entry.url ?? ""
            guard
                let url = URL(string: rawURL),
                url.scheme == "https",
                let host = url.host,
                !host.isEmpty
            else {
                throw CorpusManifestError.insecureURL(id: entryID, url: rawURL)
            }

            var approval: CorpusApproval?
            if let rawApproval = entry.approval {
                guard
                    let recordedBy = Self.nonBlank(rawApproval.recordedBy),
                    let reference = Self.nonBlank(rawApproval.reference)
                else {
                    throw CorpusManifestError.incompleteApproval(id: entryID)
                }
                approval = CorpusApproval(recordedBy: recordedBy, reference: reference)
            }

            entries.append(
                CorpusEntry(
                    id: entryID,
                    url: url,
                    licence: licence,
                    licenceReference: licenceReference,
                    expectation: expectation,
                    approval: approval
                )
            )
        }

        return CorpusManifest(id: id, entries: entries)
    }

    private static func expectation(
        from raw: RawExpectation,
        id: String
    ) throws -> CorpusExpectation {
        switch raw.outcome {
        case "extracted":
            guard let version = nonBlank(raw.extractorVersion) else {
                throw CorpusManifestError.missingExpectation(id: id)
            }
            return .extracted(extractorVersion: version)
        case "refused":
            guard
                let stageName = nonBlank(raw.stage),
                let stage = FetchStage(rawValue: stageName),
                let kind = nonBlank(raw.kind)
            else {
                throw CorpusManifestError.unknownExpectation(
                    id: id,
                    value: "\(raw.stage ?? "no stage")/\(raw.kind ?? "no kind")"
                )
            }
            return .refused(stage: stage, kind: kind)
        case let other:
            throw CorpusManifestError.unknownExpectation(id: id, value: other ?? "no outcome")
        }
    }

    private static func nonBlank(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    // MARK: Decoding shapes

    /// Optional fields throughout, so a missing key becomes a typed refusal
    /// naming the entry rather than an untyped decoder error.
    private struct RawManifest: Decodable {
        let id: String?
        let entries: [RawEntry]?
    }

    private struct RawEntry: Decodable {
        let id: String?
        let url: String?
        let licence: String?
        let licenceReference: String?
        let expectation: RawExpectation?
        let approval: RawApproval?

        enum CodingKeys: String, CodingKey {
            case id, url, licence, expectation, approval
            case licenceReference = "licence_reference"
        }
    }

    private struct RawExpectation: Decodable {
        let outcome: String?
        let extractorVersion: String?
        let stage: String?
        let kind: String?

        enum CodingKeys: String, CodingKey {
            case outcome, stage, kind
            case extractorVersion = "extractor_version"
        }
    }

    private struct RawApproval: Decodable {
        let recordedBy: String?
        let reference: String?

        enum CodingKeys: String, CodingKey {
            case reference
            case recordedBy = "recorded_by"
        }
    }
}

// MARK: - Run gate

/// Why a manifest could not be run.
public enum CorpusRunRefusal: Error, Equatable, LocalizedError, Sendable {
    case noEntries
    case noApprovedEntries(unapproved: [String])

    public var kind: String {
        switch self {
        case .noEntries: "no_entries"
        case .noApprovedEntries: "no_approved_entries"
        }
    }

    public var reason: String {
        switch self {
        case .noEntries:
            "the corpus has no entries, so a run would report a pass over nothing"
        case let .noApprovedEntries(unapproved):
            "\(unapproved.joined(separator: ", ")) carry no approval record; a run that skipped them would report a pass over a corpus it did not run"
        }
    }

    public var errorDescription: String? { reason }
}

public enum CorpusPlan: Equatable, Sendable {
    case refused(CorpusRunRefusal)
    case runnable([CorpusEntry])
}

// MARK: - Observation and verdict

/// What a live run actually saw. A live run produces these; nothing in this
/// module can produce one, because nothing in this module can fetch.
public enum CorpusObservation: Equatable, Sendable {
    case extracted(extractorVersion: String)
    case refused(stage: FetchStage, kind: String)
}

public enum CorpusVerdict: Equatable, Sendable {
    case matches
    case differs(reason: String)
}

// MARK: - The harness

/// The approval gate and the expectation check.
///
/// It holds no transport, no session, and no clock: it decides what may be run
/// and whether a run agreed with its frozen expectation, and the caller is what
/// performs any fetch. That is why the default and gated test runs cannot reach
/// the network through this module - there is nothing here to reach it with.
public enum LiveCorpus {
    /// What a manifest permits. A manifest with any unapproved entry refuses as
    /// a whole, because a run that quietly skipped entries would report a pass
    /// over a corpus it did not run.
    public static func plan(_ manifest: CorpusManifest) -> CorpusPlan {
        guard !manifest.entries.isEmpty else { return .refused(.noEntries) }
        let unapproved = manifest.entries.filter { !$0.isApproved }.map(\.id)
        guard unapproved.isEmpty else { return .refused(.noApprovedEntries(unapproved: unapproved)) }
        return .runnable(manifest.entries)
    }

    /// Whether a run agreed with the frozen expectation. A mismatch says what
    /// was expected and what was seen, so a corpus cannot fail silently.
    public static func verdict(
        _ observation: CorpusObservation,
        against expectation: CorpusExpectation
    ) -> CorpusVerdict {
        switch (expectation, observation) {
        case let (.extracted(expected), .extracted(observed)):
            guard expected == observed else {
                return .differs(reason: "expected \(expected) and observed \(observed)")
            }
            return .matches
        case let (.refused(stage, kind), .refused(observedStage, observedKind)):
            guard stage == observedStage, kind == observedKind else {
                return .differs(
                    reason: "expected \(stage.rawValue)/\(kind) and observed \(observedStage.rawValue)/\(observedKind)"
                )
            }
            return .matches
        case let (.extracted(expected), .refused(stage, kind)):
            return .differs(
                reason: "expected extracted(\(expected)) and observed refused(\(stage.rawValue)/\(kind))"
            )
        case let (.refused(stage, kind), .extracted(observed)):
            return .differs(
                reason: "expected refused(\(stage.rawValue)/\(kind)) and observed extracted(\(observed))"
            )
        }
    }
}
