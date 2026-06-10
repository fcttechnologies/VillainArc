import AppIntents
import SwiftData

struct GetHydrationIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Hydration"
    static let description = IntentDescription("Tells you how much water you've had today.")
    static let supportedModes: IntentModes = .background

    nonisolated func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = makeHealthIntentReadContext()
        return .result(dialog: IntentDialog(stringLiteral: try hydrationDialog(for: .now, context: context)))
    }
}
