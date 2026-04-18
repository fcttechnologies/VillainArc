import AppIntents
import SwiftData

struct CreateWorkoutPlanIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Workout Plan"
    static let description = IntentDescription("Creates a new workout plan")
    static let supportedModes: IntentModes = .foreground(.dynamic)

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        let context = SharedModelContainer.container.mainContext
        try SetupGuard.requireReady(context: context)
        if (try? context.fetch(WorkoutSession.incomplete).first) != nil { throw StartWorkoutPlanError.workoutIsActive }
        if (try? context.fetch(WorkoutPlan.incomplete).first) != nil { throw StartWorkoutPlanError.workoutPlanIsActive }
        AppRouter.shared.presentCreateWorkoutPlanSheet()
        return .result(opensIntent: OpenAppIntent())
    }
}

enum StartWorkoutPlanError: Error, CustomLocalizedStringResourceConvertible {
    case workoutPlanIsActive
    case workoutIsActive
    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .workoutPlanIsActive: return "You are currently working on a workout plan. Finish that first."
        case .workoutIsActive: return "You are currently working out, finish that first."
        }
    }
}
