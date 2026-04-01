import AppIntents
import SwiftData

struct GetDistanceIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Distance"
    static let description = IntentDescription("Tells you how far you walked or ran today.")
    static let supportedModes: IntentModes = .background

    nonisolated func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = makeHealthIntentReadContext()
        let snapshot = try loadHealthDaySnapshot(for: .now, context: context)
        return .result(dialog: IntentDialog(stringLiteral: healthMetricDialog(for: .distance, snapshot: snapshot)))
    }
}
