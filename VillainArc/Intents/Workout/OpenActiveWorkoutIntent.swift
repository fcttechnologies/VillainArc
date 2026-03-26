import AppIntents
import SwiftData

struct OpenActiveWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Active Workout"
    static let description = IntentDescription("Opens your active workout.")
    static let supportedModes: IntentModes = .foreground(.dynamic)

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        let context = SharedModelContainer.container.mainContext
        guard let workout = try? context.fetch(WorkoutSession.incomplete).first, workout.statusValue == .active else { throw ActiveWorkoutIntentError.noActiveWorkout }

        return .result(opensIntent: OpenAppIntent())
    }
}

enum ActiveWorkoutIntentError: Error, CustomLocalizedStringResourceConvertible {
    case noActiveWorkout

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noActiveWorkout: return "No active workout found."
        }
    }
}
