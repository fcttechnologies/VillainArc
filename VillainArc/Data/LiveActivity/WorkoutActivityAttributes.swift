import Foundation
import ActivityKit

nonisolated struct WorkoutActivityAttributes: ActivityAttributes, Sendable {
    var startDate: Date

    struct ContentState: Codable, Hashable, Sendable {
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
        var liveHeartRateBPM: Double?
        var liveActiveEnergyBurned: Double?

        var isTimerRunning: Bool {
            guard let end = timerEndDate else { return false }
            return end > Date()
        }

        var isTimerPaused: Bool {
            guard let remaining = timerPausedRemaining else { return false }
            return remaining > 0
        }

        var isTimerActive: Bool { isTimerRunning || isTimerPaused }

        var hasActiveSet: Bool { exerciseName != nil }

        var hasLiveMetrics: Bool { liveHeartRateBPM != nil || liveActiveEnergyBurned != nil }
    }
}
