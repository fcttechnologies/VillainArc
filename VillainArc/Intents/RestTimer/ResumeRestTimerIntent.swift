import AppIntents
import SwiftUI

struct ResumeRestTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "Resume Rest Timer"
    static let description = IntentDescription("Resumes the paused rest timer.")
    static let supportedModes: IntentModes = .background

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetIntent {
        let restTimer = RestTimerState.shared

        guard restTimer.isPaused, restTimer.pausedRemainingSeconds > 0 else {
            if restTimer.isRunning {
                throw RestTimerIntentError.alreadyRunning
            }
            throw RestTimerIntentError.noPausedTimer
        }

        restTimer.resume()
        return .result(dialog: "Rest timer resumed.", snippetIntent: RestTimerSnippetIntent())
    }
}
