import AppIntents
import SwiftData

struct UpdateTrainingConditionIntent: AppIntent {
    static let title: LocalizedStringResource = "Update Training Condition"
    static let description = IntentDescription("Opens the training condition editor.")
    static let supportedModes: IntentModes = .foreground(.dynamic)

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        let context = SharedModelContainer.container.mainContext
        try SetupGuard.requireReady(context: context)

        AppRouter.shared.collapseActiveFlowPresentations()
        AppRouter.shared.popToRoot(tab: .health)
        AppRouter.shared.selectTab(.health)
        AppRouter.shared.activeHealthSheet = .trainingConditionEditor
        return .result(opensIntent: OpenAppIntent())
    }
}
