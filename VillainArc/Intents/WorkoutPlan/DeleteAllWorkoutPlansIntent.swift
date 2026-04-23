import AppIntents
import SwiftData

struct DeleteAllWorkoutPlansIntent: AppIntent {
    static let title: LocalizedStringResource = "Delete All Workout Plans"
    static let description = IntentDescription("Deletes all completed workout plans.")
    static let supportedModes: IntentModes = .foreground(.dynamic)

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = SharedModelContainer.container.mainContext
        let workoutPlans = (try? context.fetch(WorkoutPlan.all)) ?? []

        guard !workoutPlans.isEmpty else { return .result(dialog: "No workout plans to delete.") }

        let assessment = WorkoutPlanDeletionCoordinator.assess(plans: workoutPlans, context: context)
        let count = workoutPlans.count
        let label = count == 1 ? "1 workout plan" : "\(count) workout plans"
        let dialog: IntentDialog = switch assessment.risk {
        case .activeEditing:
            IntentDialog("One of these workout plans is currently being edited. Deleting them will close the editor and discard its editing copy.")
        case .activeWorkout:
            IntentDialog("An active workout was started from one of these workout plans. Deleting them will turn that live workout into a standalone workout and clear copied plan targets.")
        case nil:
            IntentDialog("Delete \(label)? This action cannot be undone.")
        }
        let choice = try await requestChoice(
            between: [IntentChoiceOption(title: "Delete All", style: .destructive), .cancel],
            dialog: dialog
        )

        guard choice.style == .destructive else { throw DeleteAllWorkoutPlansIntentError.cancelled }

        WorkoutPlanDeletionCoordinator.delete(assessment, context: context)
        return .result(dialog: "Deleted \(label).")
    }
}

enum DeleteAllWorkoutPlansIntentError: Error, CustomLocalizedStringResourceConvertible {
    case cancelled

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .cancelled: return "Delete all workout plans canceled."
        }
    }
}
