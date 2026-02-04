import ActivityKit
import Foundation
import SwiftData

@MainActor
enum WorkoutActivityManager {

    static func start(workout: WorkoutSession) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        endAllActivities()

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

    static func update(for workout: WorkoutSession? = nil) {
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
        if currentActivity != nil {
            update(for: workout)
        } else {
            start(workout: workout)
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

    private static func contentState(for workout: WorkoutSession) -> WorkoutActivityAttributes.ContentState {
        let restTimer = RestTimerState.shared
        let activeInfo = workout.activeExerciseAndSet()

        return .init(
            title: workout.title,
            exerciseName: activeInfo?.exercise.name,
            setNumber: activeInfo.map { $0.set.index + 1 },
            totalSets: activeInfo?.exercise.sortedSets.count,
            weight: activeInfo?.set.weight,
            reps: activeInfo?.set.reps,
            setTypeRawValue: activeInfo?.set.type.displayName,
            timerEndDate: restTimer.isRunning ? restTimer.endDate : nil,
            timerPausedRemaining: restTimer.isPaused ? restTimer.pausedRemainingSeconds : nil,
            timerStartedSeconds: restTimer.isActive ? restTimer.startedSeconds : nil,
            hasExercises: !workout.exercises.isEmpty
        )
    }
}
