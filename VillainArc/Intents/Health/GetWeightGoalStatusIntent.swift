import AppIntents
import SwiftData

struct GetWeightGoalStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Weight Goal Status"
    static let description = IntentDescription("Tells you how your current weight goal is going.")
    static let supportedModes: IntentModes = .background

    nonisolated func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = makeHealthIntentReadContext()
        try SetupGuard.requireReady(context: context)

        let settings = AppSettingsSnapshot(settings: try context.fetch(AppSettings.single).first)
        guard let goal = try context.fetch(WeightGoal.active).first else {
            return .result(dialog: "You don't have an active weight goal.")
        }

        guard let latestEntry = try context.fetch(WeightEntry.latest).first else {
            let targetText = formattedWeightText(goal.targetWeight, unit: settings.weightUnit)
            return .result(dialog: "Your current weight goal is to \(goal.type.title.lowercased()) to \(targetText), but you don't have any weight entries yet.")
        }

        let titleText: String
        if goal.type == .maintain {
            titleText = "maintain around \(formattedWeightText(goal.targetWeight, unit: settings.weightUnit))"
        } else {
            titleText = "\(goal.type.title.lowercased()) to \(formattedWeightText(goal.targetWeight, unit: settings.weightUnit))"
        }

        var details = ["Your current weight goal is to \(titleText).", "Your latest weight is \(formattedWeightText(latestEntry.weight, unit: settings.weightUnit))."]
        if goal.type != .maintain {
            details.append("Progress is \(weightGoalProgressText(goal: goal, currentWeight: latestEntry.weight, unit: settings.weightUnit)).")
        }
        if let targetDate = goal.targetDate {
            details.append("Target date is \(formattedRecentDay(targetDate)).")
        }

        return .result(dialog: IntentDialog(stringLiteral: details.joined(separator: " ")))
    }
}
