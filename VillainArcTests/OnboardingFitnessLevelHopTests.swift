import FCTSync
import Foundation
import SwiftData
import Testing

@testable import VillainArc

/// The onboarding write path driven through the **real** `OnboardingManager` against the **real**
/// App Group container, one hop at a time.
///
/// Everything narrower has already been eliminated: the isolated round trip, the
/// mutate-an-existing-profile sequence, a duplicate singleton, the sibling context the push reads
/// from, and off-main writes. What is left is the manager's own sequence — the steps before the
/// level, the save it performs, and what the follow-on work does to the value afterwards.
///
/// `OnboardingManager` writes to `SharedModelContainer.container.mainContext`, which in this
/// app-hosted suite is the genuine App Group store, so this exercises exactly what the device runs.
/// The suite is serialized and puts the store back the way it found it.
@Suite("Onboarding fitness-level hops", .serialized)
@MainActor
struct OnboardingFitnessLevelHopTests {
    /// Removes whatever this suite created, so the shared host store is left as it was found.
    private func clearProfileAndGoals() throws {
        let context = SharedModelContainer.container.mainContext
        for profile in try context.fetch(FetchDescriptor<UserProfile>()) { context.delete(profile) }
        for goal in try context.fetch(FetchDescriptor<TrainingGoal>()) { context.delete(goal) }
        try context.save()
    }

    /// Reads the property back through a context that shares nothing with the writer's snapshot.
    private func levelFromAFreshContext() throws -> FitnessLevel? {
        let context = ModelContext(SharedModelContainer.container)
        return try context.fetch(UserProfile.single).first?.fitnessLevel
    }

    /// Every onboarding step in order, through the manager's own methods, asserting the level at
    /// each hop after it is set.
    @Test func theLevelSurvivesEveryHopOfTheManagersOwnSequence() async throws {
        try clearProfileAndGoals()
        defer { try? clearProfileAndGoals() }

        let context = SharedModelContainer.container.mainContext
        let manager = OnboardingManager()
        // The restore is not what is under test here, and a live engine is not available in the
        // suite; the sequence after it is what matters.
        manager.restoreAccountData = { true }
        let profile = try SystemState.ensureUserProfile(context: context)
        manager.profile = profile

        #expect(await manager.saveGender(.male))
        #expect(await manager.saveHeight(cm: 177.8))

        // The hop under suspicion.
        #expect(await manager.saveFitnessLevel(.advanced))

        #expect(profile.fitnessLevel == .advanced, "hop 1: the instance the manager wrote")
        #expect(try levelFromAFreshContext() == .advanced, "hop 2: a fresh context on the same container")

        // Hop 3: the follow-on work the manager does after the level, which is where the session
        // continues on the device — the training goal, then the finish.
        #expect(await manager.saveTrainingGoal(.generalTraining))

        #expect(profile.fitnessLevel == .advanced, "hop 4: after the training goal and the finish")
        #expect(try levelFromAFreshContext() == .advanced, "hop 5: fresh context after the finish")
        #expect(profile.firstMissingStep == nil, "hop 6: what a relaunch would consult")
    }

    /// The relaunch itself: what a brand-new container reads off the same file after the manager's
    /// sequence has completed. This is the case the device fails.
    @Test func theLevelSurvivesReopeningTheRealStore() async throws {
        try clearProfileAndGoals()
        defer { try? clearProfileAndGoals() }

        let context = SharedModelContainer.container.mainContext
        let manager = OnboardingManager()
        manager.restoreAccountData = { true }
        manager.profile = try SystemState.ensureUserProfile(context: context)

        #expect(await manager.saveGender(.male))
        #expect(await manager.saveHeight(cm: 177.8))
        #expect(await manager.saveFitnessLevel(.advanced))
        #expect(await manager.saveTrainingGoal(.generalTraining))

        // A second container over the same App Group file — the closest a hosted test gets to a
        // relaunch without ending the process.
        let reopened = try SharedModelContainer.configuration.makeContainer()
        let stored = try #require(try ModelContext(reopened).fetch(UserProfile.single).first)
        #expect(stored.fitnessLevel == .advanced, "what the next launch reads")
        #expect(stored.fitnessLevelSetAt != nil)
        #expect(stored.firstMissingStep == nil)
    }
}
