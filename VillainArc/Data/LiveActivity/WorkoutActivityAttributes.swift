import ActivityKit
import Foundation

struct WorkoutActivityAttributes: ActivityAttributes {
    var startDate: Date

    struct ContentState: Codable, Hashable {
        var title: String
        var exerciseName: String?
        var setNumber: Int?
        var totalSets: Int?
        var weight: Double?
        var weightUnit: String?
        var reps: Int?
        var targetRPE: Int?
        var timerEndDate: Date?
        var timerPausedRemaining: Int?
        var timerStartedSeconds: Int?
        var hasExercises: Bool

        var isTimerRunning: Bool {
            guard let end = timerEndDate else { return false }
            return end > Date()
        }

        var isTimerPaused: Bool {
            guard let remaining = timerPausedRemaining else { return false }
            return remaining > 0
        }

        var isTimerActive: Bool {
            isTimerRunning || isTimerPaused
        }

        var hasActiveSet: Bool {
            exerciseName != nil
        }
    }
}
