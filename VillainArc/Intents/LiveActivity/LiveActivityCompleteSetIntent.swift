import AppIntents
import SwiftData

struct LiveActivityCompleteSetIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Complete Set"
    static let isDiscoverable: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult {
        let context = SharedModelContainer.container.mainContext

        guard let workout = try? context.fetch(WorkoutSession.incomplete).first,
              let (_, set) = workout.activeExerciseAndSet() else {
            return .result()
        }

        set.complete = true
        set.completedAt = Date()

        if autoStartRestTimerEnabled {
            let restSeconds = set.effectiveRestSeconds
            if restSeconds > 0 {
                RestTimerState.shared.start(seconds: restSeconds, startedFromSetID: set.persistentModelID)
            }
        }

        try? context.save()
        WorkoutActivityManager.update(for: workout)

        return .result()
    }

    private var autoStartRestTimerEnabled: Bool {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "autoStartRestTimer") == nil {
            return true
        }
        return defaults.bool(forKey: "autoStartRestTimer")
    }
}
