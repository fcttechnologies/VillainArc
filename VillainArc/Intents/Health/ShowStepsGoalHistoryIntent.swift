import AppIntents
import FCTMetrics

struct ShowStepsGoalHistoryIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentShowStepsGoalHistory

    static let title: LocalizedStringResource = "Show Steps Goal History"
    static let description = IntentDescription("Opens your steps goal history.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        Diag.breadcrumb(Self.diagCrumb)
        try openHealthDestination(.stepsGoalHistory)
        return .result(opensIntent: OpenAppIntent())
    }
}
