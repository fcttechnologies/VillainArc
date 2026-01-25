import AppIntents

struct PauseRestTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "Pause Rest Timer"
    static let description = IntentDescription("Pauses the current rest timer.")
    static let supportedModes: IntentModes = .background

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let restTimer = RestTimerState.shared

        guard restTimer.isRunning else {
            if restTimer.isPaused {
                return .result(dialog: "Rest timer is already paused.")
            }
            return .result(dialog: "No running rest timer to pause.")
        }

        restTimer.pause()
        return .result(dialog: "Rest timer paused.")
    }
}
