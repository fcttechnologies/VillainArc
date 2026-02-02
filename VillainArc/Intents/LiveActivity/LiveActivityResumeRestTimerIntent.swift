import AppIntents

struct LiveActivityResumeRestTimerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Resume Rest Timer"
    static let isDiscoverable: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult {
        let restTimer = RestTimerState.shared
        guard restTimer.isPaused, restTimer.pausedRemainingSeconds > 0 else {
            return .result()
        }

        restTimer.resume()
        return .result()
    }
}
