import StoreKitTest
import Testing

@testable import VillainArc

@Suite(.serialized)
@MainActor
struct SubscriptionStoreKitIntegrationTests {
    @Test
    func freeTierRemainsLockedWithoutEntitlements() async throws {
        let session = try makeSession()
        session.clearTransactions()

        let store = SubscriptionStore.shared
        await store.loadProducts()
        await store.refreshStatus()

        #expect(store.status == .notSubscribed)
        #expect(SubscriptionGate.isPro == false)
    }

    @Test
    func monthlyPurchaseUnlocksPro() async throws {
        let session = try makeSession()
        session.clearTransactions()

        let store = SubscriptionStore.shared
        await store.loadProducts()
        await store.refreshStatus()
        let product = try #require(store.monthlyProduct)

        let transaction = try await store.purchase(product)

        #expect(transaction?.productID == SubscriptionStore.monthlyProductID)
        #expect(store.status.isPro)
        #expect(SubscriptionGate.isPro)
    }

    @Test
    func restorePreservesPurchasedEntitlement() async throws {
        let session = try makeSession()
        session.clearTransactions()

        let store = SubscriptionStore.shared
        await store.loadProducts()
        let product = try #require(store.yearlyProduct)
        _ = try await store.purchase(product)

        try await store.restore()

        #expect(store.status.isPro)
        #expect(store.status.productID == SubscriptionStore.yearlyProductID)
    }

    @Test @available(iOS 26.4, *)
    func annualCommitmentTermsLoadAndPurchaseAsMonthlyBilling() async throws {
        let session = try makeSession()
        session.clearTransactions()

        let store = SubscriptionStore.shared
        await store.loadProducts()
        await store.refreshStatus()
        let product = try #require(store.yearlyProduct)
        let terms = try #require(product.subscription?.pricingTerms.first { $0.billingPlanType == .monthly })

        #expect(terms.billingDisplayPrice == "$3.99")
        #expect(terms.commitmentInfo.displayPrice == "$47.88")

        let transaction = try #require(try await store.purchase(product, billingPlanType: .monthly))
        #expect(transaction.productID == SubscriptionStore.yearlyProductID)
        #expect(transaction.billingPlanType == .monthly)
        #expect(transaction.commitmentInfo != nil)
        #expect(store.status.isPro)
    }

    private func makeSession() throws -> SKTestSession {
        let session = try SKTestSession(configurationFileNamed: "VillainArc")
        session.disableDialogs = true
        session.resetToDefaultState()
        return session
    }
}
