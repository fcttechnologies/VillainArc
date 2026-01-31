import AppIntents
import SwiftData

struct CreateWorkoutPlanIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Workout Plan"
    static let description = IntentDescription("Creates a new workout plan")
    static let supportedModes: IntentModes = .foreground(.dynamic)

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        let context = SharedModelContainer.container.mainContext
        if let _ = try? context.fetch(WorkoutSession.incomplete).first {
            throw StartWorkoutPlanError.workoutIsActive
        }
        if let _ = try? context.fetch(WorkoutPlan.incomplete).first {
            throw StartWorkoutPlanError.workoutPlanIsActive
        }
        AppRouter.shared.createWorkoutPlan()
        return .result(opensIntent: OpenAppIntent())
    }
}

enum StartWorkoutPlanError: Error, CustomLocalizedStringResourceConvertible {
    case workoutPlanIsActive
    case workoutIsActive
    
    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .workoutPlanIsActive:
            return "You are currently creating a workout plan. Finish that first."
        case .workoutIsActive:
            return "You are currently working out, finish that first."
        }
    }
}
