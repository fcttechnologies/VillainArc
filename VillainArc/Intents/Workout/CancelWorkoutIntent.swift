import AppIntents
import FCTMetrics
import SwiftData

struct CancelWorkoutIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentCancelWorkout

    static let title: LocalizedStringResource = "Cancel Workout"
    static let description = IntentDescription("Cancels and deletes the current workout session.")
    static let supportedModes: IntentModes = .background

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        Diag.breadcrumb(Self.diagCrumb)
        let context = SharedModelContainer.container.mainContext
        guard let workoutSession = try? context.fetch(WorkoutSession.incomplete).first else { return .result(dialog: "No current workout session to cancel.") }

        AppRouter.shared.cancelWorkoutSession(workoutSession)

        return .result(dialog: "Workout cancelled.")
    }
}
