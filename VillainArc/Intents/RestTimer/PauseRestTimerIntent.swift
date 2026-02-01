import AppIntents
import SwiftUI

struct PauseRestTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "Pause Rest Timer"
    static let description = IntentDescription("Pauses the current rest timer.")
    static let supportedModes: IntentModes = .background

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetIntent {
        let restTimer = RestTimerState.shared

        guard restTimer.isRunning else {
            if restTimer.isPaused {
                throw RestTimerIntentError.alreadyPaused
            }
            throw RestTimerIntentError.noRunningTimer
        }

        restTimer.pause()
        return .result(dialog: "Rest timer paused.", snippetIntent: RestTimerSnippetIntent())
    }
}
