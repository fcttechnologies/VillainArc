import AppIntents
import FCTMetrics
import SwiftData

struct ShowWorkoutPlansIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentShowWorkoutPlans

    static let title: LocalizedStringResource = "Show Workout Plans"
    static let description = IntentDescription("Opens your workout plans list.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        func run() async throws -> some IntentResult & OpensIntent {
            let context = SharedModelContainer.container.mainContext
            try SetupGuard.requireReady(context: context)

            guard (try? context.fetch(WorkoutPlan.recent).first) != nil else { throw ShowWorkoutPlansError.noWorkoutPlansFound }

            AppRouter.shared.collapseActiveFlowPresentations()
            AppRouter.shared.navigate(to: .workoutPlansList)
            return .result(opensIntent: OpenAppIntent())
        }
        return try await Diag.intent(Self.diagCrumb, run)
    }
}

enum ShowWorkoutPlansError: Error, CustomLocalizedStringResourceConvertible {
    case noWorkoutPlansFound

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noWorkoutPlansFound: return "You don't have any workout plans yet."
        }
    }
}
