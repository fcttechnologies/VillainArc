import Foundation
import ActivityKit

nonisolated struct WorkoutActivityAttributes: ActivityAttributes, Sendable {
    var startDate: Date

    enum DisplayMode: String, Codable, Hashable, Sendable {
        case active
        case summary
    }

    struct ContentState: Codable, Hashable, Sendable {
        var displayMode: DisplayMode
        var title: String
        var endedAt: Date?
        var exerciseName: String?
        var transientStatusText: String?
        var setNumber: Int?
        var totalSets: Int?
        var completedExerciseCount: Int?
        var completedSetCount: Int?
        var summaryPRCount: Int?
        var summaryVolume: Double?
        var weight: Double?
        var weightUnit: String?
        var energyUnit: String?
        var reps: Int?
        var targetRPE: Int?
        var timerEndDate: Date?
        var timerPausedRemaining: Int?
        var timerStartedSeconds: Int?
        var hasExercises: Bool
        var liveHeartRateBPM: Double?
        var liveActiveEnergyBurned: Double?
        var averageHeartRateBPM: Double?
        var totalEnergyBurned: Double?

        var isTimerRunning: Bool {
            guard let end = timerEndDate else { return false }
            return end > Date()
        }

        var isTimerPaused: Bool {
            guard let remaining = timerPausedRemaining else { return false }
            return remaining > 0
        }

        var isTimerActive: Bool { isTimerRunning || isTimerPaused }

        var isSummaryMode: Bool { displayMode == .summary }

        var hasActiveSet: Bool { exerciseName != nil }

        var hasLiveMetrics: Bool { liveHeartRateBPM != nil || liveActiveEnergyBurned != nil }

        var hasSummaryPRs: Bool {
            guard let summaryPRCount else { return false }
            return summaryPRCount > 0
        }
    }
}
