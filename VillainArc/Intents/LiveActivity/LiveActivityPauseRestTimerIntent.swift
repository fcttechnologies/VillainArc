import AppIntents

struct LiveActivityPauseRestTimerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Pause Rest Timer"
    static let isDiscoverable: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult {
        let restTimer = RestTimerState.shared
        guard restTimer.isRunning else {
            return .result()
        }

        restTimer.pause()
        return .result()
    }
}
