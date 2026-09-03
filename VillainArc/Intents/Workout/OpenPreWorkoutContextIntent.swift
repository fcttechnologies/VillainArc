import AppIntents
import FCTMetrics
import SwiftData

struct OpenPreWorkoutContextIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentOpenPreWorkoutContext

    static let title: LocalizedStringResource = "Open Pre Workout Context"
    static let description = IntentDescription("Opens pre workout context for your active workout.")
    static let supportedModes: IntentModes = .foreground(.dynamic)

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        Diag.breadcrumb(Self.diagCrumb)
        let context = SharedModelContainer.container.mainContext
        guard let workout = try? context.fetch(WorkoutSession.incomplete).first, workout.statusValue == .active else { throw ActiveWorkoutIntentError.noActiveWorkout }

        AppRouter.shared.resumeWorkoutSession(workout)
        AppRouter.shared.presentWorkoutSheet(.preWorkoutContext)
        return .result(opensIntent: OpenAppIntent())
    }
}
