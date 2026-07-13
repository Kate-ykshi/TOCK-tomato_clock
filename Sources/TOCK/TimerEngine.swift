struct TimerEngineState: Equatable {
    var phase: TimerSessionPhase
    var remainingSeconds: Int
    var elapsedFocusSeconds: Int
    var overtimeSeconds: Int
}

enum TimerEngineEvent: Equatable {
    case focusFinished
    case breakFinished
}

struct TimerEngineResult: Equatable {
    var state: TimerEngineState
    var events: [TimerEngineEvent]
}

enum TimerEngine {
    static func advance(_ state: TimerEngineState, by deltaSeconds: Int) -> TimerEngineResult {
        guard deltaSeconds > 0 else {
            return TimerEngineResult(state: state, events: [])
        }

        var nextState = state
        var events: [TimerEngineEvent] = []

        switch state.phase {
        case .focusCountdown:
            nextState.elapsedFocusSeconds += deltaSeconds
            nextState.remainingSeconds = max(0, state.remainingSeconds - deltaSeconds)

            if state.remainingSeconds > 0 && nextState.remainingSeconds == 0 {
                nextState.phase = .focusOvertime
                nextState.overtimeSeconds = max(0, deltaSeconds - state.remainingSeconds)
                events.append(.focusFinished)
            }
        case .focusCountup:
            nextState.elapsedFocusSeconds += deltaSeconds
        case .focusOvertime:
            nextState.elapsedFocusSeconds += deltaSeconds
            nextState.overtimeSeconds += deltaSeconds
        case .breakCountdown:
            nextState.remainingSeconds = max(0, state.remainingSeconds - deltaSeconds)

            if state.remainingSeconds > 0 && nextState.remainingSeconds == 0 {
                nextState.phase = .breakFinished
                events.append(.breakFinished)
            }
        case .idle, .breakFinished:
            break
        }

        return TimerEngineResult(state: nextState, events: events)
    }
}
