import FCTMetrics
import Foundation
import Observation
import StoreKit

/// Single source of truth for Villain Arc Pro subscription state. Wraps StoreKit 2 transactions,
/// caches the resolved `isPro` flag to the shared App Group so the widget can read it, and
/// publishes an `Observable` `status` UI gates can read directly. Always instantiated as
/// `SubscriptionStore.shared`.
@MainActor
@Observable
final class SubscriptionStore {
    // MARK: - Constants

    static let monthlyProductID = "com.fcttechnologies.VillainArc.Pro.Monthly"
    static let yearlyProductID = "com.fcttechnologies.VillainArc.Pro.Yearly"
    static let allProductIDs: [String] = [monthlyProductID, yearlyProductID]

    static let manageSubscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions")!
    static let termsURL = URL(string: "https://fct-technologies.com/projects/villainarc/terms/")!
    static let privacyURL = URL(string: "https://fct-technologies.com/projects/villainarc/privacy/")!
    static let standardEULAURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    // MARK: - Singleton

    static let shared = SubscriptionStore()

    // MARK: - Status

    enum SubscriptionStatus: Equatable {
        case unknown
        case notSubscribed
        case subscribed(productID: String, expirationDate: Date?, willAutoRenew: Bool)
        case inFreeTrial(productID: String, trialEndDate: Date)
        case inGracePeriod(productID: String, expirationDate: Date)
        case expired(productID: String, expirationDate: Date)

        var isPro: Bool {
            switch self {
            case .subscribed, .inFreeTrial, .inGracePeriod: return true
            default: return false
            }
        }

        var productID: String? {
            switch self {
            case let .subscribed(id, _, _),
                 let .inFreeTrial(id, _),
                 let .inGracePeriod(id, _),
                 let .expired(id, _):
                return id
            case .unknown, .notSubscribed:
                return nil
            }
        }

        var renewalDate: Date? {
            switch self {
            case let .subscribed(_, exp, _): return exp
            case let .inFreeTrial(_, end): return end
            case let .inGracePeriod(_, exp): return exp
            case let .expired(_, exp): return exp
            case .unknown, .notSubscribed: return nil
            }
        }
    }

    // MARK: - Published state

    private(set) var status: SubscriptionStatus = .unknown
    private(set) var products: [Product] = []
    private(set) var isLoadingProducts = false
    private(set) var isEligibleForIntroOffer = true

    // MARK: - Lifecycle

    private var transactionListenerTask: Task<Void, Never>?
    private var hasStarted = false

    private init() {}

    /// Idempotent. Call once on app launch. Pre-warms `status` from the App Group cache, attaches
    /// a `Transaction.updates` listener, then fetches products + current entitlements.
    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        prewarmFromCache()

        transactionListenerTask = Task.detached(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(transactionResult: result)
            }
        }

        Task {
            await loadProducts()
            await refreshStatus()
        }
    }

    // MARK: - Product loading

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let fetched = try await Product.products(for: Self.allProductIDs)
            products = fetched.sorted { Self.sortKey(for: $0) < Self.sortKey(for: $1) }
            if let sub = products.first?.subscription {
                isEligibleForIntroOffer = await sub.isEligibleForIntroOffer
            }
        } catch {
            AppLog.error("SubscriptionStore product load failed", error: error)
        }
    }

    private static func sortKey(for product: Product) -> Int {
        guard let period = product.subscription?.subscriptionPeriod else { return 0 }
        switch period.unit {
        case .day: return period.value
        case .week: return 7 * period.value
        case .month: return 30 * period.value
        case .year: return 365 * period.value
        @unknown default: return 0
        }
    }

    // MARK: - Status refresh

    func refreshStatus() async {
        await VAMetrics.service.trackOperation(
            .subscriptionEntitlementRefresh,
            stateLabel: "current-entitlements",
            signpostName: "Subscription Entitlement Refresh"
        ) { @Sendable in
            await self.refreshStatusCore()
        }
    }

    private func refreshStatusCore() async {
        var resolved: SubscriptionStatus = .notSubscribed
        for await result in Transaction.currentEntitlements {
            guard case let .verified(transaction) = result else { continue }
            guard Self.allProductIDs.contains(transaction.productID) else { continue }
            resolved = await deriveStatus(from: transaction)
            break
        }
        status = resolved
        persistCache()
    }

    private func deriveStatus(from transaction: Transaction) async -> SubscriptionStatus {
        var productID = transaction.productID
        var expirationDate = transaction.expirationDate
        var isInTrial = transaction.offer?.type == .introductory

        if let product = products.first(where: { $0.id == productID }),
           let subscription = product.subscription,
           let statuses = try? await subscription.status,
           let info = entitlementDecidingStatus(among: statuses) {
            // The chosen status may belong to a different transaction in the group than the one
            // that got us here — a family-shared yearly where the entitlement loop found a
            // monthly. Read the product, expiry, and trial flag off the status that decided, or
            // the app reports one subscription's state under another's name and renewal date.
            if case let .verified(deciding) = info.transaction {
                productID = deciding.productID
                expirationDate = deciding.expirationDate
                isInTrial = deciding.offer?.type == .introductory
            }
            switch info.state {
            case .subscribed:
                if isInTrial, let end = expirationDate {
                    return .inFreeTrial(productID: productID, trialEndDate: end)
                }
                let willAutoRenew: Bool
                if case let .verified(renewal) = info.renewalInfo {
                    willAutoRenew = renewal.willAutoRenew
                } else {
                    willAutoRenew = false
                }
                return .subscribed(productID: productID, expirationDate: expirationDate, willAutoRenew: willAutoRenew)
            case .inGracePeriod:
                let exp = expirationDate ?? Date()
                return .inGracePeriod(productID: productID, expirationDate: exp)
            case .inBillingRetryPeriod, .expired, .revoked:
                return .expired(productID: productID, expirationDate: expirationDate ?? Date())
            default:
                return .subscribed(productID: productID, expirationDate: expirationDate, willAutoRenew: false)
            }
        }

        if isInTrial, let end = expirationDate {
            return .inFreeTrial(productID: productID, trialEndDate: end)
        }
        if let exp = expirationDate, exp < Date() {
            return .expired(productID: productID, expirationDate: exp)
        }
        return .subscribed(productID: productID, expirationDate: expirationDate, willAutoRenew: true)
    }

    // MARK: - Which status in the group decides entitlement

    /// `Product.SubscriptionInfo.status` returns one entry per transaction in the subscription
    /// group, in no defined order. Villain Arc Pro has Family Sharing enabled on both products, so
    /// a family member's own lapsed entry and the purchaser's active one sit in that array
    /// together: reading `statuses.first` hands the verdict to whichever StoreKit returned first
    /// and shows a paying customer as unsubscribed. Apple's rule is to serve the customer at the
    /// highest level of service whose state is `subscribed`.
    ///
    /// Unverified entries are dropped rather than ranked — an unverified `subscribed` must never
    /// out-rank a verified one. When nothing is left, the caller falls back to deriving status
    /// from the transaction itself.
    private func entitlementDecidingStatus(
        among statuses: [Product.SubscriptionInfo.Status]
    ) -> Product.SubscriptionInfo.Status? {
        let verified = statuses.filter {
            if case .verified = $0.transaction { return true }
            return false
        }
        let candidates = verified.map { status -> (state: Product.SubscriptionInfo.RenewalState, groupLevel: Int) in
            guard case let .verified(transaction) = status.transaction else { return (status.state, .max) }
            let level = products
                .first(where: { $0.id == transaction.productID })?
                .subscription?
                .groupLevel
            return (status.state, level ?? .max)
        }
        guard let index = Self.entitlementDecidingIndex(among: candidates) else { return nil }
        return verified[index]
    }

    /// The ranking half of ``entitlementDecidingStatus(among:)``, pure so it can be tested without
    /// a live StoreKit session. Ranks an entitled state above a lapsed one and, among equals, the
    /// lower `groupLevel` — App Store Connect numbers level 1 as the top tier. Grace period ranks
    /// below `subscribed` and above everything else, which is what the app already treats as Pro.
    static func entitlementDecidingIndex(
        among candidates: [(state: Product.SubscriptionInfo.RenewalState, groupLevel: Int)]
    ) -> Int? {
        candidates.indices.min { lhs, rhs in
            (serviceRank(candidates[lhs].state), candidates[lhs].groupLevel)
                < (serviceRank(candidates[rhs].state), candidates[rhs].groupLevel)
        }
    }

    private static func serviceRank(_ state: Product.SubscriptionInfo.RenewalState) -> Int {
        switch state {
        case .subscribed: return 0
        case .inGracePeriod: return 1
        default: return 2
        }
    }

    // MARK: - Purchase + restore

    enum SubscriptionStoreError: Error, LocalizedError {
        case verificationFailed
        case productNotFound

        var errorDescription: String? {
            switch self {
            case .verificationFailed:
                return String(localized: "Purchase couldn't be verified. Try again or restore.")
            case .productNotFound:
                return String(localized: "Subscription is unavailable right now.")
            }
        }
    }

    /// Returns the finished transaction on success, `nil` if the user cancelled or the purchase is pending.
    func purchase(_ product: Product) async throws -> Transaction? {
        try await purchase(product, options: [])
    }

    /// Purchases a specific billing plan for a subscription product. A one-year product can
    /// offer both up-front billing and monthly billing with a 12-month commitment.
    @available(iOS 26.4, *)
    func purchase(
        _ product: Product,
        billingPlanType: Product.SubscriptionInfo.BillingPlanType
    ) async throws -> Transaction? {
        try await purchase(product, options: [.billingPlanType(billingPlanType)])
    }

    private func purchase(
        _ product: Product,
        options: Set<Product.PurchaseOption>
    ) async throws -> Transaction? {
        let result = try await product.purchase(options: options)
        switch result {
        case let .success(verification):
            switch verification {
            case let .verified(transaction):
                await transaction.finish()
                await refreshStatus()
                return transaction
            case .unverified:
                throw SubscriptionStoreError.verificationFailed
            }
        case .userCancelled, .pending:
            return nil
        @unknown default:
            return nil
        }
    }

    func restore() async throws {
        try await AppStore.sync()
        await refreshStatus()
    }

    private func handle(transactionResult: VerificationResult<Transaction>) async {
        guard case let .verified(transaction) = transactionResult else { return }
        await transaction.finish()
        await refreshStatus()
    }

    // MARK: - App Group cache (shared with the widget)

    static let cachedIsProKey = "subscription_is_pro_cached"
    static let cachedExpirationKey = "subscription_cached_expiration"
    static let cachedProductIDKey = "subscription_cached_product_id"

    private func prewarmFromCache() {
        guard Self.cachedIsPro, let productID = Self.cachedProductID else {
            status = .unknown
            return
        }
        status = .subscribed(productID: productID, expirationDate: Self.cachedExpiration, willAutoRenew: true)
    }

    private func persistCache() {
        let defaults = unsafe SharedModelContainer.sharedDefaults
        defaults.set(status.isPro, forKey: Self.cachedIsProKey)
        if let productID = status.productID {
            defaults.set(productID, forKey: Self.cachedProductIDKey)
        } else {
            defaults.removeObject(forKey: Self.cachedProductIDKey)
        }
        if let renewal = status.renewalDate {
            defaults.set(renewal.timeIntervalSince1970, forKey: Self.cachedExpirationKey)
        } else {
            defaults.removeObject(forKey: Self.cachedExpirationKey)
        }
    }

    static var cachedIsPro: Bool {
        unsafe SharedModelContainer.sharedDefaults.bool(forKey: cachedIsProKey)
    }

    static var cachedExpiration: Date? {
        let interval = unsafe SharedModelContainer.sharedDefaults.double(forKey: cachedExpirationKey)
        return interval > 0 ? Date(timeIntervalSince1970: interval) : nil
    }

    static var cachedProductID: String? {
        unsafe SharedModelContainer.sharedDefaults.string(forKey: cachedProductIDKey)
    }

    // MARK: - Convenience

    /// Returns the monthly product if loaded.
    var monthlyProduct: Product? {
        products.first { $0.id == Self.monthlyProductID }
    }

    /// Returns the yearly product if loaded.
    var yearlyProduct: Product? {
        products.first { $0.id == Self.yearlyProductID }
    }
}
