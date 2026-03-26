import AppIntents
import SwiftData

struct LiveActivityCompleteSetIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Complete Set"
    static let isDiscoverable: Bool = false

    @MainActor func perform() async throws -> some IntentResult {
        let context = SharedModelContainer.container.mainContext

        guard let workout = try? context.fetch(WorkoutSession.incomplete).first, let (_, set) = workout.activeExerciseAndSet() else { return .result() }

        let shouldPrewarmSuggestions = workout.workoutPlan != nil && workout.isFinalIncompleteSet(set)
        set.complete = true
        set.completedAt = Date()

        let autoStartRestTimerEnabled = (try? context.fetch(AppSettings.single).first)?.autoStartRestTimer ?? true
        if autoStartRestTimerEnabled {
            let restSeconds = set.effectiveRestSeconds
            if restSeconds > 0 {
                RestTimerState.shared.start(seconds: restSeconds, startedFromSetID: set.id)
                RestTimeHistory.record(seconds: restSeconds, context: context)
            }
        }

        saveContext(context: context)
        WorkoutActivityManager.update(for: workout)
        if shouldPrewarmSuggestions { FoundationModelPrewarmer.warmup() }

        return .result()
    }
}
