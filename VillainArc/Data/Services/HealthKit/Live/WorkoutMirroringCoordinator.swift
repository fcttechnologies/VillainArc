import Foundation
import HealthKit
import Observation
import SwiftData
import WatchConnectivity

private final class WatchReplyHandlerBox: @unchecked Sendable {
    nonisolated(unsafe) let reply: (Data) -> Void

    nonisolated init(_ reply: @escaping (Data) -> Void) {
        self.reply = reply
    }
}

private actor WatchCommandResultCache {
    private var results: [UUID: WatchWorkoutCommandResult] = [:]
    private var order: [UUID] = []
    private let maximumCount: Int

    init(maximumCount: Int) {
        self.maximumCount = maximumCount
    }

    func result(for commandID: UUID) -> WatchWorkoutCommandResult? {
        results[commandID]
    }

    func store(_ result: WatchWorkoutCommandResult, for commandID: UUID) {
        results[commandID] = result
        order.removeAll(where: { $0 == commandID })
        order.append(commandID)

        while order.count > maximumCount {
            let oldest = order.removeFirst()
            results.removeValue(forKey: oldest)
        }
    }
}

@Observable final class WorkoutMirroringCoordinator: NSObject {
    static let shared = WorkoutMirroringCoordinator()

    private(set) var activeWorkoutSessionID: UUID?
    private(set) var latestHeartRate: Double?
    private(set) var activeEnergyBurned: Double?
    private(set) var restingEnergyBurned: Double?
    private(set) var mirroredSessionState: HKWorkoutSessionState?
    private(set) var isMirroredSessionConnected = false

    @ObservationIgnored private var mirroredWorkoutSession: HKWorkoutSession?
    @ObservationIgnored private var mirroredWorkoutBuilder: HKLiveWorkoutBuilder?

    private override init() {
        super.init()
    }

    var totalEnergyBurned: Double? {
        guard let activeEnergyBurned, let restingEnergyBurned else { return nil }
        return activeEnergyBurned + restingEnergyBurned
    }

    var isRunningLiveWorkoutCollection: Bool {
        guard isMirroredSessionConnected else { return false }
        guard activeWorkoutSessionID != nil else { return false }
        guard let state = mirroredSessionState else { return false }

        switch state {
        case .notStarted, .prepared, .running, .paused:
            return true
        case .stopped, .ended:
            return false
        @unknown default:
            return false
        }
    }

    func registerMirroringStartHandler() {
        guard HealthAuthorizationManager.isHealthDataAvailable else { return }

        HealthAuthorizationManager.healthStore.workoutSessionMirroringStartHandler = { [weak self] mirroredSession in
            Task { @MainActor in
                self?.attachMirroredSession(mirroredSession)
            }
        }
    }

    func canSendRemoteData(for sessionID: UUID) -> Bool {
        guard activeWorkoutSessionID == sessionID else { return false }
        guard mirroredWorkoutSession != nil else { return false }
        return isMirroredSessionConnected
    }

    func sendRemoteMessage(_ message: MirroredWorkoutRemoteMessage) async throws {
        guard let mirroredWorkoutSession else {
            throw NSError(domain: "WorkoutMirroringCoordinator", code: 1, userInfo: [NSLocalizedDescriptionKey: "No mirrored workout session is attached."])
        }

        let data = try JSONEncoder().encode(message)
        try await mirroredWorkoutSession.sendToRemoteWorkoutSession(data: data)
    }

    @MainActor
    private func attachMirroredSession(_ mirroredSession: HKWorkoutSession) {
        let mirroredBuilder = mirroredSession.associatedWorkoutBuilder()

        mirroredWorkoutSession = mirroredSession
        mirroredWorkoutBuilder = mirroredBuilder
        mirroredSessionState = mirroredSession.state
        isMirroredSessionConnected = true

        mirroredWorkoutSession?.delegate = self
        mirroredWorkoutBuilder?.delegate = self

        activeWorkoutSessionID = workoutSessionID(from: mirroredBuilder)
        refreshLiveStatistics()
    }

    @MainActor
    private func refreshLiveStatistics() {
        let previousHeartRate = latestHeartRate
        let previousActiveEnergy = activeEnergyBurned
        let previousRestingEnergy = restingEnergyBurned

        guard let mirroredWorkoutBuilder else {
            latestHeartRate = nil
            activeEnergyBurned = nil
            restingEnergyBurned = nil
            return
        }

        latestHeartRate = mirroredWorkoutBuilder.statistics(for: HealthKitCatalog.heartRateType)?
            .mostRecentQuantity()?
            .doubleValue(for: HealthKitCatalog.bpmUnit)

        activeEnergyBurned = mirroredWorkoutBuilder.statistics(for: HealthKitCatalog.activeEnergyBurnedType)?
            .sumQuantity()?
            .doubleValue(for: HealthKitCatalog.kilocalorieUnit)

        restingEnergyBurned = mirroredWorkoutBuilder.statistics(for: HealthKitCatalog.restingEnergyBurnedType)?
            .sumQuantity()?
            .doubleValue(for: HealthKitCatalog.kilocalorieUnit)

        let didChangeDisplayMetrics =
            roundedDisplayMetric(previousHeartRate) != roundedDisplayMetric(latestHeartRate)
            || roundedDisplayMetric(previousActiveEnergy) != roundedDisplayMetric(activeEnergyBurned)
            || roundedDisplayMetric(previousRestingEnergy) != roundedDisplayMetric(restingEnergyBurned)

        if didChangeDisplayMetrics, activeWorkoutSessionID != nil {
            WorkoutActivityManager.updateLiveMetrics()
            Task { @MainActor in
                WatchWorkoutCommandCoordinator.shared.pushLatestRuntimeStateIfNeeded()
            }
        }
    }

    @MainActor
    private func clearMirroredState() {
        mirroredWorkoutSession = nil
        mirroredWorkoutBuilder = nil
        activeWorkoutSessionID = nil
        latestHeartRate = nil
        activeEnergyBurned = nil
        restingEnergyBurned = nil
        mirroredSessionState = nil
        isMirroredSessionConnected = false
    }

    private func workoutSessionID(from workoutBuilder: HKLiveWorkoutBuilder) -> UUID? {
        guard let rawWorkoutSessionID = workoutBuilder.metadata[HealthMetadataKeys.workoutSessionID] as? String else {
            return nil
        }

        return UUID(uuidString: rawWorkoutSessionID)
    }

    private func roundedDisplayMetric(_ value: Double?) -> Int? {
        guard let value else { return nil }
        return Int(value.rounded())
    }
}

extension WorkoutMirroringCoordinator: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        Task { @MainActor in
            mirroredSessionState = toState

            switch toState {
            case .stopped, .ended:
                clearMirroredState()
            default:
                break
            }
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: any Error) {
        Task { @MainActor in
            print("Mirrored workout session failed: \(error)")
            clearMirroredState()
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didReceiveDataFromRemoteWorkoutSession data: [Data]) {
        Task { @MainActor in
            for messageData in data {
                await WatchWorkoutCommandCoordinator.shared.handleMirroredMessage(messageData)
            }
        }
    }
}

extension WorkoutMirroringCoordinator: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        Task { @MainActor in
            activeWorkoutSessionID = workoutSessionID(from: workoutBuilder)
            refreshLiveStatistics()
        }
    }
}

@MainActor
final class WatchWorkoutCommandCoordinator: NSObject, WCSessionDelegate {
    static let shared = WatchWorkoutCommandCoordinator()

    private enum ApplicationContextKey {
        static let runtime = "watchRuntime"
    }

    private let session: WCSession? = WCSession.isSupported() ? WCSession.default : nil
    private var didActivateSession = false
    private let commandResultCache = WatchCommandResultCache(maximumCount: 64)

    private override init() {
        super.init()
    }

    func activateSessionIfNeeded() {
        guard let session, !didActivateSession else { return }
        session.delegate = self
        session.activate()
        didActivateSession = true
    }

    func pushSnapshotIfMirrored(for _: WorkoutSession) {
        pushLatestRuntimeStateIfNeeded()
    }

    func pushRuntimeStateIfMirrored(for _: WorkoutSession) {
        pushLatestRuntimeStateIfNeeded()
    }

    func pushLatestRuntimeStateIfNeeded() {
        let snapshot = currentRuntimeSnapshot()
        updateApplicationContext(with: snapshot)

        if let snapshot {
            sendRuntimeEvent(.snapshot(snapshot))
        } else {
            sendRuntimeEvent(.clearActiveWorkout)
        }
    }

    func notifyWatchCancelled(sessionID: UUID) {
        updateApplicationContext(with: nil)
        sendRuntimeEvent(.discardMirroredSession(sessionID: sessionID))
    }

    func requestFinishIfMirrored(for workout: WorkoutSession) async {
        updateApplicationContext(with: nil)
        let endedAt = max(workout.startedAt, workout.endedAt ?? .now)
        sendRuntimeEvent(.finishMirroredSession(sessionID: workout.id, endedAt: endedAt))
    }

    func requestDiscardIfMirrored(for workout: WorkoutSession) {
        notifyWatchCancelled(sessionID: workout.id)
    }

    func requestWatchStartIfAvailable(for workout: WorkoutSession) async {
        guard workout.statusValue == .active else { return }
        guard workout.healthCollectionMode != .watchMirrored else { return }

        let snapshot = makeActiveWorkoutSnapshot(for: workout)
        updateApplicationContext(with: snapshot)
        await startWatchAppIfPossible()

        guard let session, canExchangeBackgroundMessages(with: session), session.isReachable else { return }

        do {
            let request = PhoneToWatchControlRequest.startMirroring(snapshot)
            let encoded = try JSONEncoder().encode(request)
            let result: WatchWorkoutCommandResult = await withCheckedContinuation { continuation in
                session.sendMessageData(encoded) { replyData in
                    let decoded = (try? JSONDecoder().decode(WatchWorkoutCommandResult.self, from: replyData))
                        ?? .failed(reason: "Received an invalid response from Apple Watch.")
                    continuation.resume(returning: decoded)
                } errorHandler: { error in
                    continuation.resume(returning: .failed(reason: (error as NSError).localizedDescription))
                }
            }

            switch result {
            case .started(let updatedSnapshot), .updated(let updatedSnapshot):
                if workout.healthCollectionMode != .watchMirrored {
                    workout.healthCollectionMode = .watchMirrored
                    saveContext(context: SharedModelContainer.container.mainContext)
                }
                updateApplicationContext(with: updatedSnapshot)
                sendRuntimeEvent(.snapshot(updatedSnapshot))
            case .finishOnPhone, .blocked, .cancelled, .failed:
                break
            }
        } catch {
            print("Failed to request Apple Watch live session start: \(error)")
        }
    }

    private func startWatchAppIfPossible() async {
        guard let session else { return }
        guard session.activationState == .activated else { return }
        guard session.isPaired, session.isWatchAppInstalled else { return }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor

        do {
            try await HealthAuthorizationManager.healthStore.startWatchApp(toHandle: configuration)
        } catch {
            print("Failed to launch Apple Watch app for workout mirroring: \(error)")
        }
    }

    func makeActiveWorkoutSnapshot(for workout: WorkoutSession) -> ActiveWorkoutSnapshot {
        let context = SharedModelContainer.container.mainContext
        let settings = (try? context.fetch(AppSettings.single))?.first
        let restTimer = RestTimerState.shared
        let usesMirroring = workout.healthCollectionMode == .watchMirrored
        let activeInfo = workout.activeExerciseAndSet()

        let heartRate = usesMirroring
            ? WorkoutMirroringCoordinator.shared.latestHeartRate
            : HealthLiveWorkoutSessionCoordinator.shared.latestHeartRate
        let activeEnergy = usesMirroring
            ? WorkoutMirroringCoordinator.shared.activeEnergyBurned
            : HealthLiveWorkoutSessionCoordinator.shared.activeEnergyBurned
        let restingEnergy = usesMirroring
            ? WorkoutMirroringCoordinator.shared.restingEnergyBurned
            : HealthLiveWorkoutSessionCoordinator.shared.restingEnergyBurned

        return ActiveWorkoutSnapshot(
            sessionID: workout.id,
            title: workout.title,
            status: workout.statusValue,
            startedAt: workout.startedAt,
            activeExerciseID: activeInfo?.exercise.id ?? workout.activeExercise?.id,
            exercises: workout.sortedExercises.map { exercise in
                WatchExerciseSnapshot(
                    exerciseID: exercise.id,
                    name: exercise.name,
                    sets: exercise.sortedSets.map { set in
                        WatchSetSnapshot(
                            setID: set.id,
                            index: set.index,
                            complete: set.complete,
                            reps: set.reps,
                            weight: set.weight,
                            targetRPE: set.prescription?.visibleTargetRPE,
                            hasTarget: set.reps > 0 || set.weight > 0 || set.prescription?.visibleTargetRPE != nil
                        )
                    }
                )
            },
            restTimer: restTimer.isActive
                ? WatchRestTimerSnapshot(
                    endDate: restTimer.endDate,
                    pausedRemainingSeconds: restTimer.pausedRemainingSeconds,
                    isPaused: restTimer.isPaused,
                    startedSeconds: restTimer.startedSeconds
                )
                : nil,
            healthCollectionMode: workout.healthCollectionMode,
            canFinishOnWatch: workout.unfinishedSetSummary.caseType == .none
                && !(settings?.promptForPostWorkoutEffort ?? true)
                && workout.statusValue == .active,
            latestHeartRate: heartRate,
            activeEnergyBurned: activeEnergy,
            restingEnergyBurned: restingEnergy
        )
    }

    func handleMirroredMessage(_ messageData: Data) async {
        guard let message = try? JSONDecoder().decode(MirroredWorkoutRemoteMessage.self, from: messageData) else {
            return
        }

        switch message {
        case .command(let command):
            let result = await handleCommand(command)
            guard let commandID = command.commandID else { return }
            do {
                try await WorkoutMirroringCoordinator.shared.sendRemoteMessage(.commandResult(commandID: commandID, result: result))
            } catch {
                print("Failed to send mirrored command result for \(commandID): \(error)")
            }
        case .snapshot, .commandResult, .finishMirroredSession, .discardMirroredSession:
            break
        }
    }

    private func currentRuntimeSnapshot() -> ActiveWorkoutSnapshot? {
        let context = SharedModelContainer.container.mainContext
        guard let workout = try? context.fetch(WorkoutSession.incomplete).first else { return nil }

        switch workout.statusValue {
        case .pending, .active:
            return makeActiveWorkoutSnapshot(for: workout)
        case .summary, .done:
            return nil
        }
    }

    private func updateApplicationContext(with snapshot: ActiveWorkoutSnapshot?) {
        guard let session, canExchangeBackgroundMessages(with: session) else { return }

        do {
            let context = WatchRuntimeApplicationContext(activeSnapshot: snapshot)
            let encoded = try JSONEncoder().encode(context)
            try session.updateApplicationContext([ApplicationContextKey.runtime: encoded])
        } catch {
            print("Failed to update watch runtime application context: \(error)")
        }
    }

    private func sendRuntimeEvent(_ event: PhoneToWatchRuntimeEvent) {
        if sendRuntimeEventOverMirroringIfPossible(event) {
            return
        }

        guard let session, session.activationState == .activated, session.isReachable else { return }

        do {
            let data = try JSONEncoder().encode(event)
            session.sendMessageData(data, replyHandler: nil) { error in
                print("Failed to send watch runtime event: \(error)")
            }
        } catch {
            print("Failed to encode watch runtime event: \(error)")
        }
    }

    private func sendRuntimeEventOverMirroringIfPossible(_ event: PhoneToWatchRuntimeEvent) -> Bool {
        let remoteMessage: MirroredWorkoutRemoteMessage
        let targetSessionID: UUID

        switch event {
        case .snapshot(let snapshot):
            guard snapshot.healthCollectionMode == .watchMirrored else { return false }
            remoteMessage = .snapshot(snapshot)
            targetSessionID = snapshot.sessionID
        case .finishMirroredSession(let sessionID, let endedAt):
            remoteMessage = .finishMirroredSession(sessionID: sessionID, endedAt: endedAt)
            targetSessionID = sessionID
        case .discardMirroredSession(let sessionID):
            remoteMessage = .discardMirroredSession(sessionID: sessionID)
            targetSessionID = sessionID
        case .clearActiveWorkout:
            return false
        }

        guard WorkoutMirroringCoordinator.shared.canSendRemoteData(for: targetSessionID) else { return false }

        Task {
            do {
                try await WorkoutMirroringCoordinator.shared.sendRemoteMessage(remoteMessage)
            } catch {
                print("Failed to send mirrored runtime event: \(error)")
            }
        }

        return true
    }

    private func canExchangeBackgroundMessages(with session: WCSession) -> Bool {
        session.activationState == .activated && session.isPaired && session.isWatchAppInstalled
    }

    private func cacheResult(_ result: WatchWorkoutCommandResult, for commandID: UUID) async {
        await commandResultCache.store(result, for: commandID)
    }

    private func handleCommand(_ command: WatchWorkoutCommand) async -> WatchWorkoutCommandResult {
        if let commandID = command.commandID, let cached = await commandResultCache.result(for: commandID) {
            return cached
        }

        let result: WatchWorkoutCommandResult

        switch command {
        case .startPlannedWorkout(let planID):
            result = handleStartWorkout(planID: planID)
        case .activateMirroring(let sessionID, let commandID):
            result = await handleActivateMirroring(sessionID: sessionID, commandID: commandID)
        case .toggleSet(let sessionID, let setID, let desiredComplete, let commandID):
            result = await handleToggleSet(sessionID: sessionID, setID: setID, desiredComplete: desiredComplete, commandID: commandID)
        case .finish(let sessionID, let commandID):
            result = await handleFinish(sessionID: sessionID, commandID: commandID)
        case .cancel(let sessionID, let commandID):
            result = await handleCancel(sessionID: sessionID, commandID: commandID)
        }

        if let commandID = command.commandID {
            await cacheResult(result, for: commandID)
        }

        return result
    }

    private func handleStartWorkout(planID: UUID) -> WatchWorkoutCommandResult {
        let context = SharedModelContainer.container.mainContext

        do {
            try SetupGuard.requireReady(context: context)
        } catch {
            return .blocked(reason: "Complete setup on iPhone first.")
        }

        if (try? context.fetch(WorkoutPlan.incomplete).first) != nil {
            return .blocked(reason: "Finish or discard the current plan on iPhone first.")
        }

        if let workout = try? context.fetch(WorkoutSession.incomplete).first {
            switch workout.statusValue {
            case .pending, .active:
                return .blocked(reason: "Resume or cancel the current workout on iPhone first.")
            case .summary, .done:
                break
            }
        }

        guard let storedPlan = try? context.fetch(WorkoutPlan.byIDForSessionStart(planID)).first else {
            return .failed(reason: "That workout plan is no longer available.")
        }

        guard storedPlan.completed else {
            return .blocked(reason: "Finish creating that plan on iPhone first.")
        }

        let settings = (try? context.fetch(AppSettings.single))?.first
        let weightUnit = settings?.weightUnit ?? .lbs
        let workoutSession = WorkoutSession(from: storedPlan)
        workoutSession.convertSetWeightsFromKg(to: weightUnit)

        let hasDeferredSuggestions = !pendingSuggestionEvents(for: storedPlan, in: context).isEmpty
        if hasDeferredSuggestions {
            workoutSession.status = SessionStatus.pending.rawValue
        }

        context.insert(workoutSession)
        saveContext(context: context)

        if hasDeferredSuggestions {
            return .finishOnPhone(reason: "Continue on iPhone to review suggestions.")
        }

        return .started(makeActiveWorkoutSnapshot(for: workoutSession))
    }

    private func handleActivateMirroring(sessionID: UUID, commandID: UUID) async -> WatchWorkoutCommandResult {
        if let cached = await commandResultCache.result(for: commandID) {
            return cached
        }

        let context = SharedModelContainer.container.mainContext
        guard let workout = try? context.fetch(WorkoutSession.byID(sessionID)).first else {
            return .failed(reason: "session not found")
        }

        guard workout.statusValue == .active else {
            return .failed(reason: "session not active")
        }

        if workout.healthCollectionMode != .watchMirrored {
            workout.healthCollectionMode = .watchMirrored
            saveContext(context: context)
            WorkoutActivityManager.update(for: workout)
        }

        return .updated(makeActiveWorkoutSnapshot(for: workout))
    }

    private func handleToggleSet(sessionID: UUID, setID: UUID, desiredComplete: Bool, commandID: UUID) async -> WatchWorkoutCommandResult {
        if let cached = await commandResultCache.result(for: commandID) {
            return cached
        }

        let context = SharedModelContainer.container.mainContext
        guard let workout = try? context.fetch(WorkoutSession.byID(sessionID)).first else {
            return .failed(reason: "session not found")
        }

        guard workout.statusValue == .active else {
            return .failed(reason: "session not active")
        }

        guard let set = workout.sortedExercises.flatMap(\.sortedSets).first(where: { $0.id == setID }) else {
            return .failed(reason: "set not found")
        }

        if set.complete == desiredComplete {
            return .updated(makeActiveWorkoutSnapshot(for: workout))
        }

        if desiredComplete {
            set.complete = true
            set.completedAt = Date()
            startRestTimerIfNeeded(for: set, in: context)
        } else {
            set.complete = false
            set.completedAt = nil
            if RestTimerState.shared.startedFromSetID == set.id {
                RestTimerState.shared.stop()
            }
        }

        saveContext(context: context)
        WorkoutActivityManager.update(for: workout)
        return .updated(makeActiveWorkoutSnapshot(for: workout))
    }

    private func handleFinish(sessionID: UUID, commandID: UUID) async -> WatchWorkoutCommandResult {
        if let cached = await commandResultCache.result(for: commandID) {
            return cached
        }

        let context = SharedModelContainer.container.mainContext
        guard let workout = try? context.fetch(WorkoutSession.byID(sessionID)).first else {
            return .failed(reason: "session not found")
        }

        guard workout.statusValue == .active else {
            return .failed(reason: "session not active")
        }

        let settings = (try? context.fetch(AppSettings.single))?.first
        let shouldPromptForPostWorkoutEffort = settings?.promptForPostWorkoutEffort ?? true

        guard workout.unfinishedSetSummary.caseType == .none else {
            return .finishOnPhone(reason: "Finish on iPhone to review unfinished sets.")
        }

        guard !shouldPromptForPostWorkoutEffort else {
            return .finishOnPhone(reason: "Finish on iPhone to review post-workout effort.")
        }

        let weightUnit = settings?.weightUnit ?? .lbs
        let result = workout.finish(action: .finish, context: context)

        switch result {
        case .finished:
            RestTimerState.shared.stop()
            workout.convertSetWeightsToKg(from: weightUnit)
            saveContext(context: context)
            WorkoutActivityManager.update(for: workout)
            return .updated(makeActiveWorkoutSnapshot(for: workout))
        case .workoutDeleted:
            AppRouter.shared.activeWorkoutSession = nil
            saveContext(context: context)
            WorkoutActivityManager.end()
            return .cancelled
        }
    }

    private func handleCancel(sessionID: UUID, commandID: UUID) async -> WatchWorkoutCommandResult {
        if let cached = await commandResultCache.result(for: commandID) {
            return cached
        }

        let context = SharedModelContainer.container.mainContext
        guard let workout = try? context.fetch(WorkoutSession.byID(sessionID)).first else {
            return .failed(reason: "session not found")
        }

        RestTimerState.shared.stop()
        context.delete(workout)
        saveContext(context: context)
        if AppRouter.shared.activeWorkoutSession?.id == sessionID {
            AppRouter.shared.activeWorkoutSession = nil
        }
        WorkoutActivityManager.end()
        return .cancelled
    }

    private func startRestTimerIfNeeded(for set: SetPerformance, in context: ModelContext) {
        let autoStartRestTimerEnabled = (try? context.fetch(AppSettings.single).first)?.autoStartRestTimer ?? true
        guard autoStartRestTimerEnabled else { return }

        let restSeconds = set.effectiveRestSeconds
        guard restSeconds > 0 else { return }

        RestTimerState.shared.start(seconds: restSeconds, startedFromSetID: set.id)
        RestTimeHistory.record(seconds: restSeconds, context: context)
    }

    private func encodedReply(for messageData: Data) async -> Data? {
        let result: WatchWorkoutCommandResult

        do {
            let command = try JSONDecoder().decode(WatchWorkoutCommand.self, from: messageData)
            result = await handleCommand(command)
        } catch {
            result = .failed(reason: "Invalid watch command.")
        }

        do {
            return try JSONEncoder().encode(result)
        } catch {
            print("Failed to encode watch command result: \(error)")
            return nil
        }
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        if let error {
            print("WCSession activation failed: \(error)")
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {}

    nonisolated func session(_ session: WCSession, didReceiveMessageData messageData: Data, replyHandler: @escaping (Data) -> Void) {
        let replyBox = WatchReplyHandlerBox(replyHandler)
        Task {
            if let encoded = await WatchWorkoutCommandCoordinator.shared.encodedReply(for: messageData) {
                replyBox.reply(encoded)
            }
        }
    }
}
