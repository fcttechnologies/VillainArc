import AppIntents
import FCTMetrics

struct ShowHealthTrendsIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentShowHealthTrends

    static let title: LocalizedStringResource = "Show Health Trends"
    static let description = IntentDescription("Opens trend views for your key health metrics.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        Diag.breadcrumb(Self.diagCrumb)
        try openHealthDestination(.healthTrends)
        return .result(opensIntent: OpenAppIntent())
    }
}
