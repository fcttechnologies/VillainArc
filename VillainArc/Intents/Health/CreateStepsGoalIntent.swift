import AppIntents
import SwiftData

struct CreateStepsGoalIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Steps Goal"
    static let description = IntentDescription("Creates or replaces your current steps goal.")
    static let supportedModes: IntentModes = .background

    static var parameterSummary: some ParameterSummary {
        Summary("Set my steps goal to \(\.$targetSteps)")
    }

    @Parameter(title: "Target Steps", requestValueDialog: IntentDialog("What should your steps goal be?"))
    var targetSteps: Int

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = SharedModelContainer.container.mainContext
        try SetupGuard.requireReady(context: context)

        let normalizedTarget = max(0, targetSteps)
        guard normalizedTarget > 0 else {
            return .result(dialog: "Your steps goal needs to be more than 0.")
        }

        let calendar = Calendar.autoupdatingCurrent
        let todayStart = calendar.startOfDay(for: .now)

        if let activeGoal = try context.fetch(StepsGoal.active).first {
            if activeGoal.startedOnDay == todayStart {
                context.delete(activeGoal)
            } else {
                activeGoal.endedOnDay = calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
            }
        }

        let goal = StepsGoal(startedOnDay: todayStart, targetSteps: normalizedTarget)
        context.insert(goal)
        try? StepsGoalEvaluator.reevaluateAchievement(forDay: todayStart, context: context, trigger: .goalChange)
        try? StepsCoachingEvaluator.reconcileTodayForGoalChange(context: context)
        saveContext(context: context)

        return .result(dialog: "Your steps goal is now \(normalizedTarget.formatted(.number)) steps.")
    }
}
