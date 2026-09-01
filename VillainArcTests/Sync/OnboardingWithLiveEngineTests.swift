import FCTServerSync
import FCTServerSyncTesting
import Foundation
import SwiftData
import Testing

@testable import VillainArc

/// **An open defect, reproduced.** The fitness level is lost by a full sync cycle.
///
/// Disabled so the gate stays green while the cause is still open; remove the trait to run it. It
/// fails at checkpoint C, deterministically.
///
/// What it establishes, and what each checkpoint rules out:
/// - **A** — after `save()`, the level is on disk. The write path is sound.
/// - **B** — after a cycle that cannot reach the server (drain only), it is still on disk. The
///   drain and the outbox are not it.
/// - **C** — after one full drain → push → pull → apply, it is **gone from disk**, while
///   `heightCm` (written the step before) and `fitnessLevelSetAt` (written on the adjacent line)
///   both survive, the profile count is still 1 under the right id, and the server holds
///   `.string("advanced")`.
///
/// Ruled out by the surrounding suites rather than assumed: `apply(_:)` given the server's own row
/// yields `.advanced`; optional enums persist through both `mainContext` and a secondary
/// `ModelContext(container)` (`OptionalEnumContextTests`); the manager's whole sequence keeps the
/// value with no engine running (`OnboardingFitnessLevelHopTests`); and there is no duplicate
/// singleton. `UserProfile.apply` clears the timestamp whenever the level is nil, so the final
/// (nil, timestamp) pair **cannot have been produced by `apply` at all** — which is the sharpest
/// clue left.
///
/// Next probe: `SyncEngine.applyPhaseHook` exposes `.afterDrain`, `.afterSnapshot`, `.afterSave`
/// and `.afterPostDrain` for exactly this — read the on-disk level at each phase to pin which of
/// the apply's own writes drops it. That needs driving `SyncEngine` directly, since `VASync` does
/// not expose its engine.
@Suite("Onboarding under a live engine", .serialized)
struct OnboardingWithLiveEngineTests {
    /// The on-disk truth: a container reopened on the same file, sharing no snapshot with the
    /// writer or with the applier's contexts.
    private func onDisk(_ harness: VASyncFaultHarness) throws -> UserProfile? {
        let reopened = try ModelContainer(
            for: SharedModelContainer.schema,
            configurations: [ModelConfiguration(nil, schema: SharedModelContainer.schema, url: harness.storeURL, allowsSave: true, cloudKitDatabase: .none)]
        )
        return try ModelContext(reopened).fetch(UserProfile.single).first
    }

    /// One profile step: mutate and save, exactly as `OnboardingManager` does.
    private func save(_ harness: VASyncFaultHarness, _ mutate: (UserProfile) -> Void) throws {
        let context = harness.container.mainContext
        let profile = try #require(try context.fetch(UserProfile.single).first)
        mutate(profile)
        try context.save()
    }

    @Test @MainActor
    func aFullCycleKeepsTheFitnessLevel() async throws {
        let harness = try VASyncFaultHarness()
        let context = harness.container.mainContext

        _ = try SystemState.ensureUserProfile(context: context)
        await harness.enroll()

        try save(harness) { $0.name = "Repro" }
        await harness.sync.syncNow(.full)
        try save(harness) { $0.heightCm = 177.8 }
        await harness.sync.syncNow(.full)

        try save(harness) {
            $0.fitnessLevel = .advanced
            $0.fitnessLevelSetAt = .now
        }

        #expect(try onDisk(harness)?.fitnessLevel == .advanced, "A: after the save, before any cycle")

        // A cycle that cannot reach the server: it drains, but pushes and applies nothing.
        await harness.injector.set(.unreachable)
        await harness.sync.syncNow(.full)
        #expect(try onDisk(harness)?.fitnessLevel == .advanced, "B: after a drain-only, offline cycle")

        // The full cycle: drain, push, pull, apply.
        await harness.injector.set(nil)
        await harness.sync.syncNow(.full)

        let id = VASyncIdentity.userProfileID
        let table = UserProfile.syncTableName
        #expect(await harness.server.value("fitness_level", of: id, in: table)?.stringValue == "advanced",
                "C: the wire carried it, so the loss is local")
        #expect(try harness.container.mainContext.fetchCount(FetchDescriptor<UserProfile>()) == 1,
                "C: still exactly one profile")
        #expect(try onDisk(harness)?.heightCm == 177.8, "C: the control survives the full cycle")
        #expect(try onDisk(harness)?.fitnessLevelSetAt != nil, "C: the timestamp survives the full cycle")
        #expect(try onDisk(harness)?.fitnessLevel == .advanced, "C: after the full cycle")
    }
}

/// The same defect on every other optional enum stored on a synced model.
///
/// `apply(_:)` re-assigns each column on every pull, so any optional enum attribute on a synced
/// model is dropped by the applier's save exactly as `UserProfile.fitnessLevel` was. `WeightGoal`
/// is the clean representative: no parent links, one optional enum, and a non-optional enum
/// (`type`) beside it as the control.
@Suite("Optional enums on synced models", .serialized)
struct SyncedOptionalEnumSweepTests {
    @Test @MainActor
    func aWeightGoalsEndReasonSurvivesAFullCycle() async throws {
        let harness = try VASyncFaultHarness()
        let context = harness.container.mainContext

        let goal = WeightGoal(type: .cut, startWeight: 90, targetWeight: 80)
        context.insert(goal)
        try context.save()
        await harness.enroll()

        goal.endedAt = .now
        goal.endReason = .achieved
        try context.save()
        await harness.sync.syncNow(.full)

        let reopened = try ModelContainer(
            for: SharedModelContainer.schema,
            configurations: [ModelConfiguration(nil, schema: SharedModelContainer.schema, url: harness.storeURL, allowsSave: true, cloudKitDatabase: .none)]
        )
        let stored = try #require(try ModelContext(reopened).fetch(FetchDescriptor<WeightGoal>()).first)
        #expect(stored.type == .cut, "the control: a non-optional enum with a default")
        #expect(stored.endedAt != nil, "the control: a Date? on the adjacent line")
        #expect(stored.endReason == .achieved, "the optional enum, now stored as raw text")
    }
}
