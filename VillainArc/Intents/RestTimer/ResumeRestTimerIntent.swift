import AppIntents
import FCTMetrics
import SwiftData
import SwiftUI

struct ResumeRestTimerIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentResumeRestTimer

    static let title: LocalizedStringResource = "Resume Rest Timer"
    static let description = IntentDescription("Resumes the paused rest timer.")
    static let supportedModes: IntentModes = .background

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetIntent {
        func run() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetIntent {
            let restTimer = RestTimerState.shared

            guard restTimer.isPaused, restTimer.pausedRemainingSeconds > 0 else {
                if restTimer.isRunning { throw RestTimerIntentError.alreadyRunning }
                throw RestTimerIntentError.noPausedTimer
            }

            restTimer.resume()
            return .result(dialog: "Rest timer resumed.", snippetIntent: RestTimerSnippetIntent())
        }
        return try await Diag.intent(Self.diagCrumb, run)
    }
}
