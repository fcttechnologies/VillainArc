import AppIntents
import FCTMetrics
import SwiftData

struct OpenExercisesIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentOpenExercises

    static let title: LocalizedStringResource = "Open Exercises"
    static let description = IntentDescription("Opens your exercises list.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        Diag.breadcrumb(Self.diagCrumb)
        let context = SharedModelContainer.container.mainContext
        try SetupGuard.requireReady(context: context)

        var descriptor = Exercise.all
        descriptor.fetchLimit = 1
        guard (try? context.fetch(descriptor).first) != nil else { throw OpenExercisesError.noExercisesAvailable }

        AppRouter.shared.collapseActiveFlowPresentations()
        AppRouter.shared.navigate(to: .exercisesList)
        return .result(opensIntent: OpenAppIntent())
    }
}

enum OpenExercisesError: Error, CustomLocalizedStringResourceConvertible {
    case noExercisesAvailable

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noExercisesAvailable: return "No exercises are available yet."
        }
    }
}
