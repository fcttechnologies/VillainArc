import AppIntents
import SwiftData

struct ShowCardioHistoryIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Cardio History"
    static let description = IntentDescription("Opens the Cardio tab with your recent sessions and routes.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        let context = SharedModelContainer.container.mainContext
        try SetupGuard.requireReady(context: context)

        AppRouter.shared.collapseActiveFlowPresentations()
        AppRouter.shared.popToRoot(tab: .cardio)
        AppRouter.shared.tabSelection = .cardio
        return .result(opensIntent: OpenAppIntent())
    }
}
