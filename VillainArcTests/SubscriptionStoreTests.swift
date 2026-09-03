import FCTStoreKit
import FCTStoreKitTesting
import Foundation
import Testing

@testable import VillainArc

/// Villain Arc's half of `FCTStoreKit`: the product catalog, the App-Group cache the widget reads,
/// and the premium-feature enum the paywall renders. The verified-entitlement state machine, the
/// merge rule, and the paywall math are the package's own and are proved in its suite — what this
/// suite answers is whether *this app* is wired to the right products and keys.
@MainActor
struct VAProConfigurationTests {

    // MARK: - The catalog

    /// The two product identifiers App Store Connect holds for the Villain Arc Pro group. A typo
    /// here loads no products, and the paywall renders empty rather than failing.
    @Test func catalogNamesTheAppStoreConnectProducts() {
        #expect(VAPro.catalog.monthlyID == "com.fcttechnologies.VillainArc.Pro.Monthly")
        #expect(VAPro.catalog.yearlyID == "com.fcttechnologies.VillainArc.Pro.Yearly")
        #expect(VAPro.catalog.lifetimeID == nil, "Villain Arc Pro sells no lifetime tier")
        #expect(VAPro.catalog.productIDs.count == 2)
    }

    @Test(arguments: [ProCatalog.Tier.monthly, .yearly])
    func everyTierResolvesBackToItsProduct(_ tier: ProCatalog.Tier) throws {
        let id = try #require(
            tier == .monthly ? VAPro.catalog.monthlyID : VAPro.catalog.yearlyID
        )
        #expect(VAPro.catalog.tier(of: id) == tier)
        #expect(VAPro.catalog.contains(id))
    }

    @Test func aStrangersProductIsNotOurs() {
        #expect(VAPro.catalog.contains("com.fcttechnologies.Anchor.Pro.Monthly") == false)
        #expect(VAPro.catalog.tier(of: "com.fcttechnologies.VillainArc.Pro") == nil)
    }

    // MARK: - The App-Group cache

    /// The widget extension reads the startup hint from the App Group under these literal keys, so
    /// the namespace is a contract between two bundles rather than an implementation detail.
    @Test func cacheKeysAreTheOnesTheWidgetReads() {
        #expect(VAPro.cache.isProKey == "subscription_is_pro_cached")
        #expect(VAPro.cache.expirationKey == "subscription_cached_expiration")
        #expect(VAPro.cache.productIDKey == "subscription_cached_product_id")
    }

    // MARK: - The premium features

    /// The five features behind Pro. The paywall lists every case as its value proposition, so a
    /// case added without copy would ship a blank row.
    @Test func everyPremiumFeatureCarriesItsPaywallCopy() {
        #expect(PremiumFeature.allCases.count == 5)
        for feature in PremiumFeature.allCases {
            #expect(feature.id == feature.rawValue)
            #expect(String(localized: feature.displayName).isEmpty == false)
            #expect(String(localized: feature.featureDescription).isEmpty == false)
            #expect(String(localized: feature.promoHeadline).isEmpty == false)
            #expect(feature.systemImage.isEmpty == false)
        }
    }

    @Test func brandingPointsAtVillainArcsOwnLegalPages() {
        #expect(VAPro.branding.termsURL.absoluteString.contains("villainarc"))
        #expect(VAPro.branding.privacyURL.absoluteString.contains("villainarc"))
        #expect(VAPro.branding.eulaURL == PaywallBranding.standardEULAURL)
    }
}

/// The transaction lifecycle against Villain Arc's own product configuration, driven through the
/// shipping store by `FCTStoreKitTesting`.
///
/// `.serialized` is required, not stylistic: one `SKTestSession` is one process-wide store, and two
/// scenarios at once clear each other's transactions mid-purchase — which reads as a purchase that
/// returned nothing rather than as a race.
///
/// **A simulator that has never served a StoreKit purchase answers `.userCancelled` for its whole
/// first run**, so on a brand-new device every scenario here fails once and passes on the next run.
/// The failure names itself; it is the device warming up, not the store.
@MainActor
@Suite(.serialized)
struct VAProStoreScenarioTests {
    /// The app's own `.storekit` — the same file the scheme's Run action points at, read from the
    /// source tree rather than copied into the test bundle. Two configurations for one catalog is
    /// two places for the product shape to drift, and the shape is what half of these scenarios
    /// assert. The scheme's *test* action deliberately names no configuration: a second one the
    /// session's `disableDialogs` never reaches parks the first purchase on a confirmation sheet.
    private func harness() throws -> SubscriptionScenarioHarness {
        let configuration = repoRoot().appending(path: "VillainArc/VillainArc.storekit")
        return try SubscriptionScenarioHarness(
            configuration: configuration,
            catalog: VAPro.catalog,
            bundleID: "com.fcttechnologies.VillainArc"
        )
    }

    /// Walks up from this file to the directory holding the Xcode project.
    private func repoRoot(file: String = #filePath) -> URL {
        var url = URL(fileURLWithPath: file).deletingLastPathComponent()
        while !FileManager.default.fileExists(atPath: url.appendingPathComponent("VillainArc.xcodeproj").path) {
            let parent = url.deletingLastPathComponent()
            precondition(parent != url, "Walked up to the filesystem root without finding VillainArc.xcodeproj")
            url = parent
        }
        return url
    }

    @Test(arguments: SubscriptionScenarios.all.map(\.name))
    func scenario(_ name: String) async throws {
        let scenario = try #require(SubscriptionScenarios.all.first { $0.name == name })
        try await scenario.run(harness())
    }
}
