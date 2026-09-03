import AppIntents
import FCTMetrics
import SwiftData

struct CreateWorkoutSplitIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentCreateWorkoutSplit

    static let title: LocalizedStringResource = "Create Workout Split"
    static let description = IntentDescription("Opens workout split creation.")
    static let supportedModes: IntentModes = .foreground(.dynamic)

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        func run() async throws -> some IntentResult & OpensIntent {
            let context = SharedModelContainer.container.mainContext
            try SetupGuard.requireReady(context: context)

            AppRouter.shared.collapseActiveFlowPresentations()
            AppRouter.shared.activeSplitSheet = .builder
            AppRouter.shared.navigate(to: .workoutSplit(autoPresentBuilder: false))
            return .result(opensIntent: OpenAppIntent())
        }
        return try await Diag.intent(Self.diagCrumb, run)
    }
}
