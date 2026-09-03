import AppIntents
import FCTMetrics
import SwiftData

struct OpenActiveWorkoutIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentOpenActiveWorkout

    static let title: LocalizedStringResource = "Open Active Workout"
    static let description = IntentDescription("Opens your active workout.")
    static let supportedModes: IntentModes = .foreground(.dynamic)

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        Diag.breadcrumb(Self.diagCrumb)
        let context = SharedModelContainer.container.mainContext
        guard let workout = try? context.fetch(WorkoutSession.incomplete).first, workout.statusValue == .active else { throw ActiveWorkoutIntentError.noActiveWorkout }

        AppRouter.shared.resumeWorkoutSession(workout)
        return .result(opensIntent: OpenAppIntent())
    }
}

enum ActiveWorkoutIntentError: Error, CustomLocalizedStringResourceConvertible {
    case noActiveWorkout

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noActiveWorkout: return "No active workout found."
        }
    }
}
