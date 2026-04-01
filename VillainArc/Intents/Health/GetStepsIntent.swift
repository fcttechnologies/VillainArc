import AppIntents
import SwiftData

struct GetStepsIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Steps"
    static let description = IntentDescription("Tells you your step count for today.")
    static let supportedModes: IntentModes = .background

    nonisolated func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = makeHealthIntentReadContext()
        let snapshot = try loadHealthDaySnapshot(for: .now, context: context)
        return .result(dialog: IntentDialog(stringLiteral: healthMetricDialog(for: .steps, snapshot: snapshot)))
    }
}
