import Foundation
import XCTest
@testable import LocalLensCore

final class ProtocolEnvelopeTests: XCTestCase {

    private func json(_ string: String) -> Data {
        Data(string.utf8)
    }

    private func assertDecodingFails<T: Decodable>(_ type: T.Type, _ data: Data) {
        XCTAssertThrowsError(try JSONDecoder().decode(type, from: data)) { error in
            guard let decodingError = error as? DecodingError, case .dataCorrupted = decodingError else {
                return XCTFail("expected dataCorrupted, got \(error)")
            }
        }
    }

    func testStartRunCommandDecodesAndRoundTrips() throws {
        let data = json(#"{"schema_version":"1.0.0","command":"start_run","run_id":"run-1","question":"Why is the sky blue?","mode":"Quick"}"#)
        let command = try JSONDecoder().decode(ResearchCommand.self, from: data)
        XCTAssertEqual(command, .startRun(runID: "run-1", question: "Why is the sky blue?", mode: .quick))

        let encoded = try JSONEncoder().encode(command)
        XCTAssertEqual(try JSONDecoder().decode(ResearchCommand.self, from: encoded), command)
    }

    func testCancelRunKeepsReasonOptional() throws {
        let withReason = try JSONDecoder().decode(
            ResearchCommand.self,
            from: json(#"{"schema_version":"1.0.0","command":"cancel_run","run_id":"run-1","reason":"User stopped"}"#)
        )
        XCTAssertEqual(withReason, .cancelRun(runID: "run-1", reason: "User stopped"))

        let withoutReason = try JSONDecoder().decode(
            ResearchCommand.self,
            from: json(#"{"schema_version":"1.0.0","command":"cancel_run","run_id":"run-1"}"#)
        )
        XCTAssertEqual(withoutReason, .cancelRun(runID: "run-1", reason: nil))
    }

    func testCommandUnknownFieldFailsClosed() {
        let data = json(#"{"schema_version":"1.0.0","command":"start_run","run_id":"run-1","question":"Why?","mode":"Quick","extra":true}"#)
        assertDecodingFails(ResearchCommand.self, data)
    }

    func testUnsupportedVersionFailsClosed() {
        let data = json(#"{"schema_version":"2.0.0","command":"start_run","run_id":"run-1","question":"Why?","mode":"Quick"}"#)
        XCTAssertThrowsError(try JSONDecoder().decode(ResearchCommand.self, from: data)) { error in
            XCTAssertEqual(error as? ProtocolError, .unsupportedVersion("2.0.0"))
        }
    }

    func testUnknownCommandFailsClosed() {
        let data = json(#"{"schema_version":"1.0.0","command":"drop_tables"}"#)
        XCTAssertThrowsError(try JSONDecoder().decode(ResearchCommand.self, from: data)) { error in
            XCTAssertEqual(error as? ProtocolError, .unknownCommand("drop_tables"))
        }
    }

    func testEventEnvelopeRoundTripsAndRejectsUnknownKind() throws {
        let envelope = EventEnvelope(runID: "run-1", event: RunEvent(sequence: 3, status: .searching, message: "Searching"))
        let data = try JSONEncoder().encode(envelope)
        XCTAssertEqual(try JSONDecoder().decode(EventEnvelope.self, from: data), envelope)

        let badKind = json(#"{"schema_version":"1.0.0","kind":"other_event","run_id":"run-1","event":{"sequence":0,"status":"created","message":"x"}}"#)
        XCTAssertThrowsError(try JSONDecoder().decode(EventEnvelope.self, from: badKind)) { error in
            XCTAssertEqual(error as? ProtocolError, .unknownEventKind("other_event"))
        }
    }

    func testErrorEnvelopeRoundTripsAndRejectsUnknownCode() throws {
        let envelope = ErrorEnvelope(code: .integrityFailure, message: "Quote mismatch", runID: "run-1")
        let data = try JSONEncoder().encode(envelope)
        XCTAssertEqual(try JSONDecoder().decode(ErrorEnvelope.self, from: data), envelope)

        XCTAssertEqual(
            Set(ErrorCode.allCases.map(\.rawValue)),
            ["illegal_transition", "terminal_state", "unknown_field", "unsupported_schema_version", "invalid_reference", "integrity_failure"]
        )

        let badCode = json(#"{"schema_version":"1.0.0","code":"made_up","message":"x"}"#)
        XCTAssertThrowsError(try JSONDecoder().decode(ErrorEnvelope.self, from: badCode)) { error in
            XCTAssertEqual(error as? ProtocolError, .unknownErrorCode("made_up"))
        }
    }

    func testTypedStopTransitionIsReachableAndTerminal() async throws {
        let machine = RunStateMachine(run: ResearchRun(id: "run-1", question: "Why?", mode: .quick))
        try await machine.transition(to: .scoped, message: "Scope fixed")

        try await machine.fail(reason: "Fetcher failed")
        let failed = await machine.run
        XCTAssertEqual(failed.status, .failed)
        XCTAssertEqual(failed.stopReason, "Fetcher failed")

        do {
            try await machine.transition(to: .rewriting, message: "Too late")
            XCTFail("expected terminalState")
        } catch let error as RunStateError {
            XCTAssertEqual(error, .terminalState(.failed))
        }
    }

    func testBudgetAndInputStopsAreTyped() async throws {
        let budgetMachine = RunStateMachine(run: ResearchRun(id: "run-2", question: "Why?", mode: .quick))
        try await budgetMachine.transition(to: .scoped, message: "Scope fixed")
        try await budgetMachine.exhaustBudget(reason: "Wall deadline reached")
        let budget = await budgetMachine.run
        XCTAssertEqual(budget.status, .budgetExhausted)
        XCTAssertEqual(budget.stopReason, "Wall deadline reached")

        let inputMachine = RunStateMachine(run: ResearchRun(id: "run-3", question: "Why?", mode: .quick))
        try await inputMachine.transition(to: .scoped, message: "Scope fixed")
        try await inputMachine.requestUserInput(reason: "Ambiguous question")
        let input = await inputMachine.run
        XCTAssertEqual(input.status, .needsUserInput)
        XCTAssertEqual(input.stopReason, "Ambiguous question")
    }

    func testGenericTransitionCannotReachStopStates() async {
        let machine = RunStateMachine(run: ResearchRun(id: "run-4", question: "Why?", mode: .quick))
        do {
            try await machine.transition(to: .failed, message: "Sneaky")
            XCTFail("expected illegalTransition")
        } catch let error as RunStateError {
            XCTAssertEqual(error, .illegalTransition(from: .created, to: .failed))
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}
