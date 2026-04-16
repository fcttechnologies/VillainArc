import AppIntents
import SwiftData

struct ManageWorkoutSplitsIntent: AppIntent {
    static let title: LocalizedStringResource = "Manage Workout Splits"
    static let description = IntentDescription("Opens your workout splits.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        let context = SharedModelContainer.container.mainContext
        try SetupGuard.requireReady(context: context)

        var descriptor = FetchDescriptor<WorkoutSplit>()
        descriptor.fetchLimit = 1
        guard (try? context.fetch(descriptor).first) != nil else { throw ManageWorkoutSplitsError.noSplitsFound }

        if let activeSplit = try? context.fetch(WorkoutSplit.active).first { activeSplit.refreshRotationIfNeeded(context: context) }

        AppRouter.shared.collapseActiveFlowPresentations()
        AppRouter.shared.activeSplitSheet = .list
        AppRouter.shared.popToRoot()
        AppRouter.shared.navigate(to: .workoutSplit(autoPresentBuilder: false))
        return .result(opensIntent: OpenAppIntent())
    }
}

enum ManageWorkoutSplitsError: Error, CustomLocalizedStringResourceConvertible {
    case noSplitsFound

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noSplitsFound: return "You don't have any workout splits yet."
        }
    }
}
