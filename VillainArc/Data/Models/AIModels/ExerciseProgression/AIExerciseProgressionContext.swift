import Foundation
import FoundationModels

@Generable
struct AIExerciseProgressionContext {
    @Guide(description: "Exercise identity and metadata.")
    let exercise: AIExerciseIdentitySnapshot
    @Guide(description: "Compact long-range history summary for this exercise.")
    let historySummary: AIExerciseHistorySummarySnapshot
    @Guide(description: "Most recent completed performances, sorted recent-first.")
    let recentPerformances: [AIExercisePerformanceSnapshot]
    @Guide(description: "Optional starter question to focus the initial analysis.")
    let starterQuestion: String?
}

@Generable
struct AIExerciseHistorySummarySnapshot {
    @Guide(description: "How many completed sessions exist for this exercise.")
    let totalSessions: Int
    @Guide(description: "Best estimated 1RM from the most recent completed session, or 0 if unavailable.")
    let latestEstimated1RM: Double
    @Guide(description: "Best estimated 1RM across all completed sessions, or 0 if unavailable.")
    let bestEstimated1RM: Double
    @Guide(description: "Heaviest successful weight used across all completed sessions, or 0 if unavailable.")
    let bestWeight: Double
    @Guide(description: "Highest reps completed in any one set across all completed sessions, or 0 if unavailable.")
    let bestReps: Int

    init(history: ExerciseHistory) {
        totalSessions = history.totalSessions
        latestEstimated1RM = history.latestEstimated1RM
        bestEstimated1RM = history.bestEstimated1RM
        bestWeight = history.bestWeight
        bestReps = history.bestReps
    }
}
