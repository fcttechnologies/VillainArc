import FCTAccount
import FCTAccountProfile
import FCTBlobSync
import FCTComponentsUI
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
    /// The account blob store's own state file and cache. Villain Arc authors no bytes of its own,
    /// so this is the only blob store the app builds.
    var accountBlobStateFileURL: () throws -> URL
    var accountBlobCacheDirectory: () throws -> URL
    var makeTransport: (any SyncAccount) -> any SyncTransport
    var makeBlobTransport: (any SyncAccount) -> any BlobTransport
    /// The change triggers the engine listens on. `LocalSaveTrigger` observes saves
    /// *process-wide*, which is right in an app and wrong in a test process, where it would wake
    /// one suite's engine on another suite's writes.
    var makeTriggers: (ModelContainer) -> [any HistoryChangeTrigger]
    /// Rung 2 of the ping ladder, held only while the app is foregrounded. `nil` where there is no
    /// socket to open — a test process, and any device the channel cannot be built for.
    ///
    /// It takes the engine's own state file because that is where this install's device id lives,
    /// and the id is what the admission door names a device by: without it a renewal could not
    /// find its own lease row and a release would give back nothing.
    var makeNudgeChannel: (any SyncAccount, SyncStateFile) -> SyncNudgeChannel?

    static var live: VASyncConfiguration {
        VASyncConfiguration(
            stateFileURL: { try VASyncConfiguration.stateURL(suffix: "syncstate.json") },
            accountBlobStateFileURL: { try VASyncConfiguration.stateURL(suffix: "account-blobstate.json") },
            accountBlobCacheDirectory: {
                try SharedModelContainer.configuration.storeURL()
                    .deletingLastPathComponent()
                    .appendingPathComponent("account-blob-cache")
            },
            makeTransport: { account in
                PostgRESTTransport(
                    baseURL: AccountEnvironment.fct.baseURL,
                    publishableKey: AccountEnvironment.fct.publishableKey,
                    account: account
                )
            },
            makeBlobTransport: { account in
                R2BlobTransport(
                    baseURL: AccountEnvironment.fct.baseURL,
                    publishableKey: AccountEnvironment.fct.publishableKey,
                    account: account
                )
            },
            makeTriggers: { container in SyncScheduler.engineTriggers(container: container) },
            makeNudgeChannel: { account, stateFile in
                SyncNudgeChannel(
                    baseURL: AccountEnvironment.fct.baseURL,
                    publishableKey: AccountEnvironment.fct.publishableKey,
                    account: account,
                    stateFile: stateFile,
                    // The slot is asked for before the join, through the same door the records go
                    // out of: one project, one account, one bearer.
                    leasing: PostgRESTTransport(
                        baseURL: AccountEnvironment.fct.baseURL,
                        publishableKey: AccountEnvironment.fct.publishableKey,
                        account: account
                    )
                )
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
    /// The avatar outbox, split the same way the record one is: a refused upload is never waiting
    /// for anything, so it must not be reported as though waiting would clear it.
    private(set) var blobCounted: OutboxCensus = OutboxCensus()
    private(set) var lastError: String?

    /// **Where this device stands with its first look at the account** — the three things a surface
    /// with nothing on it may say, decided by the package's own rule.
    ///
    /// An empty surface that is a claim about the *account* — "no workouts yet", "no plans yet" —
    /// consults this before it says so: on the first launch after a reinstall the rows are on the
    /// server and have simply not arrived, which the person reading it sees as their training
    /// history being gone.
    ///
    /// Device-sourced surfaces are not account claims and never read it: the Apple Health mirrors
    /// come from HealthKit on this phone, so their emptiness is true the moment it is rendered.
    var restore: SyncRestoreState {
        SyncRestoreState(
            hasAccount: currentAccount() != nil,
            hasCompletedFirstPull: hasCompletedFirstPull,
            status: status
        )
    }

    /// ``restore`` as the empty-state surface reads it, carrying the one thing the answer cannot:
    /// what "try again" does here. A full cycle, awaited, so the button's spinner is the real
    /// attempt — `SyncEngine.sync(_:)` consults no backoff, so this reaches the server in every
    /// state that produced an `.unreachable`.
    var restoreSurface: RestoreState {
        switch restore {
        case .restoring: .restoring
        case .unreachable: .unreachable(retry: { [weak self] in await self?.syncNow(.full) })
        case .settled: .settled
        }
    }

    /// Whether a pull has ever walked the account's feed to its end on this device. Read off the
    /// engine while one exists, and off the state file otherwise: the launch read happens before
    /// the engine is built, and the fact is durable and per account, so a returning launch is
    /// settled from the first frame rather than from the first cycle.
    var hasCompletedFirstPull: Bool {
        guard let accountID = currentAccount()?.accountID else { return false }
        if let engine, engine.accountID == accountID { return engine.hasCompletedFirstPull }
        return SyncFreshness.current(fileURL: try? configuration.stateFileURL())
            .hasCompletedFirstPull(for: accountID)
    }

    /// Set when a sign-out or switch discarded local changes the server never saw.
    private(set) var discardedOnSwitch: Int = 0
    /// Set when a sign-out found unpushed work and therefore kept the local data.
    private(set) var keptOnSignOut: Int = 0
    /// The name Apple carried on the authorization, for the account onboarding to prefill from.
    /// Apple offers it exactly once, on the first authorization, and only `enrolled` and
    /// `switched` carry it — so it is kept off the event here, or it is lost for that Apple id.
    private(set) var appleFullName: PersonNameComponents?

    /// The app's one blob store. It holds the one avatar the account has, which every FCT app
    /// reads through `AccountAvatar` and none keeps a copy of.
    @ObservationIgnored private(set) var avatars: AccountBlobStore?

    @ObservationIgnored private var engine: SyncEngine?
    @ObservationIgnored private var settledTask: Task<Void, Never>?
    @ObservationIgnored private var discardTask: Task<Void, Never>?
    @ObservationIgnored private var eventTask: Task<Void, Never>?
    /// When a cycle runs — the trigger subscription, the debounce that coalesces a burst, and the
    /// backoff wait — owned by the package so the rule it keeps is maintained in one place.
    @ObservationIgnored private lazy var scheduler = SyncScheduler { [weak self] cycle in
        await self?.syncNow(cycle)
    }
    /// The account's Realtime channel, and the task holding this foreground's subscription to it.
    @ObservationIgnored private var nudges: SyncNudgeChannel?
    @ObservationIgnored private var nudgeTask: Task<Void, Never>?
    @ObservationIgnored private var syncInFlight = false
    /// What a request arriving mid-cycle asks the loop to run next, at the strongest kind asked
    /// for while the cycle was up.
    @ObservationIgnored private var syncAgain: SyncCycle?
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
        startNudges()
        Task { await syncNow(.full) }
    }

    /// Backgrounding. iOS suspends the socket anyway, so releasing it here is what keeps the
    /// stream's teardown ours rather than the system's.
    func backgrounded() {
        nudgeTask?.cancel()
        nudgeTask = nil
    }

    /// Force a cycle now — the post-sign-in and settings-refresh path. A cycle already in flight
    /// is not joined by a second one; the request is remembered and the loop runs again once
    /// (the applier's own save fires `LocalSaveTrigger`, so every pull that lands rows asks for
    /// another cycle, which is correct and would otherwise re-enter). A request landing mid-cycle
    /// keeps the stronger kind: a nudge arriving during a push cycle is one full cycle after it,
    /// never a push that never asks.
    func syncNow(_ cycle: SyncCycle) async {
        guard let engine else { return }
        if syncInFlight {
            syncAgain = max(syncAgain ?? cycle, cycle)
            return
        }
        syncInFlight = true
        defer { syncInFlight = false }
        var current = cycle
        repeat {
            syncAgain = nil
            if let avatars { _ = await avatars.blobs.sync() }
            let result = await engine.sync(current)
            publish(result)
            scheduler.scheduleRetry(after: result)
            if let again = syncAgain { current = again }
        } while syncAgain != nil
    }

    /// Rung 2: a fresh subscription for this foreground, each nudge spent as a full cycle.
    ///
    /// Cancel-and-restart rather than a guard, because that is exactly what the channel's own
    /// contract is — one stream per foreground — and because every way a stream ends here is
    /// **ordinary**: losing the rung degrades to pull-on-foreground and post-push, which is what
    /// correctness rides on in the first place.
    private func startNudges() {
        nudgeTask?.cancel()
        guard let nudges, let engine else { return }
        let gated = nudges.nudges(gatedBy: engine)
        nudgeTask = Task { [weak self] in
            do {
                for try await _ in gated {
                    await self?.syncNow(.full)
                }
            } catch {
                AppLog.info("Sync nudge rung absent for this foreground: \(error)")
            }
        }
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
    /// Release every refused entry back to the queue and run a cycle. One explicit user action,
    /// never a loop: the engine is right that a refused payload must not be retried on its own,
    /// because the server judged that payload.
    ///
    /// It is only right about the payload, though. A refusal caused by the server's own state — a
    /// key collision, a column its schema had not learned — is repaired somewhere this device
    /// cannot see, on rows nobody is editing, so nothing local will ever change and nothing will
    /// ever re-queue them. And a refusal blocks its own recovery: the drained-outbox barrier counts
    /// stuck entries, so a device holding them can neither rebuild from the server nor sign out.
    /// Without this the only remaining move is deleting the app.
    @discardableResult
    func retryRefused() async -> Int {
        var requeued = engine?.retryFailed() ?? 0
        requeued += avatars?.blobs.retryFailed() ?? 0
        // Every backoff, or the release lands in a wire that is still waiting out the delay the
        // refusals wound up — a "try these again" that visibly does nothing for a minute.
        engine?.resetBackoff()
        avatars?.blobs.resetBackoff()
        // Full: a refusal is the one state where this device may also be the stale one — a record
        // judged because the server had moved on is repaired by hearing what the account holds,
        // not only by sending again.
        await syncNow(.full)
        return requeued
    }

    /// Rebuild this device's view from the server — the one answer to `.resyncRequired`. Refuses
    /// while anything is unpushed, which is the engine's own barrier rather than this one's.
    func fullResync() async {
        guard let engine else { return }
        do {
            try await engine.fullResync()
            publish(engine.status)
        } catch {
            lastError = "\(error)"
            publish(engine.status)
        }
    }

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
        await syncNow(.full)

        // The question is whether the PULL completed, not whether the outbox is clean, and the
        // marker is the only thing that answers it: it is stamped once a pull has walked the feed
        // to its end. A status cannot — records the server judged are a push-side fact that leaves
        // a clean pull reading `.failed`, and three of the catch paths reach `.failed` without the
        // pull having run at all.
        return engine?.hasCompletedFirstPull ?? false
    }

    /// Ask for one more pass, folded into a running cycle when one is up. A **push**: the uploads
    /// that settled freed records the gate was holding, which is a reason to send and never a
    /// reason to ask.
    private func requestAnotherCycle() {
        if syncInFlight {
            // Weaker than anything already asked for, so it only ever fills an empty slot.
            syncAgain = syncAgain ?? .push
            return
        }
        settledTask?.cancel()
        settledTask = Task { [weak self] in await self?.syncNow(.push) }
    }

    // MARK: - Account lifecycle

    func handle(_ event: AccountEvent) async {
        switch event {
        case .enrolled(let accountID, let appleFullName):
            self.appleFullName = appleFullName
            await startEngine(accountID: accountID, enrolling: true)
        case .resumed(let accountID):
            await startEngine(accountID: accountID, enrolling: false)
        case .switched(_, let to, let appleFullName):
            // A different account. Account A's rows must not silently become account B's, so this
            // clears local data — discarding whatever A never pushed, because A's credentials are
            // already gone and nothing can push it now.
            self.appleFullName = appleFullName
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

    /// The merge's local half: these rows belong to another account now, under the same ids, so
    /// the store changes owner and nothing is deleted. The engine rewrites its state file and
    /// marks every row dirty, and LWW settles the rest exactly as two ordinary devices do.
    func reHome(into account: UUID) {
        do {
            try engine?.reHome(into: account)
        } catch {
            AppLog.error("Account merge re-home failed", error: error)
        }
    }

    /// What signing out costs, in changes this device is still the only holder of. `nil` where
    /// there is no engine to ask — a count this device cannot take, which is never spelled as
    /// zero at the moment a clear is being decided.
    var unsyncedWork: OutboxCensus? {
        engine.map { unsyncedWork(engine: $0, avatars: avatars) }
    }

    private func unsyncedWork(engine: SyncEngine, avatars: AccountBlobStore?) -> OutboxCensus {
        var census = engine.state.counted
        if let blobCensus = avatars?.blobs.counted {
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
        await syncNow(.full)
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
        let avatars = self.avatars ?? makeDetachedAccountBlobStore()
        let outstanding = engine.map { unsyncedWork(engine: $0, avatars: avatars) }
        stopEngine(releasing: false)

        do {
            guard let outstanding, outstanding.isDrained else {
                throw SyncEngineError.outboxNotEmpty(outstanding ?? OutboxCensus())
            }
            try engine?.clearSyncedData()
            try avatars?.blobs.clearLocalData()
            clearLocalCaches()
            lastSyncedAt = nil
            counted = OutboxCensus()
            blobCounted = OutboxCensus()
            self.engine = nil
            self.avatars = nil
            onLocalDataCleared?()
        } catch {
            keptOnSignOut = max(outstanding?.total ?? 0, engine?.state.counted.total ?? 0)
            self.engine = nil
            self.avatars = nil
        }
    }

    private func startEngine(accountID: UUID, enrolling: Bool) async {
        guard let container, let credentials = currentAccount() else { return }
        guard credentials.accountID == accountID else { return }

        // `resume()` re-emits `.resumed` on every foregrounding: same account, not enrolling →
        // just run a cycle rather than rebuilding the trigger wiring per foreground.
        if let engine, !enrolling, engine.accountID == accountID {
            await syncNow(.full)
            return
        }
        stopEngine(releasing: true)

        let stateFile: SyncStateFile
        let avatarStore: AccountBlobStore
        do {
            stateFile = SyncStateFile(url: try configuration.stateFileURL())
            // The account's store shares this app's transport — one account, one JWT, one bucket —
            // and nothing else.
            avatarStore = AccountBlobStore(
                account: credentials,
                transport: configuration.makeBlobTransport(credentials),
                stateFileURL: try configuration.accountBlobStateFileURL(),
                cacheDirectory: try configuration.accountBlobCacheDirectory()
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
        // The ordering rule's engine half: a record with a pending or failed upload stays held, so
        // no device ever pulls a profile row naming an avatar the object store cannot serve.
        engine.pushGate = { [weak avatarStore] table, uuid in
            avatarStore?.blobs.isRecordPushable(table: table, uuid: uuid) ?? true
        }
        // The liveness half: a record the gate held is pushed the moment its upload lands.
        avatarStore.blobs.onUploadsSettled = { [weak self] in
            guard let self else { return }
            self.engine?.resetBackoff()
            self.requestAnotherCycle()
        }
        // Server-applied writes bypass every app-side write seam, so the derived surfaces
        // (Spotlight, widgets, exercise analytics) are told directly.
        engine.didApplyRemoteChanges = { [weak self] in self?.remoteChangesLanded() }
        engine.onAccountDeleted = { [weak self] in
            guard let self, let controller = self.controller else { return }
            Task { await controller.handleAccountDeleted() }
        }
        // The twin, and the one that matters more: without it the record that makes the next
        // sign-in a *resume* is never rewritten, and this app's own `.switched` handler clears the
        // store the engine's re-home just kept.
        engine.onAccountMerged = { [weak self] into in
            guard let self, let controller = self.controller else { return }
            Task { await controller.handleAccountMerged(into: into) }
        }

        if enrolling {
            do {
                try engine.enroll()
            } catch {
                lastError = "\(error)"
            }
        }
        self.engine = engine
        self.avatars = avatarStore
        self.nudges = configuration.makeNudgeChannel(credentials, stateFile)

        scheduler.observe(configuration.makeTriggers(container))
        startNudges()

        await syncNow(.full)
    }

    private func stopEngine(releasing: Bool) {
        scheduler.stop()
        nudgeTask?.cancel()
        nudgeTask = nil
        settledTask?.cancel()
        settledTask = nil
        discardTask?.cancel()
        discardTask = nil
        if releasing {
            engine = nil
            avatars = nil
            nudges = nil
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
        let avatars = self.avatars ?? makeDetachedAccountBlobStore()
        try? avatars?.blobs.clearLocalData(discardingUnsynced: true)
        clearLocalCaches()
        self.engine = nil
        self.avatars = nil
        lastSyncedAt = nil
        counted = OutboxCensus()
        blobCounted = OutboxCensus()
    }

    /// The non-synced residue a departing account leaves behind, and the other half of the store's
    /// teardown: `clearSyncedData` clears everything on the wire, this clears everything that is
    /// not, and between them they cover every model in the schema. A model in neither list is data
    /// that outlives the account that made it.
    ///
    /// All of it is re-derivable for whoever signs in next — the Apple Health mirrors from
    /// HealthKit, the analytics caches from the synced rows, the exercise catalog from the app
    /// bundle. "Re-derivable from HealthKit" is a property of the anchors, not a hope: the mirror
    /// rows and the anchors that produced them go together, or the next import resumes past
    /// history that no longer exists locally and the user reads it as data loss.
    nonisolated static let locallyClearedModels: [any PersistentModel.Type] = [
        HealthWorkout.self,
        WeightEntry.self,
        HealthStepsDistance.self,
        HealthEnergy.self,
        HealthSleepNight.self,
        HealthSleepBlock.self,
        HealthHeart.self,
        HealthRespiratoryRate.self,
        HealthWristTemperature.self,
        HydrationDay.self,
        HydrationEntry.self,
        ExerciseHistory.self,
        ProgressionPoint.self,
        RestTimeHistory.self,
        HealthSyncState.self,
        // The bundled catalog. It stopped syncing when the per-account copy became the sparse
        // `ExercisePreference`, which means the engine's clear no longer reaches it — and a
        // catalog row carries the departing account's favorite and last-added stamp.
        Exercise.self,
    ]

    private func clearLocalCaches() {
        guard let container else { return }
        let context = container.mainContext
        do {
            for model in Self.locallyClearedModels { try context.delete(model: model) }
            try context.save()
        } catch {
            AppLog.error("Sign-out cache clear failed", error: error)
        }
        HealthSyncPreferences.resetAllAnchors()
        unsafe SharedModelContainer.sharedDefaults.removeObject(forKey: DataManager.exerciseCatalogVersionKey)
        SpotlightIndexer.deleteAll()
    }

    /// The engine's own state file, for the account onboarding gate — which reads what the engine
    /// has pulled rather than what the store happens to hold. `nil` only when the App Group
    /// container cannot be resolved, which is the same condition that leaves the engine unbuilt.
    var stateFile: SyncStateFile? {
        (try? configuration.stateFileURL()).map(SyncStateFile.init(url:))
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

    private func makeDetachedAccountBlobStore() -> AccountBlobStore? {
        guard let stateURL = try? configuration.accountBlobStateFileURL(),
              let cacheURL = try? configuration.accountBlobCacheDirectory()
        else { return nil }
        return AccountBlobStore(
            account: DetachedAccount(accountID: UUID()),
            transport: UnreachableBlobTransport(),
            stateFileURL: stateURL,
            cacheDirectory: cacheURL
        )
    }

    // MARK: - Reacting

    /// Rows the engine applied bypass every app-side write path, so each derived surface is
    /// refreshed here: Spotlight + widgets and the exercise-analytics cache.
    private func remoteChangesLanded() {
        guard let container else { return }
        SpotlightIndexer.reindexAll(context: container.mainContext)
        WidgetCenter.shared.reloadAllTimelines()
        ExerciseHistoryUpdater.rebuildAllHistories(context: container.mainContext)
    }

    private func publish(_ result: SyncStatus) {
        status = result
        lastError = engine?.lastError ?? avatars?.blobs.lastError
        refreshCounters()
    }

    private func refreshCounters() {
        guard let state = engine?.state else { return }
        lastSyncedAt = state.lastSyncedAt
        counted = state.counted
        blobCounted = avatars?.blobs.counted ?? OutboxCensus()
    }

    // MARK: - Backoff and connectivity

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
                await self.syncNow(.full)
            }
        }
        monitor.start(queue: DispatchQueue(label: "com.fcttechnologies.VillainArc.sync.path"))
    }
}

/// The wire, cut. Used where a process needs an engine's local half and must never reach a server.
nonisolated struct UnreachableTransport: SyncTransport {
    func push(schemaVersion: String, records: [PushRecord]) async throws -> [PushVerdict] {
        throw SyncTransportError.connectivity("no account")
    }

    func pullAll(schemaVersion: String, cursors: [String: Int64], rowBudget: Int) async throws -> PullAllEnvelope {
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

    /// There is deliberately no session here, so a refusal is exactly what it looks like — never a
    /// transient condition worth queueing behind a backoff.
    func isSessionLoss(_ error: any Error) -> Bool { true }
}
