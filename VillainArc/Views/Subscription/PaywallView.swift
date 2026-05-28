import StoreKit
import SwiftUI

/// Full-screen paywall presented globally when a free user taps a gated feature. Reads products
/// from `SubscriptionStore.shared` and renders monthly + yearly cards with trial copy, restore,
/// and legal links.
struct PaywallView: View {
    let triggeringFeature: PremiumFeature

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var store = SubscriptionStore.shared
    @State private var selectedProductID: String?
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var errorMessage: String?

    private var monthly: Product? { store.monthlyProduct }
    private var yearly: Product? { store.yearlyProduct }

    private var selectedProduct: Product? {
        guard let id = selectedProductID else { return yearly ?? monthly }
        return store.products.first { $0.id == id }
    }

    private var canPurchase: Bool {
        selectedProduct != nil && !isPurchasing && !isRestoring
    }

    private var ctaTitle: LocalizedStringResource {
        store.isEligibleForIntroOffer ? "Start Free Trial" : "Subscribe"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    hero
                    featureList
                    planCards
                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .appCardStyle()
                    }
                    trialFooter
                    legalLinks
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 140)
            }
            .safeAreaInset(edge: .bottom) {
                ctaBar
            }
            .appBackground()
            .navigationTitle("Villain Arc Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .close) {
                        Haptics.selection()
                        PaywallPresenter.shared.dismiss()
                        dismiss()
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.paywallCloseButton)
                }
            }
        }
        .task {
            if store.products.isEmpty { await store.loadProducts() }
            if selectedProductID == nil {
                selectedProductID = (yearly ?? monthly)?.id
            }
        }
        .accessibilityIdentifier(AccessibilityIdentifiers.paywallRoot)
    }

    // MARK: - Hero

    @ViewBuilder
    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: triggeringFeature.systemImage)
                    .font(.title2)
                    .foregroundStyle(triggeringFeature.tint.gradient)
                    .frame(width: 48, height: 48)
                    .background(triggeringFeature.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(triggeringFeature.promoHeadline)
                        .font(.title2)
                        .fontWeight(.bold)
                        .fontDesign(.rounded)
                    Text("Plus 4 more premium features.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Feature list

    @ViewBuilder
    private var featureList: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(PremiumFeature.allCases) { feature in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: feature.systemImage)
                        .font(.subheadline)
                        .foregroundStyle(feature.tint.gradient)
                        .frame(width: 28, height: 28)
                        .background(feature.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.displayName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(feature.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardStyle()
    }

    // MARK: - Plan cards

    @ViewBuilder
    private var planCards: some View {
        if store.products.isEmpty {
            HStack {
                ProgressView()
                Text("Loading plans…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding()
            .appCardStyle()
            .accessibilityIdentifier(AccessibilityIdentifiers.paywallPlansLoading)
        } else {
            VStack(spacing: 12) {
                if let yearly {
                    planCard(for: yearly, isYearly: true)
                }
                if let monthly {
                    planCard(for: monthly, isYearly: false)
                }
            }
        }
    }

    @ViewBuilder
    private func planCard(for product: Product, isYearly: Bool) -> some View {
        let isSelected = selectedProductID == product.id
        Button {
            Haptics.selection()
            selectedProductID = product.id
        } label: {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.4), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 12, height: 12)
                    }
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(isYearly ? LocalizedStringResource("Yearly") : LocalizedStringResource("Monthly"))
                            .font(.headline)
                            .fontDesign(.rounded)
                        if isYearly {
                            Text("Save 33%")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.green.opacity(0.18), in: Capsule())
                                .foregroundStyle(.green)
                        }
                    }
                    Text(periodSubtitle(for: product, isYearly: isYearly))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(.headline)
                        .fontDesign(.rounded)
                    Text(isYearly ? LocalizedStringResource("per year") : LocalizedStringResource("per month"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.10) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : Color.secondary.opacity(0.25), lineWidth: isSelected ? 2 : 1)
            )
            .appCardStyle()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(isYearly ? AccessibilityIdentifiers.paywallYearlyOption : AccessibilityIdentifiers.paywallMonthlyOption)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(isYearly ? LocalizedStringResource("Yearly plan") : LocalizedStringResource("Monthly plan")))
        .accessibilityValue(Text(product.displayPrice))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func periodSubtitle(for product: Product, isYearly: Bool) -> String {
        if store.isEligibleForIntroOffer,
           let intro = product.subscription?.introductoryOffer,
           intro.paymentMode == .freeTrial {
            let days = approximateDays(in: intro.period)
            return String(localized: "\(days)-day free trial, then \(product.displayPrice)/\(isYearly ? String(localized: "year") : String(localized: "month"))")
        }
        return String(localized: "\(product.displayPrice) billed \(isYearly ? String(localized: "yearly") : String(localized: "monthly"))")
    }

    private func approximateDays(in period: Product.SubscriptionPeriod) -> Int {
        switch period.unit {
        case .day: return period.value
        case .week: return 7 * period.value
        case .month: return 30 * period.value
        case .year: return 365 * period.value
        @unknown default: return period.value
        }
    }

    // MARK: - Trial footer

    @ViewBuilder
    private var trialFooter: some View {
        let text: LocalizedStringResource = store.isEligibleForIntroOffer
            ? "7-day free trial. Cancel anytime in Settings. Subscription auto-renews until cancelled."
            : "Cancel anytime in Settings. Subscription auto-renews until cancelled."
        Text(text)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Legal links

    @ViewBuilder
    private var legalLinks: some View {
        HStack(spacing: 14) {
            Button("Terms") { openURL(SubscriptionStore.termsURL) }
            Button("Privacy") { openURL(SubscriptionStore.privacyURL) }
            Button("EULA") { openURL(SubscriptionStore.standardEULAURL) }
            Spacer()
            Button {
                Task { await handleRestore() }
            } label: {
                if isRestoring {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Restore")
                }
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.paywallRestoreButton)
            .disabled(isPurchasing || isRestoring)
        }
        .font(.caption)
        .tint(.secondary)
        .padding(.top, 4)
    }

    // MARK: - CTA bar

    @ViewBuilder
    private var ctaBar: some View {
        VStack(spacing: 8) {
            Button {
                Task { await handlePurchase() }
            } label: {
                HStack {
                    if isPurchasing {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    } else {
                        Text(ctaTitle)
                            .fontWeight(.semibold)
                            .font(.headline)
                    }
                }
                .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .buttonSizing(.flexible)
            .disabled(!canPurchase)
            .accessibilityIdentifier(AccessibilityIdentifiers.paywallSubscribeButton)

            Text("Family Sharing is on. One subscription covers your Family.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .padding(.top, 12)
        .background(.thinMaterial)
    }

    // MARK: - Actions

    private func handlePurchase() async {
        guard let product = selectedProduct else { return }
        errorMessage = nil
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            if try await store.purchase(product) != nil {
                Haptics.success()
                PaywallPresenter.shared.dismiss()
                dismiss()
            }
        } catch {
            Haptics.error()
            errorMessage = (error as? SubscriptionStore.SubscriptionStoreError)?.localizedDescription
                ?? String(localized: "Purchase failed. Please try again.")
            AppLog.error("Paywall purchase failed", error: error)
        }
    }

    private func handleRestore() async {
        errorMessage = nil
        isRestoring = true
        defer { isRestoring = false }
        do {
            try await store.restore()
            if store.status.isPro {
                Haptics.success()
                PaywallPresenter.shared.dismiss()
                dismiss()
            } else {
                errorMessage = String(localized: "No active subscription was found on this Apple ID.")
            }
        } catch {
            errorMessage = String(localized: "Restore failed. Try again later.")
            AppLog.error("Paywall restore failed", error: error)
        }
    }
}

#Preview {
    PaywallView(triggeringFeature: .aiPlanGeneration)
}
