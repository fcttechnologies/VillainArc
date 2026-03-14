import SwiftData
import Foundation
import Testing
@testable import VillainArc

struct SuggestionSystemTests {
    @MainActor
    private func flattenedChanges(from drafts: [SuggestionEventDraft]) -> [(draft: SuggestionEventDraft, change: PrescriptionChangeDraft)] {
        drafts.flatMap { draft in
            draft.changes.map { (draft: draft, change: $0) }
        }
    }
    
    @MainActor
    private func exerciseLevelChanges(from drafts: [SuggestionEventDraft]) -> [PrescriptionChangeDraft] {
        drafts.filter { $0.targetSetIndex == nil }.flatMap(\.changes)
    }
    
    // MARK: - Training Style Detection Tests
    
    @Test @MainActor
    func detectTrainingStyle_straightSets() {
        let sets = [100.0, 100.0, 100.0, 100.0].enumerated().map { (i, w) in
            TestDataFactory.makeSetPerformance(index: i, weight: w, reps: 8)
        }
        let style = MetricsCalculator.detectTrainingStyle(sets)
        #expect(style == .straightSets)
    }
    
    @Test @MainActor
    func detectTrainingStyle_straightSetsWithSmallVariance() {
        // Within 10% of average should still be straight sets
        let sets = [100.0, 105.0, 100.0, 95.0].enumerated().map { (i, w) in
            TestDataFactory.makeSetPerformance(index: i, weight: w, reps: 8)
        }
        let style = MetricsCalculator.detectTrainingStyle(sets)
        #expect(style == .straightSets)
    }
    
    @Test @MainActor
    func detectTrainingStyle_topSetBackoffs() {
        // 2 heavy sets + 2 clearly lighter sets
        let sets = [200.0, 200.0, 150.0, 150.0].enumerated().map { (i, w) in
            TestDataFactory.makeSetPerformance(index: i, weight: w, reps: 8)
        }
        let style = MetricsCalculator.detectTrainingStyle(sets)
        #expect(style == .topSetBackoffs)
    }
    
    @Test @MainActor
    func detectTrainingStyle_ascending() {
        // Spread > 10% of avg (not straight), all weights >= max*0.8 (not topSetBackoffs), monotonically increasing
        let sets = [165.0, 175.0, 185.0, 200.0].enumerated().map { (i, w) in
            TestDataFactory.makeSetPerformance(index: i, weight: w, reps: 8)
        }
        let style = MetricsCalculator.detectTrainingStyle(sets)
        #expect(style == .ascending)
    }
    
    @Test @MainActor
    func detectTrainingStyle_descendingPyramid() {
        // Spread > 10% of avg (not straight), all weights >= max*0.8 (not topSetBackoffs), monotonically decreasing
        let sets = [200.0, 185.0, 175.0, 165.0].enumerated().map { (i, w) in
            TestDataFactory.makeSetPerformance(index: i, weight: w, reps: 8)
        }
        let style = MetricsCalculator.detectTrainingStyle(sets)
        #expect(style == .descendingPyramid)
    }
    
    @Test @MainActor
    func detectTrainingStyle_ascendingPyramid() {
        // Peak in middle, spread > 10% of avg (not straight), all weights >= max*0.8 (not topSetBackoffs)
        // avg=182, threshold=18.2 → need diff > 18.2 for at least one weight
        let sets = [165.0, 185.0, 200.0, 185.0, 165.0].enumerated().map { (i, w) in
            TestDataFactory.makeSetPerformance(index: i, weight: w, reps: 8)
        }
        let style = MetricsCalculator.detectTrainingStyle(sets)
        #expect(style == .ascendingPyramid)
    }
    
    @Test @MainActor
    func detectTrainingStyle_unknownForTwoSets() {
        let sets = [100.0, 150.0].enumerated().map { (i, w) in
            TestDataFactory.makeSetPerformance(index: i, weight: w, reps: 8)
        }
        let style = MetricsCalculator.detectTrainingStyle(sets)
        #expect(style == .unknown)
    }
    
    @Test @MainActor
    func detectTrainingStyle_unknownForEmptySets() {
        let style = MetricsCalculator.detectTrainingStyle([])
        #expect(style == .unknown)
    }
    
    // MARK: - Style Increment Multiplier (via doubleProgressionTarget)
    
    @Test @MainActor
    func styleIncrementMultiplier_topSetBackoffsGetsLargerIncrement() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 3, targetWeight: 200, targetReps: 8, repRangeMode: .target)
        prescription.repRange?.targetReps = 8
        prescription.musclesTargeted = [.chest]
        prescription.equipmentType = .barbell
        
        // Build 2 sessions where user exceeded target by 1+ rep
        let session1 = TestDataFactory.makeSession(context: context, daysAgo: 3)
        let perf1 = TestDataFactory.makePerformance(context: context, session: session1, prescription: prescription, sets: [(weight: 200, reps: 10, rest: 90, type: .working), (weight: 200, reps: 10, rest: 90, type: .working), (weight: 150, reps: 12, rest: 90, type: .working)])
        
        let session2 = TestDataFactory.makeSession(context: context)
        let perf2 = TestDataFactory.makePerformance(context: context, session: session2, prescription: prescription, sets: [(weight: 200, reps: 10, rest: 90, type: .working), (weight: 200, reps: 10, rest: 90, type: .working), (weight: 150, reps: 12, rest: 90, type: .working)])
        
        // Evaluate with straight sets style
        let straightContext = ExerciseSuggestionContext(session: session2, performance: perf2, prescription: prescription, history: [perf1], plan: plan, resolvedTrainingStyle: .straightSets, weightUnit: .kg)
        let straightSuggestions = RuleEngine.evaluate(context: straightContext)
        let straightWeightChanges = flattenedChanges(from: straightSuggestions).filter { $0.change.changeType == .increaseWeight }
        
        // Evaluate with top set backoffs style
        let topSetContext = ExerciseSuggestionContext(session: session2, performance: perf2, prescription: prescription, history: [perf1], plan: plan, resolvedTrainingStyle: .topSetBackoffs, weightUnit: .kg)
        let topSetSuggestions = RuleEngine.evaluate(context: topSetContext)
        let topSetWeightChanges = flattenedChanges(from: topSetSuggestions).filter { $0.change.changeType == .increaseWeight }
        
        // Straight sets progresses every working set.
        #expect(straightWeightChanges.count == 3)
        
        // Top-set/backoff style should only progress the heavy cluster, not the lighter backoff set.
        #expect(topSetWeightChanges.count == 2)
        
        let straightValues = straightWeightChanges.map { $0.change.newValue }
        let topSetValues = topSetWeightChanges.map { $0.change.newValue }
        #expect(straightValues.allSatisfy { $0 == 202.5 })
        #expect(topSetValues.allSatisfy { $0 == 203.75 })
        
        let topSetIndices = Set(topSetWeightChanges.compactMap { $0.draft.targetSetIndex })
        #expect(topSetIndices == Set([0, 1]))
    }
    
    @Test @MainActor
    func generatedSuggestionsAttachSessionEventContext() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 3, targetWeight: 200, targetReps: 8, repRangeMode: .target)
        prescription.repRange?.targetReps = 8
        prescription.musclesTargeted = [.chest]
        prescription.equipmentType = .barbell
        
        let previousSession = TestDataFactory.makeSession(context: context, daysAgo: 3)
        previousSession.statusValue = .done
        _ = TestDataFactory.makePerformance(context: context, session: previousSession, prescription: prescription, sets: [(weight: 200, reps: 10, rest: 90, type: .working), (weight: 200, reps: 10, rest: 90, type: .working), (weight: 200, reps: 10, rest: 90, type: .working)])
        
        let workout = WorkoutSession(from: plan)
        context.insert(workout)
        workout.statusValue = .summary
        
        let currentPerformance = workout.sortedExercises.first
        #expect(currentPerformance != nil)
        guard let currentPerformance else { return }
        
        for set in currentPerformance.sortedSets {
            set.weight = 200
            set.reps = 10
            set.restSeconds = 90
            set.complete = true
        }
        
        let generated = await SuggestionGenerator.generateSuggestions(for: workout, context: context)
        
        #expect(generated.isEmpty == false)
        #expect(generated.allSatisfy { $0.sessionFrom?.id == workout.id })
        #expect(generated.allSatisfy { $0.catalogID == prescription.catalogID })
        #expect(generated.allSatisfy { ($0.changes ?? []).allSatisfy { $0.targetExercisePrescription?.workoutPlan?.id == plan.id } })
    }
    
    @Test @MainActor
    func generateSuggestions_returnsEmptyForFreeformWorkout() async throws {
        let context = try TestDataFactory.makeContext()
        let session = TestDataFactory.makeSession(context: context)
        
        let generated = await SuggestionGenerator.generateSuggestions(for: session, context: context)
        
        #expect(generated.isEmpty)
    }
    
    @Test @MainActor
    func generateSuggestions_deduplicatesOvershootToSingleStrongerEvent() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 1, targetWeight: 100, targetReps: 10, targetRest: 90, repRangeMode: .range, lowerRange: 8, upperRange: 10)
        prescription.musclesTargeted = [.chest]
        prescription.equipmentType = .barbell
        
        let workout = WorkoutSession(from: plan)
        context.insert(workout)
        workout.statusValue = .summary
        
        guard let performance = workout.sortedExercises.first,
              let set = performance.sortedSets.first else {
            Issue.record("Expected a plan-backed performance with one set.")
            return
        }
        
        set.weight = 100
        set.reps = 13
        set.restSeconds = 90
        set.complete = true
        
        let generated = await SuggestionGenerator.generateSuggestions(for: workout, context: context)
        
        #expect(generated.count == 1)
        guard let event = generated.first else { return }
        
        let weightChange = event.sortedChanges.first(where: { $0.changeType == .increaseWeight })
        let repChange = event.sortedChanges.first(where: { $0.changeType == .decreaseReps })
        
        #expect(event.sortedChanges.count == 2)
        #expect(weightChange?.previousValue == 100)
        #expect(weightChange?.newValue == 103.75)
        #expect(repChange?.previousValue == 10)
        #expect(repChange?.newValue == 8)
        #expect(event.sortedChanges.allSatisfy { $0.targetSetIndex == 0 })
        #expect(event.changeReasoning?.contains("significantly overshot the target") == true)
    }

    @Test @MainActor
    func generateSuggestions_triggerSnapshotPreservesLinkedTargetSetIndices() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 2, targetWeight: 100, targetReps: 8, targetRest: 90, repRangeMode: .target)
        prescription.repRange?.targetReps = 8

        let workout = WorkoutSession(from: plan)
        context.insert(workout)
        workout.statusValue = .summary

        guard let performance = workout.sortedExercises.first else {
            Issue.record("Expected current plan-backed performance.")
            return
        }

        for set in performance.sortedSets {
            set.weight = 100
            set.reps = 10
            set.restSeconds = 90
            set.complete = true
        }

        let generated = await SuggestionGenerator.generateSuggestions(for: workout, context: context)

        guard let event = generated.first else {
            Issue.record("Expected generated suggestion event.")
            return
        }

        let snapshotSets = event.triggerPerformanceSnapshot.sets.sorted { $0.index < $1.index }
        #expect(snapshotSets.count == 2)
        #expect(snapshotSets[0].linkedTargetSetIndex == 0)
        #expect(snapshotSets[1].linkedTargetSetIndex == 1)
    }
    
    @Test @MainActor
    func generateSuggestions_ignoresIncompleteHistoryForConfirmedProgression() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 1, targetWeight: 100, targetReps: 10, targetRest: 90, repRangeMode: .range, lowerRange: 8, upperRange: 10)
        prescription.musclesTargeted = [.chest]
        prescription.equipmentType = .barbell
        
        let incompleteHistorySession = TestDataFactory.makeSession(context: context, daysAgo: 3)
        incompleteHistorySession.statusValue = .active
        _ = TestDataFactory.makePerformance(context: context, session: incompleteHistorySession, prescription: prescription, sets: [(weight: 100, reps: 9, rest: 90, type: .working)])
        
        let workout = WorkoutSession(from: plan)
        context.insert(workout)
        workout.statusValue = .summary
        
        guard let performance = workout.sortedExercises.first,
              let set = performance.sortedSets.first else {
            Issue.record("Expected a current plan-backed performance.")
            return
        }
        
        set.weight = 100
        set.reps = 9
        set.restSeconds = 90
        set.complete = true
        
        let generated = await SuggestionGenerator.generateSuggestions(for: workout, context: context)
        
        #expect(generated.isEmpty)
    }
    
    @Test @MainActor
    func historicalSnapshotSupportsRepSuggestionAfterOldPlanLinksAreCleared() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 1, targetWeight: 100, targetReps: 8, targetRest: 90, repRangeMode: .range, lowerRange: 8, upperRange: 10)
        
        let previousSession = WorkoutSession(from: plan)
        context.insert(previousSession)
        previousSession.statusValue = .done
        
        guard let previousPerformance = previousSession.sortedExercises.first,
              let previousSet = previousPerformance.sortedSets.first else {
            Issue.record("Expected prior plan-based performance.")
            return
        }
        
        previousSet.weight = 100
        previousSet.reps = 8
        previousSet.restSeconds = 90
        previousSet.complete = true
        
        #expect(previousPerformance.originalTargetSnapshot != nil)
        previousSession.clearPrescriptionLinksForHistoricalUse()
        #expect(previousSet.linkedTargetSetIndex == 0)
        
        let currentSession = WorkoutSession(from: plan)
        context.insert(currentSession)
        
        guard let currentPerformance = currentSession.sortedExercises.first,
              let currentSet = currentPerformance.sortedSets.first else {
            Issue.record("Expected current plan-based performance.")
            return
        }
        
        currentSet.weight = 100
        currentSet.reps = 8
        currentSet.restSeconds = 90
        currentSet.complete = true
        
        let suggestionContext = ExerciseSuggestionContext(session: currentSession, performance: currentPerformance, prescription: prescription, history: [previousPerformance], plan: plan, resolvedTrainingStyle: .straightSets, weightUnit: .kg)
        
        let suggestions = RuleEngine.evaluate(context: suggestionContext)
        let repChange = flattenedChanges(from: suggestions).first(where: { $0.change.changeType == .increaseReps })
        
        #expect(repChange != nil)
        if let repChange {
            #expect(repChange.change.previousValue == 8)
            #expect(repChange.change.newValue == 9)
            #expect(repChange.draft.targetSetIndex == 0)
        }
    }

    @Test @MainActor
    func historicalLinkedTargetSetIndexMatchesReindexedHistoricalSetToOriginalTargetSlot() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 2, targetWeight: 100, targetReps: 8, targetRest: 90, repRangeMode: .range, lowerRange: 8, upperRange: 10)

        let previousSession = WorkoutSession(from: plan)
        context.insert(previousSession)
        previousSession.statusValue = .done

        guard let previousPerformance = previousSession.sortedExercises.first,
              previousPerformance.sortedSets.count == 2 else {
            Issue.record("Expected prior plan-based performance with two sets.")
            return
        }

        let previousFirstSet = previousPerformance.sortedSets[0]
        let previousSecondSet = previousPerformance.sortedSets[1]
        previousFirstSet.weight = 100
        previousFirstSet.reps = 6
        previousFirstSet.restSeconds = 90
        previousFirstSet.complete = true
        previousSecondSet.weight = 100
        previousSecondSet.reps = 8
        previousSecondSet.restSeconds = 90
        previousSecondSet.complete = true

        previousPerformance.deleteSet(previousFirstSet)
        #expect(previousPerformance.sortedSets.count == 1)
        #expect(previousPerformance.sortedSets[0].index == 0)
        #expect(previousPerformance.sortedSets[0].prescription?.index == 1)

        previousSession.clearPrescriptionLinksForHistoricalUse()
        #expect(previousPerformance.sortedSets[0].linkedTargetSetIndex == 1)

        let currentSession = WorkoutSession(from: plan)
        context.insert(currentSession)

        guard let currentPerformance = currentSession.sortedExercises.first else {
            Issue.record("Expected current plan-based performance.")
            return
        }

        for set in currentPerformance.sortedSets {
            set.weight = 100
            set.reps = 8
            set.restSeconds = 90
            set.complete = true
        }

        let suggestionContext = ExerciseSuggestionContext(session: currentSession, performance: currentPerformance, prescription: prescription, history: [previousPerformance], plan: plan, resolvedTrainingStyle: .straightSets, weightUnit: .kg)

        let suggestions = RuleEngine.evaluate(context: suggestionContext)
        let repChanges = flattenedChanges(from: suggestions).filter { $0.change.changeType == .increaseReps }

        #expect(repChanges.contains { $0.draft.targetSetIndex == 1 })
        #expect(repChanges.contains { $0.draft.targetSetIndex == 0 } == false)
    }
    
    @Test @MainActor
    func belowRangeWeightDecrease_requiresAttemptingPrescribedLoad() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 1, targetWeight: 100, targetReps: 10, targetRest: 90, repRangeMode: .range, lowerRange: 8, upperRange: 10)
        
        let previousSession = TestDataFactory.makeSession(context: context, daysAgo: 3)
        let previousPerformance = TestDataFactory.makePerformance(context: context, session: previousSession, prescription: prescription, sets: [(weight: 90, reps: 7, rest: 90, type: .working)])
        
        let currentSession = TestDataFactory.makeSession(context: context)
        let currentPerformance = TestDataFactory.makePerformance(context: context, session: currentSession, prescription: prescription, sets: [(weight: 100, reps: 7, rest: 90, type: .working)])
        
        let suggestionContext = ExerciseSuggestionContext(session: currentSession, performance: currentPerformance, prescription: prescription, history: [previousPerformance], plan: plan, resolvedTrainingStyle: .straightSets, weightUnit: .kg)
        
        let suggestions = RuleEngine.evaluate(context: suggestionContext)
        let weightDecrease = flattenedChanges(from: suggestions).filter { $0.change.changeType == .decreaseWeight }
        
        #expect(weightDecrease.isEmpty)
    }
    
    @Test @MainActor
    func belowRangeWeightDecrease_triggersAfterTwoBelowRangeSessionsAtTargetLoad() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 1, targetWeight: 100, targetReps: 10, targetRest: 90, repRangeMode: .range, lowerRange: 8, upperRange: 10)
        
        let previousSession = TestDataFactory.makeSession(context: context, daysAgo: 3)
        let previousPerformance = TestDataFactory.makePerformance(context: context, session: previousSession, prescription: prescription, sets: [(weight: 100, reps: 7, rest: 90, type: .working)])
        
        let currentSession = TestDataFactory.makeSession(context: context)
        let currentPerformance = TestDataFactory.makePerformance(context: context, session: currentSession, prescription: prescription, sets: [(weight: 100, reps: 7, rest: 90, type: .working)])
        
        let suggestionContext = ExerciseSuggestionContext(session: currentSession, performance: currentPerformance, prescription: prescription, history: [previousPerformance], plan: plan, resolvedTrainingStyle: .straightSets, weightUnit: .kg)
        
        let suggestions = RuleEngine.evaluate(context: suggestionContext)
        let weightDecrease = flattenedChanges(from: suggestions).first(where: { $0.change.changeType == .decreaseWeight })
        
        #expect(weightDecrease != nil)
        #expect(weightDecrease?.draft.targetSetIndex == 0)
        #expect(weightDecrease?.change.previousValue == 100)
        #expect(weightDecrease?.change.newValue == 97.5)
    }
    
    @Test @MainActor
    func shortRestPerformanceDrop_increasesRestForTheFatiguingSet() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 2, targetWeight: 100, targetReps: 10, targetRest: 90, repRangeMode: .range, lowerRange: 8, upperRange: 10)
        
        let previousSession = TestDataFactory.makeSession(context: context, daysAgo: 3)
        let previousPerformance = TestDataFactory.makePerformance(context: context, session: previousSession, prescription: prescription, sets: [(weight: 100, reps: 10, rest: 90, type: .working), (weight: 100, reps: 7, rest: 60, type: .working)])
        
        let currentSession = TestDataFactory.makeSession(context: context)
        let currentPerformance = TestDataFactory.makePerformance(context: context, session: currentSession, prescription: prescription, sets: [(weight: 100, reps: 10, rest: 90, type: .working), (weight: 100, reps: 7, rest: 60, type: .working)])
        
        let suggestionContext = ExerciseSuggestionContext(session: currentSession, performance: currentPerformance, prescription: prescription, history: [previousPerformance], plan: plan, resolvedTrainingStyle: .straightSets, weightUnit: .kg)
        
        let suggestions = RuleEngine.evaluate(context: suggestionContext)
        let allChanges = flattenedChanges(from: suggestions)
        let restChange = allChanges.first(where: { $0.change.changeType == .increaseRest && $0.draft.targetSetIndex == 1 })
        
        #expect(restChange != nil)
        #expect(restChange?.change.previousValue == 90)
        #expect(restChange?.change.newValue == 105)
        #expect(allChanges.contains(where: { $0.change.changeType == .increaseRest && $0.draft.targetSetIndex == 0 }) == false)
    }
    
    @Test @MainActor
    func matchActualWeight_updatesPrescriptionAfterThreeConsistentHigherLoads() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 1, targetWeight: 100, targetReps: 10, targetRest: 90, repRangeMode: .range, lowerRange: 6, upperRange: 12)
        
        let oldestSession = TestDataFactory.makeSession(context: context, daysAgo: 6)
        let oldestPerformance = TestDataFactory.makePerformance(context: context, session: oldestSession, prescription: prescription, sets: [(weight: 110, reps: 8, rest: 90, type: .working)])
        
        let previousSession = TestDataFactory.makeSession(context: context, daysAgo: 3)
        let previousPerformance = TestDataFactory.makePerformance(context: context, session: previousSession, prescription: prescription, sets: [(weight: 110, reps: 8, rest: 90, type: .working)])
        
        let currentSession = TestDataFactory.makeSession(context: context)
        let currentPerformance = TestDataFactory.makePerformance(context: context, session: currentSession, prescription: prescription, sets: [(weight: 110, reps: 8, rest: 90, type: .working)])
        
        let suggestionContext = ExerciseSuggestionContext(session: currentSession, performance: currentPerformance, prescription: prescription, history: [previousPerformance, oldestPerformance], plan: plan, resolvedTrainingStyle: .straightSets, weightUnit: .kg)
        
        let suggestions = RuleEngine.evaluate(context: suggestionContext)
        let weightChange = flattenedChanges(from: suggestions).first(where: { $0.change.changeType == .increaseWeight && $0.change.previousValue == 100 })
        
        #expect(weightChange != nil)
        #expect(weightChange?.draft.targetSetIndex == 0)
        #expect(weightChange?.change.newValue == 110)
    }
    
    @Test @MainActor
    func dropSetWithoutBase_convertsLeadingDropSetToWorkingSet() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 1, targetWeight: 100, targetReps: 10, targetRest: 90, repRangeMode: .range, lowerRange: 8, upperRange: 10)
        prescription.sortedSets.first?.type = .dropSet
        
        let currentSession = TestDataFactory.makeSession(context: context)
        let currentPerformance = TestDataFactory.makePerformance(context: context, session: currentSession, prescription: prescription, sets: [(weight: 70, reps: 12, rest: 30, type: .dropSet)])
        
        let suggestionContext = ExerciseSuggestionContext(session: currentSession, performance: currentPerformance, prescription: prescription, history: [], plan: plan, resolvedTrainingStyle: .straightSets, weightUnit: .kg)
        
        let suggestions = RuleEngine.evaluate(context: suggestionContext)
        let setTypeChange = flattenedChanges(from: suggestions).first(where: { $0.change.changeType == .changeSetType })
        
        #expect(setTypeChange != nil)
        #expect(setTypeChange?.draft.targetSetIndex == 0)
        #expect(setTypeChange?.change.newValue == Double(ExerciseSetType.working.rawValue))
    }
    
    @Test @MainActor
    func warmupActingLikeWorkingSet_promotesWarmupAfterRepeatedHeavyUse() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 2, targetWeight: 100, targetReps: 10, targetRest: 90, repRangeMode: .range, lowerRange: 6, upperRange: 12)
        prescription.sortedSets[0].type = .warmup
        prescription.sortedSets[0].targetWeight = 50
        
        let previousSession = TestDataFactory.makeSession(context: context, daysAgo: 3)
        let previousPerformance = TestDataFactory.makePerformance(context: context, session: previousSession, prescription: prescription, sets: [(weight: 95, reps: 8, rest: 60, type: .warmup), (weight: 100, reps: 8, rest: 90, type: .working)])
        
        let currentSession = TestDataFactory.makeSession(context: context)
        let currentPerformance = TestDataFactory.makePerformance(context: context, session: currentSession, prescription: prescription, sets: [(weight: 95, reps: 8, rest: 60, type: .warmup), (weight: 100, reps: 8, rest: 90, type: .working)])
        
        let suggestionContext = ExerciseSuggestionContext(session: currentSession, performance: currentPerformance, prescription: prescription, history: [previousPerformance], plan: plan, resolvedTrainingStyle: .straightSets, weightUnit: .kg)
        
        let suggestions = RuleEngine.evaluate(context: suggestionContext)
        let setTypeChange = flattenedChanges(from: suggestions).first(where: { $0.change.changeType == .changeSetType && $0.draft.targetSetIndex == 0 })
        
        #expect(setTypeChange != nil)
        #expect(setTypeChange?.change.previousValue == Double(ExerciseSetType.warmup.rawValue))
        #expect(setTypeChange?.change.newValue == Double(ExerciseSetType.working.rawValue))
    }
    
    @Test @MainActor
    func notSetRepRangeSuggestsInitialExerciseLevelRange() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 1, targetWeight: 100, targetReps: 10, targetRest: 90, repRangeMode: .notSet)
        
        let session1 = TestDataFactory.makeSession(context: context, daysAgo: 6)
        session1.statusValue = .done
        _ = TestDataFactory.makePerformance(context: context, session: session1, prescription: prescription, sets: [(weight: 100, reps: 10, rest: 90, type: .working)])
        
        let session2 = TestDataFactory.makeSession(context: context, daysAgo: 3)
        session2.statusValue = .done
        _ = TestDataFactory.makePerformance(context: context, session: session2, prescription: prescription, sets: [(weight: 100, reps: 11, rest: 90, type: .working)])
        
        let session3 = TestDataFactory.makeSession(context: context)
        let perf3 = TestDataFactory.makePerformance(context: context, session: session3, prescription: prescription, sets: [(weight: 100, reps: 12, rest: 90, type: .working)])
        
        let suggestionContext = ExerciseSuggestionContext(session: session3, performance: perf3, prescription: prescription, history: [session2.sortedExercises.first!, session1.sortedExercises.first!], plan: plan, resolvedTrainingStyle: .straightSets, weightUnit: .kg)
        let suggestions = RuleEngine.evaluate(context: suggestionContext)
        let exerciseChanges = exerciseLevelChanges(from: suggestions)
        
        #expect(suggestions.contains { $0.targetSetIndex == nil })
        #expect(exerciseChanges.contains { $0.changeType == .changeRepRangeMode })
        #expect(exerciseChanges.contains { $0.changeType == .increaseRepRangeLower && $0.newValue == 10 })
    }
    
    @Test @MainActor
    func targetRepRangeSuggestsRangeWhenRecentSessionsSpanABand() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 1, targetWeight: 100, targetReps: 8, targetRest: 90, repRangeMode: .target)
        prescription.repRange?.targetReps = 8
        
        let session1 = TestDataFactory.makeSession(context: context, daysAgo: 6)
        session1.statusValue = .done
        _ = TestDataFactory.makePerformance(context: context, session: session1, prescription: prescription, sets: [(weight: 100, reps: 9, rest: 90, type: .working)])
        
        let session2 = TestDataFactory.makeSession(context: context, daysAgo: 3)
        session2.statusValue = .done
        _ = TestDataFactory.makePerformance(context: context, session: session2, prescription: prescription, sets: [(weight: 100, reps: 8, rest: 90, type: .working)])
        
        let session3 = TestDataFactory.makeSession(context: context)
        let perf3 = TestDataFactory.makePerformance(context: context, session: session3, prescription: prescription, sets: [(weight: 100, reps: 7, rest: 90, type: .working)])
        
        let suggestionContext = ExerciseSuggestionContext(session: session3, performance: perf3, prescription: prescription, history: [session2.sortedExercises.first!, session1.sortedExercises.first!], plan: plan, resolvedTrainingStyle: .straightSets, weightUnit: .kg)
        let suggestions = RuleEngine.evaluate(context: suggestionContext)
        let exerciseChanges = exerciseLevelChanges(from: suggestions)
        
        #expect(suggestions.contains { $0.targetSetIndex == nil })
        #expect(exerciseChanges.contains { $0.changeType == .changeRepRangeMode })
        #expect(exerciseChanges.contains { $0.changeType == .increaseRepRangeLower && $0.newValue == 7 })
        #expect(exerciseChanges.contains { $0.changeType == .decreaseRepRangeUpper && $0.newValue == 9 })
    }
    
    @Test @MainActor
    func setLevelSuggestionBlocksExerciseLevelRepRangeSuggestion() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 1, targetWeight: 100, targetReps: 8, targetRest: 90, repRangeMode: .target)
        prescription.repRange?.targetReps = 8
        
        let session1 = TestDataFactory.makeSession(context: context, daysAgo: 6)
        session1.statusValue = .done
        _ = TestDataFactory.makePerformance(context: context, session: session1, prescription: prescription, sets: [(weight: 100, reps: 9, rest: 90, type: .working)])
        
        let session2 = TestDataFactory.makeSession(context: context, daysAgo: 3)
        session2.statusValue = .done
        _ = TestDataFactory.makePerformance(context: context, session: session2, prescription: prescription, sets: [(weight: 100, reps: 9, rest: 90, type: .working)])
        
        let session3 = TestDataFactory.makeSession(context: context)
        let perf3 = TestDataFactory.makePerformance(context: context, session: session3, prescription: prescription, sets: [(weight: 100, reps: 10, rest: 90, type: .working)])
        
        let suggestionContext = ExerciseSuggestionContext(session: session3, performance: perf3, prescription: prescription, history: [session2.sortedExercises.first!, session1.sortedExercises.first!], plan: plan, resolvedTrainingStyle: .straightSets, weightUnit: .kg)
        let suggestions = RuleEngine.evaluate(context: suggestionContext)
        
        #expect(suggestions.contains { $0.targetSetIndex != nil })
        #expect(suggestions.contains { $0.targetSetIndex == nil } == false)
    }
    
    @Test @MainActor
    func pendingSuggestionEventsAndGroupingUseEventAsGroupUnit() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 1, targetWeight: 135, targetReps: 10, repRangeMode: .range, lowerRange: 8, upperRange: 12)
        guard let set = prescription.sortedSets.first else {
            Issue.record("Expected plan set for grouping test.")
            return
        }
        
        let event = SuggestionEvent(catalogID: prescription.catalogID, sessionFrom: nil, triggerPerformanceSnapshot: ExercisePerformanceSnapshot(notes: "", repRange: RepRangeSnapshot(policy: prescription.repRange), sets: []), triggerTargetSnapshot: ExerciseTargetSnapshot(prescription: prescription), trainingStyle: .straightSets, changes: [])
        context.insert(event)
        
        let weightChange = PrescriptionChange(event: event, targetExercisePrescription: prescription, targetSetPrescription: set, changeType: .increaseWeight, previousValue: 135, newValue: 140)
        let repChange = PrescriptionChange(event: event, targetExercisePrescription: prescription, targetSetPrescription: set, changeType: .decreaseReps, previousValue: 10, newValue: 8)
        event.changes = [weightChange, repChange]
        prescription.changes = [weightChange, repChange]
        set.changes = [weightChange, repChange]
        
        let pendingEvents = pendingSuggestionEvents(for: plan, in: context)
        #expect(pendingEvents.count == 1)
        #expect(pendingEvents.first?.id == event.id)
        
        let sections = groupSuggestions(pendingEvents)
        #expect(sections.count == 1)
        #expect(sections.first?.groups.count == 1)
        #expect(sections.first?.groups.first?.changes.count == 2)
    }

    @Test @MainActor
    func outcomeRuleEngine_requiresLiveSetPrescriptionLinkForSetLevelChanges() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 1, targetWeight: 95, targetReps: 8, targetRest: 90, repRangeMode: .target)
        prescription.repRange?.targetReps = 8

        let workout = WorkoutSession(from: plan)
        context.insert(workout)

        guard let performance = workout.sortedExercises.first,
              let set = performance.sortedSets.first,
              let setPrescription = prescription.sortedSets.first else {
            Issue.record("Expected plan-backed performance with one linked set.")
            return
        }

        set.weight = 100
        set.reps = 8
        set.restSeconds = 90
        set.complete = true

        let change = PrescriptionChange(
            targetExercisePrescription: prescription,
            targetSetPrescription: setPrescription,
            targetSetIndex: setPrescription.index,
            changeType: .increaseWeight,
            previousValue: 95,
            newValue: 100
        )

        let matched = OutcomeRuleEngine.evaluate(change: change, exercisePerf: performance, trainingStyle: .straightSets)
        #expect(matched?.outcome == .good)

        set.prescription = nil

        let withoutLiveLink = OutcomeRuleEngine.evaluate(change: change, exercisePerf: performance, trainingStyle: .straightSets)
        #expect(withoutLiveLink == nil)
    }
}
