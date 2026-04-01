import AppIntents
import SwiftData

struct EndTrainingConditionIntent: AppIntent {
    static let title: LocalizedStringResource = "End Training Condition"
    static let description = IntentDescription("Ends your current training condition and returns you to training normally.")
    static let supportedModes: IntentModes = .background

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = SharedModelContainer.container.mainContext
        try SetupGuard.requireReady(context: context)

        guard let activeCondition = try context.fetch(TrainingConditionPeriod.activeNow).first else {
            return .result(dialog: "You're already training normally.")
        }

        let conditionTitle = activeCondition.kind.title
        try TrainingConditionStore.endActiveCondition(activeCondition, on: .now, context: context)
        return .result(dialog: "Ended your \(conditionTitle.lowercased()) status. You're back to training normally.")
    }
}
