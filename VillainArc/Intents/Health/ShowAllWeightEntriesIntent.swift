import AppIntents

struct ShowAllWeightEntriesIntent: AppIntent {
    static let title: LocalizedStringResource = "Show All Weight Entries"
    static let description = IntentDescription("Opens your complete list of weight entries.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        try openHealthDestination(.allWeightEntriesList)
        return .result(opensIntent: OpenAppIntent())
    }
}
