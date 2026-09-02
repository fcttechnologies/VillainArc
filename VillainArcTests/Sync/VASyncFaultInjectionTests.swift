import FCTAccount
import FCTBlobSync
import FCTBlobSyncTesting
import FCTServerSync
import FCTServerSyncTesting
import FCTSync
import Foundation
import SwiftData
import Testing

@testable import VillainArc

/// Villain Arc's own sync wiring under the failures the field serves.
///
/// The adopter contract suites (`VASyncContractTests`) prove the *engine* against these
/// semantics. What is proven here is the layer above it that only this app owns: `VASync`'s
/// bootstrap — the counters it republishes, the sign-out barrier it enforces before the engine's
/// own, and what the next healthy cycle does about each failure.
///
/// The distinction the fake server cannot inject on its own is the one these tests turn on: a
/// **call-level** 4xx names no record, so nothing is judged and the whole batch stays queued
/// (`retrying`), while a **per-record** rejection is a judgement and is never auto-retried
/// (`stuck`). Both surface as `.failed`; only the census tells them apart, and only the census
/// says whether waiting is the fix.

// MARK: - Fault injection

/// The failures a live server cannot be asked for on demand, switchable between cycles.
enum VASyncFault: Sendable, Equatable {
    /// No route to host. Connectivity-class: the batch stays queued and backs off.
    case unreachable
    /// A 4xx envelope naming no record — the shape `PostgRESTTransport` raises for a malformed
    /// call. (5xx maps to connectivity there, which is the `unreachable` case above.)
    case callRejected(status: Int)
    /// A slow server rather than a failed one.
    case lag(milliseconds: Int)
}

/// Holds the current fault. An actor because the transport seam is `nonisolated` and `Sendable`,
/// and the test flips the fault from the main actor between cycles.
actor VASyncFaultInjector {
    private var fault: VASyncFault?

    func set(_ fault: VASyncFault?) { self.fault = fault }

    /// Applied before the call reaches the fake server, so a fault suppresses the call entirely —
    /// which is what lets a test assert the server saw nothing.
    func apply() async throws {
        switch fault {
        case .none:
            return
        case .unreachable:
            throw SyncTransportError.connectivity("injected: no route to host")
        case .callRejected(let status):
            throw SyncTransportError.callRejected(status: status, body: "injected: malformed call")
        case .lag(let milliseconds):
            try? await Task.sleep(for: .milliseconds(milliseconds))
        }
    }
}

/// `FakeTransport` with a fault in front of it.
nonisolated struct VAFaultTransport: SyncTransport {
    let inner: FakeTransport
    let injector: VASyncFaultInjector

    func push(schemaVersion: String, records: [PushRecord]) async throws -> [PushVerdict] {
        try await injector.apply()
        return try await inner.push(schemaVersion: schemaVersion, records: records)
    }

    func pullAll(schemaVersion: String, cursors: [String: Int64], rowBudget: Int) async throws -> PullAllEnvelope {
        try await injector.apply()
        return try await inner.pullAll(schemaVersion: schemaVersion, cursors: cursors, rowBudget: rowBudget)
    }
}

// MARK: - Harness

/// One `VASync` wired to a fake server, a fake object store, and its own temporary state — the
/// real bootstrap with only the wire replaced.
@MainActor
final class VASyncFaultHarness {
    let sync: VASync
    let server: FakeSyncServer
    let objects: FakeBlobObjectStore
    let injector = VASyncFaultInjector()
    let container: ModelContainer
    let accountID: UUID

    let storeURL: URL
    private let directory: URL

    /// - Parameters:
    ///   - triggers: the change triggers the engine listens on. Empty by default:
    ///     `LocalSaveTrigger` observes saves process-wide, which would wake this engine on another
    ///     suite's writes, so every cycle here is normally asked for explicitly. A suite that is
    ///     *about* the trigger path (the debounce) passes its own `ManualTrigger` instead.
    ///   - transport: replaces the fault-injecting wire wholesale, for a suite whose subject is
    ///     the wire's timing rather than the failures it can be made to raise.
    ///   - nudges: the Realtime rung. `nil` by default — a test process opens no socket — so the
    ///     suite that is *about* the rung passes one over a scripted socket.
    ///   - server, objects, accountID: shared to make a second harness a second DEVICE on one
    ///     account, which is the only way to give a device rows it genuinely has not read.
    init(
        triggers: [any HistoryChangeTrigger] = [],
        transport: (any SyncTransport)? = nil,
        nudges: SyncNudgeChannel? = nil,
        server: FakeSyncServer = FakeSyncServer(),
        objects: FakeBlobObjectStore = FakeBlobObjectStore(),
        accountID: UUID = UUID()
    ) throws {
        self.server = server
        self.objects = objects
        self.accountID = accountID
        let made = try TestStoreFactory.onDisk(VillainArcSchemaV1.self)
        container = made.container
        storeURL = made.url
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VASyncFault-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let directory = self.directory
        let server = server
        let objects = objects
        let injector = injector
        let configuration = VASyncConfiguration(
            stateFileURL: { directory.appendingPathComponent("syncstate.json") },
            blobStateFileURL: { directory.appendingPathComponent("blobstate.json") },
            blobCacheDirectory: { directory.appendingPathComponent("blob-cache") },
            makeTransport: { _ in
                transport ?? VAFaultTransport(inner: FakeTransport(server: server), injector: injector)
            },
            makeBlobTransport: { _ in FakeBlobTransport(store: objects) },
            makeTriggers: { _ in triggers },
            makeNudgeChannel: { _ in nudges }
        )

        sync = VASync(configuration: configuration)
        sync.attachForTesting(container: container)
        let accountID = self.accountID
        sync.currentAccount = { FakeAccount(accountID: accountID) }
    }

    deinit {
        TestStoreFactory.removeStore(at: storeURL)
        try? FileManager.default.removeItem(at: directory)
    }

    /// Sign in: the engine is built and the first cycle runs.
    func enroll() async {
        await sync.handle(.enrolled(accountID, appleFullName: nil))
    }

    /// One local change the server has never seen. Returns the row's sync id.
    @discardableResult
    func writeSession(notes: String) throws -> UUID {
        let context = container.mainContext
        let session = WorkoutSession()
        session.notes = notes
        context.insert(session)
        try context.save()
        return session.id
    }

    func editSession(_ id: UUID, notes: String) throws {
        let context = container.mainContext
        let session = try #require(try context.fetch(WorkoutSession.descriptor(forSyncIDs: [id])).first)
        session.notes = notes
        try context.save()
    }

    var localSessionCount: Int {
        (try? container.mainContext.fetchCount(FetchDescriptor<WorkoutSession>())) ?? -1
    }

    func serverSessionCount() async -> Int {
        await server.liveCount(in: WorkoutSession.syncTableName)
    }
}

private func isOffline(_ status: SyncStatus) -> Bool {
    if case .offline = status { return true }
    return false
}

private func isFailed(_ status: SyncStatus) -> Bool {
    if case .failed = status { return true }
    return false
}

// MARK: - The suite

/// Serialized: the clean-sign-out path runs `VASync`'s real local-cache clear, which reaches the
/// shared App-Group defaults this test host also serves to every other suite.
@Suite("VASync under injected sync faults", .serialized)
struct VASyncFaultInjectionTests {

    // MARK: Network unreachable

    /// The wire is cut. The change is queued as `retrying` — waiting is the fix — nothing reaches
    /// the server, and the freshness stamp does not move. Reconnecting drains it.
    @Test @MainActor
    func networkUnreachableQueuesHonestlyAndRecoversNextCycle() async throws {
        let harness = try VASyncFaultHarness()
        await harness.enroll()
        try harness.writeSession(notes: "unreachable")

        // Enrolling already ran one healthy cycle, so freshness is stamped: what an offline cycle
        // must not do is move it forward.
        let freshnessBefore = harness.sync.lastSyncedAt

        await harness.injector.set(.unreachable)
        await harness.sync.syncNow(.full)

        #expect(isOffline(harness.sync.status))
        #expect(harness.sync.counted.retrying >= 1)
        #expect(harness.sync.counted.stuck == 0, "connectivity judges nothing, so nothing is stuck")
        #expect(harness.sync.lastSyncedAt == freshnessBefore, "an offline cycle must not claim freshness")
        #expect(await harness.serverSessionCount() == 0)

        await harness.injector.set(nil)
        await harness.sync.syncNow(.full)

        #expect(harness.sync.counted.isDrained)
        #expect(harness.sync.lastSyncedAt != freshnessBefore, "a healthy cycle re-stamps freshness")
        #expect(await harness.serverSessionCount() == 1)
    }

    // MARK: Server error — the call

    /// A 4xx that names no record. Nothing was judged, so the batch stays queued even though the
    /// status reads `.failed`: the census, not the status, is what says whether waiting is the
    /// fix. The next healthy cycle drains it.
    @Test @MainActor
    func callLevelServerErrorKeepsWorkQueuedAndRecoversNextCycle() async throws {
        let harness = try VASyncFaultHarness()
        await harness.enroll()
        try harness.writeSession(notes: "call rejected")

        await harness.injector.set(.callRejected(status: 400))
        await harness.sync.syncNow(.full)

        #expect(isFailed(harness.sync.status))
        #expect(harness.sync.lastError != nil)
        #expect(harness.sync.counted.retrying >= 1)
        #expect(harness.sync.counted.stuck == 0, "a call naming no record judges no record")
        #expect(await harness.serverSessionCount() == 0)

        await harness.injector.set(nil)
        await harness.sync.syncNow(.full)

        #expect(harness.sync.counted.isDrained)
        #expect(await harness.serverSessionCount() == 1)
    }

    // MARK: Server error — the record

    /// A per-record rejection is a judgement: the entry goes `stuck` and no amount of healthy
    /// cycling retries it, because retrying a judged request is a loop. The only route out is a
    /// new local edit, which re-queues it.
    @Test @MainActor
    func recordRejectionIsStuckUntilTheRowIsEditedAgain() async throws {
        let harness = try VASyncFaultHarness()
        await harness.enroll()
        let id = try harness.writeSession(notes: "rejected")

        await harness.server.setRejecting([id])
        await harness.sync.syncNow(.full)

        #expect(isFailed(harness.sync.status))
        #expect(harness.sync.counted.stuck >= 1)
        #expect(harness.sync.counted.retrying == 0)
        #expect(await harness.serverSessionCount() == 0)

        // A healthy cycle changes nothing: the entry was judged, not delayed.
        await harness.server.setRejecting([])
        await harness.sync.syncNow(.full)
        #expect(harness.sync.counted.stuck >= 1, "a judged entry is never auto-retried")
        #expect(await harness.serverSessionCount() == 0)

        // A fresh edit re-queues it, and then it lands.
        try harness.editSession(id, notes: "edited after rejection")
        await harness.sync.syncNow(.full)

        #expect(harness.sync.counted.isDrained)
        #expect(await harness.serverSessionCount() == 1)
    }

    // MARK: Lag

    /// A slow server, not a failed one. A second request arriving mid-cycle is folded into the
    /// running one rather than starting a second push of the same batch, and the work still
    /// drains once the slow cycle returns.
    @Test @MainActor
    func lagCoalescesConcurrentRequestsIntoOneCycle() async throws {
        let harness = try VASyncFaultHarness()
        await harness.enroll()
        try harness.writeSession(notes: "lagging")

        await harness.injector.set(.lag(milliseconds: 300))
        async let inFlight: Void = harness.sync.syncNow(.full)
        try await Task.sleep(for: .milliseconds(80))
        // Lands while the first cycle is still waiting on the wire.
        await harness.sync.syncNow(.full)
        await inFlight

        #expect(harness.sync.counted.isDrained)
        #expect(await harness.serverSessionCount() == 1)
        #expect(
            await harness.server.pushCallCount == 1,
            "a request arriving mid-cycle must not re-push a batch already in flight"
        )
        // Three cycles ran — the enrolling one, the lagging one, and the pass the folded request
        // bought — and the read path costs each of them exactly one call, whatever the schema's
        // twenty-five tables would once have cost.
        let reads = await harness.server.pullAllCallCount
        #expect(reads == 3, "one read per cycle: \(reads) reads for three cycles")
    }

    /// Lag must not let a destructive step run against a stale reading: while the slow cycle is
    /// still in flight the work is genuinely unpushed, and the barrier answers on that.
    @Test @MainActor
    func signOutRefusesWhileALaggingCycleIsStillInFlight() async throws {
        let harness = try VASyncFaultHarness()
        await harness.enroll()
        try harness.writeSession(notes: "lagging sign-out")

        await harness.injector.set(.lag(milliseconds: 400))
        async let inFlight: Void = harness.sync.syncNow(.full)
        try await Task.sleep(for: .milliseconds(80))

        let outstanding = try #require(harness.sync.unsyncedWork)
        #expect(!outstanding.isDrained, "work still on the wire has not reached the account")

        await inFlight
        #expect(harness.sync.counted.isDrained)
    }

    // MARK: The sign-out barrier

    /// Signing out clears this device's copy, so it must refuse while this device is the only
    /// holder of a change. The refusal keeps the data and says how much it kept.
    @Test @MainActor
    func signOutRefusesToClearWhileWorkIsUnpushed() async throws {
        let harness = try VASyncFaultHarness()
        await harness.enroll()
        try harness.writeSession(notes: "must survive sign-out")

        await harness.injector.set(.unreachable)
        await harness.sync.syncNow(.full)
        #expect(harness.sync.counted.total >= 1)

        await harness.sync.handle(.signedOut)

        #expect(harness.sync.keptOnSignOut >= 1, "the refusal must name what it kept")
        #expect(harness.localSessionCount == 1, "a refused clear keeps the local data")
        #expect(harness.sync.status == .off)
    }

    /// The other side of the same barrier: once the account holds everything, the clear runs.
    @Test @MainActor
    func signOutClearsOnceTheAccountHoldsEverything() async throws {
        let defaults = SharedModelContainer.sharedDefaults
        let storedCatalogVersion = defaults.object(forKey: DataManager.exerciseCatalogVersionKey)
        defer {
            if let storedCatalogVersion {
                defaults.set(storedCatalogVersion, forKey: DataManager.exerciseCatalogVersionKey)
            } else {
                defaults.removeObject(forKey: DataManager.exerciseCatalogVersionKey)
            }
        }

        let harness = try VASyncFaultHarness()
        await harness.enroll()
        try harness.writeSession(notes: "safely pushed")
        await harness.sync.syncNow(.full)

        #expect(harness.sync.counted.isDrained)
        #expect(await harness.serverSessionCount() == 1)

        await harness.sync.handle(.signedOut)

        #expect(harness.sync.keptOnSignOut == 0)
        #expect(harness.localSessionCount == 0, "a drained device clears on sign-out")
        #expect(harness.sync.status == .off)
    }
}
