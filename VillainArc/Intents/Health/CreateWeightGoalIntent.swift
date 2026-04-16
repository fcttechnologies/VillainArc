import AppIntents
import SwiftData

enum WeightGoalIntentType: String, AppEnum {
    case cut
    case bulk
    case maintain

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Weight Goal Type")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .cut: "Cut",
        .bulk: "Bulk",
        .maintain: "Maintain"
    ]

    var modelValue: WeightGoalType {
        switch self {
        case .cut:
            return .cut
        case .bulk:
            return .bulk
        case .maintain:
            return .maintain
        }
    }
}

struct CreateWeightGoalIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Weight Goal"
    static let description = IntentDescription("Creates or replaces your current weight goal.")
    static let supportedModes: IntentModes = .background
    private static let maintainTargetDeltaKg = 2.0

    static var parameterSummary: some ParameterSummary {
        Summary("Set my \(\.$goalType) goal to \(\.$targetWeight)")
    }

    @Parameter(title: "Goal Type", requestValueDialog: IntentDialog("Should this be a cut, bulk, or maintain goal?"))
    var goalType: WeightGoalIntentType

    @Parameter(title: "Target Weight", requestValueDialog: IntentDialog("What target weight should we use?"))
    var targetWeight: Double

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = SharedModelContainer.container.mainContext
        try SetupGuard.requireReady(context: context)

        let settings = AppSettingsSnapshot(settings: try context.fetch(AppSettings.single).first)
        let targetWeightKg = settings.weightUnit.toKg(targetWeight)
        guard targetWeightKg > 0 else {
            return .result(dialog: "Your target weight needs to be more than 0.")
        }

        let startWeightKg = (try? context.fetch(WeightEntry.latest).first?.weight) ?? targetWeightKg
        let modelGoalType = goalType.modelValue
        if let validationMessage = validationMessage(for: modelGoalType, startWeightKg: startWeightKg, targetWeightKg: targetWeightKg) {
            return .result(dialog: IntentDialog(stringLiteral: validationMessage))
        }

        let goalStartDate = Date()
        if let activeGoal = try context.fetch(WeightGoal.active).first {
            if Calendar.autoupdatingCurrent.isDate(activeGoal.startedAt, inSameDayAs: goalStartDate) {
                context.delete(activeGoal)
            } else {
                activeGoal.endedAt = goalStartDate
                activeGoal.endReason = .replaced
            }
        }

        let goal = WeightGoal(type: modelGoalType, startWeight: startWeightKg, targetWeight: targetWeightKg, targetDate: nil, targetRatePerWeek: nil)
        goal.startedAt = goalStartDate
        context.insert(goal)
        saveContext(context: context)
        HealthMetricWidgetReloader.reloadWeight()

        return .result(dialog: "Your \(modelGoalType.title.lowercased()) goal target is now \(formattedWeightText(targetWeightKg, unit: settings.weightUnit)).")
    }

    private func validationMessage(for type: WeightGoalType, startWeightKg: Double, targetWeightKg: Double) -> String? {
        switch type {
        case .cut:
            if targetWeightKg >= startWeightKg {
                return "Cut goals need a target weight below your starting weight."
            }
        case .bulk:
            if targetWeightKg <= startWeightKg {
                return "Bulk goals need a target weight above your starting weight."
            }
        case .maintain:
            if abs(targetWeightKg - startWeightKg) > Self.maintainTargetDeltaKg {
                return "Maintain goals need a target within 2 kg of your starting weight."
            }
        }
        return nil
    }
}
