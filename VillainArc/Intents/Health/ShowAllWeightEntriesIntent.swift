import AppIntents
import FCTMetrics

struct ShowAllWeightEntriesIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentShowAllWeightEntries

    static let title: LocalizedStringResource = "Show All Weight Entries"
    static let description = IntentDescription("Opens your complete list of weight entries.")
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        Diag.breadcrumb(Self.diagCrumb)
        try openHealthDestination(.allWeightEntriesList)
        return .result(opensIntent: OpenAppIntent())
    }
}
