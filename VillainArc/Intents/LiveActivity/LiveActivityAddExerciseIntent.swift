import AppIntents
import FCTMetrics
import SwiftData

struct LiveActivityAddExerciseIntent: LiveActivityIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentLiveActivityAddExercise

    static let title: LocalizedStringResource = "Add Exercise"
    static let isDiscoverable: Bool = false
    static let supportedModes: IntentModes = .foreground(.immediate)

    @MainActor func perform() async throws -> some IntentResult {
        func run() async throws -> some IntentResult {
            let context = SharedModelContainer.container.mainContext
            guard let workout = try? context.fetch(WorkoutSession.incomplete).first, workout.statusValue == .active else {
                return .result()
            }

            AppRouter.shared.resumeWorkoutSession(workout)
            AppRouter.shared.presentWorkoutSheet(.addExercise)
            return .result()
        }
        return try await Diag.intent(Self.diagCrumb, run)
    }
}
