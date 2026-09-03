import AppIntents
import FCTMetrics

struct LiveActivityResumeRestTimerIntent: LiveActivityIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentLiveActivityResumeRestTimer

    static let title: LocalizedStringResource = "Resume Rest Timer"
    static let isDiscoverable: Bool = false

    @MainActor func perform() async throws -> some IntentResult {
        func run() async throws -> some IntentResult {
            let restTimer = RestTimerState.shared
            guard restTimer.isPaused, restTimer.pausedRemainingSeconds > 0 else { return .result() }

            restTimer.resume()
            return .result()
        }
        return try await Diag.intent(Self.diagCrumb, run)
    }
}
