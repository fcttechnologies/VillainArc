import AppIntents
import SwiftData

struct DeleteAllWorkoutPlansIntent: AppIntent {
    static let title: LocalizedStringResource = "Delete All Workout Plans"
    static let description = IntentDescription("Deletes all completed workout plans.")
    static let supportedModes: IntentModes = .foreground(.dynamic)

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = SharedModelContainer.container.mainContext
        let workoutPlans = (try? context.fetch(WorkoutPlan.all)) ?? []

        guard !workoutPlans.isEmpty else {
            return .result(dialog: "No workout plans to delete.")
        }

        let count = workoutPlans.count
        let label = count == 1 ? "1 workout plan" : "\(count) workout plans"
        let choice = try await requestChoice(
            between: [IntentChoiceOption(title: "Delete All", style: .destructive), .cancel],
            dialog: IntentDialog("Delete \(label)? This action cannot be undone.")
        )

        guard choice.style == .destructive else {
            throw DeleteAllWorkoutPlansIntentError.cancelled
        }

        SpotlightIndexer.deleteWorkoutPlans(ids: workoutPlans.map(\.id))
        for plan in workoutPlans {
            context.delete(plan)
        }
        saveContext(context: context)
        return .result(dialog: "Deleted \(label).")
    }
}

enum DeleteAllWorkoutPlansIntentError: Error, CustomLocalizedStringResourceConvertible {
    case cancelled

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .cancelled:
            return "Delete all workout plans canceled."
        }
    }
}
