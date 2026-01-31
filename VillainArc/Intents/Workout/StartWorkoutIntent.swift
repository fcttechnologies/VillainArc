import AppIntents
import SwiftData

struct StartWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Workout"
    static let description = IntentDescription("Starts an empty workout session.")
    static let supportedModes: IntentModes = .foreground(.dynamic)

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        let context = SharedModelContainer.container.mainContext
        if let _ = try? context.fetch(WorkoutPlan.incomplete).first {
            throw StartWorkoutError.workoutPlanIsActive
        }
        if let _ = try? context.fetch(WorkoutSession.incomplete).first {
            throw StartWorkoutError.workoutIsActive
        }
        AppRouter.shared.startWorkoutSession()
        return .result(opensIntent: OpenAppIntent())
    }
}

enum StartWorkoutError: Error, CustomLocalizedStringResourceConvertible {
    case workoutPlanIsActive
    case workoutIsActive
    
    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .workoutPlanIsActive:
            return "You are currently creating a workout plan. Finish that first."
        case .workoutIsActive:
            return "You're already working out. Resume it first or cancel it."
        }
    }
}
