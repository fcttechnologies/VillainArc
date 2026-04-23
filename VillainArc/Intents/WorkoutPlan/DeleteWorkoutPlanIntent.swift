import AppIntents
import SwiftData

struct DeleteWorkoutPlanIntent: AppIntent {
    static let title: LocalizedStringResource = "Delete Workout Plan"
    static let description = IntentDescription("Deletes a workout plan.")
    static let supportedModes: IntentModes = .foreground(.dynamic)
    static var parameterSummary: some ParameterSummary { Summary("Delete \(\.$workoutPlan)") }

    @Parameter(title: "Workout Plan", requestValueDialog: IntentDialog("Which workout plan would you like to delete?")) var workoutPlan: WorkoutPlanEntity

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = SharedModelContainer.container.mainContext

        let workoutPlanID = workoutPlan.id
        guard let storedPlan = try context.fetch(WorkoutPlan.byIDForDeletion(workoutPlanID)).first else { throw DeleteWorkoutPlanIntentError.workoutPlanNotFound }
        guard storedPlan.completed else { throw DeleteWorkoutPlanIntentError.workoutPlanIncomplete }

        let assessment = WorkoutPlanDeletionCoordinator.assess(plans: [storedPlan], context: context)
        let dialog: IntentDialog = switch assessment.risk {
        case .activeEditing:
            IntentDialog("You're currently editing this workout plan. Deleting it will close the editor and discard the editing copy.")
        case .activeWorkout:
            IntentDialog("An active workout was started from this workout plan. Deleting it will turn that live workout into a standalone workout and clear copied plan targets.")
        case nil:
            IntentDialog("Delete \"\(storedPlan.title)\"? This action cannot be undone.")
        }
        let choice = try await requestChoice(
            between: [IntentChoiceOption(title: "Delete", style: .destructive), .cancel],
            dialog: dialog
        )

        guard choice.style == .destructive else { throw DeleteWorkoutPlanIntentError.cancelled }

        WorkoutPlanDeletionCoordinator.delete(assessment, context: context)
        return .result(dialog: "Workout plan deleted.")
    }
}

enum DeleteWorkoutPlanIntentError: Error, CustomLocalizedStringResourceConvertible {
    case workoutPlanNotFound
    case workoutPlanIncomplete
    case cancelled

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .workoutPlanNotFound: return "That workout plan is no longer available."
        case .workoutPlanIncomplete: return "Only completed workout plans can be deleted."
        case .cancelled: return "Delete workout plan canceled."
        }
    }
}
