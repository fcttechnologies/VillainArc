import AppIntents
import FCTMetrics
import SwiftData

struct GetSleepIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentGetSleep

    static let title: LocalizedStringResource = "Get Sleep"
    static let description = IntentDescription("Tells you how much you slept for today.")
    static let supportedModes: IntentModes = .background

    nonisolated func perform() async throws -> some IntentResult & ProvidesDialog {
        Diag.breadcrumb(Self.diagCrumb)
        let context = makeHealthIntentReadContext()
        let snapshot = try loadHealthDaySnapshot(for: .now, context: context)
        return .result(dialog: IntentDialog(stringLiteral: healthMetricDialog(for: .sleep, snapshot: snapshot)))
    }
}
