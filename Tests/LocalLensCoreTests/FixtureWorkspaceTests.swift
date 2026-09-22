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
}
