import AppIntents
import SwiftData

struct GetActiveCaloriesIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Active Calories"
    static let description = IntentDescription("Tells you your active calories burned today.")
    static let supportedModes: IntentModes = .background

    nonisolated func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = makeHealthIntentReadContext()
        let snapshot = try loadHealthDaySnapshot(for: .now, context: context)

        guard let activeEnergy = snapshot.activeEnergyKilocalories else {
            return .result(dialog: "You don't have active calories data for today.")
        }

        return .result(dialog: "Today you've burned \(formattedEnergyText(activeEnergy, unit: snapshot.settings.energyUnit)) active.")
    }
}
