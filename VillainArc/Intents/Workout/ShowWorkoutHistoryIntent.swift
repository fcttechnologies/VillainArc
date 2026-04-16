import AppIntents
import SwiftData

struct ShowWorkoutHistoryIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Workout History"
    static let description = IntentDescription("Opens your workout history.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        let context = SharedModelContainer.container.mainContext
        try SetupGuard.requireReady(context: context)

        guard (try? context.fetch(WorkoutSession.recent).first) != nil else { throw ShowWorkoutHistoryError.noWorkoutsFound }

        AppRouter.shared.collapseActiveFlowPresentations()
        AppRouter.shared.popToRoot()
        AppRouter.shared.navigate(to: .workoutSessionsList)
        return .result(opensIntent: OpenAppIntent())
    }
}

enum ShowWorkoutHistoryError: Error, CustomLocalizedStringResourceConvertible {
    case noWorkoutsFound

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noWorkoutsFound: return "You haven't completed a workout."
        }
    }
}
