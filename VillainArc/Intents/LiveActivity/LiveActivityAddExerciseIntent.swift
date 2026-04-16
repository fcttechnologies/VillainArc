import AppIntents
import SwiftData

struct LiveActivityAddExerciseIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Add Exercise"
    static let isDiscoverable: Bool = false
    static let supportedModes: IntentModes = .foreground(.immediate)

    @MainActor func perform() async throws -> some IntentResult {
        let context = SharedModelContainer.container.mainContext
        guard let workout = try? context.fetch(WorkoutSession.incomplete).first, workout.statusValue == .active else {
            return .result()
        }

        AppRouter.shared.resumeWorkoutSession(workout)
        AppRouter.shared.presentWorkoutSheet(.addExercise)
        return .result()
    }
}
