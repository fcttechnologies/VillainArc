import AppIntents
import FCTMetrics

struct ShowSleepGoalHistoryIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentShowSleepGoalHistory

    static let title: LocalizedStringResource = "Show Sleep Goal History"
    static let description = IntentDescription("Opens your sleep goal history.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        Diag.breadcrumb(Self.diagCrumb)
        try openHealthDestination(.sleepGoalHistory)
        return .result(opensIntent: OpenAppIntent())
    }
}
