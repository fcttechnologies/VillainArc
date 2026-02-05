import Foundation
import SwiftData
import FoundationModels

struct ExerciseHistoryContextTool: Tool, Sendable {
    let name = "getExerciseHistoryContext"
    let description = """
        Get comprehensive cached statistics for an exercise across ALL completed workout sessions.
        
        Use this when you need:
        - Historical context (PRs, progression trends, typical patterns)
        - To understand if performance is improving, stable, or declining over time
        - Baseline stats to compare current session against (e.g., "Is today's weight near their PR?")
        - Volume and frequency patterns (how often they train this exercise)
        
        This is very token-efficient since it returns pre-aggregated summary stats.
        Call this first before considering getRecentExercisePerformances for detailed analysis.
        
        Returns: Cached summary with PRs, averages, trends, and typical values across all history.
        """

    @Generable
    struct Arguments: Equatable, Sendable {
        let catalogID: String
    }

    func call(arguments: Arguments) async throws -> AIExerciseHistoryContext {
        let context = await ModelContext(SharedModelContainer.container)
        let descriptor = ExerciseHistory.forCatalogID(arguments.catalogID)
        let history = try? context.fetch(descriptor).first
        return AIExerciseHistoryContext.from(history: history)
    }
}

struct RecentExercisePerformancesTool: Tool, Sendable {
    let name = "getRecentExercisePerformances"
    let description = """
        Get detailed performance history for the last N workout sessions (max 5).
        Each performance includes date, all sets with weights/reps/rest, and rep range settings.
        
        Use this when you need:
        - Detailed set-by-set progression data (not just summary stats)
        - To analyze recent workout patterns and identify plateaus or regression
        - To compare weights, reps, and volume across last few sessions
        - To understand performance variability (consistency vs fluctuation)
        - To check recency of training (gaps between sessions)
        
        Best practices:
        - Start with limit=2-3 for token efficiency (most cases need 2-3 sessions for context)
        - Use limit=5 only when deeper historical analysis is needed
        - Performances are sorted most recent first (index 0 = most recent)
        
        Returns: Array of detailed performance snapshots with dates and all completed sets.
        """

    @Generable
    struct Arguments: Equatable, Sendable {
        let catalogID: String
        let limit: Int
    }

    func call(arguments: Arguments) async throws -> [AIExercisePerformanceSnapshot] {
        let context = await ModelContext(SharedModelContainer.container)
        var descriptor = ExercisePerformance.matching(catalogID: arguments.catalogID)
        descriptor.fetchLimit = max(1, min(arguments.limit, 5))
        let performances = (try? context.fetch(descriptor)) ?? []
        return performances.map { AIExercisePerformanceSnapshot(performance: $0) }
    }
}
