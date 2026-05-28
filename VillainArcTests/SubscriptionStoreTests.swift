import Foundation
import Testing

@testable import VillainArc

// SubscriptionStatus equality + isPro mapping. These cover the status enum without needing
// to stand up a live StoreKit session, which is what the integration tests in
// VillainArcUITests would exercise once subscription UI ships.
struct SubscriptionStoreTests {
    typealias Status = SubscriptionStore.SubscriptionStatus

    // MARK: - isPro

    @Test
    func isPro_subscribed_returnsTrue() {
        let status = Status.subscribed(productID: SubscriptionStore.monthlyProductID, expirationDate: Date().addingTimeInterval(86_400), willAutoRenew: true)
        #expect(status.isPro)
    }

    @Test
    func isPro_inFreeTrial_returnsTrue() {
        let status = Status.inFreeTrial(productID: SubscriptionStore.yearlyProductID, trialEndDate: Date().addingTimeInterval(7 * 86_400))
        #expect(status.isPro)
    }

    @Test
    func isPro_inGracePeriod_returnsTrue() {
        let status = Status.inGracePeriod(productID: SubscriptionStore.monthlyProductID, expirationDate: Date().addingTimeInterval(86_400))
        #expect(status.isPro)
    }

    @Test
    func isPro_expired_returnsFalse() {
        let status = Status.expired(productID: SubscriptionStore.monthlyProductID, expirationDate: Date().addingTimeInterval(-86_400))
        #expect(status.isPro == false)
    }

    @Test
    func isPro_notSubscribed_returnsFalse() {
        #expect(Status.notSubscribed.isPro == false)
    }

    @Test
    func isPro_unknown_returnsFalse() {
        #expect(Status.unknown.isPro == false)
    }

    // MARK: - productID

    @Test
    func productID_subscribed_returnsProductID() {
        let status = Status.subscribed(productID: SubscriptionStore.yearlyProductID, expirationDate: nil, willAutoRenew: true)
        #expect(status.productID == SubscriptionStore.yearlyProductID)
    }

    @Test
    func productID_notSubscribed_returnsNil() {
        #expect(Status.notSubscribed.productID == nil)
    }

    @Test
    func productID_unknown_returnsNil() {
        #expect(Status.unknown.productID == nil)
    }

    // MARK: - renewalDate

    @Test
    func renewalDate_inFreeTrial_returnsTrialEnd() {
        let end = Date(timeIntervalSince1970: 1_780_000_000)
        let status = Status.inFreeTrial(productID: SubscriptionStore.monthlyProductID, trialEndDate: end)
        #expect(status.renewalDate == end)
    }

    @Test
    func renewalDate_subscribed_returnsExpirationDate() {
        let exp = Date(timeIntervalSince1970: 1_790_000_000)
        let status = Status.subscribed(productID: SubscriptionStore.yearlyProductID, expirationDate: exp, willAutoRenew: true)
        #expect(status.renewalDate == exp)
    }

    @Test
    func renewalDate_subscribedNoExp_returnsNil() {
        let status = Status.subscribed(productID: SubscriptionStore.yearlyProductID, expirationDate: nil, willAutoRenew: true)
        #expect(status.renewalDate == nil)
    }

    // MARK: - allProductIDs

    @Test
    func allProductIDs_containsMonthlyAndYearly() {
        #expect(SubscriptionStore.allProductIDs.contains(SubscriptionStore.monthlyProductID))
        #expect(SubscriptionStore.allProductIDs.contains(SubscriptionStore.yearlyProductID))
        #expect(SubscriptionStore.allProductIDs.count == 2)
    }

    @Test
    func productIDs_useBundlePrefixConvention() {
        #expect(SubscriptionStore.monthlyProductID.hasPrefix("com.fcttechnologies.VillainArc."))
        #expect(SubscriptionStore.yearlyProductID.hasPrefix("com.fcttechnologies.VillainArc."))
    }

    // MARK: - App Group cache keys

    @Test
    func cacheKeys_areStable() {
        // The widget extension reads the cache via these literal keys. If they change, the
        // widget must be updated in lockstep. This test pins the contract.
        #expect(SubscriptionStore.cachedIsProKey == "subscription_is_pro_cached")
        #expect(SubscriptionStore.cachedExpirationKey == "subscription_cached_expiration")
        #expect(SubscriptionStore.cachedProductIDKey == "subscription_cached_product_id")
    }
}
