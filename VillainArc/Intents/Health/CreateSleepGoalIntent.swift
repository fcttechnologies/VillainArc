import AppIntents
import Foundation
import SwiftData

struct CreateSleepGoalIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Sleep Goal"
    static let description = IntentDescription("Creates or replaces your current sleep goal.")
    static let supportedModes: IntentModes = .background
    private static let minimumGoalSeconds: Double = 4 * 3_600
    private static let maximumGoalSeconds: Double = 12 * 3_600

    static var parameterSummary: some ParameterSummary {
        Summary("Set my sleep goal to \(\.$duration)")
    }

    @Parameter(title: "Duration", defaultUnit: .hours, supportsNegativeNumbers: false, requestValueDialog: IntentDialog("How much sleep should you aim for each night?"))
    var duration: Measurement<UnitDuration>

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = SharedModelContainer.container.mainContext
        try SetupGuard.requireReady(context: context)

        let seconds = duration.converted(to: .seconds).value
        guard seconds > 0 else {
            return .result(dialog: "Your sleep goal needs to be more than 0.")
        }

        let normalizedGoalDuration = normalizedGoalDurationSeconds(seconds)
        _ = try? SleepGoal.replaceActiveGoal(with: normalizedGoalDuration, context: context)
        saveContext(context: context)
        HealthMetricWidgetReloader.reloadSleep()

        return .result(dialog: "Your sleep goal is now \(formattedDurationText(normalizedGoalDuration)). Changes apply starting tomorrow.")
    }

    private func normalizedGoalDurationSeconds(_ seconds: Double) -> TimeInterval {
        let clamped = min(max(seconds, Self.minimumGoalSeconds), Self.maximumGoalSeconds)
        let roundedToQuarterHour = (clamped / 900).rounded() * 900
        return min(max(roundedToQuarterHour, Self.minimumGoalSeconds), Self.maximumGoalSeconds)
    }

    private func formattedDurationText(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 2
        return formatter.string(from: duration) ?? "0 minutes"
    }
}
