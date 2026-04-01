import AppIntents
import SwiftData

struct GetCaloriesBurnedIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Calories Burned"
    static let description = IntentDescription("Tells you how many calories you burned today.")
    static let supportedModes: IntentModes = .background

    nonisolated func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = makeHealthIntentReadContext()
        let snapshot = try loadHealthDaySnapshot(for: .now, context: context)
        return .result(dialog: IntentDialog(stringLiteral: healthMetricDialog(for: .caloriesBurned, snapshot: snapshot)))
    }
}
