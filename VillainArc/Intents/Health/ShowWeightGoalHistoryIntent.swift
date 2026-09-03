import AppIntents
import FCTMetrics

struct ShowWeightGoalHistoryIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentShowWeightGoalHistory

    static let title: LocalizedStringResource = "Show Weight Goal History"
    static let description = IntentDescription("Opens your weight goal history.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        Diag.breadcrumb(Self.diagCrumb)
        try openHealthDestination(.weightGoalHistory)
        return .result(opensIntent: OpenAppIntent())
    }
}
