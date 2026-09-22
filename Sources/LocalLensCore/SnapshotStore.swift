import Foundation

// MARK: - Store records

/// One stored document: the frozen snapshot, the passages that belong to it, and
/// every acquisition attempt that was recognised as the same bytes.
///
/// A record accumulates attempts rather than replacing them, because "we already
/// have this document" is a fact about the run that a user is entitled to see.
public struct SnapshotRecord: Equatable, Sendable {
    public let snapshot: Snapshot
    public let passages: [Passage]
    /// Every source identity that produced these bytes, first one first.
    public let sourceIDs: [String]
    /// Every URL that was actually requested, so a redirect or a retry does not
    /// erase where the run looked.
    public let requestedURLs: [URL]
    public let finalURL: URL
    /// The attempt that produced the stored bytes.
    public let attempt: Int
    /// Later offers that were recognised as the same bytes and stored nothing.
    public let duplicateAttempts: Int

    public init(
        snapshot: Snapshot,
        passages: [Passage],
        sourceIDs: [String],
        requestedURLs: [URL],
        finalURL: URL,
        attempt: Int,
        duplicateAttempts: Int
    ) {
        self.snapshot = snapshot
        self.passages = passages
        self.sourceIDs = sourceIDs
        self.requestedURLs = requestedURLs
        self.finalURL = finalURL
        self.attempt = attempt
        self.duplicateAttempts = duplicateAttempts
    }

    public var totalAttempts: Int { attempt + duplicateAttempts }

    public var id: String { snapshot.id }
}

/// Why a second offer of the same bytes stored nothing. These are different
/// facts: a retry, a second URL for one document, and two origins publishing the
/// same bytes are not the same event.
public enum DuplicateReason: String, Equatable, Sendable {
    case repeatedAttempt = "repeated_attempt"
    case sameContentFromAnotherURL = "same_content_from_another_url"
    case sameBytesFromAnotherSource = "same_bytes_from_another_source"
}

public enum SnapshotStoreOutcome: Equatable, Sendable {
    case stored(SnapshotRecord)
    case duplicate(SnapshotRecord, reason: DuplicateReason)

    public var kind: String {
        switch self {
        case .stored: "stored"
        case .duplicate: "duplicate"
        }
    }

    public var record: SnapshotRecord {
        switch self {
        case let .stored(record), let .duplicate(record, _): record
        }
    }

    public var duplicateReason: DuplicateReason? {
        switch self {
        case .stored: nil
        case let .duplicate(_, reason): reason
        }
    }
}

public enum SnapshotStoreError: Error, Equatable, LocalizedError, Sendable {
    /// Attempt numbers are 1-based; an attempt number that cannot be one is a
    /// caller bug, not a stored fact.
    case invalidAttempt(attempt: Int)
    /// The page does not describe itself: a passage that does not belong to its
    /// snapshot, a broken ordinal run, or a content hash that does not match the
    /// extracted text.
    case inconsistentPage(reason: String)
    /// A search hit is discovery metadata. Until its bytes have been acquired
    /// and extracted, it is not evidence.
    case hitIsNotEvidence(hitID: String, url: URL)
    case unknownSnapshot(id: String)

    public var kind: String {
        switch self {
        case .invalidAttempt: "invalid_attempt"
        case .inconsistentPage: "inconsistent_page"
        case .hitIsNotEvidence: "hit_is_not_evidence"
        case .unknownSnapshot: "unknown_snapshot"
        }
    }

    public var reason: String {
        switch self {
        case let .invalidAttempt(attempt):
            "acquisition attempts are numbered from one, and \(attempt) is not a valid attempt number"
        case let .inconsistentPage(reason):
            "the extracted page did not describe itself consistently: \(reason)"
        case let .hitIsNotEvidence(hitID, url):
            "search hit \(hitID) at \(url.absoluteString) has not been acquired and extracted, so it cannot be evidence"
        case let .unknownSnapshot(id):
            "no snapshot \(id) is stored"
        }
    }

    public var errorDescription: String? { reason }
}

// MARK: - Store

/// Keeps extracted documents as immutable, content-addressed snapshots and
/// refuses to store the same bytes twice.
///
/// Deduplication is keyed by the content hash, which is what makes it safe under
/// retry: a retried request, a redirect that lands on an already-seen document,
/// and a second origin publishing identical bytes all resolve to the one snapshot
/// that was stored first, while every source identity and every requested URL
/// stays recorded on the record. The stored snapshot keeps the identity it was
/// given when it was first stored, so deduplication never rewrites an identity
/// that a citation may already point at.
///
/// This is an actor because the fetch schedule that feeds it is bounded-parallel:
/// two in-flight requests for the same bytes must not both be told they stored a
/// new snapshot.
public actor SnapshotStore {
    private var recordsByContentHash: [String: SnapshotRecord] = [:]

    public init() {}

    /// Stores an extracted page, or reports that its bytes are already stored.
    ///
    /// - Parameter attempt: the 1-based acquisition attempt this page came from.
    ///   A retry is a later attempt of the same source, and the record keeps the
    ///   attempt that produced the stored bytes.
    @discardableResult
    public func store(_ page: ExtractedPage, attempt: Int = 1) throws -> SnapshotStoreOutcome {
        guard attempt >= 1 else {
            throw SnapshotStoreError.invalidAttempt(attempt: attempt)
        }
        try Self.validate(page)

        if let existing = recordsByContentHash[page.contentHash] {
            let reason = Self.duplicateReason(of: page, against: existing)
            let updated = SnapshotRecord(
                snapshot: existing.snapshot,
                passages: existing.passages,
                sourceIDs: existing.sourceIDs.contains(page.sourceID)
                    ? existing.sourceIDs
                    : existing.sourceIDs + [page.sourceID],
                requestedURLs: existing.requestedURLs.contains(page.requestedURL)
                    ? existing.requestedURLs
                    : existing.requestedURLs + [page.requestedURL],
                finalURL: existing.finalURL,
                attempt: existing.attempt,
                duplicateAttempts: existing.duplicateAttempts + 1
            )
            recordsByContentHash[page.contentHash] = updated
            return .duplicate(updated, reason: reason)
        }

        let record = SnapshotRecord(
            snapshot: page.snapshot,
            passages: page.passages,
            sourceIDs: [page.sourceID],
            requestedURLs: [page.requestedURL],
            finalURL: page.finalURL,
            attempt: attempt,
            duplicateAttempts: 0
        )
        recordsByContentHash[page.contentHash] = record
        return .stored(record)
    }

    /// Every stored record, ordered by content hash so two runs over the same
    /// offers describe themselves identically even when the offers arrived
    /// concurrently.
    public func records() -> [SnapshotRecord] {
        recordsByContentHash.values.sorted { $0.snapshot.contentHash < $1.snapshot.contentHash }
    }

    public func snapshotCount() -> Int { recordsByContentHash.count }

    public func record(id: String) throws -> SnapshotRecord {
        guard let record = recordsByContentHash.values.first(where: { $0.snapshot.id == id }) else {
            throw SnapshotStoreError.unknownSnapshot(id: id)
        }
        return record
    }

    public func passages(snapshotID: String) throws -> [Passage] {
        try record(id: snapshotID).passages
    }

    /// Resolves a search hit to stored evidence, or refuses.
    ///
    /// A hit is a URL and a snippet. The store resolves the hit's URL against the
    /// URLs it actually fetched, so a hit can only become evidence through a
    /// document that was acquired and extracted; the snippet itself is never
    /// consulted.
    public func record(forHit hit: SearchHit) throws -> SnapshotRecord {
        let candidates = recordsByContentHash.values.filter { record in
            record.requestedURLs.contains(hit.url) || record.finalURL == hit.url
        }
        guard let record = candidates.min(by: { $0.snapshot.contentHash < $1.snapshot.contentHash }) else {
            throw SnapshotStoreError.hitIsNotEvidence(hitID: hit.id, url: hit.url)
        }
        return record
    }

    // MARK: Integrity

    private static func duplicateReason(
        of page: ExtractedPage,
        against existing: SnapshotRecord
    ) -> DuplicateReason {
        if existing.requestedURLs.contains(page.requestedURL) {
            return .repeatedAttempt
        }
        if existing.sourceIDs.contains(page.sourceID) {
            return .sameContentFromAnotherURL
        }
        return .sameBytesFromAnotherSource
    }

    /// A page that does not describe itself must not become stored evidence, so
    /// the store re-derives the identity it is handed instead of trusting it.
    static func validate(_ page: ExtractedPage) throws {
        guard page.snapshot.sourceID == page.sourceID else {
            throw SnapshotStoreError.inconsistentPage(
                reason: "the snapshot names source \(page.snapshot.sourceID) but the page names \(page.sourceID)"
            )
        }
        guard page.snapshot.contentHash == StableIdentity.digest(page.text) else {
            throw SnapshotStoreError.inconsistentPage(
                reason: "the snapshot content hash does not match the extracted text"
            )
        }
        guard page.snapshot.id == StableIdentity.make("snapshot", page.sourceID, page.snapshot.contentHash) else {
            throw SnapshotStoreError.inconsistentPage(
                reason: "the snapshot identity does not follow from its source and content hash"
            )
        }
        guard page.snapshot.extractedText == page.text else {
            throw SnapshotStoreError.inconsistentPage(
                reason: "the snapshot text and the page text differ"
            )
        }
        guard page.passages.count == page.blocks.count else {
            throw SnapshotStoreError.inconsistentPage(
                reason: "the page has \(page.blocks.count) blocks but \(page.passages.count) passages"
            )
        }
        for (ordinal, passage) in page.passages.enumerated() {
            guard passage.ordinal == ordinal else {
                throw SnapshotStoreError.inconsistentPage(
                    reason: "passage ordinals must run from zero without gaps"
                )
            }
            guard passage.snapshotID == page.snapshot.id else {
                throw SnapshotStoreError.inconsistentPage(
                    reason: "passage \(passage.id) does not resolve to the page's snapshot"
                )
            }
            guard passage.textHash == StableIdentity.digest(passage.text) else {
                throw SnapshotStoreError.inconsistentPage(
                    reason: "passage \(passage.id) text hash does not match its text"
                )
            }
            guard passage.id == StableIdentity.make(
                "passage",
                page.snapshot.id,
                String(passage.ordinal),
                passage.textHash
            ) else {
                throw SnapshotStoreError.inconsistentPage(
                    reason: "passage \(passage.id) does not follow from its snapshot, ordinal and text hash"
                )
            }
        }
        guard page.passages.map(\.text).joined(separator: "\n\n") == page.text else {
            throw SnapshotStoreError.inconsistentPage(
                reason: "the extracted text is not the passages joined in order"
            )
        }
    }
}
