import AppIntents
import SwiftData

struct AddHydrationEntryIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Hydration Entry"
    static let description = IntentDescription("Logs a water intake entry using your current hydration unit.")
    static let supportedModes: IntentModes = .background

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$volume) of water")
    }

    @Parameter(title: "Volume", requestValueDialog: IntentDialog("How much water would you like to log?"))
    var volume: Double

    @Parameter(title: "Date", description: "When to log the water. Leave empty for now.")
    var date: Date?

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = SharedModelContainer.container.mainContext
        try SetupGuard.requireReady(context: context)

        let settings = AppSettingsSnapshot(settings: try context.fetch(AppSettings.single).first)
        let volumeML = settings.hydrationUnit.toML(volume)
        guard volumeML > 0 else {
            return .result(dialog: "Your water entry needs to be more than 0.")
        }

        let entryDate = date ?? .now
        let entry = HydrationEntry(date: entryDate, volume: volumeML)
        context.insert(entry)
        let hydrationGoalNotification = try? HydrationDay.reconcile(for: entryDate, context: context)
        saveContext(context: context)
        HealthMetricWidgetReloader.reloadHydration()

        if let hydrationGoalNotification,
           hydrationGoalNotification.didCompleteGoal,
           let targetML = hydrationGoalNotification.day.goalTargetML {
            await NotificationCoordinator.deliverHydrationGoal(HydrationGoalNotification(date: hydrationGoalNotification.day.date, totalVolume: hydrationGoalNotification.day.totalVolume, targetML: targetML))
        }
        await HealthExportCoordinator.shared.exportIfEligible(hydrationEntryID: entry.id)

        let volumeText = settings.hydrationUnit.display(volumeML)
        if hydrationGoalNotification?.didCompleteGoal == true,
           let targetML = hydrationGoalNotification?.day.goalTargetML {
            return .result(dialog: "Logged \(volumeText) of water. You also reached your \(settings.hydrationUnit.display(targetML)) hydration goal.")
        }

        return .result(dialog: "Logged \(volumeText) of water.")
    }
}
