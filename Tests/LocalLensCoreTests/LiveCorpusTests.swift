import Foundation
import XCTest

@testable import LocalLensCore

/// The approved live corpus harness.
///
/// The tests in this file never fetch anything. They prove the harness cannot:
/// it takes no transport, it holds no network primitive, and its approval gate
/// refuses to plan a run while any entry lacks a recorded licence or a recorded
/// owner approval.
final class LiveCorpusTests: XCTestCase {

    // MARK: The shipped manifest

    func testShippedManifestShipsEmptyAndRefusesToRun() throws {
        let data = try Data(contentsOf: Self.corpusFixtureURL)
        let manifest = try CorpusManifest.decode(data)

        XCTAssertEqual(manifest.id, "live-corpus-v1")
        XCTAssertEqual(
            manifest.entries.count,
            0,
            "a corpus entry claims that a page may be fetched and that its licence permits it; no such claim has been approved"
        )
        XCTAssertEqual(
            LiveCorpus.plan(manifest),
            .refused(.noEntries),
            "an empty corpus proves nothing, so it must refuse rather than report a pass"
        )

        // The blocker is recorded in the artifact itself, so deleting it is a
        // visible edit rather than a silent one.
        let raw = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: data) as? [String: Any],
            "the fixture must be a JSON object"
        )
        let note = try XCTUnwrap(
            (raw["_fixture"] as? [String: Any])?["why_empty"] as? String,
            "the fixture must record why it ships empty"
        )
        XCTAssertTrue(note.contains("licence"), "the note must name the licence requirement")
        XCTAssertTrue(note.contains("owner approval"), "the note must name the approval requirement")
        let steps = try XCTUnwrap(
            (raw["_fixture"] as? [String: Any])?["to_add_an_entry"] as? [String]
        )
        XCTAssertGreaterThanOrEqual(
            steps.count,
            4,
            "adding the first entry must be a documented, reviewable act"
        )
    }

    // MARK: The approval gate

    func testPlanRefusesWhileAnyEntryLacksAnApproval() throws {
        let manifest = try CorpusManifest.decode(
            Data(Self.manifestJSON(entries: [
                Self.entryJSON(id: "approved-entry", approval: #"{"recorded_by": "owner", "reference": "record-1"}"#),
                Self.entryJSON(id: "unapproved-entry"),
            ]).utf8)
        )

        XCTAssertEqual(
            LiveCorpus.plan(manifest),
            .refused(.noApprovedEntries(unapproved: ["unapproved-entry"])),
            "a run that silently skipped an entry would report a pass over a corpus it did not run"
        )
    }

    func testPlanOpensOnlyForAFullyApprovedManifest() throws {
        let manifest = try CorpusManifest.decode(
            Data(Self.manifestJSON(entries: [
                Self.entryJSON(id: "e1", approval: #"{"recorded_by": "owner", "reference": "record-1"}"#),
                Self.entryJSON(id: "e2", approval: #"{"recorded_by": "owner", "reference": "record-2"}"#),
            ]).utf8)
        )

        guard case let .runnable(entries) = LiveCorpus.plan(manifest) else {
            return XCTFail("an approved manifest must plan a run")
        }
        XCTAssertEqual(entries.map { $0.id }, ["e1", "e2"])
        XCTAssertTrue(
            entries.allSatisfy { $0.isApproved },
            "nothing may be planned that carries no approval record"
        )
        XCTAssertEqual(
            LiveCorpus.plan(manifest),
            LiveCorpus.plan(manifest),
            "planning is a pure function of the manifest"
        )
    }

    func testAnUnapprovedEntryIsRefusedByNameAndNotRun() throws {
        let manifest = try CorpusManifest.decode(
            Data(Self.manifestJSON(entries: [Self.entryJSON(id: "lonely")]).utf8)
        )
        guard case let .refused(refusal) = LiveCorpus.plan(manifest) else {
            return XCTFail("an unapproved manifest must refuse")
        }
        XCTAssertEqual(refusal.kind, "no_approved_entries")
        XCTAssertTrue(refusal.reason.contains("lonely"), "the refusal must name the entry it refused")
    }

    // MARK: Structural validation

    func testEntryWithoutALicenceIsRefused() {
        assertDecodeFails(
            Self.manifestJSON(entries: [Self.entryJSON(id: "e1", licence: "")]),
            kind: "unrecorded_licence"
        )
        assertDecodeFails(
            Self.manifestJSON(entries: [Self.entryJSON(id: "e1", licence: nil)]),
            kind: "unrecorded_licence"
        )
    }

    func testEntryWithoutALicenceReferenceIsRefused() {
        assertDecodeFails(
            Self.manifestJSON(entries: [Self.entryJSON(id: "e1", licenceReference: "   ")]),
            kind: "unrecorded_licence_reference"
        )
    }

    func testEntryWithoutAnExpectedOutcomeIsRefused() {
        assertDecodeFails(
            Self.manifestJSON(entries: [Self.entryJSON(id: "e1", expectation: nil)]),
            kind: "missing_expectation"
        )
        assertDecodeFails(
            Self.manifestJSON(entries: [Self.entryJSON(id: "e1", expectation: #"{"outcome": "guessed"}"#)]),
            kind: "unknown_expectation"
        )
    }

    func testEntryWithoutAnIdentifierIsRefused() {
        assertDecodeFails(
            Self.manifestJSON(entries: [Self.entryJSON(id: "  ")]),
            kind: "missing_identifier"
        )
    }

    func testTwoEntriesMayNotShareAnIdentifier() {
        assertDecodeFails(
            Self.manifestJSON(entries: [Self.entryJSON(id: "e1"), Self.entryJSON(id: "e1")]),
            kind: "duplicate_identifier"
        )
    }

    func testAnEntryMustBeReachedOverHTTPS() {
        assertDecodeFails(
            Self.manifestJSON(entries: [Self.entryJSON(id: "e1", url: "http://example.invalid/page")]),
            kind: "insecure_url"
        )
        assertDecodeFails(
            Self.manifestJSON(entries: [Self.entryJSON(id: "e1", url: "not a url")]),
            kind: "insecure_url"
        )
    }

    func testAManifestWithoutAnIdentifierOrWithABrokenBodyIsRefused() throws {
        assertDecodeFails("not json at all", kind: "unreadable_json")
        assertDecodeFails(#"{"id": "m", "entries": "not a list"}"#, kind: "unreadable_json")
        assertDecodeFails(#"{"entries": [{"id": "e1"}]}"#, kind: "missing_manifest_identifier")

        // An empty manifest is a real state - no corpus is approved yet - so it
        // decodes. It is the run gate, not the decoder, that refuses it.
        let empty = try CorpusManifest.decode(Data(#"{"id": "m", "entries": []}"#.utf8))
        XCTAssertEqual(empty.entries.count, 0)
        XCTAssertEqual(LiveCorpus.plan(empty), .refused(.noEntries))
    }

    func testAHalfRecordedApprovalIsRefusedRatherThanTreatedAsApproval() {
        assertDecodeFails(
            Self.manifestJSON(entries: [Self.entryJSON(id: "e1", approval: #"{"recorded_by": "owner"}"#)]),
            kind: "incomplete_approval"
        )
        assertDecodeFails(
            Self.manifestJSON(entries: [Self.entryJSON(id: "e1", approval: #"{"recorded_by": "  ", "reference": "r"}"#)]),
            kind: "incomplete_approval"
        )
    }

    func testManifestRefusalFamilyIsEnumeratedAndTyped() {
        let kinds = [
            CorpusManifestError.unreadableJSON(reason: "r").kind,
            CorpusManifestError.missingManifestIdentifier.kind,
            CorpusManifestError.missingIdentifier(index: 0).kind,
            CorpusManifestError.duplicateIdentifier(id: "i").kind,
            CorpusManifestError.unrecordedLicence(id: "i").kind,
            CorpusManifestError.unrecordedLicenceReference(id: "i").kind,
            CorpusManifestError.missingExpectation(id: "i").kind,
            CorpusManifestError.unknownExpectation(id: "i", value: "v").kind,
            CorpusManifestError.insecureURL(id: "i", url: "u").kind,
            CorpusManifestError.incompleteApproval(id: "i").kind,
        ]
        XCTAssertEqual(
            Set(kinds).count,
            kinds.count,
            "every refusal kind must be distinct, so a kind names one fact"
        )
        XCTAssertEqual(kinds.count, 10, "the manifest refusal family is frozen at ten kinds")
        for kind in kinds {
            XCTAssertEqual(kind, kind.lowercased(), "\(kind) must be a token")
            XCTAssertFalse(kind.contains(" "), "\(kind) must be a token")
        }

        let runKinds = [
            CorpusRunRefusal.noEntries.kind,
            CorpusRunRefusal.noApprovedEntries(unapproved: ["i"]).kind,
        ]
        XCTAssertEqual(
            Set(runKinds).count,
            2,
            "the run refusal family is frozen at two kinds: an empty corpus, and a corpus with an unapproved entry"
        )
    }

    // MARK: Verdicts

    func testVerdictComparesAnObservationAgainstTheFrozenExpectation() {
        XCTAssertEqual(
            LiveCorpus.verdict(
                .extracted(extractorVersion: "html-extractor-1"),
                against: .extracted(extractorVersion: "html-extractor-1")
            ),
            .matches
        )
        XCTAssertEqual(
            LiveCorpus.verdict(
                .refused(stage: .extraction, kind: "no_readable_text"),
                against: .refused(stage: .extraction, kind: "no_readable_text")
            ),
            .matches
        )

        // A corpus whose expectations never fail is not a test, so the mismatch
        // path must be proven too - and it must say what it saw.
        let wrongVersion = LiveCorpus.verdict(
            .extracted(extractorVersion: "html-extractor-2"),
            against: .extracted(extractorVersion: "html-extractor-1")
        )
        guard case let .differs(reason) = wrongVersion else {
            return XCTFail("a different extractor version is a different result")
        }
        XCTAssertTrue(reason.contains("html-extractor-2") && reason.contains("html-extractor-1"))

        let wrongStage = LiveCorpus.verdict(
            .refused(stage: .robots, kind: "published_rule"),
            against: .refused(stage: .extraction, kind: "no_readable_text")
        )
        guard case .differs = wrongStage else {
            return XCTFail("a different boundary is a different result")
        }

        let expectedRefusalObservedPage = LiveCorpus.verdict(
            .extracted(extractorVersion: "html-extractor-1"),
            against: .refused(stage: .extraction, kind: "no_readable_text")
        )
        guard case let .differs(shapeReason) = expectedRefusalObservedPage else {
            return XCTFail("an expected refusal that became a page is a different result")
        }
        XCTAssertTrue(shapeReason.contains("refused"))
    }

    // MARK: The offline guarantee

    func testTheCorpusSourceHoldsNoNetworkPrimitiveNoClockAndNoTransport() throws {
        let source = try String(
            contentsOf: Self.repositoryRoot.appendingPathComponent("Sources/LocalLensCore/LiveCorpus.swift"),
            encoding: .utf8
        )

        // Built by concatenation so this guard does not match its own source.
        let forbidden = [
            "URL" + "Session",
            "System" + "Host" + "Resolver",
            "getaddr" + "info",
            "Task" + ".sleep",
            "Date" + "(",
            "Transport",
            "http" + "Client",
        ]
        for needle in forbidden {
            XCTAssertFalse(
                source.contains(needle),
                "the corpus harness must hold no \(needle); it cannot fetch, so no run can reach the network"
            )
        }
        XCTAssertFalse(
            source.contains("import") && source.contains("Darwin"),
            "the harness needs no system library"
        )
        XCTAssertTrue(
            source.contains("import Foundation"),
            "the harness decodes JSON and nothing else"
        )
    }

    // MARK: Helpers

    private static let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private static var corpusFixtureURL: URL {
        repositoryRoot.appendingPathComponent("Fixtures/corpus/live-corpus.json")
    }

    private func assertDecodeFails(
        _ json: String,
        kind: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        do {
            _ = try CorpusManifest.decode(Data(json.utf8))
            XCTFail("decoding must fail with \(kind)", file: file, line: line)
        } catch let error as CorpusManifestError {
            XCTAssertEqual(error.kind, kind, file: file, line: line)
            XCTAssertFalse(error.reason.isEmpty, "a refusal always says why", file: file, line: line)
        } catch {
            XCTFail("expected a typed CorpusManifestError, got \(error)", file: file, line: line)
        }
    }

    private static func manifestJSON(entries: [String]) -> String {
        #"{"id": "synthetic-manifest", "entries": [\#(entries.joined(separator: ","))]}"#
    }

    private static func entryJSON(
        id: String,
        url: String = "https://example.invalid/page",
        licence: String? = "CC-BY-4.0",
        licenceReference: String? = "https://example.invalid/licence",
        expectation: String? = #"{"outcome": "extracted", "extractor_version": "html-extractor-1"}"#,
        approval: String? = nil
    ) -> String {
        var fields = [#""id": "\#(id)""#, #""url": "\#(url)""#]
        if let licence { fields.append(#""licence": "\#(licence)""#) }
        if let licenceReference { fields.append(#""licence_reference": "\#(licenceReference)""#) }
        if let expectation { fields.append(#""expectation": \#(expectation)"#) }
        if let approval { fields.append(#""approval": \#(approval)"#) }
        return "{\(fields.joined(separator: ", "))}"
    }
}
