import AppIntents
import SwiftData

struct OpenProfileIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Profile"
    static let description = IntentDescription("Opens your profile.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        let context = SharedModelContainer.container.mainContext
        try SetupGuard.requireReady(context: context)

        AppRouter.shared.collapseActiveFlowPresentations()
        AppRouter.shared.presentAppSheet(.profile)
        return .result(opensIntent: OpenAppIntent())
    }
}
