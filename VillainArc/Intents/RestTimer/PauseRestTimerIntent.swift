import AppIntents
import FCTMetrics
import SwiftData
import SwiftUI

struct PauseRestTimerIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentPauseRestTimer

    static let title: LocalizedStringResource = "Pause Rest Timer"
    static let description = IntentDescription("Pauses the current rest timer.")
    static let supportedModes: IntentModes = .background

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetIntent {
        func run() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetIntent {
            let restTimer = RestTimerState.shared

            guard restTimer.isRunning else {
                if restTimer.isPaused { throw RestTimerIntentError.alreadyPaused }
                throw RestTimerIntentError.noRunningTimer
            }

            restTimer.pause()
            return .result(dialog: "Rest timer paused.", snippetIntent: RestTimerSnippetIntent())
        }
        return try await Diag.intent(Self.diagCrumb, run)
    }
}
