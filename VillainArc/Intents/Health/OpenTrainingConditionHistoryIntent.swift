import AppIntents
import FCTMetrics

struct OpenTrainingConditionHistoryIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentOpenTrainingConditionHistory

    static let title: LocalizedStringResource = "Open Training Condition History"
    static let description = IntentDescription("Opens your training condition history.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        func run() async throws -> some IntentResult & OpensIntent {
            try openHealthDestination(.trainingConditionHistory)
            return .result(opensIntent: OpenAppIntent())
        }
        return try await Diag.intent(Self.diagCrumb, run)
    }
}
