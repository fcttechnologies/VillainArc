import Foundation
import SwiftData
import FoundationModels

struct RecentExercisePerformancesTool: Tool, Sendable {
    let name = "getRecentExercisePerformances"
    let description = """
        Get detailed performance history for the last N workout sessions (max 5).
        Each performance includes date and all sets with weights, reps, rest, and set type.
        
        Use this when you need more context to classify the user's training style or rep range:
        - Look at weight patterns across sets to determine training style
        - Look at rep counts across sessions to determine a consistent rep range
        - Compare multiple sessions for pattern consistency
        
        Best practices:
        - Start with limit=2-3 for efficiency
        - Use limit=5 only when the current session data is ambiguous
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
