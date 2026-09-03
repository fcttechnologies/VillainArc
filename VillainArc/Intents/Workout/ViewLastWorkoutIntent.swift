import AppIntents
import FCTMetrics
import SwiftData

struct ViewLastWorkoutIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentViewLastWorkout

    static let title: LocalizedStringResource = "View Last Workout"
    static let description = IntentDescription("Shows your most recent completed workout.")
    static let supportedModes: IntentModes = .foreground(.dynamic)

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        func run() async throws -> some IntentResult & OpensIntent {
            let context = SharedModelContainer.container.mainContext
            try SetupGuard.requireReady(context: context)
            guard let lastWorkoutSession = try context.fetch(WorkoutSession.recent).first else { throw ViewLastWorkoutError.noWorkoutsFound }
            AppRouter.shared.collapseActiveFlowPresentations()
            AppRouter.shared.navigate(to: .workoutSessionDetail(lastWorkoutSession))
            return .result(opensIntent: OpenAppIntent())
        }
        return try await Diag.intent(Self.diagCrumb, run)
    }
}

enum ViewLastWorkoutError: Error, CustomLocalizedStringResourceConvertible {
    case noWorkoutsFound
    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noWorkoutsFound: return "You haven't completed a workout."
        }
    }
}
