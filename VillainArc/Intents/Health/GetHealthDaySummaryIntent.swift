import AppIntents
import SwiftData

struct GetHealthDaySummaryIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Health Day Summary"
    static let description = IntentDescription("Summarizes your health metrics for today.")
    static let supportedModes: IntentModes = .background

    nonisolated func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = makeHealthIntentReadContext()
        let snapshot = try loadHealthDaySnapshot(for: .now, context: context)
        return .result(dialog: IntentDialog(stringLiteral: healthDaySummaryDialog(for: snapshot)))
    }
}
