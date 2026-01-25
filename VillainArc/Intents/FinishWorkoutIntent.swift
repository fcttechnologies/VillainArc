import AppIntents
import SwiftData

struct FinishWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Finish Workout"
    static let description = IntentDescription("Finishes the currently active workout.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = SharedModelContainer.container.mainContext
        
        guard let workout = try? context.fetch(Workout.incomplete).first else {
            return .result(dialog: "No active workout found.")
        }
        
        guard !workout.exercises.isEmpty else {
            return .result(dialog: "Cannot finish a workout with no exercises.")
        }
        
        // Check if at least one set is completed
        let hasCompletedSet = workout.exercises.contains { exercise in
            exercise.sets.contains { $0.complete }
        }
        
        guard hasCompletedSet else {
            return .result(dialog: "You must complete at least one set to finish the workout.")
        }
        
        // Cleanup: Delete incomplete sets
        for exercise in workout.exercises {
            let incompleteSets = exercise.sets.filter { !$0.complete }
            for set in incompleteSets {
                exercise.removeSet(set)
                context.delete(set)
            }
        }
        
        // Cleanup: Delete empty exercises (those that had all sets removed)
        let emptyExercises = workout.exercises.filter { $0.sets.isEmpty }
        for exercise in emptyExercises {
            workout.removeExercise(exercise)
            context.delete(exercise)
        }
        
        workout.completed = true
        workout.endTime = Date.now
        workout.sourceTemplate?.updateLastUsed()

        RestTimerState.shared.stop()
        saveContext(context: context)
        AppRouter.shared.activeWorkout = nil
        
        await IntentDonations.donateLastWorkoutSummary()
        await IntentDonations.donateViewLastWorkout()
        
        return .result(dialog: "Workout finished.")
    }
}
