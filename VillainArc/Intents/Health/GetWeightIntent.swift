import AppIntents
import SwiftData

struct GetWeightIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Weight"
    static let description = IntentDescription("Tells you your latest logged weight for today.")
    static let supportedModes: IntentModes = .background

    nonisolated func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = makeHealthIntentReadContext()
        let snapshot = try loadHealthDaySnapshot(for: .now, context: context)
        return .result(dialog: IntentDialog(stringLiteral: healthMetricDialog(for: .weight, snapshot: snapshot)))
    }
}
