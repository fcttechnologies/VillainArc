import AppIntents
import FCTMetrics
import SwiftData

struct GetHealthMetricIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentGetHealthMetric

    static let title: LocalizedStringResource = "Get Health Metric"
    static let description = IntentDescription("Tells you a health metric for today.")
    static let supportedModes: IntentModes = .background

    static var parameterSummary: some ParameterSummary {
        Summary("Get \(\.$metric)")
    }

    @Parameter(title: "Metric") var metric: HealthMetric

    nonisolated func perform() async throws -> some IntentResult & ProvidesDialog {
        Diag.breadcrumb(Self.diagCrumb)
        let context = makeHealthIntentReadContext()
        let snapshot = try loadHealthDaySnapshot(for: .now, context: context)
        return .result(dialog: IntentDialog(stringLiteral: healthMetricDialog(for: metric, snapshot: snapshot)))
    }
}
