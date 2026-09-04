import FCTIntelligence
import Foundation
import SwiftData
import WatchConnectivity

// The iOS side of the Watch companion sync. The phone is the source of truth: this
// manager observes the live app state (rest timer, active strength/cardio session,
// live Health metrics) and pushes `WatchSyncPayload` snapshots to the watch via
// `updateApplicationContext` (latest-state semantics — exactly what a glance needs).
// Commands from the watch (rest-timer control, complete set) arrive as messages and
// run the same code paths the app's own UI and App Intents use.
//
// State changes are picked up with a re-arming `withObservationTracking` pass over
// `buildPayload()` — every observable property the payload reads (RestTimerState,
// AppRouter's active sessions, the Health coordinators' live metrics, the SwiftData
// session models) re-triggers a debounced sync, so no call sites need edits.
@Observable final class PhoneWatchSyncManager: NSObject {
    static let shared = PhoneWatchSyncManager()

    @ObservationIgnored private var lastSentPayload: WatchSyncPayload?
    @ObservationIgnored private var pendingSyncTask: Task<Void, Never>?
    @ObservationIgnored private var hasActivated = false

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        guard !hasActivated else { return }
        hasActivated = true
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: - Sync scheduling

    func scheduleSync() {
        pendingSyncTask?.cancel()
        pendingSyncTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            self?.syncNow()
        }
    }

    private func syncNow() {
        let payload = withObservationTracking {
            buildPayload()
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.scheduleSync()
            }
        }
        push(payload)
    }

    private func push(_ payload: WatchSyncPayload) {
        let session = WCSession.default
        guard hasActivated, session.activationState == .activated else { return }
        guard session.isPaired, session.isWatchAppInstalled else { return }
        guard payload != lastSentPayload else { return }
        guard let dictionary = WatchSync.encodePayload(payload) else { return }
        do {
            try session.updateApplicationContext(dictionary)
            lastSentPayload = payload
        } catch {
            AppLog.error("Failed to push watch application context", error: error)
        }
    }

    // MARK: - Payload

    private func buildPayload() -> WatchSyncPayload {
        let context = SharedModelContainer.container.mainContext
        let settings = try? context.fetch(AppSettings.single).first
        let weightUnit = settings?.weightUnit ?? .systemDefault
        let distanceUnit = settings?.distanceUnit ?? .systemDefault
        let energyUnit = settings?.energyUnit ?? .systemDefault

        var payload = WatchSyncPayload()
        payload.restTimer = restTimerSnapshot()
        payload.liveSession = liveSessionSnapshot(weightUnit: weightUnit, distanceUnit: distanceUnit, energyUnit: energyUnit)
        payload.quickStats = quickStatsSnapshot(context: context, weightUnit: weightUnit)
        payload.heartRateZones = zoneConfig()
        return payload
    }

    private func restTimerSnapshot() -> WatchRestTimerSnapshot? {
        let timer = RestTimerState.shared
        let snapshot = WatchRestTimerSnapshot(
            endDate: timer.endDate,
            pausedRemainingSeconds: timer.pausedRemainingSeconds,
            isPaused: timer.isPaused,
            startedSeconds: timer.startedSeconds
        )
        return snapshot.isActive ? snapshot : nil
    }

    private func liveSessionSnapshot(weightUnit: WeightUnit, distanceUnit: DistanceUnit, energyUnit: EnergyUnit) -> WatchLiveSessionSnapshot? {
        if let workout = AppRouter.shared.activeWorkoutSession, workout.statusValue == .active {
            return strengthSnapshot(for: workout, weightUnit: weightUnit, energyUnit: energyUnit)
        }
        if let session = AppRouter.shared.activeCardioSession, session.statusValue == .active {
            return cardioSnapshot(for: session, distanceUnit: distanceUnit, energyUnit: energyUnit)
        }
        return nil
    }

    private func strengthSnapshot(for workout: WorkoutSession, weightUnit: WeightUnit, energyUnit: EnergyUnit) -> WatchLiveSessionSnapshot {
        let coordinator = HealthLiveWorkoutSessionCoordinator.shared
        var snapshot = WatchLiveSessionSnapshot(kind: .strength, title: workout.title, startedAt: workout.startedAt)
        snapshot.heartRateBPM = coordinator.latestHeartRate
        if let activeEnergy = coordinator.activeEnergyBurned, activeEnergy > 0 {
            snapshot.activeEnergyText = formattedEnergyText(activeEnergy, unit: energyUnit)
        }

        let exercises = workout.sortedExercises
        snapshot.exerciseCount = exercises.count
        let allSets = exercises.flatMap(\.sortedSets)
        snapshot.totalSets = allSets.count
        snapshot.completedSets = allSets.filter(\.complete).count

        if let (exercise, set) = workout.activeExerciseAndSet() {
            snapshot.exerciseName = exercise.name
            if let exerciseIndex = exercises.firstIndex(of: exercise) {
                snapshot.exercisePosition = exerciseIndex + 1
            }
            let sets = exercise.sortedSets
            if let setIndex = sets.firstIndex(of: set) {
                snapshot.setPosition = setIndex + 1
            }
            snapshot.setCount = sets.count
            // During live logging, set weights hold DISPLAY units (the user's typed
            // values); they only convert to canonical kg on finish. So format the raw
            // value with the unit label directly — no kg conversion here.
            if set.reps > 0 || set.weight > 0 {
                var parts: [String] = []
                if set.reps > 0 {
                    parts.append(String(localized: "\(set.reps) reps"))
                }
                if set.weight > 0 {
                    parts.append("\(set.weight.formatted(.number.precision(.fractionLength(0...1)))) \(weightUnit.unitLabel)")
                }
                snapshot.targetText = parts.joined(separator: " · ")
            }
        }
        return snapshot
    }

    private func cardioSnapshot(for session: CardioSession, distanceUnit: DistanceUnit, energyUnit: EnergyUnit) -> WatchLiveSessionSnapshot {
        let coordinator = CardioHealthWorkoutCoordinator.shared
        let startedAt = session.startedAt ?? .now
        var snapshot = WatchLiveSessionSnapshot(kind: .cardio, title: session.displayTitle, startedAt: startedAt)
        snapshot.heartRateBPM = coordinator.latestHeartRate
        if let activeEnergy = coordinator.activeEnergyBurned, activeEnergy > 0 {
            snapshot.activeEnergyText = formattedEnergyText(activeEnergy, unit: energyUnit)
        }
        let distanceMeters = session.totalDistanceMeters
        if distanceMeters > 0 {
            snapshot.distanceText = formattedDistanceText(distanceMeters, unit: distanceUnit)
            snapshot.paceText = formattedPaceText(duration: Date.now.timeIntervalSince(startedAt), distanceMeters: distanceMeters, distanceUnit: distanceUnit)
        }
        return snapshot
    }

    private func quickStatsSnapshot(context: ModelContext, weightUnit: WeightUnit) -> WatchQuickStatsSnapshot? {
        var stats = WatchQuickStatsSnapshot()
        if let lastWorkout = try? context.fetch(WorkoutSession.recent).first {
            stats.lastWorkoutTitle = lastWorkout.title
            stats.lastWorkoutDate = lastWorkout.startedAt
            stats.lastWorkoutDurationSeconds = lastWorkout.totalDuration
            stats.lastWorkoutSets = lastWorkout.totalSets
            if lastWorkout.totalVolume > 0 {
                stats.lastWorkoutVolumeText = formattedWeightText(lastWorkout.totalVolume, unit: weightUnit, fractionDigits: 0...0)
            }
        }
        if let heart = try? context.fetch(HealthHeart.latest).first {
            stats.restingHeartRateBPM = heart.restingHeartRate
        }
        return stats == WatchQuickStatsSnapshot() ? nil : stats
    }

    /// The zones are age-derived, and the age is the **account's** birthday. Unknown until the
    /// account onboarding's trusted row has been read, and the watch simply gets no zone payload
    /// until then rather than one drawn from a guessed age.
    private func zoneConfig() -> WatchHeartRateZoneConfig? {
        guard let maximum = AccountBirthday.shared.estimatedMaxHeartRate() else { return nil }
        return WatchHeartRateZoneConfig(estimatedMaxHeartRate: maximum)
    }

    // MARK: - Commands

    private func handle(_ command: WatchSyncCommand) {
        switch command {
        case .requestSync:
            break
        case .startRestTimer(let seconds):
            RestTimerState.shared.start(seconds: min(max(0, seconds), 10 * 60))
        case .pauseRestTimer:
            RestTimerState.shared.pause()
        case .resumeRestTimer:
            RestTimerState.shared.resume()
        case .stopRestTimer:
            RestTimerState.shared.stop()
        case .adjustRestTimer(let deltaSeconds):
            RestTimerState.shared.adjust(by: deltaSeconds)
        case .completeActiveSet:
            completeActiveSet()
        }
    }

    // Mirrors CompleteActiveSetIntent.perform(). Watch taps, like widget and Live
    // Activity intent paths, do not donate.
    private func completeActiveSet() {
        let context = SharedModelContainer.container.mainContext
        guard let workout = try? context.fetch(WorkoutSession.incomplete).first else { return }
        guard let (_, set) = workout.activeExerciseAndSet() else { return }

        let settings = try? context.fetch(AppSettings.single).first
        let settingsSnapshot = AppSettingsSnapshot(settings: settings)
        let shouldPrewarmSuggestions = workout.workoutPlan != nil && workout.isFinalIncompleteSet(set)
        workout.completeSet(set, settings: settingsSnapshot)

        if settingsSnapshot.autoStartRestTimer {
            let restSeconds = set.effectiveRestSeconds
            RestTimerState.shared.start(seconds: restSeconds, startedFromSetID: set.id)
            if restSeconds > 0 {
                RestTimeHistory.record(seconds: restSeconds, context: context)
            }
        }
        saveContext(context: context)
        WorkoutActivityManager.update(for: workout)
        if shouldPrewarmSuggestions { FoundationModelPrewarmer.warmUp() }
    }
}

// Wraps the non-Sendable reply handler so it can cross into the MainActor task that
// builds the reply payload. WatchConnectivity delivers each reply handler exactly
// once and it is only called from that one task.
private nonisolated struct WatchReplyBox: @unchecked Sendable {
    let dictionary: [String: Any]
    let reply: ([String: Any]) -> Void
}

extension PhoneWatchSyncManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        if let error {
            AppLog.error("Watch session activation failed", error: error)
        }
        Task { @MainActor in
            PhoneWatchSyncManager.shared.scheduleSync()
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // The user switched to another paired Apple Watch — reconnect to it.
        session.activate()
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            PhoneWatchSyncManager.shared.scheduleSync()
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            PhoneWatchSyncManager.shared.scheduleSync()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let command = WatchSync.decodeCommand(from: message) else { return }
        Task { @MainActor in
            PhoneWatchSyncManager.shared.handleReceived(command)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        let box = WatchReplyBox(dictionary: message, reply: replyHandler)
        Task { @MainActor in
            PhoneWatchSyncManager.shared.handleReceived(box)
        }
    }

    fileprivate func handleReceived(_ command: WatchSyncCommand) {
        handle(command)
        scheduleSync()
    }

    fileprivate func handleReceived(_ box: WatchReplyBox) {
        if let command = WatchSync.decodeCommand(from: box.dictionary) {
            handle(command)
        }
        // The reply carries the fresh payload for immediate UI feedback; the
        // application context still syncs separately so a cold watch launch reads
        // current state too (lastSentPayload is deliberately not updated here).
        let payload = buildPayload()
        box.reply(WatchSync.encodePayload(payload) ?? [:])
        scheduleSync()
    }
}
