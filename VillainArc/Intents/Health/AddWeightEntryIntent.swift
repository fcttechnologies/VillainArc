import AppIntents
import Foundation
import SwiftData

struct AddWeightEntryIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Weight Entry"
    static let description = IntentDescription("Logs a new weight entry for right now.")
    static let supportedModes: IntentModes = .background

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$weight)")
    }

    @Parameter(title: "Weight", requestValueDialog: IntentDialog("What weight would you like to log?"))
    var weight: Double

    private let goalAchievementToleranceKg = 0.1

    @MainActor func perform() async throws -> some IntentResult {
        let context = SharedModelContainer.container.mainContext
        try SetupGuard.requireReady(context: context)

        let settings = AppSettingsSnapshot(settings: try context.fetch(AppSettings.single).first)
        let weightInKg = settings.weightUnit.toKg(weight)
        guard weightInKg > 0 else {
            return .result(dialog: "Your weight entry needs to be more than 0.")
        }

        let entry = WeightEntry(date: .now, weight: weightInKg)
        let activeGoal = try context.fetch(WeightGoal.active).first
        let reachedGoal = activeGoal.map { $0.contains(entry.date) && $0.reachesTarget(with: entry.weight, toleranceKg: goalAchievementToleranceKg) } == true

        context.insert(entry)
        saveContext(context: context)
        HealthMetricWidgetReloader.reloadWeight()

        await HealthExportCoordinator.shared.exportIfEligible(weightEntryID: entry.id)

        let weightText = formattedWeightText(entry.weight, unit: settings.weightUnit)
        if reachedGoal, let activeGoal {
            AppRouter.shared.presentWeightGoalCompletion(for: activeGoal, trigger: .achievedByEntry, triggeringEntry: entry, referenceDate: entry.date)
            return .result(opensIntent: OpenAppIntent(), dialog: "Logged \(weightText). You also reached your \(activeGoal.type.title.lowercased()) goal.")
        }

        return .result(dialog: "Logged \(weightText).")
    }
}
