import AppIntents
import SwiftData

struct GetWristTemperatureIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Wrist Temperature"
    static let description = IntentDescription("Tells you your sleeping wrist temperature for today.")
    static let supportedModes: IntentModes = .background

    nonisolated func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = makeHealthIntentReadContext()
        return .result(dialog: IntentDialog(stringLiteral: try wristTemperatureDialog(for: .now, context: context)))
    }
}
