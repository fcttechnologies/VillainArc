import AppIntents
import SwiftUI
import SwiftData

struct StopRestTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop Rest Timer"
    static let description = IntentDescription("Stops the current rest timer.")
    static let supportedModes: IntentModes = .background

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = SharedModelContainer.container.mainContext
        let restTimer = RestTimerState.shared

        guard restTimer.isActive else { throw RestTimerIntentError.noActiveTimer }

        restTimer.stop()
        if let workout = try? context.fetch(WorkoutSession.incomplete).first {
            WatchWorkoutCommandCoordinator.shared.pushRuntimeStateIfMirrored(for: workout)
        }
        return .result(dialog: "Rest timer stopped.")
    }
}
