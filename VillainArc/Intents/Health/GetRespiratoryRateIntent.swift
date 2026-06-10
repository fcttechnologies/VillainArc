import AppIntents
import SwiftData

struct GetRespiratoryRateIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Respiratory Rate"
    static let description = IntentDescription("Tells you your respiratory rate range for today.")
    static let supportedModes: IntentModes = .background

    nonisolated func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = makeHealthIntentReadContext()
        return .result(dialog: IntentDialog(stringLiteral: try respiratoryRateDialog(for: .now, context: context)))
    }
}
