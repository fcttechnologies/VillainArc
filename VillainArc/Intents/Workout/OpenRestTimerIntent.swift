import AppIntents
import SwiftData

struct OpenRestTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Rest Timer"
    static let description = IntentDescription("Opens the rest timer for your active workout.")
    static let supportedModes: IntentModes = .foreground(.dynamic)

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        let context = SharedModelContainer.container.mainContext
        guard let workout = try? context.fetch(WorkoutSession.incomplete).first, workout.statusValue == .active else { throw ActiveWorkoutIntentError.noActiveWorkout }

        AppRouter.shared.resumeWorkoutSession(workout)
        AppRouter.shared.presentWorkoutSheet(.restTimer)
        return .result(opensIntent: OpenAppIntent())
    }
}
