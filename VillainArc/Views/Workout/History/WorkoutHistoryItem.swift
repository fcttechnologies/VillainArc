import Foundation

struct WorkoutHistoryItem: Identifiable, Hashable {
    enum Source: Hashable {
        case session(WorkoutSession)
        case health(HealthWorkout)
        case cardio(CardioSession)
    }

    let source: Source

    var id: String {
        switch source {
        case .session(let workout):
            return "session-\(workout.id.uuidString)"
        case .health(let workout):
            return "health-\(workout.healthWorkoutUUID.uuidString)"
        case .cardio(let session):
            return "cardio-\(session.id.uuidString)"
        }
    }

    var sortDate: Date {
        switch source {
        case .session(let workout):
            return workout.startedAt
        case .health(let workout):
            return workout.startDate
        case .cardio(let session):
            return session.startedAt ?? .distantPast
        }
    }

    var session: WorkoutSession? {
        switch source {
        case .session(let workout):
            return workout
        case .health, .cardio:
            return nil
        }
    }

    var healthWorkout: HealthWorkout? {
        switch source {
        case .health(let workout):
            return workout
        case .session, .cardio:
            return nil
        }
    }

    var cardioSession: CardioSession? {
        switch source {
        case .cardio(let session):
            return session
        case .session, .health:
            return nil
        }
    }
}
