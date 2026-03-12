import Foundation

enum ExerciseProgressionContextBuilder {
    static let minimumSessionCount = 3
    static let maximumRecentPerformances = 5

    static func canGenerateInsights(history: ExerciseHistory?) -> Bool {
        guard let history else { return false }
        return history.totalSessions >= minimumSessionCount
    }

    @MainActor
    static func build(
        exercise: Exercise,
        history: ExerciseHistory,
        performances: [ExercisePerformance],
        starterQuestion: String? = nil
    ) -> AIExerciseProgressionContext? {
        guard canGenerateInsights(history: history) else { return nil }

        let recentPerformances = Array(
            performances
                .sorted { left, right in
                    if left.date != right.date {
                        return left.date > right.date
                    }
                    return left.id.uuidString < right.id.uuidString
                }
                .prefix(maximumRecentPerformances)
        )

        guard !recentPerformances.isEmpty else { return nil }

        return AIExerciseProgressionContext(
            exercise: AIExerciseIdentitySnapshot(exercise: exercise),
            historySummary: AIExerciseHistorySummarySnapshot(history: history),
            recentPerformances: recentPerformances.map(AIExercisePerformanceSnapshot.init(performance:)),
            starterQuestion: starterQuestion
        )
    }
}
