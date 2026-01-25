import AppIntents
import SwiftData

struct CancelWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Cancel Workout"
    static let description = IntentDescription("Cancels and deletes the currently active workout.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = SharedModelContainer.container.mainContext
        
        guard let workout = try? context.fetch(Workout.incomplete).first else {
            return .result(dialog: "No active workout to cancel.")
        }

        RestTimerState.shared.stop()
        context.delete(workout)
        saveContext(context: context)
        AppRouter.shared.activeWorkout = nil
        
        return .result(dialog: "Workout cancelled.")
    }
}
