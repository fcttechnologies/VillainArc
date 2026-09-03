import AppIntents
import FCTMetrics

struct ShowSleepInsightsIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentShowSleepInsights

    static let title: LocalizedStringResource = "Show Sleep Insights"
    static let description = IntentDescription("Opens your sleep timing patterns and consistency score.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        func run() async throws -> some IntentResult & OpensIntent {
            try openHealthDestination(.sleepTimingInsights)
            return .result(opensIntent: OpenAppIntent())
        }
        return try await Diag.intent(Self.diagCrumb, run)
    }
}
