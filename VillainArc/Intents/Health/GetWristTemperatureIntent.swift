import AppIntents
import FCTMetrics
import SwiftData

struct GetWristTemperatureIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentGetWristTemperature

    static let title: LocalizedStringResource = "Get Wrist Temperature"
    static let description = IntentDescription("Tells you your sleeping wrist temperature for today.")
    static let supportedModes: IntentModes = .background

    nonisolated func perform() async throws -> some IntentResult & ProvidesDialog {
        func run() async throws -> some IntentResult & ProvidesDialog {
            let context = makeHealthIntentReadContext()
            return .result(dialog: IntentDialog(stringLiteral: try wristTemperatureDialog(for: .now, context: context)))
        }
        return try await Diag.intent(Self.diagCrumb, run)
    }
}
