import Foundation
import SwiftData

@MainActor
struct SuggestionGenerator {
    // Orchestrates the full suggestion pipeline for a workout session.
    static func existingSuggestions(for session: WorkoutSession, context: ModelContext) -> [PrescriptionChange] {
        let sessionID = session.id
        let predicate = #Predicate<PrescriptionChange> { change in
            change.sessionFrom?.id == sessionID
        }
        let descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\PrescriptionChange.createdAt, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    static func generateSuggestions(for session: WorkoutSession, context: ModelContext) async -> [PrescriptionChange] {
        // For each exercise, gather history + cached context, run rules, then dedupe.
        guard let plan = session.workoutPlan else {
            return []
        }

        var allSuggestions: [PrescriptionChange] = []

        for exercisePerf in session.sortedExercises {
            guard let prescription = exercisePerf.prescription else {
                continue
            }

            let history = fetchHistory(catalogID: exercisePerf.catalogID, limit: 3, context: context)
            let historySummary = ExerciseHistoryUpdater.fetchOrCreateHistory(for: exercisePerf.catalogID, context: context)

            // Bundle the data needed by rules.
            let suggestionContext = ExerciseSuggestionContext(
                session: session,
                performance: exercisePerf,
                prescription: prescription,
                history: history,
                historySummary: historySummary,
                plan: plan
            )

            let candidateSuggestions = RuleEngine.evaluate(context: suggestionContext)
            allSuggestions.append(contentsOf: candidateSuggestions)
        }

//        let aiSuggestions = await AISuggestionGenerator.generateSuggestions(for: session)
//        allSuggestions.append(contentsOf: aiSuggestions)

        return SuggestionDeduplicator.process(suggestions: allSuggestions, context: context)
    }

    private static func fetchHistory(catalogID: String, limit: Int, context: ModelContext) -> [ExercisePerformance] {
        // Pull the most recent completed sessions for this exercise.
        var descriptor = ExercisePerformance.matching(catalogID: catalogID)
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }
}
