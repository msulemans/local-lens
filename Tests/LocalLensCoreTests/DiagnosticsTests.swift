import Foundation
import XCTest
@testable import LocalLensCore

final class DiagnosticsTests: XCTestCase {
    private func report() -> DiagnosticsReport {
        DiagnosticsReport(
            appVersion: "1.0.0",
            appBuild: "9",
            protocolVersion: ProtocolVersion.v1,
            operatingSystem: "macOS 27.0",
            architecture: "arm64",
            generatedAt: "2026-09-26T00:00:00Z",
            storage: .init(historyEntries: 3, snapshots: 12, passages: 24, bytesOnDisk: 4096),
            settings: .init(
                mode: "Academic",
                searchBackend: "tavily",
                usesLocalProvider: true,
                localEndpointHost: DiagnosticsReport.hostOnly("http://127.0.0.1:11434/v1"),
                localModel: "qwen2.5-coder:14b-instruct-q4_K_M",
                reasoningEffort: nil,
                hasHostedKey: false,
                hasSearchKey: true
            ),
            recentFailures: [
                .init(runIdentifier: "a1b2c3d4e5f6", mode: "News", reason: "no openable search hits", at: "2026-09-26T00:00:00Z")
            ]
        )
    }

    func testDiagnosticsCarryCountsAndNeverResearchContent() throws {
        let data = try report().json()
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        let lowered = text.lowercased()

        // A loopback endpoint is reported by host only, without its path.
        XCTAssertEqual(DiagnosticsReport.hostOnly("https://api.example.com/v1/search?q=secret&key=abc"), "api.example.com")
        XCTAssertEqual(DiagnosticsReport.hostOnly("not a url"), "")
        XCTAssertTrue(text.contains("127.0.0.1"))

        // Nothing that could carry a question, an answer, a quote, or a
        // credential is present as a field or a value.
        XCTAssertFalse(lowered.contains("q=secret"))
        XCTAssertFalse(lowered.contains("key=abc"))
        for marker in DiagnosticsReport.forbiddenMarkers {
            XCTAssertFalse(lowered.contains("\"\(marker)"), "the bundle exposes a \(marker) field")
        }

        // And it round-trips.
        let decoded = try JSONDecoder().decode(DiagnosticsReport.self, from: data)
        XCTAssertEqual(decoded, report())
    }
}
