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

    private func makeSession() throws -> SKTestSession {
        let session = try SKTestSession(configurationFileNamed: "VillainArc")
        session.disableDialogs = true
        session.resetToDefaultState()
        return session
    }
}
