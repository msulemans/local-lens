import XCTest
@testable import LocalLensCore

final class LocalLensCoreTests: XCTestCase {
    func testStableIdentityIsDeterministicAndOrderSensitive() {
        let first = StableIdentity.make("claim", "alpha", "beta")
        let repeated = StableIdentity.make("claim", "alpha", "beta")
        let reordered = StableIdentity.make("claim", "beta", "alpha")

        XCTAssertEqual(first, repeated)
        XCTAssertNotEqual(first, reordered)
        XCTAssertEqual(first.count, 20)
    }

    func testLegalTransitionIsRecorded() async throws {
        let run = ResearchRun(id: "run-1", question: "Why?", mode: .quick)
        let machine = RunStateMachine(run: run)

        try await machine.transition(to: .scoped, message: "Scope fixed")

        let current = await machine.run
        let events = await machine.events
        XCTAssertEqual(current.status, .scoped)
        XCTAssertEqual(events.map(\.sequence), [0, 1])
        XCTAssertEqual(events.last?.message, "Scope fixed")
    }

    func testIllegalTransitionFailsClosed() async {
        let run = ResearchRun(id: "run-1", question: "Why?", mode: .quick)
        let machine = RunStateMachine(run: run)

        do {
            try await machine.transition(to: .complete, message: "Skip ahead")
            XCTFail("Expected the state machine to reject an illegal transition")
        } catch {
            XCTAssertEqual(
                error as? RunStateError,
                .illegalTransition(from: .created, to: .complete)
            )
        }
    }

    func testCancellationIsTerminal() async throws {
        let run = ResearchRun(id: "run-1", question: "Why?", mode: .quick)
        let machine = RunStateMachine(run: run)

        try await machine.cancel(reason: "User stopped")

        let cancelled = await machine.run
        XCTAssertEqual(cancelled.status, .cancelled)
        XCTAssertEqual(cancelled.stopReason, "User stopped")

        do {
            try await machine.transition(to: .scoped, message: "Too late")
            XCTFail("Expected a terminal-state error")
        } catch {
            XCTAssertEqual(error as? RunStateError, .terminalState(.cancelled))
        }
    }
}
