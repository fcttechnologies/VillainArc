import Foundation
import SwiftData

@MainActor
struct SuggestionGenerator {
    static func generateSuggestions(for session: WorkoutSession, context: ModelContext) async -> [SuggestionEvent] {
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
        var allSuggestions: [SuggestionEventDraft] = []
        var resolvedTrainingStyleByPrescriptionID: [UUID: TrainingStyle] = [:]

        let weightUnit = (try? context.fetch(AppSettings.single))?.first?.weightUnit ?? .lbs

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

            resolvedTrainingStyleByPrescriptionID[prescription.id] = resolvedTrainingStyle

            let suggestionContext = ExerciseSuggestionContext(session: session, performance: exercisePerf, prescription: prescription, history: performanceHistory, plan: plan, resolvedTrainingStyle: resolvedTrainingStyle, weightUnit: weightUnit)

            let candidateSuggestions = RuleEngine.evaluate(context: suggestionContext)
            allSuggestions.append(contentsOf: candidateSuggestions)
        }

        let unresolvedFiltered = filterDraftsBlockedByUnresolvedEvents(allSuggestions, plan: plan)
        let deduplicated = SuggestionDeduplicator.process(suggestions: unresolvedFiltered)
        return buildSuggestionEvents(from: deduplicated, session: session, resolvedTrainingStyleByPrescriptionID: resolvedTrainingStyleByPrescriptionID)
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

    private static func filterDraftsBlockedByUnresolvedEvents(_ drafts: [SuggestionEventDraft], plan: WorkoutPlan) -> [SuggestionEventDraft] {
        let existingEvents = collectPlanSuggestionEvents(plan)

        return drafts.filter { draft in
            !existingEvents.contains { event in
                guard event.outcome == .pending else { return false }
                guard event.targetExercisePrescription?.id == draft.targetExercisePrescription.id else { return false }
                guard event.resolvedTargetSetIndex == draft.idScope.setIndex else { return false }
                return !SuggestionDeduplicator.isCompatible(event.category, draft.category, isSetScoped: draft.idScope.setIndex != nil)
            }
        }
    }

    private static func collectPlanSuggestionEvents(_ plan: WorkoutPlan) -> [SuggestionEvent] {
        var seenEventIDs = Set<UUID>()
        let exerciseEvents = plan.sortedExercises.flatMap { Array($0.suggestionEvents ?? []) }
        let setEvents = plan.sortedExercises.flatMap { $0.sortedSets.flatMap { Array($0.suggestionEvents ?? []) } }

        return (exerciseEvents + setEvents).filter { event in
            seenEventIDs.insert(event.id).inserted
        }
    }

    private static func buildSuggestionEvents(from drafts: [SuggestionEventDraft], session: WorkoutSession, resolvedTrainingStyleByPrescriptionID: [UUID: TrainingStyle]) -> [SuggestionEvent] {
        let performanceByPrescriptionID = Dictionary(uniqueKeysWithValues: session.sortedExercises.compactMap { performance in
            performance.prescription.map { ($0.id, performance) }
        })

        return drafts.compactMap { draft in
            let exercisePrescription = draft.targetExercisePrescription
            guard let exercisePerformance = performanceByPrescriptionID[exercisePrescription.id] else { return nil }

            let triggerTargetSnapshot = exercisePerformance.originalTargetSnapshot ?? ExerciseTargetSnapshot(prescription: exercisePrescription)
            let triggerPerformanceSnapshot = ExercisePerformanceSnapshot(performance: exercisePerformance)
            let changes = draft.changes.map { change in
                PrescriptionChange(
                    changeType: change.changeType,
                    previousValue: change.previousValue,
                    newValue: change.newValue
                )
            }

            let event = SuggestionEvent(source: draft.source, category: draft.category, catalogID: exercisePrescription.catalogID, sessionFrom: session, targetExercisePrescription: draft.targetExercisePrescription, targetSetPrescription: draft.targetSetPrescription, targetSetIndex: draft.targetSetIndex, triggerPerformanceSnapshot: triggerPerformanceSnapshot, triggerTargetSnapshot: triggerTargetSnapshot, trainingStyle: resolvedTrainingStyleByPrescriptionID[exercisePrescription.id] ?? .unknown, changeReasoning: draft.changeReasoning, changes: changes)
            return event
        }
        .sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.catalogID < rhs.catalogID
        }
    }
}
