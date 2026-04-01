import AppIntents
import SwiftData

struct OpenPreWorkoutContextIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Pre Workout Context"
    static let description = IntentDescription("Opens pre workout context for your active workout.")
    static let supportedModes: IntentModes = .foreground(.dynamic)

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        let context = SharedModelContainer.container.mainContext
        guard let workout = try? context.fetch(WorkoutSession.incomplete).first, workout.statusValue == .active else { throw ActiveWorkoutIntentError.noActiveWorkout }

        AppRouter.shared.activeWorkoutSheet = .preWorkoutContext
        return .result(opensIntent: OpenAppIntent())
    }
}
