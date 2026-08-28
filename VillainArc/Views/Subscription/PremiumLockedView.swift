import SwiftUI

/// Inline "this feature requires Pro" placeholder used at navigationDestinations for premium
/// surfaces. Renders a centered card with the feature icon, headline, description, and a CTA
/// that opens the paywall. Used as a safety net in case App Intents push a premium destination
/// without going through the SubscriptionGate at the tap point.
struct PremiumLockedView: View {
    let feature: PremiumFeature

    @State private var store = SubscriptionStore.shared

    private var ctaTitle: LocalizedStringResource {
        store.isEligibleForIntroOffer ? "Start Free Trial" : "Unlock Pro"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 18) {
                Image(systemName: feature.systemImage)
                    .font(.system(size: 44))
                    .foregroundStyle(feature.tint.gradient)
                    .frame(width: 96, height: 96)
                    .background(feature.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .padding(.top, 24)

                VStack(spacing: 8) {
                    Text(feature.promoHeadline)
                        .font(.title2)
                        .fontWeight(.bold)
                        .fontDesign(.rounded)
                        .multilineTextAlignment(.center)
                    Text(feature.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }

                Button {
                    Haptics.selection()
                    PaywallPresenter.shared.present(for: feature)
                } label: {
                    Text(ctaTitle)
                        .fontWeight(.semibold)
                        .font(.headline)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.glassProminent)
                .buttonSizing(.flexible)
                .accessibilityIdentifier(AccessibilityIdentifiers.premiumLockedUpgradeButton)
                .padding(.horizontal, 24)

                Text("Plus \(PremiumFeature.allCases.count - 1) more premium features.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .appBackground()
        .navigationTitle(Text(feature.displayName))
        .toolbarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { PremiumLockedView(feature: .healthTrends) }
}
