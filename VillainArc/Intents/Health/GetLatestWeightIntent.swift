import AppIntents
import SwiftData

struct GetLatestWeightIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Latest Weight"
    static let description = IntentDescription("Tells you your latest logged weight.")
    static let supportedModes: IntentModes = .background

    nonisolated func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = makeHealthIntentReadContext()
        try SetupGuard.requireReady(context: context)

        let settings = AppSettingsSnapshot(settings: try context.fetch(AppSettings.single).first)
        guard let latestEntry = try context.fetch(WeightEntry.latest).first else {
            return .result(dialog: "You don't have any weight entries yet.")
        }

        let weightText = formattedWeightText(latestEntry.weight, unit: settings.weightUnit)
        let dateText = formattedRecentDayAndTime(latestEntry.date)
        return .result(dialog: "Your latest logged weight was \(weightText) on \(dateText).")
    }
}
