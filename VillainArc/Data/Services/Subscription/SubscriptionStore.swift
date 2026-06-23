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
        // Under the unit-test host, don't attach the background `Transaction.updates` listener or
        // kick off the launch-time load: the StoreKit integration tests drive this shared store
        // deterministically against their own `SKTestSession`, and a launch-time listener bound to
        // the host's StoreKit context deadlocks `product.purchase()` in those tests. Production app
        // launch (no test env var) starts normally; tests call `loadProducts()`/`refreshStatus()`
        // explicitly.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil { return }
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
        await MetricsService.trackOperation(
            .subscriptionEntitlementRefresh,
            stateLabel: "current-entitlements",
            signpostName: "Subscription Entitlement Refresh"
        ) {
            await refreshStatusCore()
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
        let productID = transaction.productID
        let expirationDate = transaction.expirationDate
        let isInTrial = transaction.offer?.type == .introductory

        if let product = products.first(where: { $0.id == productID }),
           let subscription = product.subscription,
           let statuses = try? await subscription.status,
           let info = statuses.first {
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
        let defaults = SharedModelContainer.sharedDefaults
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
        SharedModelContainer.sharedDefaults.bool(forKey: cachedIsProKey)
    }

    static var cachedExpiration: Date? {
        let interval = SharedModelContainer.sharedDefaults.double(forKey: cachedExpirationKey)
        return interval > 0 ? Date(timeIntervalSince1970: interval) : nil
    }

    static var cachedProductID: String? {
        SharedModelContainer.sharedDefaults.string(forKey: cachedProductIDKey)
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
