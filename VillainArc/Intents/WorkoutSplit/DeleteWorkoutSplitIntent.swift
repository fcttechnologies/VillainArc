import AppIntents
import FCTMetrics
import SwiftData

struct DeleteWorkoutSplitIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentDeleteWorkoutSplit

    static let title: LocalizedStringResource = "Delete Workout Split"
    static let description = IntentDescription("Deletes a workout split and its days.")
    static let supportedModes: IntentModes = .foreground(.dynamic)
    static var parameterSummary: some ParameterSummary { Summary("Delete \(\.$workoutSplit)") }

    @Parameter(title: "Workout Split", requestValueDialog: IntentDialog("Which workout split would you like to delete?")) var workoutSplit: WorkoutSplitEntity

    /// The split's days go with it; the workout plans those days point at are their own records and
    /// stay. Deleting the ACTIVE split is allowed, as it is on the split screen, but it is what the
    /// day's schedule resolves from — so the confirmation says so rather than the intent refusing.
    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        func run() async throws -> some IntentResult & ProvidesDialog {
            let context = SharedModelContainer.container.mainContext

            let splitID = workoutSplit.id
            let predicate = #Predicate<WorkoutSplit> { $0.id == splitID }
            var descriptor = FetchDescriptor(predicate: predicate)
            descriptor.fetchLimit = 1

            guard let storedSplit = try context.fetch(descriptor).first else { throw DeleteWorkoutSplitIntentError.workoutSplitNotFound }

            let dialog: IntentDialog = storedSplit.isActive
                ? IntentDialog("\"\(workoutSplit.title)\" is your active split — deleting it leaves you with no schedule for today. This action cannot be undone.")
                : IntentDialog("Delete \"\(workoutSplit.title)\"? This action cannot be undone.")
            let choice = try await requestChoice(
                between: [IntentChoiceOption(title: "Delete", style: .destructive), .cancel],
                dialog: dialog
            )
            guard choice.style == .destructive else { throw DeleteWorkoutSplitIntentError.cancelled }

            Diag.breadcrumb(VACrumb.splitDeleted)
            SpotlightIndexer.deleteWorkoutSplit(id: splitID)
            context.delete(storedSplit)
            saveContext(context: context)
            return .result(dialog: "Workout split deleted.")
        }
        return try await Diag.intent(Self.diagCrumb, run)
    }
}

enum DeleteWorkoutSplitIntentError: Error, CustomLocalizedStringResourceConvertible {
    case workoutSplitNotFound
    case cancelled

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .workoutSplitNotFound: return "That workout split is no longer available."
        case .cancelled: return "Delete workout split canceled."
        }
    }
}
