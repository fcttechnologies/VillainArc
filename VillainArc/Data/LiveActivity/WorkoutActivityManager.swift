import Foundation
import SwiftData
import ActivityKit

enum WorkoutActivityManager {
    private static var liveActivitiesEnabled: Bool {
        let context = SharedModelContainer.container.mainContext
        return (try? context.fetch(AppSettings.single).first)?.liveActivitiesEnabled ?? true
    }

    static func start(workout: WorkoutSession) {
        guard liveActivitiesEnabled else {
            endAllActivities()
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        endAllActivities()
        requestActivity(for: workout)
    }

    static func update(for workout: WorkoutSession? = nil) {
        guard liveActivitiesEnabled else {
            endAllActivities()
            return
        }
        guard let activity = currentActivity else { return }

        let resolvedWorkout: WorkoutSession?
        if let workout {
            resolvedWorkout = workout
        } else {
            let context = SharedModelContainer.container.mainContext
            resolvedWorkout = try? context.fetch(WorkoutSession.incomplete).first
        }

        guard let workout = resolvedWorkout else {
            endAllActivities()
            return
        }

        let activityID = activity.id
        let state = contentState(for: workout)
        Task { await updateActivity(id: activityID, state: state) }
    }

    static func end() { endAllActivities() }

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
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        Task { @MainActor in
            let activityIDs = Activity<WorkoutActivityAttributes>.activities.map(\.id)
            await endActivities(ids: activityIDs)
            requestActivity(for: workout)
        }
    }

    private static var currentActivity: Activity<WorkoutActivityAttributes>? { Activity<WorkoutActivityAttributes>.activities.first }

    private static func endAllActivities() {
        let activityIDs = Activity<WorkoutActivityAttributes>.activities.map(\.id)
        Task { await endActivities(ids: activityIDs) }
    }

    private static func requestActivity(for workout: WorkoutSession) {
        let attributes = WorkoutActivityAttributes(startDate: workout.startedAt)
        let state = contentState(for: workout)
        do {
            _ = try Activity.request(attributes: attributes, content: .init(state: state, staleDate: nil), pushType: nil)
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

        return .init(title: workout.title, exerciseName: activeInfo?.exercise.name, setNumber: activeInfo.map { $0.set.index + 1 }, totalSets: activeInfo?.exercise.sortedSets.count, weight: activeInfo?.set.weight, weightUnit: weightUnit.rawValue, reps: activeInfo?.set.reps, targetRPE: activeInfo?.set.prescription?.visibleTargetRPE, timerEndDate: restTimer.isRunning ? restTimer.endDate : nil, timerPausedRemaining: restTimer.isPaused ? restTimer.pausedRemainingSeconds : nil, timerStartedSeconds: restTimer.isActive ? restTimer.startedSeconds : nil, hasExercises: !workout.exercises!.isEmpty, liveHeartRateBPM: healthLiveWorkoutCoordinator.latestHeartRate, liveActiveEnergyBurned: healthLiveWorkoutCoordinator.activeEnergyBurned)
    }

    nonisolated private static func updateActivity(id: String, state: WorkoutActivityAttributes.ContentState) async {
        guard let activity = Activity<WorkoutActivityAttributes>.activities.first(where: { $0.id == id }) else { return }
        await activity.update(.init(state: state, staleDate: nil))
    }

    nonisolated private static func endActivities(ids: [String]) async {
        for id in ids {
            guard let activity = Activity<WorkoutActivityAttributes>.activities.first(where: { $0.id == id }) else { continue }
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
