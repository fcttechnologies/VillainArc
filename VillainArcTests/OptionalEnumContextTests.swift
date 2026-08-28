import Foundation
import SwiftData
import Testing

@testable import VillainArc

/// Which **context** an optional enum is written through, and whether it reaches the file.
///
/// `OptionalEnumPersistenceTests` writes through `mainContext` and passes. The sync applier does
/// not: it writes through a plain `ModelContext(container)`. These isolate that one variable, with
/// a `Date?` assigned on the adjacent line as the control — because on the device that `Date?`
/// survives while the enum beside it does not.
@MainActor
struct OptionalEnumContextTests {
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

    /// The control: the same two assignments through `mainContext`.
    @Test func anOptionalEnumWrittenThroughMainContextPersists() throws {
        let (container, url) = try makeStore()
        defer { try? FileManager.default.removeItem(at: url) }

        let profile = try SystemState.ensureUserProfile(context: container.mainContext)
        profile.fitnessLevel = .advanced
        profile.fitnessLevelSetAt = Date(timeIntervalSince1970: 1_772_000_000)
        try container.mainContext.save()

        let stored = try #require(try reread(url))
        #expect(stored.fitnessLevel == .advanced)
        #expect(stored.fitnessLevelSetAt != nil)
    }

    /// The applier's shape: a plain `ModelContext(container)`, the same two assignments, one save.
    @Test func anOptionalEnumWrittenThroughASecondaryContextPersists() throws {
        let (container, url) = try makeStore()
        defer { try? FileManager.default.removeItem(at: url) }

        _ = try SystemState.ensureUserProfile(context: container.mainContext)

        let applier = ModelContext(container)
        let profile = try #require(try applier.fetch(UserProfile.single).first)
        profile.fitnessLevel = .advanced
        profile.fitnessLevelSetAt = Date(timeIntervalSince1970: 1_772_000_000)
        try applier.save()

        let stored = try #require(try reread(url))
        #expect(stored.fitnessLevelSetAt != nil, "the control: the Date? on the adjacent line")
        #expect(stored.fitnessLevel == .advanced, "the optional enum")
    }

    /// A non-optional enum with a default, written through the same secondary context — the shape
    /// `gender` has, which survives on the device.
    @Test func aNonOptionalEnumWrittenThroughASecondaryContextPersists() throws {
        let (container, url) = try makeStore()
        defer { try? FileManager.default.removeItem(at: url) }

        _ = try SystemState.ensureUserProfile(context: container.mainContext)

        let applier = ModelContext(container)
        let profile = try #require(try applier.fetch(UserProfile.single).first)
        profile.gender = .male
        try applier.save()

        #expect(try reread(url)?.gender == .male)
    }
}
