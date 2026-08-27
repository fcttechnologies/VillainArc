import FCTAccount
import FCTMetrics
import Foundation

/// Villain Arc's performance domains, fed to `FCTMetrics.MetricsService` (the shared collector
/// this app's original in-repo implementation was extracted into).
enum VAMetricsDomain: String, MetricsDomain, CaseIterable {
    case launch = "com.fcttechnologies.villainarc.launch"
    case healthSync = "com.fcttechnologies.villainarc.health-sync"
    case aiPlanGeneration = "com.fcttechnologies.villainarc.ai-plan-generation"
    case aiExerciseReplacement = "com.fcttechnologies.villainarc.ai-exercise-replacement"
    case askAssistant = "com.fcttechnologies.villainarc.ask-assistant"
    case subscriptionEntitlementRefresh = "com.fcttechnologies.villainarc.subscription-entitlement-refresh"
}

/// The one metrics collector, plus the launch call that starts the always-on diagnostics client.
nonisolated enum VAMetrics {
    static let service = MetricsService<VAMetricsDomain>(
        configuration: MetricsConfiguration(appGroupID: SharedModelContainer.appGroupID)
    )

    /// Register MetricKit collection and start the FCT Diagnostics client. Called once at app
    /// init; both halves are idempotent and no-op where their platform pieces are unavailable.
    static func start() {
        service.register(enabledDomains: Array(VAMetricsDomain.allCases))
        Diag.start(DiagConfiguration(
            endpoint: AccountEnvironment.fct.baseURL.appendingPathComponent("functions/v1/diag-ingest"),
            appGroupID: SharedModelContainer.appGroupID
        ))
    }
}
