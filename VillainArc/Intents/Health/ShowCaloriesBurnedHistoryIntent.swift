import AppIntents

struct ShowCaloriesBurnedHistoryIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Calories Burned History"
    static let description = IntentDescription("Opens your calories burned history.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        try openHealthDestination(.energyHistory)
        return .result(opensIntent: OpenAppIntent())
    }
}
