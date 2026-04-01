import AppIntents

struct OpenTrainingConditionHistoryIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Training Condition History"
    static let description = IntentDescription("Opens your training condition history.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        try openHealthDestination(.trainingConditionHistory)
        return .result(opensIntent: OpenAppIntent())
    }
}
