import AppIntents
import SwiftData

struct CancelWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Cancel Workout"
    static let description = IntentDescription("Cancels and deletes the current workout session.")
    static let supportedModes: IntentModes = .background

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = SharedModelContainer.container.mainContext
        
        guard let workoutSession = try? context.fetch(WorkoutSession.incomplete).first else {
            return .result(dialog: "No current workout session to cancel.")
        }

        RestTimerState.shared.stop()
        context.delete(workoutSession)
        saveContext(context: context)
        AppRouter.shared.activeWorkoutSession = nil
        
        return .result(dialog: "Workout cancelled.")
    }
}
