import AppIntents
import FCTMetrics

struct LiveActivityPauseRestTimerIntent: LiveActivityIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentLiveActivityPauseRestTimer

    static let title: LocalizedStringResource = "Pause Rest Timer"
    static let isDiscoverable: Bool = false

    @MainActor func perform() async throws -> some IntentResult {
        func run() async throws -> some IntentResult {
            let restTimer = RestTimerState.shared
            guard restTimer.isRunning else { return .result() }

            restTimer.pause()
            return .result()
        }
        return try await Diag.intent(Self.diagCrumb, run)
    }
}
