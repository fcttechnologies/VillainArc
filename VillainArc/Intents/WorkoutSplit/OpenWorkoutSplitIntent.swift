import AppIntents
import FCTMetrics
import SwiftData

struct OpenWorkoutSplitIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentOpenWorkoutSplit

    static let title: LocalizedStringResource = "Open Workout Split"
    static let description = IntentDescription("Opens your active workout split.")
    static let supportedModes: IntentModes = .foreground(.dynamic)

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        Diag.breadcrumb(Self.diagCrumb)
        let context = SharedModelContainer.container.mainContext
        try SetupGuard.requireReady(context: context)

        guard let split = try? context.fetch(WorkoutSplit.active).first else { throw OpenWorkoutSplitError.noActiveSplit }
        _ = SplitScheduleResolver.resolve(split, context: context)

        AppRouter.shared.collapseActiveFlowPresentations()
        AppRouter.shared.navigate(to: .workoutSplit(autoPresentBuilder: false))
        return .result(opensIntent: OpenAppIntent())
    }
}

enum OpenWorkoutSplitError: Error, CustomLocalizedStringResourceConvertible {
    case noActiveSplit

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noActiveSplit: return "You don't have an active workout split."
        }
    }
}
