import AppIntents
import SwiftData

struct GetWristTemperatureIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Wrist Temperature"
    static let description = IntentDescription("Tells you your sleeping wrist temperature for today.")
    static let supportedModes: IntentModes = .background

    nonisolated func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = makeHealthIntentReadContext()
        try SetupGuard.requireReady(context: context)

        guard let entry = try context.fetch(HealthWristTemperature.forDay(.now)).first else {
            return .result(dialog: "You don't have wrist temperature data for today yet.")
        }

        let settings = AppSettingsSnapshot(settings: try context.fetch(AppSettings.single).first)
        return .result(dialog: "Today, your sleeping wrist temperature is \(settings.temperatureUnit.display(entry.temperature)).")
    }
}
