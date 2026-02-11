import AppIntents
import SwiftData

struct DeleteAllWorkoutsIntent: AppIntent {
    static let title: LocalizedStringResource = "Delete All Workouts"
    static let description = IntentDescription("Deletes all completed workouts.")
    static let supportedModes: IntentModes = .foreground(.dynamic)

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = SharedModelContainer.container.mainContext
        let workouts = (try? context.fetch(WorkoutSession.completedSession)) ?? []

        guard !workouts.isEmpty else {
            return .result(dialog: "No completed workouts to delete.")
        }

        let count = workouts.count
        let label = count == 1 ? "1 workout" : "\(count) workouts"
        let choice = try await requestChoice(
            between: [IntentChoiceOption(title: "Delete All", style: .destructive), .cancel],
            dialog: IntentDialog("Delete \(label)? This action cannot be undone.")
        )

        guard choice.style == .destructive else {
            throw DeleteAllWorkoutsIntentError.cancelled
        }

        var affectedCatalogIDs = Set<String>()
        for workout in workouts {
            affectedCatalogIDs.formUnion(workout.exercises.map { $0.catalogID })
        }

        SpotlightIndexer.deleteWorkoutSessions(ids: workouts.map(\.id))
        for workout in workouts {
            context.delete(workout)
        }

        for catalogID in affectedCatalogIDs {
            ExerciseHistoryUpdater.updateHistory(for: catalogID, context: context)
        }

        saveContext(context: context)
        return .result(dialog: "Deleted \(label).")
    }
}

enum DeleteAllWorkoutsIntentError: Error, CustomLocalizedStringResourceConvertible {
    case cancelled

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .cancelled:
            return "Delete all workouts canceled."
        }
    }
}
