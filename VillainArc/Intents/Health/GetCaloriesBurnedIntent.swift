import AppIntents
import FCTMetrics
import SwiftData

struct GetCaloriesBurnedIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentGetCaloriesBurned

    static let title: LocalizedStringResource = "Get Calories Burned"
    static let description = IntentDescription("Tells you how many calories you burned today.")
    static let supportedModes: IntentModes = .background

    nonisolated func perform() async throws -> some IntentResult & ProvidesDialog {
        func run() async throws -> some IntentResult & ProvidesDialog {
            let context = makeHealthIntentReadContext()
            let snapshot = try loadHealthDaySnapshot(for: .now, context: context)
            return .result(dialog: IntentDialog(stringLiteral: healthMetricDialog(for: .caloriesBurned, snapshot: snapshot)))
        }
        return try await Diag.intent(Self.diagCrumb, run)
    }
}
