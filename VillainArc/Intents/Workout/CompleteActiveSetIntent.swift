import AppIntents
import SwiftData

struct CompleteActiveSetIntent: AppIntent {
    static let title: LocalizedStringResource = "Complete Active Set"
    static let description = IntentDescription("Completes the next incomplete set in your workout session.")
    static let supportedModes: IntentModes = .background

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = SharedModelContainer.container.mainContext
        guard let workout = try? context.fetch(WorkoutSession.incomplete).first else {
            return .result(dialog: "No workout session to update.")
        }

        guard let (exercise, set) = workout.activeExerciseAndSet() else {
            return .result(dialog: "No incomplete sets found.")
        }

        let shouldPrewarmSuggestions = workout.workoutPlan != nil && workout.isFinalIncompleteSet(set)
        set.complete = true
        set.completedAt = Date()

        let autoStartRestTimerEnabled = (try? context.fetch(AppSettings.single).first)?.autoStartRestTimer ?? true
        if autoStartRestTimerEnabled {
            let restSeconds = set.effectiveRestSeconds
            if restSeconds > 0 {
                RestTimerState.shared.start(seconds: restSeconds, startedFromSetID: set.id)
                RestTimeHistory.record(seconds: restSeconds, context: context)
                Task { await IntentDonations.donateStartRestTimer(seconds: restSeconds) }
            }
        }
        
        saveContext(context: context)
        WorkoutActivityManager.update(for: workout)
        if shouldPrewarmSuggestions {
            FoundationModelPrewarmer.warmup()
        }
        let setNumber = set.index + 1
        return .result(dialog: "Completed set \(setNumber) of \(exercise.name).")
    }
}
