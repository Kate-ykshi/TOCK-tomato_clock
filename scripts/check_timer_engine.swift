import Foundation

@main
struct TimerEngineCheck {
    static func main() {
        let countdown = TimerEngine.advance(
            TimerEngineState(
                phase: .focusCountdown,
                remainingSeconds: 3,
                elapsedFocusSeconds: 10,
                overtimeSeconds: 0
            ),
            by: 5
        )
        expect(countdown.state.phase == .focusOvertime, "focus countdown should enter overtime")
        expect(countdown.state.remainingSeconds == 0, "focus countdown should clamp remaining seconds")
        expect(countdown.state.elapsedFocusSeconds == 15, "focus countdown should count all focused seconds")
        expect(countdown.state.overtimeSeconds == 2, "focus overtime should keep overflow seconds")
        expect(countdown.events == [.focusFinished], "focus countdown should emit focusFinished once")

        let countup = TimerEngine.advance(
            TimerEngineState(
                phase: .focusCountup,
                remainingSeconds: 0,
                elapsedFocusSeconds: 40,
                overtimeSeconds: 0
            ),
            by: 20
        )
        expect(countup.state.phase == .focusCountup, "countup should stay in countup")
        expect(countup.state.elapsedFocusSeconds == 60, "countup should increase elapsed focus seconds")
        expect(countup.events.isEmpty, "countup should not emit events")

        let breakFinished = TimerEngine.advance(
            TimerEngineState(
                phase: .breakCountdown,
                remainingSeconds: 5,
                elapsedFocusSeconds: 1500,
                overtimeSeconds: 0
            ),
            by: 5
        )
        expect(breakFinished.state.phase == .breakFinished, "break countdown should finish")
        expect(breakFinished.state.remainingSeconds == 0, "break countdown should clamp remaining seconds")
        expect(breakFinished.events == [.breakFinished], "break countdown should emit breakFinished")

        print("TimerEngine checks passed")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            fputs("TimerEngine check failed: \(message)\n", stderr)
            exit(1)
        }
    }
}
