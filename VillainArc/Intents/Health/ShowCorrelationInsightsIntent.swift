import AppIntents
import FCTMetrics

struct ShowCorrelationInsightsIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentShowCorrelationInsights

    static let title: LocalizedStringResource = "Show Performance Correlations"
    static let description = IntentDescription("Opens the correlation between your sleep, RPE, and session quality.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        Diag.breadcrumb(Self.diagCrumb)
        try openHealthDestination(.correlationInsights)
        return .result(opensIntent: OpenAppIntent())
    }
}
