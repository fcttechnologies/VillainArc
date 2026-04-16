import AppIntents
import SwiftData

struct OpenActiveWorkoutPlanIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Active Plan"
    static let description = IntentDescription("Opens your active workout plan flow.")
    static let supportedModes: IntentModes = .foreground(.dynamic)

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        if AppRouter.shared.activeWorkoutPlan != nil {
            AppRouter.shared.presentActiveWorkoutPlanIfPossible()
            return .result(opensIntent: OpenAppIntent())
        }

        let context = SharedModelContainer.container.mainContext
        guard let plan = try? context.fetch(WorkoutPlan.resumableIncomplete).first else { throw ActiveWorkoutPlanIntentError.noActivePlan }

        AppRouter.shared.resumeWorkoutPlanCreation(plan)
        return .result(opensIntent: OpenAppIntent())
    }
}

enum ActiveWorkoutPlanIntentError: Error, CustomLocalizedStringResourceConvertible {
    case noActivePlan

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noActivePlan: return "No active workout plan found."
        }
    }
}
