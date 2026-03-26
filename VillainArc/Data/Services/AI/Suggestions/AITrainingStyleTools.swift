import Foundation
import FoundationModels
import SwiftData

struct RecentExercisePerformancesTool: Tool, Sendable {
    let name = "getRecentExercisePerformances"
    let description = "Fetch up to 3 recent exercise performances, newest first. Use only when the current workout is ambiguous."

    @Generable struct Arguments {
        @Guide(description: "Exercise catalog id.")
        let catalogID: String
        @Guide(description: "How many sessions.", .range(1...3))
        let limit: Int
    }

    func call(arguments: Arguments) async throws -> [AIExercisePerformanceSnapshot] {
        let context = await ModelContext(SharedModelContainer.container)
        var descriptor = ExercisePerformance.matching(catalogID: arguments.catalogID, includingHidden: true)
        descriptor.fetchLimit = max(1, min(arguments.limit, 3))
        let performances = (try? context.fetch(descriptor)) ?? []
        return performances.map { AIExercisePerformanceSnapshot(performance: $0) }
    }
}
