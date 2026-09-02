import FCTBlobSyncTesting
import FCTServerSync
import FCTServerSyncTesting
import Foundation
import SwiftData
import Testing

@testable import VillainArc

/// The profile row's two halves of the setup question: what a pulled row is allowed to leave
/// behind, and what an empty store is allowed to be read as.
@MainActor
struct UserProfileApplyTests {
    private func makeProfile() throws -> (ModelContext, UserProfile) {
        let context = try TestDataFactory.makeContext()
        let profile = UserProfile()
        context.insert(profile)
        return (context, profile)
    }

    /// The fitness level and the moment it was chosen are one fact. A row carrying a null level
    /// must not leave the timestamp standing: `firstMissingStep` reads that pair as "still
    /// missing", so a half-applied row asks the user for a level they already gave and keeps
    /// asking however many times they answer.
    @Test func aNullFitnessLevelClearsItsTimestamp() throws {
        let (_, profile) = try makeProfile()
        profile.fitnessLevel = .advanced
        profile.fitnessLevelSetAt = Date(timeIntervalSince1970: 1_772_000_000)

        profile.apply([
            "fitness_level": .null,
            "fitness_level_set_at": .date(Date(timeIntervalSince1970: 1_772_000_000)),
        ])

        #expect(profile.fitnessLevel == nil)
        #expect(profile.fitnessLevelSetAt == nil, "a timestamp without a level is a state no write path produces")
    }

    /// The same row applied whole restores both halves.
    @Test func aFitnessLevelAndItsTimestampApplyTogether() throws {
        let (_, profile) = try makeProfile()
        let setAt = Date(timeIntervalSince1970: 1_772_000_000)

        profile.apply([
            "fitness_level": .string(FitnessLevel.advanced.rawValue),
            "fitness_level_set_at": .date(setAt),
        ])

        #expect(profile.fitnessLevel == .advanced)
        #expect(profile.fitnessLevelSetAt == setAt)
    }

    /// A profile restored whole from the account asks nothing. This is the fact the first-run
    /// path leans on: setup is what the *restored* store still lacks, never what an unrestored
    /// one happens to be empty of.
    @Test func aWhollyRestoredProfileIsComplete() throws {
        let (_, profile) = try makeProfile()

        profile.apply([
            "name": .string("Fernando"),
            "birthday": .date(Date(timeIntervalSince1970: 1_034_000_000)),
            "gender": .string(UserGender.male.rawValue),
            "height_cm": .double(170.18),
            "fitness_level": .string(FitnessLevel.advanced.rawValue),
            "fitness_level_set_at": .date(Date(timeIntervalSince1970: 1_772_000_000)),
        ])

        #expect(profile.firstMissingStep == nil)
        #expect(profile.isComplete)
    }
}

/// `restoreAccountData()`'s contract, which is what the first-run path spends: it either brings
/// the account down or says it could not.
///
/// That the pull itself delivers every row correctly is the engine's own property and is proven
/// against the adopter contract in `VASyncContractTests`. What is proven here is the answer this
/// app acts on — because the one reading that must never happen is "the call failed, therefore
/// the account is empty, therefore ask the user to type everything back in."
@Suite("First-run account restore", .serialized)
struct VASyncRestoreTests {
    @Test @MainActor
    func aHealthyCycleCompletesTheRestore() async throws {
        let harness = try VASyncFaultHarness()
        await harness.enroll()

        #expect(await harness.sync.restoreAccountData())
    }

    /// The honest-failure half. An unreachable server must come back as a refusal, never as a
    /// completed restore over an empty store — those look identical and mean opposite things.
    @Test @MainActor
    func anUnreachableAccountRefusesRatherThanReportingAnEmptyOne() async throws {
        let harness = try VASyncFaultHarness()
        await harness.enroll()
        await harness.injector.set(.unreachable)

        #expect(await harness.sync.restoreAccountData() == false)
    }

    /// A device with no engine at all cannot have restored anything, and says so rather than
    /// waiting forever for one that is never coming.
    @Test @MainActor
    func noEngineIsNotARestore() async throws {
        let harness = try VASyncFaultHarness()

        #expect(await harness.sync.restoreAccountData(waitingUpTo: .milliseconds(200)) == false)
    }

    /// **A push cycle is not a read, and the restore is answered only by a read.**
    ///
    /// A local save asks for a `.push`: it drains and sends, and pulls only if the reply says
    /// another device has written since. A device whose own push *is* the account's high-water is
    /// told nothing, so the cycle comes back `.idle` having fetched no row.
    ///
    /// The shape is the one that costs most — a first run that could not reach the account, then
    /// one workout logged by hand — and the property that makes it safe is that `restoreAccountData`
    /// asks a full cycle of its own every time. A clean push before it must not be mistakable for a
    /// restore, or setup would open over a library still sitting on the server.
    @Test @MainActor
    func aCleanPushCycleIsNotMistakenForARestore() async throws {
        let server = FakeSyncServer()
        let objects = FakeBlobObjectStore()
        let accountID = UUID()

        // Another device on this account already has a session on the server.
        let other = try VASyncFaultHarness(server: server, objects: objects, accountID: accountID)
        try other.writeSession(notes: "seeded elsewhere")
        await other.enroll()
        try #require(await other.serverSessionCount() == 1, "the seeding device did reach the account")

        // This device: same account, nothing local, and a first run that cannot reach it.
        let harness = try VASyncFaultHarness(server: server, objects: objects, accountID: accountID)
        await harness.injector.set(.unreachable)
        await harness.enroll()
        #expect(await harness.sync.restoreAccountData() == false,
                "an unanswered question is never 'the account is empty'")

        // The link is back, and the user logs a workout. That save is a reason to SEND, not to ask.
        await harness.injector.set(nil)
        try harness.writeSession(notes: "logged by hand")
        await harness.sync.syncNow(.push)
        try #require(harness.sync.status == .idle, "the push cycle itself completed cleanly")
        #expect(harness.localSessionCount == 1,
                "and the account's own session is still not on this device")

        // The restore is answered by a pull of its own, not by the push that just succeeded.
        #expect(await harness.sync.restoreAccountData())
        #expect(harness.localSessionCount == 2, "the account's session came down with it")
    }

    /// Records the server judged and refused are a **push**-side fact that never clears on its own.
    /// The pull still ran, so the account was read and setup may proceed — gating on a clean outbox
    /// instead would strand the user at an error screen with no profile and a Retry that can never
    /// succeed, which is exactly what one poisoned unrelated table did.
    @Test @MainActor
    func recordsTheServerRefusedDoNotBlockTheRestore() async throws {
        let harness = try VASyncFaultHarness()
        await harness.enroll()

        let stuck = try harness.writeSession(notes: "refused")
        await harness.server.setRejecting([stuck])
        await harness.sync.syncNow(.full)
        #expect(harness.sync.counted.stuck >= 1, "the fixture must actually strand a record")

        #expect(await harness.sync.restoreAccountData())
    }
}
