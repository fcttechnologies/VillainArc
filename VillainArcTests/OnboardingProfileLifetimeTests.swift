import Foundation
import SwiftData
import Testing

@testable import VillainArc

/// What the setup steps read after the row behind the profile has gone.
///
/// A `@Model` reference outlives its row, and every property read off a deleted one traps inside
/// SwiftData — which is not a failing test but a dead process, taking whatever else was running
/// with it. The store is cleared under this exact view on a sign-out, an account switch and a
/// deletion, so the manager has to answer "no profile" rather than hand out a reference that
/// cannot be read.
@Suite("Onboarding profile lifetime", .serialized)
@MainActor
struct OnboardingProfileLifetimeTests {
    @Test func theManagerDropsAProfileWhoseRowWasDeleted() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)
        let profile = UserProfile()
        context.insert(profile)
        try context.save()

        let manager = OnboardingManager()
        manager.profile = profile
        #expect(manager.profile != nil)

        context.delete(profile)
        try context.save()

        // The state a deleted-and-saved row is actually in, measured rather than assumed: it is
        // detached from its context while still reporting `isDeleted == false`, and that pairing
        // is what the manager's guard has to be written against.
        #expect(profile.modelContext == nil)
        #expect(profile.isDeleted == false)
        #expect(manager.profile == nil, "a deleted row is not a profile the setup steps can read")
    }

    /// The step that crashes when it is handed one: it reads `gender` straight off the profile in
    /// its `init`, which is where a dead reference becomes a dead process.
    @Test func theGenderTheStepStartsOnSurvivesADeletedProfile() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)
        let profile = UserProfile()
        profile.gender = .female
        context.insert(profile)
        try context.save()

        let manager = OnboardingManager()
        manager.profile = profile
        #expect(manager.profile?.gender == .female)

        context.delete(profile)
        try context.save()

        #expect((manager.profile?.gender ?? .notSet) == .notSet)
    }
}
