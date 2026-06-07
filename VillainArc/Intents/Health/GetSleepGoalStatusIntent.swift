import AppIntents
import SwiftData

struct GetSleepGoalStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Sleep Goal Status"
    static let description = IntentDescription("Tells you how your current sleep goal is going.")
    static let supportedModes: IntentModes = .background

    nonisolated func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = makeHealthIntentReadContext()
        try SetupGuard.requireReady(context: context)

        guard let goal = try context.fetch(SleepGoal.active).first else {
            return .result(dialog: "You don't have an active sleep goal.")
        }

        let targetText = formattedSleepDurationText(goal.targetSleepDuration)
        guard let lastNight = try context.fetch(HealthSleepNight.forWakeDay(.now)).first?.timeAsleep, lastNight > 0 else {
            return .result(dialog: "Your sleep goal is \(targetText). You don't have sleep data from last night yet.")
        }

        let sleptText = formattedSleepDurationText(lastNight)
        if lastNight >= goal.targetSleepDuration {
            return .result(dialog: "You hit your sleep goal last night, sleeping \(sleptText) against a goal of \(targetText).")
        }

        let remainingText = formattedSleepDurationText(goal.targetSleepDuration - lastNight)
        return .result(dialog: "Your sleep goal is \(targetText). Last night you slept \(sleptText), \(remainingText) short.")
    }
}
