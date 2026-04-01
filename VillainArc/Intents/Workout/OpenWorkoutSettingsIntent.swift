import AppIntents
import SwiftData

struct OpenWorkoutSettingsIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Workout Settings"
    static let description = IntentDescription("Opens settings for your active workout.")
    static let supportedModes: IntentModes = .foreground(.dynamic)

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        let context = SharedModelContainer.container.mainContext
        guard let workout = try? context.fetch(WorkoutSession.incomplete).first, workout.statusValue == .active else { throw ActiveWorkoutIntentError.noActiveWorkout }

        AppRouter.shared.activeWorkoutSheet = .settings
        return .result(opensIntent: OpenAppIntent())
    }
}
