import AppIntents
import FCTMetrics
import SwiftData

struct ActivateWorkoutSplitIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentActivateWorkoutSplit

    static let title: LocalizedStringResource = "Activate Workout Split"
    static let description = IntentDescription("Makes a workout split the active one.")
    static let supportedModes: IntentModes = .background
    static var parameterSummary: some ParameterSummary { Summary("Activate \(\.$workoutSplit)") }

    @Parameter(title: "Workout Split", requestValueDialog: IntentDialog("Which workout split would you like to activate?")) var workoutSplit: WorkoutSplitEntity

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        func run() async throws -> some IntentResult & ProvidesDialog {
            let context = SharedModelContainer.container.mainContext
            try SetupGuard.requireReady(context: context)

            let splitID = workoutSplit.id
            let splits = try context.fetch(FetchDescriptor<WorkoutSplit>())
            guard let split = splits.first(where: { $0.id == splitID }) else { throw ActivateWorkoutSplitIntentError.workoutSplitNotFound }
            guard !split.isActive else { throw ActivateWorkoutSplitIntentError.alreadyActive }

            WorkoutSplitActivation.activate(split, among: splits, context: context)
            return .result(dialog: "\"\(workoutSplit.title)\" is now your active split.")
        }
        return try await Diag.intent(Self.diagCrumb, run)
    }
}

enum ActivateWorkoutSplitIntentError: Error, CustomLocalizedStringResourceConvertible {
    case workoutSplitNotFound
    case alreadyActive

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .workoutSplitNotFound: return "That workout split is no longer available."
        case .alreadyActive: return "That workout split is already your active one."
        }
    }
}
