#if DEBUG
import FCTScreenshotStudio
import FCTSync
import Foundation
import SwiftData
import Testing

@testable import VillainArc

/// What the debug surface's safety actually rests on: it writes into a **different store file**.
///
/// The sync engine drains one thing — the app's own store's persistent history — so that history
/// is where this looks. A seed that reached the account would have to appear there first, and a
/// seed that appears nowhere in it cannot have produced a push, whatever the seeder does with the
/// rows it was given.
///
/// The drain is only worth its known-answer control: an empty batch from a reader watching the
/// wrong store, or one whose cursor already ran past the window, reads exactly like proof. So every
/// case that expects silence follows it with one real write to the same store through the same
/// reader, and expects that one to be reported.
@MainActor
struct DetachedDebugStoreTests {
    private struct Stores {
        let real: ModelContainer
        let debug: DebugStoreSwitch
        let directory: URL
    }

    /// An app store and the detached store beside it, wired exactly as the app root wires them —
    /// same schema, `DebugStore`'s own URL derivation, no CloudKit on either.
    private func makeStores() throws -> Stores {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "VADebugStoreTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let realURL = directory.appending(path: "VillainArc.store")
        let real = try ModelContainer(
            for: SharedModelContainer.schema,
            configurations: [ModelConfiguration(nil, schema: SharedModelContainer.schema, url: realURL, allowsSave: true, cloudKitDatabase: .none)]
        )
        let detachedURL = DebugStore.detachedURL(besideStoreAt: realURL)
        #expect(detachedURL != realURL, "the detached store is the app's own store: nothing below can mean anything")

        let debug = DebugStoreSwitch {
            try DebugStore.detached(schema: SharedModelContainer.schema, url: detachedURL)
        }
        return Stores(real: real, debug: debug, directory: directory)
    }

    private func removeStores(_ stores: Stores) {
        try? FileManager.default.removeItem(at: stores.directory)
    }

    // MARK: - The seed

    @Test func aStudioSeedWritesNothingIntoTheAppsOwnHistory() throws {
        let stores = try makeStores()
        defer { removeStores(stores) }

        // `.any` is the whole feed: filtering here could hide a write rather than prove there
        // wasn't one.
        let reader = StoreHistoryReader(container: stores.real, authorFilter: .any)
        try reader.establishBaseline()

        try ScreenshotStudioSeeder.seedAll(in: stores.debug.detachedContainer().mainContext)

        let afterSeed = try reader.drain()
        #expect(afterSeed.transactions.isEmpty, "the seed put \(afterSeed.transactions.count) transaction(s) into the app's own store's history")
        #expect(afterSeed.inserted.isEmpty, "the seed inserted \(afterSeed.inserted.count) row(s) into the app's own store")
        #expect(afterSeed.updated.isEmpty, "the seed updated \(afterSeed.updated.count) row(s) in the app's own store")
        #expect(afterSeed.deleted.isEmpty, "the seed deleted \(afterSeed.deleted.count) row(s) from the app's own store — each one a tombstone")

        // The control: one real write, through this same reader, must come back. Without it the
        // silence above is unfalsifiable.
        let realContext = stores.real.mainContext
        realContext.insert(WorkoutPlan(title: "The user's own plan"))
        try realContext.save()

        let control = try reader.drain()
        #expect(control.inserted.count == 1, "the control write was reported as \(control.inserted.count) insert(s), not 1 — this reader cannot see this store, so the empty drain above proves nothing")
    }

    @Test func everyDebugSeedWritesNothingIntoTheAppsOwnHistory() throws {
        let stores = try makeStores()
        defer { removeStores(stores) }

        let reader = StoreHistoryReader(container: stores.real, authorFilter: .any)
        try reader.establishBaseline()

        let debugContext = try stores.debug.detachedContainer().mainContext
        try DebugOperations.seedDemoData(in: debugContext)
        try DebugOperations.seedWorkoutData(in: debugContext)
        try DebugOperations.touchAllModels(in: debugContext)
        for scenario in DebugOperations.HealthSampleScenario.allCases {
            try DebugOperations.seedHealthSamples(scenario: scenario, in: debugContext)
        }

        let afterSeeds = try reader.drain()
        #expect(afterSeeds.transactions.isEmpty, "a debug menu operation reached the app's own store: \(afterSeeds.inserted.count) inserted, \(afterSeeds.updated.count) updated, \(afterSeeds.deleted.count) deleted")

        let realContext = stores.real.mainContext
        realContext.insert(WorkoutPlan(title: "The user's own plan"))
        try realContext.save()
        #expect(try reader.drain().inserted.count == 1, "the control write was not reported — the empty drain above proves nothing")
    }

    /// The demo store is a store like any other: the seed has to land somewhere, and this is the
    /// half that says the seed ran at all rather than silently doing nothing.
    @Test func theSeedLandsInTheDetachedStore() throws {
        let stores = try makeStores()
        defer { removeStores(stores) }

        let debugContext = try stores.debug.detachedContainer().mainContext
        try ScreenshotStudioSeeder.seedAll(in: debugContext)

        #expect(try debugContext.fetch(WorkoutPlan.byID(ScreenshotStudioSeeder.DemoID.plan)).first != nil)
        #expect(try debugContext.fetch(FetchDescriptor<HealthStepsDistance>()).count == 35)
        #expect(try ModelContext(stores.real).fetch(FetchDescriptor<WorkoutPlan>()).isEmpty, "the seed reached the app's own store")
    }

    // MARK: - The reset

    @Test func aResetRefusesWhileAnAccountIsSignedIn() throws {
        let stores = try makeStores()
        defer { removeStores(stores) }

        let debugContext = try stores.debug.detachedContainer().mainContext
        try ScreenshotStudioSeeder.seedAll(in: debugContext)

        // A cache the app would hand over: the refusal has to come before anything is removed.
        let cache = stores.directory.appending(path: "VillainArc.store.syncstate.json")
        try Data("{}".utf8).write(to: cache)

        #expect(throws: DebugResetRefusal.accountSignedIn) {
            try DebugReset.perform(stores.debug, isSignedIn: true, localCaches: [cache])
        }

        #expect(FileManager.default.fileExists(atPath: cache.path), "the refused reset removed the sync state file anyway")
        #expect(try ModelContext(stores.debug.detachedContainer()).fetch(FetchDescriptor<WorkoutPlan>()).isEmpty == false, "the refused reset erased the store anyway")
    }

    @Test func aResetSignedOutErasesTheDebugStoreAndNothingElse() throws {
        let stores = try makeStores()
        defer { removeStores(stores) }

        let realContext = stores.real.mainContext
        realContext.insert(WorkoutPlan(title: "The user's own plan"))
        try realContext.save()

        try ScreenshotStudioSeeder.seedAll(in: stores.debug.detachedContainer().mainContext)

        let cache = stores.directory.appending(path: "VillainArc.store.syncstate.json")
        try Data("{}".utf8).write(to: cache)

        try DebugReset.perform(stores.debug, isSignedIn: false, localCaches: [cache])

        #expect(try ModelContext(stores.debug.detachedContainer()).fetch(FetchDescriptor<WorkoutPlan>()).isEmpty, "the debug store survived its own reset")
        #expect(FileManager.default.fileExists(atPath: cache.path) == false, "the named cache survived the reset")
        #expect(try ModelContext(stores.real).fetch(FetchDescriptor<WorkoutPlan>()).count == 1, "the reset reached the app's own store")
    }
}
#endif
