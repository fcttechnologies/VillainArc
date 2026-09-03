import AppIntents
import FCTMetrics
import SwiftData

struct OpenWorkoutPlanIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentOpenWorkoutPlan

    static let title: LocalizedStringResource = "Open Workout Plan"
    static let description = IntentDescription("Opens a specific workout plan.")
    static let supportedModes: IntentModes = .foreground(.dynamic)
    static var parameterSummary: some ParameterSummary { Summary("Open \(\.$workoutPlan)") }

    @Parameter(title: "Workout Plan", requestValueDialog: IntentDialog("Which workout plan would you like to open?")) var workoutPlan: WorkoutPlanEntity

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        Diag.breadcrumb(Self.diagCrumb)
        let context = SharedModelContainer.container.mainContext
        try SetupGuard.requireReady(context: context)

        let workoutPlanID = workoutPlan.id
        guard let storedPlan = try context.fetch(WorkoutPlan.byID(workoutPlanID)).first else { throw OpenWorkoutPlanError.workoutPlanNotFound }
        guard storedPlan.completed else { throw OpenWorkoutPlanError.workoutPlanIncomplete }

        AppRouter.shared.collapseActiveFlowPresentations()
        AppRouter.shared.navigate(to: .workoutPlanDetail(storedPlan, false))
        return .result(opensIntent: OpenAppIntent())
    }
}

enum OpenWorkoutPlanError: Error, CustomLocalizedStringResourceConvertible {
    case workoutPlanNotFound
    case workoutPlanIncomplete

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .workoutPlanNotFound: return "That workout plan is no longer available."
        case .workoutPlanIncomplete: return "Finish creating the workout plan before opening it."
        }
    }
}
