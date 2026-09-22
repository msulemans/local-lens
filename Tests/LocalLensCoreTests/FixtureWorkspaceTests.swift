import Foundation
import XCTest
@testable import LocalLensCore

final class FixtureWorkspaceTests: XCTestCase {

    private var fixtureURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/deterministic/quick-coffee.json")
    }

    private func runFixture() async throws -> PersistedRun {
        let corpus = try FixtureWorkspace.loadFixture(from: fixtureURL)
        return try await DeterministicPipeline.run(corpus)
    }

    func testInspectionsResolveEveryCitationToPassageAndSource() async throws {
        let persisted = try await runFixture()
        let inspections = try FixtureWorkspace.inspections(in: persisted.result)

        XCTAssertEqual(inspections.count, persisted.result.citations.count)
        XCTAssertFalse(inspections.isEmpty)
        for inspection in inspections {
            XCTAssertEqual(persisted.result.passage(for: inspection.citation.id)?.id, inspection.passage.id)
            let link = try XCTUnwrap(
                persisted.result.evidenceLinks.first { inspection.citation.evidenceLinkIDs.contains($0.id) }
            )
            XCTAssertTrue(inspection.passage.text.contains(link.quote))
            XCTAssertFalse(inspection.source.title.isEmpty)
            XCTAssertFalse(inspection.claim.text.isEmpty)
        }
    }

    func testUnknownCitationFailsClosed() async throws {
        let persisted = try await runFixture()

        XCTAssertThrowsError(try FixtureWorkspace.inspection(for: "missing-citation", in: persisted.result)) { error in
            XCTAssertEqual(error as? IntegrityError, .unknownReference(kind: "citation", id: "missing-citation"))
        }
    }

    func testEvidenceMapBuildsOneNodePerCitationWithRelationAndSource() async throws {
        let persisted = try await runFixture()
        let map = try FixtureWorkspace.evidenceMap(in: persisted.result)

        XCTAssertEqual(map.question, persisted.result.run.question)
        XCTAssertEqual(map.nodes.count, persisted.result.citations.count)
        XCTAssertEqual(Set(map.nodes.map(\.relation)), [.supports])
        XCTAssertEqual(map.sources.count, Set(map.nodes.map(\.source.id)).count)
        for node in map.nodes {
            XCTAssertEqual(persisted.result.passage(for: node.citationID)?.id, node.passage.id)
            let link = try XCTUnwrap(persisted.result.evidenceLinks.first { $0.claimID == node.claim.id })
            XCTAssertTrue(node.passage.text.contains(link.quote))
            XCTAssertFalse(node.source.title.isEmpty)
        }
    }

    func testMapNodeSelectionResolvesToTheSamePassageAsInspection() async throws {
        let persisted = try await runFixture()
        let map = try FixtureWorkspace.evidenceMap(in: persisted.result)
        let node = try XCTUnwrap(map.nodes.first)

        let inspection = try FixtureWorkspace.inspection(for: node.citationID, in: persisted.result)
        XCTAssertEqual(inspection.passage.id, node.passage.id)
        XCTAssertEqual(inspection.source.id, node.source.id)
        XCTAssertEqual(inspection.claim.id, node.id)
    }
}
