import FCTAccount
import FCTAccountProfile
import FCTServerSync
import FCTServerSyncTesting
import Foundation
import SwiftData
import Testing

@testable import VillainArc

/// Villain Arc's adoption of the shared account: that the fragment it composed into its own schema
/// really rides its own wire, and that the gate its root view builds is reached after sign-in
/// through this app's driver rather than a hypothetical one.
///
/// What is proven in `FCTAccountProfile` and deliberately not repeated: the stage rule itself, the
/// completion order, and the funnel.
@Suite("The FCT account, adopted", .serialized)
struct AccountAdoptionTests {

    /// The gate's wait begins before the engine exists — the account's event stream builds the
    /// engine and races the view that starts waiting — so the cycle it asks for has to be the one
    /// that actually lands. A driver returning "no engine" immediately would settle the attempt
    /// against a pull that never ran and show the unreachable surface on a healthy first launch.
    @Test @MainActor
    func theGateAsksOnceTheFirstPullLandsAfterSignIn() async throws {
        let harness = try VASyncFaultHarness()
        let coordinator = AccountOnboardingCoordinator(
            stateFile: try #require(harness.sync.stateFile),
            sync: { _ = await harness.sync.restoreAccountData() },
            trusted: AccountTrusted(account: FakeAccount(accountID: harness.accountID))
        )

        #expect(coordinator.stage(hasRow: false) == .waiting, "nothing is asked before the pull answers")

        async let pull: Void = coordinator.waitForPull()
        await harness.enroll()
        await pull

        #expect(coordinator.stage(hasRow: false) == .onboarding, "the server answered and the account is new")
        #expect(coordinator.stage(hasRow: true) == .app, "a row on file opens the app instead")
    }

    /// The name Apple carried on the authorization survives the event, which is the only place it
    /// is ever offered — the gate prefills from this and from nothing else.
    @Test @MainActor
    func enrollingKeepsTheAppleName() async throws {
        let harness = try VASyncFaultHarness()
        var name = PersonNameComponents()
        name.givenName = "Fernando"
        name.familyName = "Cortez"

        await harness.sync.handle(.enrolled(harness.accountID, appleFullName: name))

        #expect(harness.sync.appleFullName?.givenName == "Fernando")
        #expect(harness.sync.appleFullName?.familyName == "Cortez")
    }

    /// The two account tables ride Villain Arc's own schema over Villain Arc's own wire: one
    /// device writes them, a second device on the same account pulls them back under the fixed
    /// uuids the server pins.
    @Test @MainActor
    func theAccountFragmentRoundTripsToASecondDevice() async throws {
        let server = FakeSyncServer()
        let accountID = UUID()
        let author = try VASyncFaultHarness(server: server, accountID: accountID)
        let reader = try VASyncFaultHarness(server: server, accountID: accountID)

        let authored = author.container.mainContext
        authored.insert(AccountOnboardingRecord(completedIn: VASyncSchema.appSlug))
        authored.insert(AccountProfileField(kind: .givenName, value: "Fernando"))
        authored.insert(AccountProfileField(kind: .familyName, value: "Cortez"))
        try authored.save()
        await author.enroll()
        await author.sync.syncNow(.full)

        await reader.enroll()
        await reader.sync.syncNow(.full)

        let read = reader.container.mainContext
        let onboarding = try read.fetch(FetchDescriptor<AccountOnboardingRecord>())
        #expect(onboarding.count == 1)
        #expect(onboarding.first?.id == AccountSchema.onboardingID)
        #expect(onboarding.first?.completedIn == VASyncSchema.appSlug)

        let given = try #require(try AccountProfileField.fetch(.givenName, in: read))
        #expect(given.value == "Fernando")
        #expect(given.id == AccountProfileField.Kind.givenName.id)
        let family = try #require(try AccountProfileField.fetch(.familyName, in: read))
        #expect(family.value == "Cortez")
        #expect(family.id == AccountProfileField.Kind.familyName.id)
    }
}
