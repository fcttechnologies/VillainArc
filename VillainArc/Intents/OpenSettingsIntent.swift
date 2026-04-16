import AppIntents
import SwiftData

struct OpenSettingsIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Settings"
    static let description = IntentDescription("Opens app settings.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        let context = SharedModelContainer.container.mainContext
        try SetupGuard.requireReady(context: context)

        AppRouter.shared.collapseActiveFlowPresentations()
        AppRouter.shared.presentAppSheet(.settings)
        return .result(opensIntent: OpenAppIntent())
    }
}
