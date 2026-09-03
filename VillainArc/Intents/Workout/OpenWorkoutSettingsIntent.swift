import AppIntents
import FCTMetrics
import SwiftData

struct OpenWorkoutSettingsIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentOpenWorkoutSettings

    static let title: LocalizedStringResource = "Open Workout Settings"
    static let description = IntentDescription("Opens settings for your active workout.")
    static let supportedModes: IntentModes = .foreground(.dynamic)

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        Diag.breadcrumb(Self.diagCrumb)
        let context = SharedModelContainer.container.mainContext
        guard let workout = try? context.fetch(WorkoutSession.incomplete).first, workout.statusValue == .active else { throw ActiveWorkoutIntentError.noActiveWorkout }

        AppRouter.shared.resumeWorkoutSession(workout)
        AppRouter.shared.presentWorkoutSheet(.settings)
        return .result(opensIntent: OpenAppIntent())
    }
}
