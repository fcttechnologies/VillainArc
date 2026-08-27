import StoreKit
import SwiftUI
import UIKit

/// Full-screen paywall presented globally when a free user taps a gated feature. Reads products
/// from `SubscriptionStore.shared` and renders monthly + yearly cards with trial copy, restore,
/// and legal links.
struct PaywallView: View {
    let triggeringFeature: PremiumFeature

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var store = SubscriptionStore.shared
    @State private var selectedProductID: String?
    @State private var selectsAnnualCommitment = false
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var isRedeemingOfferCode = false
    @State private var errorMessage: String?
    @State private var productsState: ProductsLoadState = .loading

    private enum ProductsLoadState: Equatable { case loading, loaded, failed }

    private var monthly: Product? { store.monthlyProduct }
    private var yearly: Product? { store.yearlyProduct }

    private var selectedProduct: Product? {
        guard let id = selectedProductID else { return monthly ?? yearly }
        return store.products.first { $0.id == id }
    }

    @available(iOS 26.4, *)
    private var annualCommitmentTerms: Product.SubscriptionInfo.PricingTerms? {
        yearly?.subscription?.pricingTerms.first { $0.billingPlanType == .monthly }
    }

    private var selectedIncludesFreeTrial: Bool {
        guard store.isEligibleForIntroOffer, let selectedProduct else { return false }
        if selectsAnnualCommitment {
            if #available(iOS 26.4, *), let terms = annualCommitmentTerms {
                return terms[offers: .introductory].contains { $0.paymentMode == .freeTrial }
            }
            return false
        }
        return selectedProduct.subscription?.introductoryOffer?.paymentMode == .freeTrial
    }

    private var canPurchase: Bool {
        selectedProduct != nil && !isPurchasing && !isRestoring
    }

    /// Yearly savings vs paying monthly for a year, derived from live prices (no hardcoded percent).
    private var yearlySavingsPercent: Int? {
        guard let monthly = store.monthlyProduct, let yearly = store.yearlyProduct else { return nil }
        let annualizedMonthly = monthly.price * 12
        guard annualizedMonthly > 0 else { return nil }
        let fraction = (annualizedMonthly - yearly.price) / annualizedMonthly
        let percent = Int((NSDecimalNumber(decimal: fraction).doubleValue * 100).rounded())
        return percent > 0 ? percent : nil
    }

    private var ctaTitle: LocalizedStringResource {
        selectedIncludesFreeTrial ? "Start Free Trial" : "Subscribe"
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
            await loadProducts()
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
                    Text("Plus \(PremiumFeature.allCases.count - 1) more premium features.")
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
        if !store.products.isEmpty {
            VStack(spacing: 12) {
                if let yearly {
                    planCard(for: yearly, isYearly: true)
                    if #available(iOS 26.4, *), let terms = annualCommitmentTerms {
                        annualCommitmentCard(for: yearly, terms: terms)
                    }
                }
                if let monthly {
                    planCard(for: monthly, isYearly: false)
                }
            }
        } else if productsState == .failed {
            VStack(spacing: 10) {
                Text("Couldn't load subscription options.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Try Again") {
                    Task { await loadProducts() }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding()
            .appCardStyle()
        } else {
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
        }
    }

    @ViewBuilder
    private func planCard(for product: Product, isYearly: Bool) -> some View {
        let isSelected = selectedProductID == product.id && !selectsAnnualCommitment
        Button {
            Haptics.selection()
            selectedProductID = product.id
            selectsAnnualCommitment = false
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
                        if isYearly, let savingsPercent = yearlySavingsPercent {
                            Text("Save \(savingsPercent)%")
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
        .accessibilityValue(Text(planAccessibilityValue(for: product, isYearly: isYearly)))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @available(iOS 26.4, *)
    @ViewBuilder
    private func annualCommitmentCard(
        for product: Product,
        terms: Product.SubscriptionInfo.PricingTerms
    ) -> some View {
        let isSelected = selectedProductID == product.id && selectsAnnualCommitment
        Button {
            Haptics.selection()
            selectedProductID = product.id
            selectsAnnualCommitment = true
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
                        Text("Annual commitment")
                            .font(.headline)
                            .fontDesign(.rounded)
                        Text("Pay monthly")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.blue.opacity(0.18), in: Capsule())
                            .foregroundStyle(.blue)
                    }
                    Text("\(terms.billingDisplayPrice) each month for 12 months")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(terms.billingDisplayPrice)
                        .font(.headline)
                        .fontDesign(.rounded)
                    Text("\(terms.commitmentInfo.displayPrice) total")
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
        .accessibilityLabel("Annual commitment plan")
        .accessibilityValue("\(terms.billingDisplayPrice) per month for 12 months. \(terms.commitmentInfo.displayPrice) total commitment.")
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

    private func planAccessibilityValue(for product: Product, isYearly: Bool) -> String {
        var parts = [product.displayPrice, periodSubtitle(for: product, isYearly: isYearly)]
        if isYearly, let savingsPercent = yearlySavingsPercent {
            parts.append(String(localized: "Save \(savingsPercent)%"))
        }
        return parts.joined(separator: ". ")
    }

    // MARK: - Trial footer

    @ViewBuilder
    private var trialFooter: some View {
        let text: LocalizedStringResource = selectedIncludesFreeTrial
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
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                Button("Terms") { openURL(SubscriptionStore.termsURL) }
                Button("Privacy") { openURL(SubscriptionStore.privacyURL) }
                Button("EULA") { openURL(SubscriptionStore.standardEULAURL) }
                Spacer()
            }
            HStack(spacing: 14) {
                Button {
                    Task { await handleOfferCodeRedemption() }
                } label: {
                    if isRedeemingOfferCode {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Redeem Code")
                    }
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.paywallRedeemOfferCodeButton)
                .disabled(isPurchasing || isRestoring || isRedeemingOfferCode)

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
                .disabled(isPurchasing || isRestoring || isRedeemingOfferCode)
            }
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

    private func loadProducts() async {
        if store.products.isEmpty {
            productsState = .loading
            await store.loadProducts()
        }
        productsState = store.products.isEmpty ? .failed : .loaded
        if selectedProductID == nil {
            selectedProductID = (monthly ?? yearly)?.id
        }
    }

    private func handlePurchase() async {
        guard let product = selectedProduct else { return }
        errorMessage = nil
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let transaction: StoreKit.Transaction?
            if selectsAnnualCommitment, #available(iOS 26.4, *) {
                transaction = try await store.purchase(product, billingPlanType: .monthly)
            } else {
                transaction = try await store.purchase(product)
            }
            if transaction != nil {
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

    private func handleOfferCodeRedemption() async {
        errorMessage = nil
        isRedeemingOfferCode = true
        defer { isRedeemingOfferCode = false }

        do {
            guard let scene = activeWindowScene else {
                errorMessage = String(localized: "Offer code redemption isn't available right now.")
                return
            }

            guard let viewController = scene.keyWindow?.rootViewController?.topPresentedViewController else {
                errorMessage = String(localized: "Offer code redemption isn't available right now.")
                return
            }
            let result = try await AppStore.presentOfferCodeRedeemSheet(from: viewController)
            guard case let .verified(transaction) = result else {
                throw SubscriptionStore.SubscriptionStoreError.verificationFailed
            }
            await transaction.finish()

            await store.refreshStatus()
            if store.status.isPro {
                Haptics.success()
                PaywallPresenter.shared.dismiss()
                dismiss()
            }
        } catch {
            Haptics.error()
            errorMessage = (error as? SubscriptionStore.SubscriptionStoreError)?.localizedDescription
                ?? String(localized: "Offer code redemption failed. Please try again.")
            AppLog.error("Offer code redemption failed", error: error)
        }
    }

    private var activeWindowScene: UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
    }
}

private extension UIViewController {
    var topPresentedViewController: UIViewController {
        presentedViewController?.topPresentedViewController ?? self
    }
}

#Preview {
    PaywallView(triggeringFeature: .aiPlanGeneration)
}
