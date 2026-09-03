import AppIntents
import FCTMetrics
import SwiftData

struct GetDistanceIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentGetDistance

    static let title: LocalizedStringResource = "Get Distance"
    static let description = IntentDescription("Tells you how far you walked or ran today.")
    static let supportedModes: IntentModes = .background

    nonisolated func perform() async throws -> some IntentResult & ProvidesDialog {
        func run() async throws -> some IntentResult & ProvidesDialog {
            let context = makeHealthIntentReadContext()
            let snapshot = try loadHealthDaySnapshot(for: .now, context: context)
            return .result(dialog: IntentDialog(stringLiteral: healthMetricDialog(for: .distance, snapshot: snapshot)))
        }
        return try await Diag.intent(Self.diagCrumb, run)
    }
}
