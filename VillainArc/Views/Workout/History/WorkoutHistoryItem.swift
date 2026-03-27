import Foundation

struct WorkoutHistoryItem: Identifiable, Hashable {
    enum Source: Hashable {
        case session(WorkoutSession)
        case health(HealthWorkout)
    }

    let source: Source

    var id: String {
        switch source {
        case .session(let workout):
            return "session-\(workout.id.uuidString)"
        case .health(let workout):
            return "health-\(workout.healthWorkoutUUID.uuidString)"
        }
    }

    var sortDate: Date {
        switch source {
        case .session(let workout):
            return workout.startedAt
        case .health(let workout):
            return workout.startDate
        }
    }

    var session: WorkoutSession? {
        switch source {
        case .session(let workout):
            return workout
        case .health:
            return nil
        }
    }

    var healthWorkout: HealthWorkout? {
        switch source {
        case .session:
            return nil
        case .health(let workout):
            return workout
        }
    }
}
