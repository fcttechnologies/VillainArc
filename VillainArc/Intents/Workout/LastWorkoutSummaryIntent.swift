import AppIntents
import FCTMetrics
import SwiftData

struct LastWorkoutSummaryIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentLastWorkoutSummary

    static let title: LocalizedStringResource = "Last Workout Summary"
    static let description = IntentDescription("Tells you about your last workout session.")
    static let supportedModes: IntentModes = .background

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        Diag.breadcrumb(Self.diagCrumb)
        let context = SharedModelContainer.container.mainContext
        guard let lastWorkoutSession = try context.fetch(WorkoutSession.recent).first else { return .result(dialog: "You haven't completed a workout.") }
        let exercisesList = lastWorkoutSession.exerciseSummary
        return .result(dialog: "In your last workout, you did \(exercisesList).")
    }
}
