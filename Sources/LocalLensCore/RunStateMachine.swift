import Foundation

public enum RunStateError: Error, Equatable, LocalizedError {
    case illegalTransition(from: RunStatus, to: RunStatus)
    case terminalState(RunStatus)

    public var errorDescription: String? {
        switch self {
        case let .illegalTransition(from, to):
            "Illegal run transition from \(from.rawValue) to \(to.rawValue)."
        case let .terminalState(status):
            "Run is already terminal in \(status.rawValue)."
        }
    }
}

public actor RunStateMachine {
    private(set) public var run: ResearchRun
    private(set) public var events: [RunEvent]

    private static let allowed: [RunStatus: Set<RunStatus>] = [
        .created: [.scoped],
        .scoped: [.rewriting],
        .rewriting: [.searching],
        .searching: [.acquiring],
        .acquiring: [.extracting],
        .extracting: [.retrieving],
        .retrieving: [.buildingEvidence],
        .buildingEvidence: [.drafting],
        .drafting: [.validating],
        .validating: [.complete]
    ]

    public init(run: ResearchRun) {
        self.run = run
        self.events = [RunEvent(sequence: 0, status: .created, message: "Run created")]
    }

    public func transition(to next: RunStatus, message: String) throws {
        guard !run.status.isTerminal else { throw RunStateError.terminalState(run.status) }
        guard Self.allowed[run.status, default: []].contains(next) else {
            throw RunStateError.illegalTransition(from: run.status, to: next)
        }
        run.status = next
        events.append(RunEvent(sequence: events.count, status: next, message: message))
    }

    public func cancel(reason: String = "Cancelled by user") throws {
        guard !run.status.isTerminal else { throw RunStateError.terminalState(run.status) }
        run.status = .cancelled
        run.stopReason = reason
        events.append(RunEvent(sequence: events.count, status: .cancelled, message: reason))
    }

    /// Typed stop paths. These are deliberately not reachable through
    /// `transition(to:)`; each records its reason and ends the run.
    public func fail(reason: String) throws {
        try stop(at: .failed, reason: reason)
    }

    public func exhaustBudget(reason: String) throws {
        try stop(at: .budgetExhausted, reason: reason)
    }

    public func requestUserInput(reason: String) throws {
        try stop(at: .needsUserInput, reason: reason)
    }

    private func stop(at status: RunStatus, reason: String) throws {
        guard !run.status.isTerminal else { throw RunStateError.terminalState(run.status) }
        run.status = status
        run.stopReason = reason
        events.append(RunEvent(sequence: events.count, status: status, message: reason))
    }
}
