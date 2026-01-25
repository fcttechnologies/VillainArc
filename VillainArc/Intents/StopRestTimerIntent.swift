import AppIntents

struct StopRestTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop Rest Timer"
    static let description = IntentDescription("Stops the current rest timer.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let restTimer = RestTimerState.shared

        guard restTimer.isActive else {
            return .result(dialog: "No active rest timer to stop.")
        }

        restTimer.stop()
        return .result(dialog: "Rest timer stopped.")
    }
}
