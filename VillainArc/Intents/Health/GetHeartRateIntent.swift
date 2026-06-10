import AppIntents
import SwiftData

struct GetHeartRateIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Heart Rate"
    static let description = IntentDescription("Tells you your heart vitals for today — resting heart rate, range, and variability.")
    static let supportedModes: IntentModes = .background

    nonisolated func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = makeHealthIntentReadContext()
        return .result(dialog: IntentDialog(stringLiteral: try heartRateDialog(for: .now, context: context)))
    }
}
