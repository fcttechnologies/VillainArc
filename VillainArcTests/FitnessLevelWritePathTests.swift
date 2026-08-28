import FCTServerSync
import FCTSync
import Foundation
import SwiftData
import Testing

@testable import VillainArc

/// The onboarding write path for the fitness level, hop by hop.
///
/// `OptionalEnumPersistenceTests` proves an optional enum survives a store round trip, but it
/// builds the profile whole and saves once. The app does not: `SystemState.ensureUserProfile`
/// inserts and **saves** a blank profile, and `OnboardingManager.saveFitnessLevel` mutates that
/// already-persisted instance later, in a second transaction. These pin that real sequence, and
/// each of the places the value is read afterwards.
@MainActor
struct FitnessLevelWritePathTests {
    /// A store on disk, so a "fresh read" can mean a genuinely new container rather than the same
    /// context answering from its own snapshot.
    private func makeStore() throws -> (ModelContainer, URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("VillainArcTests-\(UUID().uuidString).store")
        let configuration = ModelConfiguration(nil, schema: SharedModelContainer.schema, url: url, allowsSave: true, cloudKitDatabase: .none)
        return (try ModelContainer(for: SharedModelContainer.schema, configurations: [configuration]), url)
    }

    /// The app's exact sequence: ensure (insert + save), then set the level on that same instance
    /// and save again.
    @Test func aLevelSetOnAnAlreadyPersistedProfileSurvivesAFreshContainer() throws {
        let (container, url) = try makeStore()
        defer { try? FileManager.default.removeItem(at: url) }

        // SystemState.ensureUserProfile
        let profile = try SystemState.ensureUserProfile(context: container.mainContext)

        // OnboardingManager.saveFitnessLevel
        profile.fitnessLevel = .advanced
        profile.fitnessLevelSetAt = .now
        try container.mainContext.save()

        #expect(profile.fitnessLevel == .advanced, "the instance just written")
        #expect(profile.firstMissingStep != .fitnessLevel, "what nextRequiredStep consults")

        let reread = try ModelContainer(for: SharedModelContainer.schema, configurations: [
            ModelConfiguration(nil, schema: SharedModelContainer.schema, url: url, allowsSave: true, cloudKitDatabase: .none)
        ])
        let stored = try #require(try reread.mainContext.fetch(UserProfile.single).first)
        #expect(stored.fitnessLevel == .advanced, "what a relaunch reads")
        #expect(stored.fitnessLevelSetAt != nil)
    }

    /// The push reads the row through its own `ModelContext(container)`, not the main one, so the
    /// value has to be visible to a sibling context on the same container.
    @Test func aLevelIsVisibleToTheContextTheSyncPushReadsFrom() throws {
        let (container, url) = try makeStore()
        defer { try? FileManager.default.removeItem(at: url) }

        let profile = try SystemState.ensureUserProfile(context: container.mainContext)
        profile.fitnessLevel = .advanced
        profile.fitnessLevelSetAt = .now
        try container.mainContext.save()

        let pushContext = ModelContext(container)
        let seen = try #require(try pushContext.fetch(UserProfile.descriptor(forSyncIDs: [profile.id])).first)
        let row = seen.syncRow()
        #expect(row["fitness_level"]?.stringValue == FitnessLevel.advanced.rawValue)
        #expect(row["fitness_level_set_at"]?.isNull == false)
    }

    /// The singleton is fetched two different ways — `UserProfile.single` takes *any* row, while
    /// the sync path matches on the fixed id. Two rows would let those disagree, and only one of
    /// them would ever be written.
    @Test func thereIsExactlyOneProfileAndBothFetchesAgree() throws {
        let (container, url) = try makeStore()
        defer { try? FileManager.default.removeItem(at: url) }

        let profile = try SystemState.ensureUserProfile(context: container.mainContext)
        profile.fitnessLevel = .advanced
        profile.fitnessLevelSetAt = .now
        try container.mainContext.save()

        // A second ensure must not mint a second singleton.
        _ = try SystemState.ensureUserProfile(context: container.mainContext)

        let all = try container.mainContext.fetch(FetchDescriptor<UserProfile>())
        #expect(all.count == 1, "two profiles means only one of them is ever written")
        #expect(all.first?.id == VASyncIdentity.userProfileID)

        let bySingle = try #require(try container.mainContext.fetch(UserProfile.single).first)
        let byID = try #require(try container.mainContext.fetch(UserProfile.descriptor(forSyncIDs: [VASyncIdentity.userProfileID])).first)
        #expect(bySingle.fitnessLevel == .advanced)
        #expect(byID.fitnessLevel == .advanced)
    }

    /// The same sequence through the app's **own** container wiring — `AppGroupStoreConfiguration`,
    /// the real App Group container, `VillainArcSchemaV1` — rather than a bare `ModelConfiguration`
    /// on a temp file. Only the store filename differs, so the app's own store is untouched.
    ///
    /// If the level survives a bare container but not this one, the difference between them is the
    /// bug.
    @Test func aLevelSurvivesTheAppsOwnContainerWiring() throws {
        let name = "FitnessLevelWritePathTests-\(UUID().uuidString).store"
        let configuration = AppGroupStoreConfiguration(
            appGroupID: SharedModelContainer.appGroupID,
            storeName: name,
            cloudContainerID: nil,
            versionedSchema: VillainArcSchemaV1.self
        )
        let url = try configuration.storeURL()
        defer {
            for suffix in ["", "-shm", "-wal"] {
                try? FileManager.default.removeItem(at: url.appendingPathExtension(suffix.isEmpty ? "" : String(suffix.dropFirst())))
            }
            try? FileManager.default.removeItem(at: url)
        }

        let container = try configuration.makeContainer()
        let profile = try SystemState.ensureUserProfile(context: container.mainContext)
        profile.fitnessLevel = .advanced
        profile.fitnessLevelSetAt = .now
        try container.mainContext.save()

        let reread = try configuration.makeContainer()
        let stored = try #require(try reread.mainContext.fetch(UserProfile.single).first)
        #expect(stored.fitnessLevel == .advanced, "what a relaunch reads from the real store")
        #expect(stored.fitnessLevelSetAt != nil)
        #expect(stored.firstMissingStep != .fitnessLevel)
    }
}
