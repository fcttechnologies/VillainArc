import AppIntents

struct ResumeRestTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "Resume Rest Timer"
    static let description = IntentDescription("Resumes the paused rest timer.")
    static let supportedModes: IntentModes = .background

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let restTimer = RestTimerState.shared

        guard restTimer.isPaused, restTimer.pausedRemainingSeconds > 0 else {
            if restTimer.isRunning {
                return .result(dialog: "Rest timer is already running.")
            }
            return .result(dialog: "No paused rest timer to resume.")
        }

        restTimer.resume()
        return .result(dialog: "Rest timer resumed.")
    }
}
