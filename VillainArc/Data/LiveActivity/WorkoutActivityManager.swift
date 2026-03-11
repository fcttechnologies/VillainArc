import ActivityKit
import Foundation
import SwiftData

@MainActor
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

        let state = contentState(for: workout)
        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    static func end() {
        endAllActivities()
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
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        Task { @MainActor in
            for activity in Activity<WorkoutActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            requestActivity(for: workout)
        }
    }

    private static var currentActivity: Activity<WorkoutActivityAttributes>? {
        Activity<WorkoutActivityAttributes>.activities.first
    }

    private static func endAllActivities() {
        for activity in Activity<WorkoutActivityAttributes>.activities {
            Task {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private static func requestActivity(for workout: WorkoutSession) {
        let attributes = WorkoutActivityAttributes(startDate: workout.startedAt)
        let state = contentState(for: workout)
        do {
            _ = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }

    private static func contentState(for workout: WorkoutSession) -> WorkoutActivityAttributes.ContentState {
        let restTimer = RestTimerState.shared
        let activeInfo = workout.activeExerciseAndSet()

        return .init(title: workout.title, exerciseName: activeInfo?.exercise.name, setNumber: activeInfo.map { $0.set.index + 1 }, totalSets: activeInfo?.exercise.sortedSets.count, weight: activeInfo?.set.weight, reps: activeInfo?.set.reps, targetRPE: activeInfo?.set.prescription?.visibleTargetRPE, timerEndDate: restTimer.isRunning ? restTimer.endDate : nil, timerPausedRemaining: restTimer.isPaused ? restTimer.pausedRemainingSeconds : nil, timerStartedSeconds: restTimer.isActive ? restTimer.startedSeconds : nil, hasExercises: !workout.exercises!.isEmpty)
    }
}
