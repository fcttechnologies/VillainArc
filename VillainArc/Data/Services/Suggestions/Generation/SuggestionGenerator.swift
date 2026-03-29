import Foundation
import SwiftData

struct SuggestionGenerator {
    static func generateSuggestions(for session: WorkoutSession, context: ModelContext) async -> [SuggestionEvent] {
        guard let plan = session.workoutPlan else { return [] }

        // Step 1: Gather data for AI inference (Main Actor)
        // We do this first to avoid accessing SwiftData objects on background threads.
        var aiRequests: [UUID: AIRequest] = [:]
        var historyByCatalogID: [String: [ExercisePerformance]] = [:]
        for exercisePerf in session.sortedExercises {
            guard exercisePerf.prescription != nil else { continue }
            let completeSets = exercisePerf.sortedSets.filter { $0.complete }
            let resolvedTrainingStyle = MetricsCalculator.detectTrainingStyle(completeSets)
            historyByCatalogID[exercisePerf.catalogID] = historyByCatalogID[exercisePerf.catalogID] ?? fetchCompletedPerformances(catalogID: exercisePerf.catalogID, context: context)

            // Trigger AI if we don't know the training style
            if resolvedTrainingStyle == .unknown { aiRequests[exercisePerf.id] = AIRequest(snapshot: AIExercisePerformanceSnapshot(performance: exercisePerf)) }
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
            for await (id, output) in group { if let output { results[id] = output } }
            return results
        }

        // Step 3: Evaluate Rules (Main Actor)
        var allSuggestions: [SuggestionEventDraft] = []
        var resolvedTrainingStyleByPrescriptionID: [UUID: TrainingStyle] = [:]

        let weightUnit = (try? context.fetch(AppSettings.single))?.first?.weightUnit ?? .lbs
        let catalogIDs = Array(Set(session.sortedExercises.map(\.catalogID)))
        let exercises = (try? context.fetch(Exercise.withCatalogIDs(catalogIDs))) ?? []
        let preferredWeightChangeByCatalogID = Dictionary(exercises.map { ($0.catalogID, $0.preferredWeightChange) },
            uniquingKeysWith: { first, second in
                if let second, second > 0 { return second }
                return first
            })

        for exercisePerf in session.sortedExercises {
            guard let prescription = exercisePerf.prescription else { continue }
            let performanceHistory = historyByCatalogID[exercisePerf.catalogID] ?? []
            let completeSets = exercisePerf.sortedSets.filter { $0.complete }

            var resolvedTrainingStyle = MetricsCalculator.detectTrainingStyle(completeSets)
            let aiResult = aiResults[exercisePerf.id]
            if resolvedTrainingStyle == .unknown, shouldUseAITrainingStyle(aiResult), let aiStyle = aiResult?.trainingStyleClassification { resolvedTrainingStyle = aiStyle }

            resolvedTrainingStyleByPrescriptionID[prescription.id] = resolvedTrainingStyle

            let suggestionContext = ExerciseSuggestionContext(
                session: session, performance: exercisePerf, prescription: prescription, history: performanceHistory, plan: plan, resolvedTrainingStyle: resolvedTrainingStyle, weightUnit: weightUnit, preferredWeightChange: preferredWeightChangeByCatalogID[exercisePerf.catalogID] ?? nil)

            let candidateSuggestions = RuleEngine.evaluate(context: suggestionContext)
            allSuggestions.append(contentsOf: candidateSuggestions)
        }

        let unresolvedFiltered = filterDraftsBlockedByUnresolvedEvents(allSuggestions, plan: plan)
        let deduplicated = SuggestionDeduplicator.process(suggestions: unresolvedFiltered)
        return buildSuggestionEvents(from: deduplicated, session: session, resolvedTrainingStyleByPrescriptionID: resolvedTrainingStyleByPrescriptionID, preferredWeightChangeByCatalogID: preferredWeightChangeByCatalogID)
    }
    private struct AIRequest: Sendable { let snapshot: AIExercisePerformanceSnapshot }

    static func shouldUseAITrainingStyle(_ output: AIInferenceOutput?) -> Bool {
        guard let output, output.trainingStyleClassification != nil else { return false }
        return output.confidence > 0.5
    }

    private static func requiredEvaluationCount(for changes: [PrescriptionChangeDraft], category: SuggestionCategory, equipmentType: EquipmentType) -> Int {
        // Category-level overrides take precedence.
        switch category {
        case .warmupCalibration, .structure, .volume: return 1
        default: break
        }
        // Key by the strictest change type in the group.
        return changes.map { requiredCount(for: $0.changeType, equipmentType: equipmentType) }.max() ?? 1
    }

    private static func requiredCount(for changeType: ChangeType, equipmentType: EquipmentType) -> Int {
        switch changeType {
        case .increaseWeight: return equipmentType.usesAssistanceWeightSemantics ? 1 : 2
        case .decreaseWeight: return equipmentType.usesAssistanceWeightSemantics ? 2 : 1
        case .increaseReps, .increaseRest: return 2
        case .increaseRepRangeLower, .decreaseRepRangeLower, .increaseRepRangeUpper, .decreaseRepRangeUpper, .increaseRepRangeTarget, .decreaseRepRangeTarget, .changeRepRangeMode: return 2
        default: return 1
        }
    }

    private static func fetchCompletedPerformances(catalogID: String, limit: Int? = nil, context: ModelContext) -> [ExercisePerformance] {
        // Pull the most recent completed sessions for this exercise.
        var descriptor = ExercisePerformance.matching(catalogID: catalogID, includingHidden: true)
        if let limit { descriptor.fetchLimit = limit }
        return (try? context.fetch(descriptor)) ?? []
    }

    private static func filterDraftsBlockedByUnresolvedEvents(_ drafts: [SuggestionEventDraft], plan: WorkoutPlan) -> [SuggestionEventDraft] {
        let existingEvents = collectPlanSuggestionEvents(plan)

        return drafts.filter { draft in
            !existingEvents.contains { event in
                guard event.outcome == .pending else { return false }
                guard event.targetExercisePrescription?.id == draft.targetExercisePrescription.id else { return false }
                if let draftSetID = draft.targetSetPrescription?.id {
                    guard event.targetSetPrescription?.id == draftSetID else { return false }
                } else {
                    guard event.targetSetPrescription == nil else { return false }
                }
                return !SuggestionDeduplicator.isCompatible(event.category, draft.category, isSetScoped: draft.idScope.setID != nil)
            }
        }
    }

    private static func collectPlanSuggestionEvents(_ plan: WorkoutPlan) -> [SuggestionEvent] {
        var seenEventIDs = Set<UUID>()
        let exerciseEvents = plan.sortedExercises.flatMap { Array($0.suggestionEvents ?? []) }
        let setEvents = plan.sortedExercises.flatMap { $0.sortedSets.flatMap { Array($0.suggestionEvents ?? []) } }

        return (exerciseEvents + setEvents).filter { event in seenEventIDs.insert(event.id).inserted }
    }

    private static func buildSuggestionEvents(from drafts: [SuggestionEventDraft], session: WorkoutSession, resolvedTrainingStyleByPrescriptionID: [UUID: TrainingStyle], preferredWeightChangeByCatalogID: [String: Double?]) -> [SuggestionEvent] {
        let performanceByPrescriptionID = Dictionary(uniqueKeysWithValues: session.sortedExercises.compactMap { performance in performance.prescription.map { ($0.id, performance) } })

        return
            drafts.compactMap { draft in
                let exercisePrescription = draft.targetExercisePrescription
                guard let exercisePerformance = performanceByPrescriptionID[exercisePrescription.id] else { return nil }

                let changes = draft.changes.map { change in PrescriptionChange(changeType: change.changeType, previousValue: change.previousValue, newValue: change.newValue) }

                let requiredCount = requiredEvaluationCount(for: draft.changes, category: draft.category, equipmentType: exercisePrescription.equipmentType)
                let event = SuggestionEvent(
                    source: draft.source, category: draft.category, catalogID: exercisePrescription.catalogID, sessionFrom: session, targetExercisePrescription: draft.targetExercisePrescription, targetSetPrescription: draft.targetSetPrescription, triggerTargetSetID: draft.triggerTargetSetID,
                    triggerPerformance: exercisePerformance, ruleID: draft.rule, trainingStyle: resolvedTrainingStyleByPrescriptionID[exercisePrescription.id] ?? .unknown, requiredEvaluationCount: requiredCount,
                    weightStepUsed: weightStepUsed(for: draft, exercisePrescription: exercisePrescription, preferredWeightChange: preferredWeightChangeByCatalogID[exercisePrescription.catalogID] ?? nil), changeReasoning: draft.changeReasoning, changes: changes, suggestionConfidence: suggestionConfidence(for: draft))
                return event
            }
            .sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
                return lhs.catalogID < rhs.catalogID
            }
    }

    static func suggestionConfidence(for draft: SuggestionEventDraft) -> Double {
        switch draft.evidenceStrength {
        case .heuristic: return SuggestionConfidenceTier.exploratory.defaultScore
        case .pattern: return SuggestionConfidenceTier.moderate.defaultScore
        case .directTargetEvidence: return SuggestionConfidenceTier.strong.defaultScore
        }
    }

    private static func weightStepUsed(for draft: SuggestionEventDraft, exercisePrescription: ExercisePrescription, preferredWeightChange: Double?) -> Double? {
        guard draft.changes.contains(where: { $0.changeType == .increaseWeight || $0.changeType == .decreaseWeight }) else { return nil }

        if usesPreferredWeightChange(for: draft.rule), let preferredWeightChange, preferredWeightChange > 0 { return preferredWeightChange }

        guard let weightChange = draft.changes.first(where: { $0.changeType == .increaseWeight || $0.changeType == .decreaseWeight }) else { return nil }

        let referenceWeight = weightChange.newValue > 0 ? weightChange.newValue : weightChange.previousValue
        let primaryMuscle = exercisePrescription.musclesTargeted.first ?? .chest
        return MetricsCalculator.weightIncrement(for: referenceWeight, primaryMuscle: primaryMuscle, equipmentType: exercisePrescription.equipmentType, catalogID: exercisePrescription.catalogID)
    }

    private static func usesPreferredWeightChange(for rule: SuggestionRule?) -> Bool {
        switch rule {
        case .immediateProgressionRange, .immediateProgressionTarget, .confirmedProgressionRange, .confirmedProgressionTarget, .largeOvershootProgression, .belowRangeWeightDecrease: return true
        default: return false
        }
    }
}
