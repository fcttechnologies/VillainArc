import AppIntents
import SwiftData

struct EditWorkoutPlanIntent: AppIntent {
    static let title: LocalizedStringResource = "Edit Workout Plan"
    static let description = IntentDescription("Starts editing a workout plan using the plan editing flow.")
    static let supportedModes: IntentModes = .foreground(.dynamic)
    static var parameterSummary: some ParameterSummary { Summary("Edit \(\.$workoutPlan)") }

    @Parameter(title: "Workout Plan", requestValueDialog: IntentDialog("Which workout plan would you like to edit?")) var workoutPlan: WorkoutPlanEntity

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        let context = SharedModelContainer.container.mainContext
        try SetupGuard.requireReadyAndNoActiveFlow(context: context)

        let workoutPlanID = workoutPlan.id
        let predicate = #Predicate<WorkoutPlan> { $0.id == workoutPlanID }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        guard let storedPlan = try context.fetch(descriptor).first else { throw EditWorkoutPlanError.workoutPlanNotFound }
        guard storedPlan.completed && !storedPlan.isEditing else { throw EditWorkoutPlanError.workoutPlanIncomplete }

        AppRouter.shared.editWorkoutPlan(storedPlan)
        return .result(opensIntent: OpenAppIntent())
    }
}

enum EditWorkoutPlanError: Error, CustomLocalizedStringResourceConvertible {
    case workoutPlanNotFound
    case workoutPlanIncomplete

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .workoutPlanNotFound: return "That workout plan is no longer available."
        case .workoutPlanIncomplete: return "Finish creating the workout plan before editing it."
        }
    }
}
