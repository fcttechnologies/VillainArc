import AppIntents
import SwiftData

struct GetStepsGoalStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Steps Goal Status"
    static let description = IntentDescription("Tells you how your current steps goal is going today.")
    static let supportedModes: IntentModes = .background

    nonisolated func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = makeHealthIntentReadContext()
        try SetupGuard.requireReady(context: context)

        guard let goal = try context.fetch(StepsGoal.active).first else {
            return .result(dialog: "You don't have an active steps goal.")
        }

        let todayEntry = try context.fetch(HealthStepsDistance.forDay(.now)).first
        let currentSteps = todayEntry?.stepCount ?? 0

        if todayEntry?.goalCompleted == true {
            return .result(dialog: "You've already hit your steps goal today with \(currentSteps.formatted(.number)) steps against a goal of \(goal.targetSteps.formatted(.number)).")
        }

        let remaining = max(goal.targetSteps - currentSteps, 0)
        return .result(dialog: "Your steps goal is \(goal.targetSteps.formatted(.number)) steps. You're at \(currentSteps.formatted(.number)) today, with \(remaining.formatted(.number)) to go.")
    }
}
