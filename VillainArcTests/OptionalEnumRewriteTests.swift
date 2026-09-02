import Foundation
import SwiftData
import Testing

@testable import VillainArc

/// Re-assigning a stored property **the value it already holds**, then saving.
///
/// This is what the sync applier does on every pull: it fetches the row, calls `apply(_:)`, and
/// `apply` assigns each column from the server — which, for a row this device just pushed, is the
/// value already there. Every other test in this repo changes the value; none re-writes an equal
/// one, which is why they all pass while the device fails.
@MainActor
struct OptionalEnumRewriteTests {
    private func makeStore() throws -> (ModelContainer, URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("VillainArcTests-\(UUID().uuidString).store")
        return (try ModelContainer(for: SharedModelContainer.schema, configurations: [
            ModelConfiguration(nil, schema: SharedModelContainer.schema, url: url, allowsSave: true, cloudKitDatabase: .none)
        ]), url)
    }

    private func reread(_ url: URL) throws -> UserProfile? {
        let reopened = try ModelContainer(for: SharedModelContainer.schema, configurations: [
            ModelConfiguration(nil, schema: SharedModelContainer.schema, url: url, allowsSave: true, cloudKitDatabase: .none)
        ])
        return try ModelContext(reopened).fetch(UserProfile.single).first
    }

    /// Seeds a profile whose every field is already set, committed to disk.
    private func seed(_ container: ModelContainer, setAt: Date) throws {
        let profile = try SystemState.ensureUserProfile(context: container.mainContext)
        profile.heightCm = 177.8
        profile.fitnessLevel = .advanced
        profile.fitnessLevelSetAt = setAt
        try container.mainContext.save()
    }

    /// The applier's exact shape: secondary context, every field re-assigned its current value.
    @Test func rewritingEqualValuesInASecondaryContextKeepsThemAll() throws {
        let (container, url) = try makeStore()
        defer { try? FileManager.default.removeItem(at: url) }
        let setAt = Date(timeIntervalSince1970: 1_772_000_000)
        try seed(container, setAt: setAt)

        let applier = ModelContext(container)
        let profile = try #require(try applier.fetch(UserProfile.single).first)
        #expect(profile.fitnessLevel == .advanced, "precondition: the applier reads it before rewriting")
        profile.heightCm = 177.8
        profile.fitnessLevel = .advanced
        profile.fitnessLevelSetAt = setAt
        try applier.save()

        let stored = try #require(try reread(url))
        #expect(stored.heightCm == 177.8, "Double?")
        #expect(stored.fitnessLevelSetAt == setAt, "Date?")
        #expect(stored.fitnessLevel == .advanced, "the optional enum")
    }

    /// The same rewrite through `mainContext`, to say whether the context is part of the trigger.
    @Test func rewritingEqualValuesInMainContextKeepsThemAll() throws {
        let (container, url) = try makeStore()
        defer { try? FileManager.default.removeItem(at: url) }
        let setAt = Date(timeIntervalSince1970: 1_772_000_000)
        try seed(container, setAt: setAt)

        let profile = try #require(try container.mainContext.fetch(UserProfile.single).first)
        profile.fitnessLevel = .advanced
        profile.fitnessLevelSetAt = setAt
        try container.mainContext.save()

        #expect(try reread(url)?.fitnessLevel == .advanced)
    }
}
