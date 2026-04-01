import AppIntents
import SwiftData

struct GetSleepIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Sleep"
    static let description = IntentDescription("Tells you how much you slept for today.")
    static let supportedModes: IntentModes = .background

    nonisolated func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = makeHealthIntentReadContext()
        let snapshot = try loadHealthDaySnapshot(for: .now, context: context)
        return .result(dialog: IntentDialog(stringLiteral: healthMetricDialog(for: .sleep, snapshot: snapshot)))
    }
}
