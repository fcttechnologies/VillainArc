import AppIntents
import FCTMetrics
import SwiftData

struct GetTrainingConditionIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentGetTrainingCondition

    static let title: LocalizedStringResource = "Get Training Condition"
    static let description = IntentDescription("Tells you your current training condition.")
    static let supportedModes: IntentModes = .background

    nonisolated func perform() async throws -> some IntentResult & ProvidesDialog {
        Diag.breadcrumb(Self.diagCrumb)
        let context = makeHealthIntentReadContext()
        try SetupGuard.requireReady(context: context)

        guard let condition = try context.fetch(TrainingConditionPeriod.activeNow).first else {
            return .result(dialog: "You're training normally.")
        }

        var parts = [condition.kind.title, condition.trainingImpact.title]
        if let endDay = TrainingConditionStore.displayedEndDay(for: condition.endDate) {
            parts.append("ending \(formattedRecentDay(endDay))")
        }
        if condition.kind.usesAffectedMuscles, condition.hasAffectedMuscles {
            parts.append("affecting \(ListFormatter.localizedString(byJoining: condition.sortedAffectedMuscles.map(\.displayName)))")
        }

        return .result(dialog: "Your current training condition is \(parts.joined(separator: ", ")).")
    }
}
