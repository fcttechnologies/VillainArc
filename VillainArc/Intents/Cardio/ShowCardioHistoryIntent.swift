import AppIntents
import FCTMetrics
import SwiftData

struct ShowCardioHistoryIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentShowCardioHistory

    static let title: LocalizedStringResource = "Show Cardio History"
    static let description = IntentDescription("Opens the Cardio tab with your recent sessions and routes.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        func run() async throws -> some IntentResult & OpensIntent {
            let context = SharedModelContainer.container.mainContext
            try SetupGuard.requireReady(context: context)

            AppRouter.shared.collapseActiveFlowPresentations()
            AppRouter.shared.popToRoot(tab: .cardio)
            AppRouter.shared.tabSelection = .cardio
            return .result(opensIntent: OpenAppIntent())
        }
        return try await Diag.intent(Self.diagCrumb, run)
    }
}
