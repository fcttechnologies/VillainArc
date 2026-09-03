import AppIntents
import FCTMetrics
import SwiftData

struct GetHeartRateIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentGetHeartRate

    static let title: LocalizedStringResource = "Get Heart Rate"
    static let description = IntentDescription("Tells you your heart vitals for today — resting heart rate, range, and variability.")
    static let supportedModes: IntentModes = .background

    nonisolated func perform() async throws -> some IntentResult & ProvidesDialog {
        func run() async throws -> some IntentResult & ProvidesDialog {
            let context = makeHealthIntentReadContext()
            return .result(dialog: IntentDialog(stringLiteral: try heartRateDialog(for: .now, context: context)))
        }
        return try await Diag.intent(Self.diagCrumb, run)
    }
}
