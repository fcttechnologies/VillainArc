import Foundation
import SwiftData
import ActivityKit

enum WorkoutActivityManager {
    private static let transientStatusDuration: TimeInterval = 4
    private static var lastDeliveredActivityID: String?
    private static var lastDeliveredState: WorkoutActivityAttributes.ContentState?
    private static var pendingTransientStatusResetTask: Task<Void, Never>?

    private static var liveActivitiesEnabled: Bool {
        let context = SharedModelContainer.container.mainContext
        return (try? context.fetch(AppSettings.single).first)?.liveActivitiesEnabled ?? true
    }

    static var areActivitiesAvailable: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    static func start(workout: WorkoutSession) {
        guard liveActivitiesEnabled else {
            endAllActivities()
            return
        }
        guard areActivitiesAvailable else { return }
        endAllActivities()
        requestActivity(for: workout)
    }

    static func update(for workout: WorkoutSession? = nil) {
        guard liveActivitiesEnabled else {
            endAllActivities()
            return
        }
        performImmediateUpdate(for: workout)
    }

    static func updateLiveMetrics() {
        guard liveActivitiesEnabled else {
            endAllActivities()
            return
        }
        guard currentActivity != nil else { return }
        guard !hasActiveTransientStatus else { return }
        performImmediateUpdate(for: nil)
    }

    static func end() { endAllActivities() }

    static func showRestTimerCompletionAlert(for workout: WorkoutSession? = nil) {
        guard canPresentRestTimerCompletionAlert else { return }
        guard let activity = currentActivity else { return }
        guard let workout = resolveWorkout(for: workout) else {
            endAllActivities()
            return
        }

        pendingTransientStatusResetTask?.cancel()

        var state = normalizedContentState(for: contentState(for: workout))
        state.transientStatusText = "Rest time done"
        recordDeliveredState(state, forActivityID: activity.id)

        let alertConfiguration = AlertConfiguration(title: "Rest time done", body: "Time to lift again.", sound: .default)

        let activityID = activity.id
        Task {
            await updateActivity(id: activityID, state: state, alertConfiguration: alertConfiguration)
        }

        pendingTransientStatusResetTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64((transientStatusDuration * 1_000_000_000).rounded()))
            guard !Task.isCancelled else { return }
            pendingTransientStatusResetTask = nil
            performImmediateUpdate(for: workout, ignoringTransientStatus: true)
        }
    }

    static func restoreIfNeeded(workout: WorkoutSession) {
        guard liveActivitiesEnabled else {
            endAllActivities()
            return
        }
        if currentActivity != nil {
            update(for: workout)
        } else {
            start(workout: workout)
        }
    }

    static func restart(workout: WorkoutSession) {
        guard liveActivitiesEnabled else {
            endAllActivities()
            return
        }
        guard areActivitiesAvailable else { return }
        Task {
            let activityIDs = Activity<WorkoutActivityAttributes>.activities.map(\.id)
            await endActivities(ids: activityIDs)
            requestActivity(for: workout)
        }
    }

    private static var currentActivity: Activity<WorkoutActivityAttributes>? { Activity<WorkoutActivityAttributes>.activities.first }
    static var canPresentRestTimerCompletionAlert: Bool {
        guard liveActivitiesEnabled else { return false }
        guard areActivitiesAvailable else { return false }
        guard currentActivity != nil else { return false }
        return HealthLiveWorkoutSessionCoordinator.shared.isRunningLiveWorkoutCollection
    }

    private static func endAllActivities() {
        resetTrackedActivityState()
        let activityIDs = Activity<WorkoutActivityAttributes>.activities.map(\.id)
        Task { await endActivities(ids: activityIDs) }
    }

    private static func requestActivity(for workout: WorkoutSession) {
        resetTrackedActivityState()
        let attributes = WorkoutActivityAttributes(startDate: workout.startedAt)
        let state = normalizedContentState(for: contentState(for: workout))
        do {
            let activity = try Activity.request(attributes: attributes, content: .init(state: state, staleDate: nil), pushType: nil)
            recordDeliveredState(state, forActivityID: activity.id)
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }

    private static func contentState(for workout: WorkoutSession) -> WorkoutActivityAttributes.ContentState {
        let restTimer = RestTimerState.shared
        let activeInfo = workout.activeExerciseAndSet()
        let healthLiveWorkoutCoordinator = HealthLiveWorkoutSessionCoordinator.shared
        let context = SharedModelContainer.container.mainContext
        let weightUnit = (try? context.fetch(AppSettings.single))?.first?.weightUnit ?? .lbs
        let energyUnit = (try? context.fetch(AppSettings.single))?.first?.energyUnit ?? .systemDefault

        return .init(title: workout.title, exerciseName: activeInfo?.exercise.name, transientStatusText: nil, setNumber: activeInfo.map { $0.set.index + 1 }, totalSets: activeInfo?.exercise.sortedSets.count, weight: activeInfo?.set.weight, weightUnit: weightUnit.rawValue, energyUnit: energyUnit.rawValue, reps: activeInfo?.set.reps, targetRPE: activeInfo?.set.prescription?.visibleTargetRPE, timerEndDate: restTimer.isRunning ? restTimer.endDate : nil, timerPausedRemaining: restTimer.isPaused ? restTimer.pausedRemainingSeconds : nil, timerStartedSeconds: restTimer.isActive ? restTimer.startedSeconds : nil, hasExercises: !workout.exercises!.isEmpty, liveHeartRateBPM: healthLiveWorkoutCoordinator.latestHeartRate, liveActiveEnergyBurned: healthLiveWorkoutCoordinator.activeEnergyBurned)
    }

    private static var hasActiveTransientStatus: Bool {
        pendingTransientStatusResetTask != nil || lastDeliveredState?.transientStatusText != nil
    }

    private static func performImmediateUpdate(for workout: WorkoutSession?, ignoringTransientStatus: Bool = false) {
        guard let activity = currentActivity else { return }
        guard ignoringTransientStatus || !hasActiveTransientStatus else { return }
        let isResettingTransientStatus = ignoringTransientStatus && pendingTransientStatusResetTask == nil
        if !isResettingTransientStatus {
            pendingTransientStatusResetTask?.cancel()
            pendingTransientStatusResetTask = nil
        }

        guard let workout = resolveWorkout(for: workout) else {
            endAllActivities()
            return
        }

        let state = normalizedContentState(for: contentState(for: workout))
        guard shouldDeliver(state, toActivityID: activity.id) else { return }

        recordDeliveredState(state, forActivityID: activity.id)
        let activityID = activity.id
        Task { await updateActivity(id: activityID, state: state) }
    }

    private static func normalizedContentState(for state: WorkoutActivityAttributes.ContentState) -> WorkoutActivityAttributes.ContentState {
        var normalizedState = state
        normalizedState.liveHeartRateBPM = normalizedDisplayedHeartRate(state.liveHeartRateBPM)
        normalizedState.liveActiveEnergyBurned = normalizedDisplayedActiveEnergy(state.liveActiveEnergyBurned, unit: state.energyUnit)
        return normalizedState
    }

    private static func normalizedDisplayedHeartRate(_ value: Double?) -> Double? {
        guard let value else { return nil }
        return Double(Int(value.rounded()))
    }

    private static func normalizedDisplayedActiveEnergy(_ value: Double?, unit: String?) -> Double? {
        guard let value else { return nil }

        switch unit {
        case "kJ":
            return Double(Int((value * 4.184).rounded()))
        default:
            return Double(Int(value.rounded()))
        }
    }

    private static func shouldDeliver(_ state: WorkoutActivityAttributes.ContentState, toActivityID activityID: String) -> Bool {
        guard lastDeliveredActivityID == activityID else { return true }
        return lastDeliveredState != state
    }

    private static func resolveWorkout(for workout: WorkoutSession?) -> WorkoutSession? {
        if let workout {
            return workout
        }

        let context = SharedModelContainer.container.mainContext
        return try? context.fetch(WorkoutSession.incomplete).first
    }

    private static func recordDeliveredState(_ state: WorkoutActivityAttributes.ContentState, forActivityID activityID: String) {
        lastDeliveredActivityID = activityID
        lastDeliveredState = state
    }

    private static func resetTrackedActivityState() {
        pendingTransientStatusResetTask?.cancel()
        pendingTransientStatusResetTask = nil
        lastDeliveredActivityID = nil
        lastDeliveredState = nil
    }

    nonisolated private static func updateActivity(id: String, state: WorkoutActivityAttributes.ContentState, alertConfiguration: AlertConfiguration? = nil) async {
        guard let activity = Activity<WorkoutActivityAttributes>.activities.first(where: { $0.id == id }) else { return }
        await activity.update(.init(state: state, staleDate: nil), alertConfiguration: alertConfiguration)
    }

    nonisolated private static func endActivities(ids: [String]) async {
        for id in ids {
            guard let activity = Activity<WorkoutActivityAttributes>.activities.first(where: { $0.id == id }) else { continue }
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
