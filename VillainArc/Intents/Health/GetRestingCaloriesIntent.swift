import AppIntents
import FCTMetrics
import SwiftData

struct GetRestingCaloriesIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentGetRestingCalories

    static let title: LocalizedStringResource = "Get Resting Calories"
    static let description = IntentDescription("Tells you your resting calories burned today.")
    static let supportedModes: IntentModes = .background

    nonisolated func perform() async throws -> some IntentResult & ProvidesDialog {
        Diag.breadcrumb(Self.diagCrumb)
        let context = makeHealthIntentReadContext()
        let snapshot = try loadHealthDaySnapshot(for: .now, context: context)

        guard let restingEnergy = snapshot.restingEnergyKilocalories else {
            return .result(dialog: "You don't have resting calories data for today.")
        }

        return .result(dialog: "Today you've burned \(formattedEnergyText(restingEnergy, unit: snapshot.settings.energyUnit)) resting.")
    }
}
