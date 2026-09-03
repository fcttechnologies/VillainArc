import AppIntents
import FCTMetrics
import SwiftData

struct CreateHydrationGoalIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentCreateHydrationGoal

    static let title: LocalizedStringResource = "Create Hydration Goal"
    static let description = IntentDescription("Creates or replaces your current hydration goal using your current hydration unit.")
    static let supportedModes: IntentModes = .background

    static var parameterSummary: some ParameterSummary {
        Summary("Set my hydration goal to \(\.$targetVolume)")
    }

    @Parameter(title: "Target Volume", requestValueDialog: IntentDialog("What should your hydration goal be?"))
    var targetVolume: Double

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        Diag.breadcrumb(Self.diagCrumb)
        let context = SharedModelContainer.container.mainContext
        try SetupGuard.requireReady(context: context)

        let settings = AppSettingsSnapshot(settings: try context.fetch(AppSettings.single).first)
        let targetML = settings.hydrationUnit.toML(targetVolume)
        guard targetML > 0 else {
            return .result(dialog: "Your hydration goal needs to be more than 0.")
        }

        let calendar = Calendar.autoupdatingCurrent
        let todayStart = calendar.startOfDay(for: .now)

        if let activeGoal = try context.fetch(HydrationGoal.active).first {
            if activeGoal.startedOnDay == todayStart {
                context.delete(activeGoal)
            } else {
                activeGoal.endedOnDay = calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
            }
        }

        let goal = HydrationGoal(startedOnDay: todayStart, targetML: targetML)
        context.insert(goal)
        try? HydrationDay.reconcileAll(context: context)
        saveContext(context: context)
        HealthMetricWidgetReloader.reloadHydration()

        return .result(dialog: "Your hydration goal is now \(settings.hydrationUnit.display(targetML)).")
    }
}
