import FCTAccount
import FCTBlobSync
import FCTServerSync
import FCTSync
import Foundation
import Network
import SwiftData
import WidgetKit

/// `FCTAccount` satisfies the engine's account seam by shape; this is the line that joins them.
extension AccountCredentials: @retroactive SyncAccount {}

/// What the bootstrap builds an engine *from*: where the sync state lives and how the wire is
/// made. `.live` is the shipping wiring; tests substitute a temporary directory and a fake
/// transport.
struct VASyncConfiguration {
    var stateFileURL: () throws -> URL
    var blobStateFileURL: () throws -> URL
    var blobCacheDirectory: () throws -> URL
    var makeTransport: (any SyncAccount) -> any SyncTransport
    var makeBlobTransport: (any SyncAccount) -> any BlobTransport
    /// The change triggers the engine listens on, beside the bootstrap's own manual pulse.
    /// `LocalSaveTrigger` observes saves *process-wide*, which is right in an app and wrong in a
    /// test process, where it would wake one suite's engine on another suite's writes.
    var makeTriggers: (ModelContainer) -> [any HistoryChangeTrigger]

    static var live: VASyncConfiguration {
        VASyncConfiguration(
            stateFileURL: { try VASyncConfiguration.stateURL(suffix: "syncstate.json") },
            blobStateFileURL: { try VASyncConfiguration.stateURL(suffix: "blobstate.json") },
            blobCacheDirectory: {
                try SharedModelContainer.configuration.storeURL()
                    .deletingLastPathComponent()
                    .appendingPathComponent("blob-cache")
            },
            makeTransport: { account in
                PostgRESTTransport(
                    baseURL: AccountEnvironment.fct.baseURL,
                    publishableKey: AccountEnvironment.fct.publishableKey,
                    account: account
                )
            },
            makeBlobTransport: { account in
                SupabaseStorageTransport(
                    baseURL: AccountEnvironment.fct.baseURL,
                    publishableKey: AccountEnvironment.fct.publishableKey,
                    account: account
                )
            },
            // The cross-process rung is what makes a widget/intents-extension write reach the
            // server without waiting for the app's next foreground.
            makeTriggers: { container in
                var triggers: [any HistoryChangeTrigger] = [LocalSaveTrigger()]
                if let remote = try? RemoteHistoryChangeTrigger(container: container) {
                    triggers.append(remote)
                }
                return triggers
            }
        )
    }

    /// Beside the store, in the App Group, so `SyncFreshness` stays readable by processes with no
    /// engine.
    private static func stateURL(suffix: String) throws -> URL {
        try SharedModelContainer.configuration.storeURL()
            .deletingLastPathComponent()
            .appendingPathComponent("VillainArc.store.\(suffix)")
    }
}

/// Villain Arc's sync bootstrap: the account's lifecycle mapped onto an engine's, the triggers
/// wired to the real events, and the one status surface the settings screen renders.
///
/// **The engine exists only while an account does.** The account itself is mandatory (onboarding
/// ends in the sign-in step), so in steady state the engine is simply always on; the optionality
/// below covers the moments around sign-out, re-auth, and account deletion.
@MainActor
@Observable
final class VASync {
    static let shared = VASync()

    private(set) var status: SyncStatus = .off
    private(set) var lastSyncedAt: Date?
    /// The record outbox, split by whether waiting will clear it: `retrying` goes by itself,
    /// `stuck` never will.
    private(set) var counted: OutboxCensus = OutboxCensus()
    /// Staged uploads and refused uploads — the blob half of "what has not reached the account".
    private(set) var blobPendingCount: Int = 0
    private(set) var lastError: String?
    /// Set when a sign-out or switch discarded local changes the server never saw.
    private(set) var discardedOnSwitch: Int = 0
    /// Set when a sign-out found unpushed work and therefore kept the local data.
    private(set) var keptOnSignOut: Int = 0

    @ObservationIgnored private var engine: SyncEngine?
    @ObservationIgnored private var blobs: BlobStore?
    @ObservationIgnored private var settledTask: Task<Void, Never>?
    @ObservationIgnored private var discardTask: Task<Void, Never>?
    @ObservationIgnored private let manual = ManualTrigger()
    @ObservationIgnored private var eventTask: Task<Void, Never>?
    @ObservationIgnored private var triggerTask: Task<Void, Never>?
    @ObservationIgnored private var retryTask: Task<Void, Never>?
    @ObservationIgnored private var debounceTask: Task<Void, Never>?
    @ObservationIgnored private var syncInFlight = false
    @ObservationIgnored private var syncAgain = false
    @ObservationIgnored private var pathMonitor: NWPathMonitor?
    @ObservationIgnored private weak var controller: AccountController?
    @ObservationIgnored private var container: ModelContainer?
    @ObservationIgnored private let configuration: VASyncConfiguration
    @ObservationIgnored var currentAccount: () -> (any SyncAccount)? = { nil }
    /// Runs after a local wipe (sign-out, switch, deletion) so the shell can restart onboarding.
    @ObservationIgnored var onLocalDataCleared: (@MainActor () -> Void)?

    init(configuration: VASyncConfiguration = .live) {
        self.configuration = configuration
    }

    // MARK: - Bootstrap

    /// Wire the account's events to the engine's lifecycle. Called once, from the app shell.
    func start(controller: AccountController, container: ModelContainer) {
        guard eventTask == nil else { return }
        self.controller = controller
        self.container = container
        self.currentAccount = { [weak controller] in controller?.credentials }

        let events = controller.events
        eventTask = Task { [weak self] in
            for await event in events {
                guard let self else { return }
                await self.handle(event)
            }
        }
        startPathMonitor()
    }

    /// Test seam: the bootstrap normally learns the container from `start(controller:container:)`;
    /// harness tests wire it directly, because constructing a real `AccountController` would touch
    /// the live keychain.
    func attachForTesting(container: ModelContainer) {
        self.container = container
    }

    /// Launch and every foregrounding. Unconditional, cursor-cheap, and the rung correctness
    /// actually rides on — everything above it only buys freshness.
    func foregrounded() {
        guard engine != nil else { return }
        engine?.resetBackoff()
        manual.fire()
        Task { await syncNow() }
    }

    /// Force a cycle now — the post-sign-in and settings-refresh path. A cycle already in flight
    /// is not joined by a second one; the request is remembered and the loop runs again once
    /// (the applier's own save fires `LocalSaveTrigger`, so every pull that lands rows asks for
    /// another cycle, which is correct and would otherwise re-enter).
    func syncNow() async {
        guard let engine else { return }
        if syncInFlight {
            syncAgain = true
            return
        }
        syncInFlight = true
        defer { syncInFlight = false }
        repeat {
            syncAgain = false
            stageAuthoredAssets()
            if let blobs { _ = await blobs.sync() }
            let result = await engine.sync()
            publish(result)
            scheduleRetry(after: result)
        } while syncAgain
    }

    /// Bring the account's rows down before Villain Arc's own setup asks for anything the account
    /// may already hold.
    ///
    /// A signed-in device with an empty store cannot tell a new account from an unrestored one:
    /// both are empty, and they mean opposite things. So the question is settled by a completed
    /// pull rather than inferred from emptiness.
    ///
    /// - Returns: whether the restore completed. A `false` is an **unanswered** question and never
    ///   "new account" — the caller has to say so rather than start setup over data it did not
    ///   look at.
    func restoreAccountData(waitingUpTo timeout: Duration = .seconds(30)) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        // The engine is built from the account's event stream, which races the setup path that
        // needs it. A cycle that stream already started has to finish first, too: `syncNow()`
        // coalesces a concurrent request into the running cycle and returns immediately, which
        // would hand back a verdict about a pull that had not happened.
        while engine == nil || syncInFlight {
            guard ContinuousClock.now < deadline else { return false }
            try? await Task.sleep(for: .milliseconds(50))
        }
        await syncNow()

        // The question is whether the PULL completed, not whether the outbox is clean. Records the
        // server judged and refused are a push-side fact that never clears by itself, so gating on
        // `.idle` would make a single stuck record block setup forever — with no profile and a
        // Retry that cannot succeed. Only the states that mean "this device did not read the
        // account" are a failed restore.
        switch status {
        case .idle, .failed: return true
        case .off, .syncing, .offline, .needsReauthentication, .resyncRequired: return false
        }
    }

    /// Ask for one more pass, folded into a running cycle when one is up.
    private func requestAnotherCycle() {
        if syncInFlight {
            syncAgain = true
            return
        }
        settledTask?.cancel()
        settledTask = Task { [weak self] in await self?.syncNow() }
    }

    // MARK: - Rule 7: the staging sweep (the profile photo)

    /// Move the profile photo's authored bytes into the blob layer: stage (cache + durable upload
    /// queue), write the `AssetSource` back onto the row, release a replaced object. The write
    /// dirties the record and the engine's push gate holds it until the upload confirms, so no
    /// device ever pulls a profile whose photo the object store cannot serve.
    private func stageAuthoredAssets() {
        guard let blobs, let container else { return }
        let context = container.mainContext
        guard let profile = try? context.fetch(UserProfile.single).first, profile.photoNeedsStaging else { return }

        let previous = profile.photoAsset?.blobRef
        do {
            if let data = profile.profileImageData {
                let ref = try blobs.stage(
                    data,
                    contentType: VAImageBytes.contentType(of: data),
                    preview: BlobPreview.imageThumbnail(from: data),
                    owner: BlobOwner(table: UserProfile.syncTableName, uuid: profile.id)
                )
                profile.photoAsset = .authored(ref)
            } else {
                profile.photoAsset = nil
            }
            profile.photoNeedsStaging = false
            if let previous, previous.id != profile.photoAsset?.blobRef?.id {
                blobs.discard(previous)
            }
            saveContext(context: context)
        } catch {
            lastError = "\(error)"
        }
    }

    /// A restored device's photo: the row carries the asset, the cache may not carry the bytes.
    /// Fill `profileImageData` from the cache or a lazy digest-verified fetch — directly, never
    /// through `setPhoto(_:)`, which would re-stage bytes the account already holds.
    private func hydrateProfilePhotoIfNeeded() {
        guard let blobs, let container else { return }
        let context = container.mainContext
        guard let profile = try? context.fetch(UserProfile.single).first,
              profile.profileImageData == nil,
              !profile.photoNeedsStaging,
              let ref = profile.photoAsset?.blobRef
        else { return }

        if let cached = blobs.cachedData(for: ref) {
            profile.profileImageData = cached
            saveContext(context: context)
            return
        }
        Task { [weak self] in
            guard let data = try? await blobs.data(for: ref) else { return }
            guard let self, let container = self.container else { return }
            let context = container.mainContext
            guard let profile = try? context.fetch(UserProfile.single).first,
                  profile.photoAsset?.blobRef?.id == ref.id,
                  profile.profileImageData == nil
            else { return }
            profile.profileImageData = data
            saveContext(context: context)
        }
    }

    // MARK: - Account lifecycle

    func handle(_ event: AccountEvent) async {
        switch event {
        case .enrolled(let accountID):
            await startEngine(accountID: accountID, enrolling: true)
        case .resumed(let accountID):
            await startEngine(accountID: accountID, enrolling: false)
        case .switched(_, let to):
            // A different account. Account A's rows must not silently become account B's, so this
            // clears local data — discarding whatever A never pushed, because A's credentials are
            // already gone and nothing can push it now.
            discardLocalData()
            await startEngine(accountID: to, enrolling: true)
            onLocalDataCleared?()
        case .needsReauthentication:
            // Involuntary. The engine idles; nothing local is cleared, the outbox is untouched,
            // and one sign-in resumes.
            stopEngine(releasing: false)
            status = .needsReauthentication
        case .signedOut:
            // Deliberate, and barrier-gated: local data clears once the account holds all of it.
            clearOnSignOut()
            status = .off
        case .deleted:
            // The user asked for the data to be gone, here and everywhere (5.1.1(v)).
            stopEngine(releasing: true)
            discardLocalData()
            status = .off
            onLocalDataCleared?()
        }
        refreshCounters()
    }

    /// What signing out costs, in changes this device is still the only holder of. `nil` where
    /// there is no engine to ask — a count this device cannot take, which is never spelled as
    /// zero at the moment a clear is being decided.
    var unsyncedWork: OutboxCensus? {
        engine.map { unsyncedWork(engine: $0, blobs: blobs) }
    }

    private func unsyncedWork(engine: SyncEngine, blobs: BlobStore?) -> OutboxCensus {
        var census = engine.state.counted
        if let blobCensus = blobs?.counted {
            census.retrying += blobCensus.retrying
            census.stuck += blobCensus.stuck
        }
        return census
    }

    /// The pre-flight the settings sign-out button awaits, **before** the session is destroyed:
    /// one last cycle while there is still a token to push with, then the answer to "is anything
    /// about to be lost".
    @discardableResult
    func signOutPreflight() async -> OutboxCensus? {
        await syncNow()
        return unsyncedWork
    }

    /// **Signing out clears this device's copy**, barrier-gated: everything the app authors now
    /// syncs, so after a clean sign-out nothing exists only here. Between a local write and its
    /// push ack this device is the only holder of that change, so the clear refuses while
    /// anything is unpushed — the engine's own non-discarding clear enforces that.
    private func clearOnSignOut() {
        keptOnSignOut = 0
        guard let container else {
            stopEngine(releasing: true)
            return
        }
        // Detached stand-ins, because `.signedOut` can land on a process that never built an
        // engine (a relaunch between the tap and the event).
        let engine = self.engine ?? makeDetachedEngine(container: container)
        let blobs = self.blobs ?? makeDetachedBlobStore()
        let outstanding = engine.map { unsyncedWork(engine: $0, blobs: blobs) }
        stopEngine(releasing: false)

        do {
            guard let outstanding, outstanding.isDrained else {
                throw SyncEngineError.outboxNotEmpty(outstanding ?? OutboxCensus())
            }
            try engine?.clearSyncedData()
            try blobs?.clearLocalData()
            clearLocalCaches()
            lastSyncedAt = nil
            counted = OutboxCensus()
            blobPendingCount = 0
            self.engine = nil
            self.blobs = nil
            onLocalDataCleared?()
        } catch {
            keptOnSignOut = max(outstanding?.total ?? 0, engine?.state.counted.total ?? 0)
            self.engine = nil
            self.blobs = nil
        }
    }

    private func startEngine(accountID: UUID, enrolling: Bool) async {
        guard let container, let credentials = currentAccount() else { return }
        guard credentials.accountID == accountID else { return }

        // `resume()` re-emits `.resumed` on every foregrounding: same account, not enrolling →
        // just run a cycle rather than rebuilding the trigger wiring per foreground.
        if let engine, !enrolling, engine.accountID == accountID {
            await syncNow()
            return
        }
        stopEngine(releasing: true)

        let stateFile: SyncStateFile
        let blobStore: BlobStore
        do {
            stateFile = SyncStateFile(url: try configuration.stateFileURL())
            blobStore = BlobStore(
                appSlug: VASyncSchema.appSlug,
                account: credentials,
                transport: configuration.makeBlobTransport(credentials),
                stateFileURL: try configuration.blobStateFileURL(),
                cacheDirectory: try configuration.blobCacheDirectory()
            )
        } catch {
            lastError = "\(error)"
            status = .failed(count: 1)
            return
        }

        let engine = SyncEngine(
            container: container,
            stateFile: stateFile,
            transport: configuration.makeTransport(credentials),
            account: credentials,
            schema: VASyncSchema.schema
        )
        // The ordering rule's engine half: a record with a pending or failed upload stays held,
        // so no device ever pulls a profile whose photo the object store cannot serve.
        engine.pushGate = { [weak blobStore] table, uuid in
            blobStore?.isRecordPushable(table: table, uuid: uuid) ?? true
        }
        // The liveness half: a record the gate held is pushed the moment its upload lands.
        blobStore.onUploadsSettled = { [weak self] in
            guard let self else { return }
            self.engine?.resetBackoff()
            self.requestAnotherCycle()
        }
        // Server-applied writes bypass every app-side write seam, so the derived surfaces
        // (Spotlight, widgets, exercise analytics, the photo cache) are told directly.
        engine.didApplyRemoteChanges = { [weak self] in self?.remoteChangesLanded() }
        engine.onAccountDeleted = { [weak self] in
            guard let self, let controller = self.controller else { return }
            Task { await controller.handleAccountDeleted() }
        }

        if enrolling {
            do {
                try engine.enroll()
            } catch {
                lastError = "\(error)"
            }
        }
        self.engine = engine
        self.blobs = blobStore

        let triggers = configuration.makeTriggers(container) + [manual]
        let signals = CompositeHistoryChangeTrigger(triggers).signals()
        triggerTask = Task { [weak self] in
            for await _ in signals {
                guard let self else { return }
                self.scheduleDebouncedSync()
            }
        }

        await syncNow()
    }

    private func stopEngine(releasing: Bool) {
        triggerTask?.cancel()
        triggerTask = nil
        retryTask?.cancel()
        retryTask = nil
        debounceTask?.cancel()
        debounceTask = nil
        settledTask?.cancel()
        settledTask = nil
        discardTask?.cancel()
        discardTask = nil
        if releasing {
            engine = nil
            blobs = nil
        }
    }

    /// The narrow deletion door's local half: the server's rows for this app are already erased,
    /// so this device's copy goes unconditionally and the engine rebuilds against the now-empty
    /// account at cursor 0. The session survives — the app returns to signed-in-empty.
    func eraseAppDataLocally() async {
        discardLocalData()
        if let controller, let credentials = controller.credentials {
            await startEngine(accountID: credentials.accountID, enrolling: true)
        }
        onLocalDataCleared?()
    }

    /// Every synced row, the engine's state, the blob queue and cache — gone. Switch and delete
    /// only.
    private func discardLocalData() {
        guard let container else { return }
        let engine = self.engine ?? makeDetachedEngine(container: container)
        discardedOnSwitch = engine?.state.outbox.count ?? 0
        try? engine?.clearSyncedData(discardingUnsynced: true)
        let blobs = self.blobs ?? makeDetachedBlobStore()
        try? blobs?.clearLocalData(discardingUnsynced: true)
        clearLocalCaches()
        self.engine = nil
        self.blobs = nil
        lastSyncedAt = nil
        counted = OutboxCensus()
        blobPendingCount = 0
    }

    /// The non-synced residue a departing account leaves behind: the Apple Health mirrors and
    /// derived caches (all re-derivable — from HealthKit or from the synced rows — for whoever
    /// signs in next), and the bootstrap markers, so the next launch runs a full first bootstrap.
    ///
    /// "Re-derivable from HealthKit" is a property of the anchors, not a hope: the mirror rows and
    /// the anchors that produced them go together, or the next import resumes past history that no
    /// longer exists locally and the user reads it as data loss.
    private func clearLocalCaches() {
        guard let container else { return }
        let context = container.mainContext
        do {
            try context.delete(model: HealthWorkout.self)
            try context.delete(model: WeightEntry.self)
            try context.delete(model: HealthStepsDistance.self)
            try context.delete(model: HealthEnergy.self)
            try context.delete(model: HealthSleepNight.self)
            try context.delete(model: HealthSleepBlock.self)
            try context.delete(model: HealthHeart.self)
            try context.delete(model: HealthRespiratoryRate.self)
            try context.delete(model: HealthWristTemperature.self)
            try context.delete(model: HydrationDay.self)
            try context.delete(model: HydrationEntry.self)
            try context.delete(model: ExerciseHistory.self)
            try context.delete(model: ProgressionPoint.self)
            try context.delete(model: RestTimeHistory.self)
            try context.delete(model: HealthSyncState.self)
            try context.save()
        } catch {
            AppLog.error("Sign-out cache clear failed", error: error)
        }
        HealthSyncPreferences.resetAllAnchors()
        SharedModelContainer.sharedDefaults.removeObject(forKey: DataManager.exerciseCatalogVersionKey)
        SpotlightIndexer.deleteAll()
    }

    private func makeDetachedEngine(container: ModelContainer) -> SyncEngine? {
        guard let url = try? configuration.stateFileURL() else { return nil }
        let state = SyncStateFile(url: url)
        return SyncEngine(
            container: container,
            stateFile: state,
            transport: UnreachableTransport(),
            account: DetachedAccount(accountID: state.read().accountID ?? UUID()),
            schema: VASyncSchema.schema
        )
    }

    private func makeDetachedBlobStore() -> BlobStore? {
        guard let stateURL = try? configuration.blobStateFileURL(),
              let cacheURL = try? configuration.blobCacheDirectory()
        else { return nil }
        return BlobStore(
            appSlug: VASyncSchema.appSlug,
            account: DetachedAccount(accountID: UUID()),
            transport: UnreachableBlobTransport(),
            stateFileURL: stateURL,
            cacheDirectory: cacheURL
        )
    }

    // MARK: - Reacting

    /// Rows the engine applied bypass every app-side write path, so each derived surface is
    /// refreshed here: Spotlight + widgets, the exercise-analytics cache, and the photo bytes.
    private func remoteChangesLanded() {
        guard let container else { return }
        SpotlightIndexer.reindexAll(context: container.mainContext)
        WidgetCenter.shared.reloadAllTimelines()
        ExerciseHistoryUpdater.rebuildAllHistories(context: container.mainContext)
        hydrateProfilePhotoIfNeeded()
    }

    private func publish(_ result: SyncStatus) {
        status = result
        lastError = engine?.lastError ?? blobs?.lastError
        refreshCounters()
    }

    private func refreshCounters() {
        guard let state = engine?.state else { return }
        lastSyncedAt = state.lastSyncedAt
        counted = state.counted
        blobPendingCount = blobs.map { $0.counted.retrying + $0.counted.stuck } ?? 0
    }

    /// Coalesce a burst of triggers into one cycle: live logging is a save per set completion,
    /// and each one would be a round trip if nothing gathered them.
    private func scheduleDebouncedSync() {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            await self?.syncNow()
        }
    }

    // MARK: - Backoff and connectivity

    private func scheduleRetry(after result: SyncStatus) {
        retryTask?.cancel()
        retryTask = nil
        guard case .offline(let delay) = result else { return }
        retryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            await self?.syncNow()
        }
    }

    /// The clock resets on a network-path change, so a device coming back on Wi-Fi retries at
    /// once rather than at the tail of a backoff it earned while genuinely offline.
    private func startPathMonitor() {
        guard pathMonitor == nil else { return }
        let monitor = NWPathMonitor()
        pathMonitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            Task { @MainActor in
                guard let self, self.engine != nil else { return }
                self.engine?.resetBackoff()
                await self.syncNow()
            }
        }
        monitor.start(queue: DispatchQueue(label: "com.fcttechnologies.VillainArc.sync.path"))
    }
}

/// The MIME type staged bytes are filed under, read from the bytes themselves.
nonisolated enum VAImageBytes {
    static func contentType(of data: Data) -> String {
        let head = [UInt8](data.prefix(12))
        if head.count >= 4, Array(head[0...3]) == [0x89, 0x50, 0x4E, 0x47] { return "image/png" }
        if head.count >= 12, Array(head[4...11]) == Array("ftypheic".utf8) { return "image/heic" }
        return "image/jpeg"
    }
}

/// The wire, cut. Used where a process needs an engine's local half and must never reach a server.
nonisolated struct UnreachableTransport: SyncTransport {
    func push(schemaVersion: String, records: [PushRecord]) async throws -> [PushVerdict] {
        throw SyncTransportError.connectivity("no account")
    }

    func pull(schemaVersion: String, table: String, cursor: Int64, pageLimit: Int) async throws -> PullEnvelope {
        throw SyncTransportError.connectivity("no account")
    }
}

/// The object store, cut — the blob half of `UnreachableTransport`.
nonisolated struct UnreachableBlobTransport: BlobTransport {
    func upload(_ bytes: Data, contentType: String, to path: BlobPath) async throws {
        throw SyncTransportError.connectivity("no account")
    }

    func download(_ path: BlobPath) async throws -> Data {
        throw SyncTransportError.connectivity("no account")
    }

    func delete(_ path: BlobPath) async throws {
        throw SyncTransportError.connectivity("no account")
    }
}

nonisolated struct DetachedAccount: SyncAccount {
    let accountID: UUID
    func accessToken() async throws -> String { throw SyncTransportError.authRefused("no session") }
    func accessToken(afterRefusalOf refused: String) async throws -> String {
        throw SyncTransportError.authRefused("no session")
    }
}
