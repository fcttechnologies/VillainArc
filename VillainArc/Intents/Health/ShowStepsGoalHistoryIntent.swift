import AppIntents

struct ShowStepsGoalHistoryIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Steps Goal History"
    static let description = IntentDescription("Opens your steps goal history.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        try openHealthDestination(.stepsGoalHistory)
        return .result(opensIntent: OpenAppIntent())
    }
}
