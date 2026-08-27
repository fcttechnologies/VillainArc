import FCTMetrics
import Foundation
import Observation
import SwiftUI

/// The five paywalled premium features in Villain Arc 1.3. Identifier for `SubscriptionGate.require`
/// and for `PaywallPresenter.present(for:)` so the paywall can spotlight the triggering feature.
enum PremiumFeature: String, CaseIterable, Identifiable, Hashable {
    case aiPlanGeneration
    case aiExerciseReplacement
    case healthTrends
    case sleepTimingInsights
    case correlationInsights

    var id: String { rawValue }

    var displayName: LocalizedStringResource {
        switch self {
        case .aiPlanGeneration: return "AI Plan Generation"
        case .aiExerciseReplacement: return "AI Exercise Replacement"
        case .healthTrends: return "Health Trends"
        case .sleepTimingInsights: return "Sleep Timing Insights"
        case .correlationInsights: return "Correlation Insights"
        }
    }

    var systemImage: String {
        switch self {
        case .aiPlanGeneration: return "sparkles"
        case .aiExerciseReplacement: return "arrow.triangle.2.circlepath"
        case .healthTrends: return "chart.line.uptrend.xyaxis"
        case .sleepTimingInsights: return "moon.stars.fill"
        case .correlationInsights: return "chart.dots.scatter"
        }
    }

    var tint: Color {
        switch self {
        case .aiPlanGeneration, .aiExerciseReplacement: return .purple
        case .healthTrends: return .teal
        case .sleepTimingInsights: return .indigo
        case .correlationInsights: return .orange
        }
    }

    var description: LocalizedStringResource {
        switch self {
        case .aiPlanGeneration:
            return "Generate complete plans with on-device AI from a single sentence."
        case .aiExerciseReplacement:
            return "Smarter substitutions reasoned over your training context."
        case .healthTrends:
            return "Long-range trends across weight, sleep, heart rate, energy, steps, and volume."
        case .sleepTimingInsights:
            return "Bedtime consistency, scatter, and shifts at a glance."
        case .correlationInsights:
            return "How sleep and RPE shape your session quality."
        }
    }

    var promoHeadline: LocalizedStringResource {
        switch self {
        case .aiPlanGeneration: return "Unlock AI Plan Generation"
        case .aiExerciseReplacement: return "Unlock AI Exercise Replacement"
        case .healthTrends: return "Unlock Health Trends"
        case .sleepTimingInsights: return "Unlock Sleep Timing Insights"
        case .correlationInsights: return "Unlock Correlation Insights"
        }
    }
}

/// Gate helper used at every premium-feature call site. Reads the live `SubscriptionStore.status`
/// and falls back to the App Group cache to avoid a paywall flash before StoreKit has resolved.
@MainActor
enum SubscriptionGate {
    /// True when the current entitlement gives Pro access, including free trial and grace period.
    /// When `status == .unknown` (first launch, products not yet fetched), trusts the App Group
    /// `cachedIsPro` flag so a known-Pro user doesn't see a flash of paywall on cold launch.
    static var isPro: Bool {
        #if DEBUG
        if DebugSubscriptionOverride.forcePro { return true }
        #endif
        let live = SubscriptionStore.shared.status
        if live.isPro { return true }
        if live == .unknown { return SubscriptionStore.cachedIsPro }
        return false
    }

    /// Runs `action` if the user has Pro access. Otherwise presents the paywall for the given feature.
    static func require(_ feature: PremiumFeature, _ action: () -> Void) {
        if isPro {
            action()
        } else {
            PaywallPresenter.shared.present(for: feature)
        }
    }
}

/// Drives the single global paywall sheet. `ContentView` mounts a full-screen cover bound to
/// `PaywallPresenter.shared.trigger`; call sites set it via `SubscriptionGate.require`.
@MainActor
@Observable
final class PaywallPresenter {
    static let shared = PaywallPresenter()

    var trigger: PremiumFeature?

    private init() {}

    func present(for feature: PremiumFeature) {
        Haptics.selection()
        trigger = feature
        Diag.breadcrumb(VACrumb.paywallShown)
    }

    func dismiss() {
        trigger = nil
    }
}
