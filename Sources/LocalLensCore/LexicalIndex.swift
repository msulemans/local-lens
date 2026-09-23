import Foundation
import SQLite3

// MARK: - Query policy

/// The recorded ranking rules for the lexical baseline.
///
/// The policy is data, not a preference: two runs that use the same policy over
/// the same stored passages must produce the same ordered result. Every number
/// here is validated before it can reach SQL, and every number here is one the
/// fixture can name.
public struct LexicalQueryPolicy: Equatable, Sendable {
    /// The hard cap on how many hits a single query may return. A caller may
    /// lower it for one query but may not raise it, so the recorded policy
    /// always bounds the result.
    public let maximumResults: Int
    /// The diversity bound: how many passages from one source may appear in one
    /// result. Without it, one long document could occupy every slot.
    public let maximumPassagesPerSource: Int
    /// How many ranked candidates are read before the diversity bound is
    /// applied, so a single source cannot crowd out the whole result window.
    public let maximumCandidates: Int
    /// The bm25 column weight for a passage's heading.
    public let headingWeight: Double
    /// The bm25 column weight for a passage's body text.
    public let bodyWeight: Double

    /// The shipped policy. It is built through the unchecked initializer because
    /// a static constant cannot throw; the values are the same ones the checked
    /// initializer validates by default.
    public static let `default` = LexicalQueryPolicy(
        uncheckedMaximumResults: 10,
        maximumPassagesPerSource: 2,
        maximumCandidates: 200,
        headingWeight: 3.0,
        bodyWeight: 1.0
    )

    private init(
        uncheckedMaximumResults: Int,
        maximumPassagesPerSource: Int,
        maximumCandidates: Int,
        headingWeight: Double,
        bodyWeight: Double
    ) {
        self.maximumResults = uncheckedMaximumResults
        self.maximumPassagesPerSource = maximumPassagesPerSource
        self.maximumCandidates = maximumCandidates
        self.headingWeight = headingWeight
        self.bodyWeight = bodyWeight
    }

    public init(
        maximumResults: Int = 10,
        maximumPassagesPerSource: Int = 2,
        maximumCandidates: Int = 200,
        headingWeight: Double = 3.0,
        bodyWeight: Double = 1.0
    ) throws {
        guard maximumResults >= 1 else {
            throw LexicalIndexError.invalidPolicy(reason: "maximumResults must be at least one")
        }
        guard maximumPassagesPerSource >= 1 else {
            throw LexicalIndexError.invalidPolicy(reason: "maximumPassagesPerSource must be at least one")
        }
        guard maximumCandidates >= maximumResults else {
            throw LexicalIndexError.invalidPolicy(
                reason: "maximumCandidates (\(maximumCandidates)) must not be below maximumResults (\(maximumResults))"
            )
        }
        guard headingWeight.isFinite, headingWeight > 0 else {
            throw LexicalIndexError.invalidPolicy(reason: "headingWeight must be a positive finite number")
        }
        guard bodyWeight.isFinite, bodyWeight > 0 else {
            throw LexicalIndexError.invalidPolicy(reason: "bodyWeight must be a positive finite number")
        }
        self.init(
            uncheckedMaximumResults: maximumResults,
            maximumPassagesPerSource: maximumPassagesPerSource,
            maximumCandidates: maximumCandidates,
            headingWeight: headingWeight,
            bodyWeight: bodyWeight
        )
    }
}

// MARK: - Typed refusals

/// Why a lexical ingest or query could not complete.
///
/// Every case is a different fact: an empty query is not an unusable database,
/// and a passage that does not describe itself is not a passage that is merely
/// absent. Nothing here is silent: ingest and query either return a value or
/// throw one of these.
public enum LexicalIndexError: Error, Equatable, LocalizedError, Sendable {
    /// SQLite, or the FTS5 module, could not be used. The index fails closed
    /// rather than falling back to a scan that was never measured.
    case unavailable(reason: String)
    /// The ranking policy is unusable.
    case invalidPolicy(reason: String)
    /// The snapshot is not a self-consistent, indexable document.
    case invalidSnapshot(reason: String)
    /// A passage does not resolve to its snapshot, its ordinal, or its text.
    case invalidPassage(passageID: String, reason: String)
    /// The query held no term that could be retrieved.
    case emptyQuery
    /// The requested result limit is not a usable number.
    case invalidLimit(limit: Int)
    /// The requested result limit is larger than the recorded policy allows, so
    /// honouring it would mean silently returning fewer results than were asked
    /// for. The boundary refuses instead.
    case limitExceedsPolicy(limit: Int, maximum: Int)
    /// A resolution named a passage that was never indexed.
    case unknownPassage(passageID: String)
    /// A stored row no longer describes itself, so it cannot be evidence.
    case inconsistentRow(passageID: String, reason: String)

    public var kind: String {
        switch self {
        case .unavailable: "unavailable"
        case .invalidPolicy: "invalid_policy"
        case .invalidSnapshot: "invalid_snapshot"
        case .invalidPassage: "invalid_passage"
        case .emptyQuery: "empty_query"
        case .invalidLimit: "invalid_limit"
        case .limitExceedsPolicy: "limit_exceeds_policy"
        case .unknownPassage: "unknown_passage"
        case .inconsistentRow: "inconsistent_row"
        }
    }

    public var reason: String {
        switch self {
        case let .unavailable(reason):
            "the lexical index is unavailable: \(reason)"
        case let .invalidPolicy(reason):
            "the lexical query policy is unusable: \(reason)"
        case let .invalidSnapshot(reason):
            "the snapshot cannot be indexed: \(reason)"
        case let .invalidPassage(passageID, reason):
            "passage \(passageID) cannot be indexed: \(reason)"
        case .emptyQuery:
            "a query with no retrievable term cannot retrieve anything"
        case let .invalidLimit(limit):
            "a result limit of \(limit) is not a positive number"
        case let .limitExceedsPolicy(limit, maximum):
            "a result limit of \(limit) exceeds the policy maximum of \(maximum)"
        case let .unknownPassage(passageID):
            "no passage \(passageID) is indexed"
        case let .inconsistentRow(passageID, reason):
            "the stored row for passage \(passageID) does not describe itself: \(reason)"
        }
    }

    public var errorDescription: String? { reason }
}

// MARK: - Typed outcomes

/// What happened when a snapshot was offered to the index.
///
/// The index is keyed by passage identity, which is content-addressed, so a
/// repeat offer is a different fact from a first one: it stores nothing and
/// rewrites nothing.
public enum LexicalIngestOutcome: Equatable, Sendable {
    case indexed(snapshotID: String, passageCount: Int)
    case duplicate(snapshotID: String, passageCount: Int)

    public var kind: String {
        switch self {
        case .indexed: "indexed"
        case .duplicate: "duplicate"
        }
    }

    public var snapshotID: String {
        switch self {
        case let .indexed(snapshotID, _), let .duplicate(snapshotID, _): snapshotID
        }
    }

    public var passageCount: Int {
        switch self {
        case let .indexed(_, passageCount), let .duplicate(_, passageCount): passageCount
        }
    }
}

/// One ranked passage. There is deliberately no snippet field: the only thing a
/// search can return is a passage that already exists in a stored snapshot.
public struct IndexedHit: Equatable, Sendable {
    public let passage: Passage
    public let sourceID: String
    public let score: Double
    /// 1-based position in the ordered result this hit was returned in.
    public let rank: Int

    public init(passage: Passage, sourceID: String, score: Double, rank: Int) {
        self.passage = passage
        self.sourceID = sourceID
        self.score = score
        self.rank = rank
    }
}

/// A passage and its source, resolved from the index rather than from a hit.
public struct IndexedEvidence: Equatable, Sendable {
    public let passage: Passage
    public let sourceID: String

    public init(passage: Passage, sourceID: String) {
        self.passage = passage
        self.sourceID = sourceID
    }
}

// MARK: - Index

/// A local SQLite FTS5 index over stored passages, ranked with BM25 and
/// deterministic source features.
///
/// The index is a derived artifact: the snapshot store stays the source of
/// truth, and the only unit that can be indexed or retrieved is a stored
/// `Passage`, never a search snippet. Ingest and query both fail closed with a
/// typed outcome, and ranking is fully specified so identical input produces an
/// identical ordered result.
///
/// - The `passage_index` virtual table indexes exactly two columns, `heading`
///   and `text`. Every identity column is `UNINDEXED`, which also keeps the
///   `bm25()` weight list to the two indexed columns in declaration order.
/// - Scoring is `bm25(passage_index, headingWeight, bodyWeight)`, so a heading
///   match ranks above a body match by the recorded policy.
/// - Ties are broken by ascending passage ordinal, then ascending passage id.
///   The rule is applied in SQL and again in the selection pass, so the order
///   never depends on SQLite's row order.
/// - Diversity is a bound as well as a feature: at most
///   `maximumPassagesPerSource` passages from one source may appear, applied
///   deterministically over the ranked candidates.
public actor LexicalIndex {
    /// Owns the SQLite handle and closes it when the index is released. The
    /// actor never shares the handle, so the unchecked conformance only records
    /// a fact the isolation already enforces.
    private final class SQLiteConnection: @unchecked Sendable {
        let handle: OpaquePointer

        init(handle: OpaquePointer) {
            self.handle = handle
        }

        deinit {
            sqlite3_close(handle)
        }
    }

    private let database: SQLiteConnection
    public let policy: LexicalQueryPolicy

    public init(policy: LexicalQueryPolicy = .default) throws {
        self.policy = policy
        self.database = try Self.open(path: ":memory:")
    }

    /// Opens a durable index at `databasePath`. The schema is created if it is
    /// not already present, so reopening an existing index keeps its rows.
    public init(databasePath: String, policy: LexicalQueryPolicy = .default) throws {
        guard !databasePath.isEmpty else {
            throw LexicalIndexError.unavailable(reason: "the database path is empty")
        }
        self.policy = policy
        self.database = try Self.open(path: databasePath)
    }

    // MARK: Ingest

    /// Indexes a stored snapshot's passages, or reports that it is already
    /// indexed.
    ///
    /// The record is re-derived before it is trusted, exactly as the snapshot
    /// store does: a caller cannot hand in a passage whose identity does not
    /// follow from its snapshot, ordinal and text.
    @discardableResult
    public func ingest(_ record: SnapshotRecord) throws -> LexicalIngestOutcome {
        try Self.validate(record)
        let connection = database.handle

        if try scalarInt(connection, "SELECT count(*) FROM passage_index WHERE snapshot_id = ?", record.snapshot.id) > 0 {
            return .duplicate(snapshotID: record.snapshot.id, passageCount: record.passages.count)
        }

        try execute(connection, "BEGIN IMMEDIATE")
        do {
            for passage in record.passages {
                try insert(passage, sourceID: record.snapshot.sourceID, into: connection)
            }
            try execute(connection, "COMMIT")
        } catch {
            try? execute(connection, "ROLLBACK")
            throw error
        }
        return .indexed(snapshotID: record.snapshot.id, passageCount: record.passages.count)
    }

    // MARK: Query

    /// Returns the ranked passages that match `query`.
    ///
    /// `query` is reduced to its alphanumeric terms and each term is quoted, so
    /// a query is data and never FTS5 syntax. A query with no term is refused.
    public func search(_ query: String, limit: Int? = nil) throws -> [IndexedHit] {
        let effectiveLimit = limit ?? policy.maximumResults
        guard effectiveLimit >= 1 else {
            throw LexicalIndexError.invalidLimit(limit: effectiveLimit)
        }
        guard effectiveLimit <= policy.maximumResults else {
            throw LexicalIndexError.limitExceedsPolicy(
                limit: effectiveLimit,
                maximum: policy.maximumResults
            )
        }
        let match = try Self.matchExpression(for: query)
        let connection = database.handle

        let candidates = try rankedCandidates(match: match, connection: connection)

        var selected: [IndexedHit] = []
        var perSource: [String: Int] = [:]
        for candidate in candidates {
            if selected.count >= effectiveLimit { break }
            let used = perSource[candidate.sourceID, default: 0]
            if used >= policy.maximumPassagesPerSource { continue }
            perSource[candidate.sourceID] = used + 1
            selected.append(
                IndexedHit(
                    passage: candidate.passage,
                    sourceID: candidate.sourceID,
                    score: candidate.score,
                    rank: selected.count + 1
                )
            )
        }
        return selected
    }

    /// Resolves a passage id to the exact stored passage and its source, or
    /// refuses. This is the only path from the index to evidence, and it
    /// re-derives the passage's identity from the stored row.
    public func resolve(_ passageID: String) throws -> IndexedEvidence {
        let connection = database.handle
        let statement = try prepare(connection, Self.selectOneSQL)
        defer { sqlite3_finalize(statement) }
        bind(statement, 1, passageID)
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw LexicalIndexError.unknownPassage(passageID: passageID)
        }
        let hit = try rowHit(statement)
        return IndexedEvidence(passage: hit.passage, sourceID: hit.sourceID)
    }

    public func passageCount() throws -> Int {
        try scalarInt(database.handle, "SELECT count(*) FROM passage_index", nil)
    }

    /// Every indexed snapshot id, ordered, so two runs describe themselves
    /// identically.
    public func indexedSnapshotIDs() throws -> [String] {
        let connection = database.handle
        let statement = try prepare(connection, "SELECT DISTINCT snapshot_id FROM passage_index ORDER BY snapshot_id ASC")
        defer { sqlite3_finalize(statement) }
        var ids: [String] = []
        while true {
            let code = sqlite3_step(statement)
            if code == SQLITE_DONE { break }
            guard code == SQLITE_ROW else {
                throw LexicalIndexError.unavailable(reason: String(cString: sqlite3_errmsg(connection)))
            }
            ids.append(text(statement, 0))
        }
        return ids
    }

    // MARK: Ranking

    private func rankedCandidates(match: String, connection: OpaquePointer) throws -> [IndexedHit] {
        let statement = try prepare(connection, Self.searchSQL)
        defer { sqlite3_finalize(statement) }
        // The placeholder order is fixed by `searchSQL`: the two bm25 weights,
        // then the match expression, then the candidate ceiling.
        bindDouble(statement, 1, policy.headingWeight)
        bindDouble(statement, 2, policy.bodyWeight)
        bind(statement, 3, match)
        bindInt(statement, 4, policy.maximumCandidates)

        var hits: [IndexedHit] = []
        while true {
            let code = sqlite3_step(statement)
            if code == SQLITE_DONE { break }
            guard code == SQLITE_ROW else {
                throw LexicalIndexError.unavailable(reason: String(cString: sqlite3_errmsg(connection)))
            }
            hits.append(try rowHit(statement))
        }
        return hits
    }

    // MARK: SQLite plumbing

    private static let schema = """
    CREATE VIRTUAL TABLE IF NOT EXISTS passage_index USING fts5(
        heading,
        text,
        passage_id UNINDEXED,
        snapshot_id UNINDEXED,
        source_id UNINDEXED,
        ordinal UNINDEXED,
        text_hash UNINDEXED
    );
    """

    private static let insertSQL = """
    INSERT INTO passage_index (heading, text, passage_id, snapshot_id, source_id, ordinal, text_hash)
    VALUES (?, ?, ?, ?, ?, ?, ?)
    """

    /// The SELECT column order is fixed: `rowHit` reads by position.
    private static let selectColumns = """
    passage_id, snapshot_id, source_id, ordinal, text_hash, heading, text
    """

    private static let searchSQL = """
    SELECT \(selectColumns), bm25(passage_index, ?, ?) AS score
    FROM passage_index
    WHERE passage_index MATCH ?
    ORDER BY score ASC, CAST(ordinal AS INTEGER) ASC, passage_id ASC
    LIMIT ?
    """

    private static let selectOneSQL = """
    SELECT \(selectColumns), 0.0 AS score
    FROM passage_index
    WHERE passage_id = ?
    LIMIT 1
    """

    private static func open(path: String) throws -> SQLiteConnection {
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(path, &handle, flags, nil) == SQLITE_OK, let handle else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "the database could not be opened"
            if let handle { sqlite3_close(handle) }
            throw LexicalIndexError.unavailable(reason: message)
        }
        guard sqlite3_exec(handle, schema, nil, nil, nil) == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(handle))
            sqlite3_close(handle)
            throw LexicalIndexError.unavailable(
                reason: "the FTS5 passage index could not be created; FTS5 may not be compiled into this SQLite: \(message)"
            )
        }
        return SQLiteConnection(handle: handle)
    }

    private func execute(_ db: OpaquePointer, _ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw LexicalIndexError.unavailable(reason: String(cString: sqlite3_errmsg(db)))
        }
    }

    private func prepare(_ db: OpaquePointer, _ sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw LexicalIndexError.unavailable(reason: String(cString: sqlite3_errmsg(db)))
        }
        return statement
    }

    private func insert(_ passage: Passage, sourceID: String, into db: OpaquePointer) throws {
        let statement = try prepare(db, Self.insertSQL)
        defer { sqlite3_finalize(statement) }
        bind(statement, 1, passage.heading)
        bind(statement, 2, passage.text)
        bind(statement, 3, passage.id)
        bind(statement, 4, passage.snapshotID)
        bind(statement, 5, sourceID)
        bind(statement, 6, String(passage.ordinal))
        bind(statement, 7, passage.textHash)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw LexicalIndexError.unavailable(reason: String(cString: sqlite3_errmsg(db)))
        }
    }

    private func scalarInt(_ db: OpaquePointer, _ sql: String, _ argument: String?) throws -> Int {
        let statement = try prepare(db, sql)
        defer { sqlite3_finalize(statement) }
        if let argument { bind(statement, 1, argument) }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw LexicalIndexError.unavailable(reason: String(cString: sqlite3_errmsg(db)))
        }
        return Int(sqlite3_column_int64(statement, 0))
    }

    private func rowHit(_ statement: OpaquePointer) throws -> IndexedHit {
        let passageID = text(statement, 0)
        let snapshotID = text(statement, 1)
        let sourceID = text(statement, 2)
        let ordinalText = text(statement, 3)
        let textHash = text(statement, 4)
        let heading = text(statement, 5)
        let body = text(statement, 6)
        let score = sqlite3_column_double(statement, 7)

        guard let ordinal = Int(ordinalText) else {
            throw LexicalIndexError.inconsistentRow(
                passageID: passageID,
                reason: "the stored ordinal \(ordinalText) is not an integer"
            )
        }
        let passage = Passage(
            id: passageID,
            snapshotID: snapshotID,
            ordinal: ordinal,
            heading: heading,
            text: body,
            textHash: textHash
        )
        try Self.validate(passage: passage)
        return IndexedHit(passage: passage, sourceID: sourceID, score: score, rank: 0)
    }

    private func text(_ statement: OpaquePointer, _ index: Int32) -> String {
        guard let value = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: value)
    }

    private func bind(_ statement: OpaquePointer, _ index: Int32, _ value: String) {
        sqlite3_bind_text(statement, index, value, -1, Self.transient)
    }

    private func bindInt(_ statement: OpaquePointer, _ index: Int32, _ value: Int) {
        // Bind 64-bit so a policy value at the top of `Int` cannot trap in a
        // narrowing conversion or silently become SQLite's "no limit" -1.
        sqlite3_bind_int64(statement, index, sqlite3_int64(value))
    }

    private func bindDouble(_ statement: OpaquePointer, _ index: Int32, _ value: Double) {
        sqlite3_bind_double(statement, index, value)
    }

    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    // MARK: Identity and query construction

    /// Reduces a query to its alphanumeric terms and joins them with `AND`.
    ///
    /// Each term is quoted, so the result cannot become FTS5 syntax. A query
    /// with no term is refused rather than silently matching nothing.
    static func matchExpression(for query: String) throws -> String {
        var terms: [String] = []
        var current = ""
        for character in query {
            if character.isLetter || character.isNumber {
                current.append(character)
            } else if !current.isEmpty {
                terms.append(current)
                current = ""
            }
        }
        if !current.isEmpty { terms.append(current) }
        guard !terms.isEmpty else { throw LexicalIndexError.emptyQuery }
        return terms.map { "\"\($0)\"" }.joined(separator: " AND ")
    }

    static func validate(_ record: SnapshotRecord) throws {
        guard !record.snapshot.id.isEmpty else {
            throw LexicalIndexError.invalidSnapshot(reason: "the snapshot has no identity")
        }
        guard !record.passages.isEmpty else {
            throw LexicalIndexError.invalidSnapshot(reason: "the snapshot has no passages to index")
        }
        guard record.snapshot.contentHash == StableIdentity.digest(record.snapshot.extractedText) else {
            throw LexicalIndexError.invalidSnapshot(reason: "the snapshot content hash does not match its extracted text")
        }
        guard record.snapshot.id == StableIdentity.make(
            "snapshot",
            record.snapshot.sourceID,
            record.snapshot.contentHash
        ) else {
            throw LexicalIndexError.invalidSnapshot(reason: "the snapshot id does not follow from its source and content hash")
        }
        guard record.passages.map(\.text).joined(separator: "\n\n") == record.snapshot.extractedText else {
            throw LexicalIndexError.invalidSnapshot(reason: "the extracted text is not the passages joined in order")
        }
        for (ordinal, passage) in record.passages.enumerated() {
            guard passage.ordinal == ordinal else {
                throw LexicalIndexError.invalidPassage(
                    passageID: passage.id,
                    reason: "passage ordinals must run from zero without gaps"
                )
            }
            try validate(passage: passage)
        }
    }

    static func validate(passage: Passage) throws {
        guard !passage.id.isEmpty else {
            throw LexicalIndexError.invalidPassage(passageID: passage.id, reason: "the passage has no identity")
        }
        guard !passage.snapshotID.isEmpty else {
            throw LexicalIndexError.invalidPassage(passageID: passage.id, reason: "the passage names no snapshot")
        }
        guard passage.textHash == StableIdentity.digest(passage.text) else {
            throw LexicalIndexError.invalidPassage(passageID: passage.id, reason: "the passage text hash does not match its text")
        }
        guard passage.id == StableIdentity.make(
            "passage",
            passage.snapshotID,
            String(passage.ordinal),
            passage.textHash
        ) else {
            throw LexicalIndexError.invalidPassage(
                passageID: passage.id,
                reason: "the passage id does not follow from its snapshot, ordinal and text hash"
            )
        }
    }
}
