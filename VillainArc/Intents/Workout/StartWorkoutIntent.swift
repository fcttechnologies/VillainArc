import AppIntents
import SwiftData

struct StartWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Workout"
    static let description = IntentDescription("Starts a new empty workout.")
    static let supportedModes: IntentModes = .foreground(.dynamic)

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        let context = SharedModelContainer.container.mainContext
        if let _ = try? context.fetch(WorkoutTemplate.incomplete).first {
            throw StartWorkoutError.templateIsActive
        }
        if let _ = try? context.fetch(Workout.incomplete).first {
            throw StartWorkoutError.workoutIsActive
        }
        AppRouter.shared.startWorkout()
        return .result(opensIntent: OpenAppIntent())
    }
}

enum StartWorkoutError: Error, CustomLocalizedStringResourceConvertible {
    case templateIsActive
    case workoutIsActive
    
    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .templateIsActive:
            return "You are currently creating a template. Finish that first."
        case .workoutIsActive:
            return "You already have an active workout. Resume it first."
        }
    }
}
