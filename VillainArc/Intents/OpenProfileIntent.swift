import AppIntents
import FCTMetrics
import SwiftData

struct OpenProfileIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentOpenProfile

    static let title: LocalizedStringResource = "Open Profile"
    static let description = IntentDescription("Opens your profile.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        Diag.breadcrumb(Self.diagCrumb)
        let context = SharedModelContainer.container.mainContext
        try SetupGuard.requireReady(context: context)

        AppRouter.shared.collapseActiveFlowPresentations()
        AppRouter.shared.presentAppSheet(.profile)
        return .result(opensIntent: OpenAppIntent())
    }
}
