import AppIntents
import FCTMetrics

struct ShowCaloriesBurnedHistoryIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentShowCaloriesBurnedHistory

    static let title: LocalizedStringResource = "Show Calories Burned History"
    static let description = IntentDescription("Opens your calories burned history.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        func run() async throws -> some IntentResult & OpensIntent {
            try openHealthDestination(.energyHistory)
            return .result(opensIntent: OpenAppIntent())
        }
        return try await Diag.intent(Self.diagCrumb, run)
    }
}
