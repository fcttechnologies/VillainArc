import AppIntents
import FCTMetrics
import SwiftData

struct OpenSettingsIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentOpenSettings

    static let title: LocalizedStringResource = "Open Settings"
    static let description = IntentDescription("Opens app settings.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        Diag.breadcrumb(Self.diagCrumb)
        let context = SharedModelContainer.container.mainContext
        try SetupGuard.requireReady(context: context)

        AppRouter.shared.presentSettingsFromSystem()
        return .result(opensIntent: OpenAppIntent())
    }
}
