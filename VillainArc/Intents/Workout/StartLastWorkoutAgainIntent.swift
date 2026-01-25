import AppIntents
import SwiftData

struct StartLastWorkoutAgainIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Last Workout Again"
    static let description = IntentDescription("Starts a new workout based on your most recent completed workout.")
    static let supportedModes: IntentModes = .foreground(.dynamic)

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        let context = SharedModelContainer.container.mainContext
        if let _ = try? context.fetch(WorkoutTemplate.incomplete).first {
            throw StartLastWorkoutAgainError.templateIsActive
        }
        if let _ = try? context.fetch(Workout.incomplete).first {
            throw StartLastWorkoutAgainError.workoutIsActive
        }
        guard let lastWorkout = try context.fetch(Workout.recentWorkout).first else {
            throw StartLastWorkoutAgainError.noWorkoutsFound
        }
        AppRouter.shared.startWorkout(from: lastWorkout)
        return .result(opensIntent: OpenAppIntent())
    }
}

enum StartLastWorkoutAgainError: Error, CustomLocalizedStringResourceConvertible {
    case templateIsActive
    case workoutIsActive
    case noWorkoutsFound

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .templateIsActive:
            return "You are currently creating a template. Finish that first."
        case .workoutIsActive:
            return "You already have an active workout. Resume it first."
        case .noWorkoutsFound:
            return "You haven't completed a workout yet."
        }
    }
}
