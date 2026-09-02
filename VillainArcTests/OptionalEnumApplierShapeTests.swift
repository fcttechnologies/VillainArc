import FCTServerSync
import Foundation
import SwiftData
import Testing

@testable import VillainArc

/// The applier's save, reduced to its parts.
///
/// Established by `ApplyPhaseProbeTests`: `apply(_:)` receives the correct row
/// (`fitness_level = .string("advanced")`), assigns it, and the applier's very next `save()`
/// persists NULL for that one attribute while the `Date?` on the adjacent line survives. A plain
/// secondary context doing the same assignments does **not** lose it
/// (`OptionalEnumRewriteTests`), so the trigger is something else the applier does. It does two
/// unusual things: it sets `ModelContext.author`, and it fetches through
/// `descriptor(forSyncIDs:)` rather than `UserProfile.single`.
@MainActor
struct OptionalEnumApplierShapeTests {
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

    private let setAt = Date(timeIntervalSince1970: 1_772_000_000)

    private func seed(_ container: ModelContainer) throws {
        let profile = try SystemState.ensureUserProfile(context: container.mainContext)
        profile.heightCm = 177.8
        profile.fitnessLevel = .advanced
        profile.fitnessLevelSetAt = setAt
        try container.mainContext.save()
    }

    /// The row the applier really receives, as captured from the wire.
    private var wireRow: [String: JSONValue] {
        [
            "gender": .string(UserGender.notSet.rawValue),
            "date_joined": .date(Date(timeIntervalSince1970: 1_700_000_000)),
            "height_cm": .double(177.8),
            "fitness_level": .string(FitnessLevel.advanced.rawValue),
            "fitness_level_set_at": .date(setAt),
        ]
    }

    /// Runs the applier's shape with each ingredient switchable, and reports what reached disk.
    private func applierSave(author: Bool, fetchBySyncID: Bool) throws -> FitnessLevel? {
        let (container, url) = try makeStore()
        defer { try? FileManager.default.removeItem(at: url) }
        try seed(container)

        let context = ModelContext(container)
        if author { context.author = "fct-server-sync.applier" }
        let profile: UserProfile
        if fetchBySyncID {
            profile = try #require(try context.fetch(UserProfile.descriptor(forSyncIDs: [VASyncIdentity.userProfileID])).first)
        } else {
            profile = try #require(try context.fetch(UserProfile.single).first)
        }
        profile.apply(wireRow)
        try context.save()

        return try reread(url)?.fitnessLevel
    }

    @Test func neitherIngredient() throws {
        #expect(try applierSave(author: false, fetchBySyncID: false) == .advanced)
    }

    @Test func authorOnly() throws {
        #expect(try applierSave(author: true, fetchBySyncID: false) == .advanced)
    }

    @Test func syncIDFetchOnly() throws {
        #expect(try applierSave(author: false, fetchBySyncID: true) == .advanced)
    }

    @Test func bothAsTheApplierDoes() throws {
        #expect(try applierSave(author: true, fetchBySyncID: true) == .advanced)
    }
}
