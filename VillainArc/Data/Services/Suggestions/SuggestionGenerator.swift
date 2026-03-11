import Foundation
import SwiftData

@MainActor
struct SuggestionGenerator {
    static func generateSuggestions(for session: WorkoutSession, context: ModelContext) async -> [PrescriptionChange] {
        guard let plan = session.workoutPlan else { return [] }

        // Step 1: Gather data for AI inference (Main Actor)
        // We do this first to avoid accessing SwiftData objects on background threads.
        var aiRequests: [UUID: AIRequest] = [:]
        var historyByCatalogID: [String: [ExercisePerformance]] = [:]
        
        for exercisePerf in session.sortedExercises {
            guard let _ = exercisePerf.prescription else { continue }
            
            let completeSets = exercisePerf.sortedSets.filter { $0.complete }
            let resolvedTrainingStyle = MetricsCalculator.detectTrainingStyle(completeSets)
            historyByCatalogID[exercisePerf.catalogID] = historyByCatalogID[exercisePerf.catalogID] ?? fetchCompletedPerformances(catalogID: exercisePerf.catalogID, context: context)

            // Trigger AI if we don't know the training style
            if resolvedTrainingStyle == .unknown {
                aiRequests[exercisePerf.id] = AIRequest(snapshot: AIExercisePerformanceSnapshot(performance: exercisePerf))
            }
        }
        
        // Step 2: Execute AI inference in parallel (Background Threads)
        let aiResults = await withTaskGroup(of: (UUID, AIInferenceOutput?).self) { group in
            for (id, request) in aiRequests {
                group.addTask {
                    let result = await AITrainingStyleClassifier.infer(performance: request.snapshot)
                    return (id, result)
                }
            }
            
            var results: [UUID: AIInferenceOutput] = [:]
            for await (id, output) in group {
                if let output {
                    results[id] = output
                }
            }
            return results
        }

        // Step 3: Evaluate Rules (Main Actor)
        var allSuggestions: [PrescriptionChange] = []

        for exercisePerf in session.sortedExercises {
            guard let prescription = exercisePerf.prescription else { continue }
            
            let performanceHistory = historyByCatalogID[exercisePerf.catalogID] ?? []
            let completeSets = exercisePerf.sortedSets.filter { $0.complete }

            var resolvedTrainingStyle = MetricsCalculator.detectTrainingStyle(completeSets)
            let aiResult = aiResults[exercisePerf.id]
            
            if resolvedTrainingStyle == .unknown,
               let aiStyle = aiResult?.trainingStyleClassification {
                resolvedTrainingStyle = aiStyle
            }

            let suggestionContext = ExerciseSuggestionContext(session: session, performance: exercisePerf, prescription: prescription, history: performanceHistory, plan: plan, resolvedTrainingStyle: resolvedTrainingStyle)

            let candidateSuggestions = RuleEngine.evaluate(context: suggestionContext)
            allSuggestions.append(contentsOf: candidateSuggestions)
        }

        return SuggestionDeduplicator.process(suggestions: allSuggestions)
    }
    
    private struct AIRequest: Sendable {
        let snapshot: AIExercisePerformanceSnapshot
    }

    private static func fetchCompletedPerformances(catalogID: String, limit: Int? = nil, context: ModelContext) -> [ExercisePerformance] {
        // Pull the most recent completed sessions for this exercise.
        var descriptor = ExercisePerformance.matching(catalogID: catalogID)
        if let limit {
            descriptor.fetchLimit = limit
        }
        return (try? context.fetch(descriptor)) ?? []
    }
}
