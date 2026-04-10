import AppIntents
import SwiftUI
import SwiftData

struct ResumeRestTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "Resume Rest Timer"
    static let description = IntentDescription("Resumes the paused rest timer.")
    static let supportedModes: IntentModes = .background

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetIntent {
        let context = SharedModelContainer.container.mainContext
        let restTimer = RestTimerState.shared

        guard restTimer.isPaused, restTimer.pausedRemainingSeconds > 0 else {
            if restTimer.isRunning { throw RestTimerIntentError.alreadyRunning }
            throw RestTimerIntentError.noPausedTimer
        }

        restTimer.resume()
        if let workout = try? context.fetch(WorkoutSession.incomplete).first {
            WatchWorkoutCommandCoordinator.shared.pushRuntimeStateIfMirrored(for: workout)
        }
        return .result(dialog: "Rest timer resumed.", snippetIntent: RestTimerSnippetIntent())
    }
}
