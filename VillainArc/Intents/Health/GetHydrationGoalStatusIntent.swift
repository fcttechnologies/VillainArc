import AppIntents
import SwiftData

struct GetHydrationGoalStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Hydration Goal Status"
    static let description = IntentDescription("Tells you how your current hydration goal is going today.")
    static let supportedModes: IntentModes = .background

    nonisolated func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = makeHealthIntentReadContext()
        try SetupGuard.requireReady(context: context)

        guard let goal = try context.fetch(HydrationGoal.active).first else {
            return .result(dialog: "You don't have an active hydration goal.")
        }

        let settings = AppSettingsSnapshot(settings: try context.fetch(AppSettings.single).first)
        let total = try context.fetch(HydrationDay.forDay(.now)).first?.totalVolume ?? 0
        let targetText = settings.hydrationUnit.display(goal.targetML)
        let totalText = settings.hydrationUnit.display(total)

        if total >= goal.targetML {
            return .result(dialog: "You've hit your hydration goal today with \(totalText) against a goal of \(targetText).")
        }

        let remainingText = settings.hydrationUnit.display(max(goal.targetML - total, 0))
        return .result(dialog: "Your hydration goal is \(targetText). You're at \(totalText) today, with \(remainingText) to go.")
    }
}
