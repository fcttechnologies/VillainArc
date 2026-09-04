import FCTAccount
import FCTStoreKit
import Foundation
import SwiftUI

/// The five paywalled premium features in Villain Arc. Identifies a feature for
/// `PremiumGate.require` and for the paywall, which spotlights the one that triggered it.
nonisolated enum PremiumFeature: String, PaywallFeature {
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

    var featureDescription: LocalizedStringResource {
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

/// Villain Arc's half of `FCTStoreKit`: the product catalog, the App-Group cache namespace, and
/// the paywall's branding. Everything else about selling Pro — the verified-entitlement state
/// machine, the server claim, the paywall shell, the gate — is the package's.
@MainActor
enum VAPro {
    /// The two auto-renewing products, by role. Both carry a 7-day introductory free trial, which
    /// lives in App Store Connect rather than here.
    static let catalog = ProCatalog(
        monthly: "com.fcttechnologies.VillainArc.Pro.Monthly",
        yearly: "com.fcttechnologies.VillainArc.Pro.Yearly"
    )

    /// The default namespace reproduces the keys the widget already reads
    /// (`subscription_is_pro_cached` and friends) in the App Group.
    static let cache = SubscriptionCache(defaults: unsafe SharedModelContainer.sharedDefaults)

    static let branding = PaywallBranding(
        productDisplayName: "Villain Arc Pro",
        termsURL: URL(string: "https://fct-technologies.com/projects/villainarc/terms/")!,
        privacyURL: URL(string: "https://fct-technologies.com/projects/villainarc/privacy/")!
    )

    /// The store, the presenter, and the gate the whole app reads. One instance, constructed at
    /// launch and injected into the environment by `VillainArcApp`.
    static let store = SubscriptionStore(catalog: catalog, cache: cache)
    static let presenter = PaywallPresenter<PremiumFeature>()
    static let gate = PremiumGate(store: store, presenter: presenter)

    /// The "this needs Pro" placeholder for a gated destination something pushed without passing
    /// the gate — an App Intent, or a restored navigation path.
    static func lockedView(_ feature: PremiumFeature) -> some View {
        PremiumLockedView(
            feature: feature,
            presenter: presenter,
            isEligibleForIntroOffer: store.isEligibleForIntroOffer
        )
    }

    /// Bind the store to the FCT account, or release it on sign-out. The device's own Apple ID
    /// purchase never depended on the account, so signing out forgets only the server's answer.
    static func accountChanged(to credentials: AccountCredentials?) async {
        if let credentials {
            store.entitlements = EntitlementClient(
                account: credentials,
                transport: SupabaseEntitlementTransport(
                    baseURL: VAAccount.controller.environment.baseURL,
                    publishableKey: VAAccount.controller.environment.publishableKey
                )
            )
        } else {
            store.entitlements = nil
        }
        await store.refreshEntitlements()
    }
}

/// The entitlement client takes the account by shape, not by conformance, so the account layer and
/// the store layer stay unlinked.
extension AccountCredentials: @retroactive EntitlementAccount {}
