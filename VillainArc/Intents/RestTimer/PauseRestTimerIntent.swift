import AppIntents
import SwiftUI
import SwiftData

struct PauseRestTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "Pause Rest Timer"
    static let description = IntentDescription("Pauses the current rest timer.")
    static let supportedModes: IntentModes = .background

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetIntent {
        let context = SharedModelContainer.container.mainContext
        let restTimer = RestTimerState.shared

        guard restTimer.isRunning else {
            if restTimer.isPaused { throw RestTimerIntentError.alreadyPaused }
            throw RestTimerIntentError.noRunningTimer
        }

        restTimer.pause()
        if let workout = try? context.fetch(WorkoutSession.incomplete).first {
            WatchWorkoutCommandCoordinator.shared.pushRuntimeStateIfMirrored(for: workout)
        }
        return .result(dialog: "Rest timer paused.", snippetIntent: RestTimerSnippetIntent())
    }
}
