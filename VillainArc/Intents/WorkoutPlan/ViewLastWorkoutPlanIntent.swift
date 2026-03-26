import AppIntents
import SwiftData

struct ViewLastWorkoutPlanIntent: AppIntent {
    static let title: LocalizedStringResource = "View Last Workout Plan"
    static let description = IntentDescription("Shows your most recently used workout plan.")
    static let supportedModes: IntentModes = .foreground(.dynamic)

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        let context = SharedModelContainer.container.mainContext
        try SetupGuard.requireReadyAndNoActiveFlow(context: context)

        guard let lastWorkoutPlan = try context.fetch(WorkoutPlan.recent).first else { throw ViewLastWorkoutPlanError.noWorkoutPlansFound }

        AppRouter.shared.popToRoot()
        AppRouter.shared.navigate(to: .workoutPlanDetail(lastWorkoutPlan, false))
        return .result(opensIntent: OpenAppIntent())
    }
}

enum ViewLastWorkoutPlanError: Error, CustomLocalizedStringResourceConvertible {
    case noWorkoutPlansFound

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noWorkoutPlansFound: return "You don't have a completed workout plan yet."
        }
    }
}
