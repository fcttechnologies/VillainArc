import AppIntents
import SwiftData

struct FinishWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Finish Workout"
    static let description = IntentDescription("Finishes the current workout session.")
    static let supportedModes: IntentModes = .background

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = SharedModelContainer.container.mainContext
        
        guard let workoutSession = try? context.fetch(WorkoutSession.incomplete).first else {
            return .result(dialog: "No workout session found.")
        }
        
        guard !workoutSession.exercises.isEmpty else {
            return .result(dialog: "Cannot finish a workout with no exercises.")
        }
        
        // Check if at least one set is completed
        let hasCompletedSet = workoutSession.exercises.contains { exercise in
            exercise.sets.contains { $0.complete }
        }
        
        guard hasCompletedSet else {
            return .result(dialog: "You must complete at least one set to finish the workout.")
        }
        
        workoutSession.completed = true
        workoutSession.endedAt = Date()

        RestTimerState.shared.stop()
        saveContext(context: context)
        SpotlightIndexer.index(workoutSession: workoutSession)
        AppRouter.shared.activeWorkoutSession = nil
        
        let exercisesList = workoutSession.exerciseSummary
        
        await IntentDonations.donateLastWorkoutSummary()
        await IntentDonations.donateViewLastWorkout()
        
        return .result(dialog: "Workout finished. You did \(exercisesList).")
    }
}
