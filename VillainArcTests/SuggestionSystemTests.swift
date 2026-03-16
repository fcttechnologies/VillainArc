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
        drafts.filter { $0.targetSetPrescription == nil }.flatMap(\.changes)
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
        // Tight small variance with no clear structure should still be straight sets.
        let sets = [100.0, 105.0, 100.0, 95.0].enumerated().map { (i, w) in
            TestDataFactory.makeSetPerformance(index: i, weight: w, reps: 8)
        }
        let style = MetricsCalculator.detectTrainingStyle(sets)
        #expect(style == .straightSets)
    }

    @Test @MainActor
    func detectTrainingStyle_moderateRampWithinOldTenPercentBand_prefersAscending() {
        let sets = [100.0, 105.0, 110.0].enumerated().map { (i, w) in
            TestDataFactory.makeSetPerformance(index: i, weight: w, reps: 8)
        }
        let style = MetricsCalculator.detectTrainingStyle(sets)
        #expect(style == .ascending)
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
    func detectTrainingStyle_descendingPyramid_notMisclassifiedAsTopSetBackoffs() {
        let sets = [100.0, 90.0, 80.0, 70.0].enumerated().map { (i, w) in
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
    func detectTrainingStyle_mildInteriorPlateauBackoff_prefersUnknownOverStraightSets() {
        let sets = [100.0, 110.0, 110.0, 100.0].enumerated().map { (i, w) in
            TestDataFactory.makeSetPerformance(index: i, weight: w, reps: 8)
        }
        let style = MetricsCalculator.detectTrainingStyle(sets)
        #expect(style == .unknown)
    }

    @Test @MainActor
    func detectTrainingStyle_unknownForNoisyMiddlePeak() {
        let sets = [100.0, 125.0, 105.0, 115.0].enumerated().map { (i, w) in
            TestDataFactory.makeSetPerformance(index: i, weight: w, reps: 8)
        }
        let style = MetricsCalculator.detectTrainingStyle(sets)
        #expect(style == .unknown)
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
        
        let topSetIndices = Set(topSetWeightChanges.compactMap { $0.draft.targetSetPrescription?.index })
        #expect(topSetIndices == Set([0, 1]))
    }

    @Test @MainActor
    func selectProgressionSets_ascendingStyleIncludesTopThreeWeights() throws {
        let context = try TestDataFactory.makeContext()
        let (_, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 5, targetWeight: 100, targetReps: 8, repRangeMode: .range, lowerRange: 6, upperRange: 12)
        let session = TestDataFactory.makeSession(context: context)
        let performance = TestDataFactory.makePerformance(
            context: context,
            session: session,
            prescription: prescription,
            sets: [
                (weight: 60, reps: 12, rest: 90, type: .working),
                (weight: 70, reps: 12, rest: 90, type: .working),
                (weight: 80, reps: 12, rest: 90, type: .working),
                (weight: 90, reps: 12, rest: 90, type: .working),
                (weight: 100, reps: 11, rest: 90, type: .working)
            ]
        )

        let progressionSets = MetricsCalculator.selectProgressionSets(from: performance, overrideStyle: .ascending)
        let progressionWeights = progressionSets.map(\.weight)

        #expect(progressionWeights == [80, 90, 100])
    }

    @Test @MainActor
    func selectProgressionSets_detectedModerateAscendingRamp_excludesFeederSets() throws {
        let context = try TestDataFactory.makeContext()
        let (_, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 5, targetWeight: 100, targetReps: 8, repRangeMode: .range, lowerRange: 6, upperRange: 12)
        let session = TestDataFactory.makeSession(context: context)
        let performance = TestDataFactory.makePerformance(
            context: context,
            session: session,
            prescription: prescription,
            sets: [
                (weight: 90, reps: 12, rest: 90, type: .working),
                (weight: 95, reps: 11, rest: 90, type: .working),
                (weight: 100, reps: 10, rest: 90, type: .working),
                (weight: 105, reps: 9, rest: 90, type: .working),
                (weight: 110, reps: 8, rest: 90, type: .working)
            ]
        )

        let detectedStyle = MetricsCalculator.detectTrainingStyle(performance.sortedSets)
        let progressionSets = MetricsCalculator.selectProgressionSets(from: performance)

        #expect(detectedStyle == .ascending)
        #expect(progressionSets.map(\.weight) == [100, 105, 110])
    }

    @Test @MainActor
    func weightIncrement_usesFiveKgForWhitelistedBarbellPulls() {
        let increment = MetricsCalculator.weightIncrement(
            for: 100,
            primaryMuscle: .lats,
            equipmentType: .barbell,
            catalogID: "barbell_deadlift"
        )

        #expect(increment == 5.0)
    }

    @Test @MainActor
    func weightIncrement_keepsConservativeStepForNonWhitelistedBackExercises() {
        let increment = MetricsCalculator.weightIncrement(
            for: 100,
            primaryMuscle: .lats,
            equipmentType: .barbell,
            catalogID: "barbell_shrugs"
        )

        #expect(increment == 2.5)
    }

    @Test @MainActor
    func immediateProgressionRange_doesNotFire_whenLastSetMissesCeiling() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(
            context: context,
            workingSets: 4,
            targetWeight: 100,
            targetReps: 8,
            targetRest: 90,
            repRangeMode: .range,
            lowerRange: 8,
            upperRange: 12
        )

        let currentSession = TestDataFactory.makeSession(context: context)
        let currentPerformance = TestDataFactory.makePerformance(
            context: context,
            session: currentSession,
            prescription: prescription,
            sets: [
                (weight: 100, reps: 12, rest: 90, type: .working),
                (weight: 100, reps: 12, rest: 90, type: .working),
                (weight: 100, reps: 12, rest: 90, type: .working),
                (weight: 100, reps: 11, rest: 90, type: .working)
            ]
        )

        let suggestionContext = ExerciseSuggestionContext(session: currentSession, performance: currentPerformance, prescription: prescription, history: [], plan: plan, resolvedTrainingStyle: .straightSets, weightUnit: .kg)

        let suggestions = RuleEngine.evaluate(context: suggestionContext)
        let weightIncrease = flattenedChanges(from: suggestions).first(where: { $0.change.changeType == .increaseWeight })

        #expect(weightIncrease == nil,
            "Immediate range progression should stay strict for a single-session fatigue miss on the last set")
    }

    @Test @MainActor
    func immediateProgressionRange_ignoresCloseUnlinkedWorkingSet() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(
            context: context,
            workingSets: 2,
            targetWeight: 100,
            targetReps: 8,
            targetRest: 90,
            repRangeMode: .range,
            lowerRange: 8,
            upperRange: 10
        )

        let currentSession = TestDataFactory.makeSession(context: context)
        let currentPerformance = TestDataFactory.makePerformance(
            context: context,
            session: currentSession,
            prescription: prescription,
            sets: [
                (weight: 100, reps: 10, rest: 90, type: .working),
                (weight: 100, reps: 10, rest: 90, type: .working),
                (weight: 100, reps: 9, rest: 90, type: .working)
            ]
        )

        let suggestionContext = ExerciseSuggestionContext(session: currentSession, performance: currentPerformance, prescription: prescription, history: [], plan: plan, resolvedTrainingStyle: .straightSets, weightUnit: .kg)

        let suggestions = RuleEngine.evaluate(context: suggestionContext)
        let weightChanges = flattenedChanges(from: suggestions).filter { $0.change.changeType == .increaseWeight }
        let targetedIndices = Set(weightChanges.compactMap { $0.draft.targetSetPrescription?.index })

        #expect(targetedIndices == Set([0, 1]),
            "A close unlinked working set should not block progression for linked prescribed sets")
    }

    @Test @MainActor
    func immediateProgressionRange_blocksOnStronglyContradictoryComparableUnlinkedSet() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(
            context: context,
            workingSets: 2,
            targetWeight: 100,
            targetReps: 8,
            targetRest: 90,
            repRangeMode: .range,
            lowerRange: 8,
            upperRange: 10
        )

        let currentSession = TestDataFactory.makeSession(context: context)
        let currentPerformance = TestDataFactory.makePerformance(
            context: context,
            session: currentSession,
            prescription: prescription,
            sets: [
                (weight: 100, reps: 10, rest: 90, type: .working),
                (weight: 100, reps: 10, rest: 90, type: .working),
                (weight: 100, reps: 6, rest: 90, type: .working)
            ]
        )

        let suggestionContext = ExerciseSuggestionContext(session: currentSession, performance: currentPerformance, prescription: prescription, history: [], plan: plan, resolvedTrainingStyle: .straightSets, weightUnit: .kg)

        let suggestions = RuleEngine.evaluate(context: suggestionContext)
        let weightIncrease = flattenedChanges(from: suggestions).first(where: { $0.change.changeType == .increaseWeight })

        #expect(weightIncrease == nil,
            "A strongly underperforming comparable unlinked working set should block immediate progression")
    }

    @Test @MainActor
    func confirmedProgressionRange_fires_whenLastSetMissesCeilingByOneAcrossTwoSessions() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(
            context: context,
            workingSets: 4,
            targetWeight: 100,
            targetReps: 8,
            targetRest: 90,
            repRangeMode: .range,
            lowerRange: 8,
            upperRange: 12
        )
        prescription.musclesTargeted = [.chest]
        prescription.equipmentType = .barbell

        let previousSession = TestDataFactory.makeSession(context: context, daysAgo: 3)
        previousSession.statusValue = .done
        let previousPerformance = TestDataFactory.makePerformance(
            context: context,
            session: previousSession,
            prescription: prescription,
            sets: [
                (weight: 100, reps: 12, rest: 90, type: .working),
                (weight: 100, reps: 12, rest: 90, type: .working),
                (weight: 100, reps: 12, rest: 90, type: .working),
                (weight: 100, reps: 11, rest: 90, type: .working)
            ]
        )

        let currentSession = TestDataFactory.makeSession(context: context)
        let currentPerformance = TestDataFactory.makePerformance(
            context: context,
            session: currentSession,
            prescription: prescription,
            sets: [
                (weight: 100, reps: 12, rest: 90, type: .working),
                (weight: 100, reps: 12, rest: 90, type: .working),
                (weight: 100, reps: 12, rest: 90, type: .working),
                (weight: 100, reps: 11, rest: 90, type: .working)
            ]
        )

        let suggestionContext = ExerciseSuggestionContext(
            session: currentSession,
            performance: currentPerformance,
            prescription: prescription,
            history: [previousPerformance],
            plan: plan,
            resolvedTrainingStyle: .straightSets,
            weightUnit: .kg
        )

        let suggestions = RuleEngine.evaluate(context: suggestionContext)
        let weightChanges = flattenedChanges(from: suggestions).filter { $0.change.changeType == .increaseWeight }
        let repChanges = flattenedChanges(from: suggestions).filter { $0.change.changeType == .decreaseReps }

        #expect(weightChanges.count == 4,
            "Confirmed range progression should fire after two sessions when every set is at ceiling or one rep shy")
        #expect(repChanges.isEmpty,
            "Rep reset should not be emitted when the prescription is already at the lower bound")
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
        #expect(generated.allSatisfy { $0.targetExercisePrescription?.workoutPlan?.id == plan.id })
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
        #expect(event.triggerTargetSetID == set.prescription?.id)
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
        #expect(snapshotSets[0].originalTargetSetID == prescription.sortedSets[0].id)
        #expect(snapshotSets[1].originalTargetSetID == prescription.sortedSets[1].id)
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
        #expect(previousSet.originalTargetSetID == prescription.sortedSets[0].id)
        
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
            #expect(repChange.draft.targetSetPrescription?.index == 0)
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
        #expect(previousPerformance.sortedSets[0].originalTargetSetID == prescription.sortedSets[1].id)

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

        #expect(repChanges.contains { $0.draft.targetSetPrescription?.index == 1 })
        #expect(repChanges.contains { $0.draft.targetSetPrescription?.index == 0 } == false)
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
        #expect(weightDecrease?.draft.targetSetPrescription?.index == 0)
        #expect(weightDecrease?.change.previousValue == 100)
        #expect(weightDecrease?.change.newValue == 97.5)
    }

    @Test @MainActor
    func reducedWeightToHitReps_doesNotTrigger_whenReducedLoadOnlyHitsRangeFloor() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 1, targetWeight: 100, targetReps: 10, targetRest: 90, repRangeMode: .range, lowerRange: 8, upperRange: 10)

        let previousSession = TestDataFactory.makeSession(context: context, daysAgo: 3)
        let previousPerformance = TestDataFactory.makePerformance(context: context, session: previousSession, prescription: prescription, sets: [(weight: 97.5, reps: 8, rest: 90, type: .working)])

        let currentSession = TestDataFactory.makeSession(context: context)
        let currentPerformance = TestDataFactory.makePerformance(context: context, session: currentSession, prescription: prescription, sets: [(weight: 97.5, reps: 8, rest: 90, type: .working)])

        let suggestionContext = ExerciseSuggestionContext(session: currentSession, performance: currentPerformance, prescription: prescription, history: [previousPerformance], plan: plan, resolvedTrainingStyle: .straightSets, weightUnit: .kg)

        let suggestions = RuleEngine.evaluate(context: suggestionContext)
        let weightDecrease = flattenedChanges(from: suggestions).first(where: { $0.change.changeType == .decreaseWeight })

        #expect(weightDecrease == nil,
            "Two reduced-load sessions that still hit the range floor should not lower the prescription")
    }

    @Test @MainActor
    func reducedWeightToHitReps_triggers_whenOneReducedLoadSessionFallsBelowRangeFloor() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 1, targetWeight: 100, targetReps: 10, targetRest: 90, repRangeMode: .range, lowerRange: 8, upperRange: 10)

        let previousSession = TestDataFactory.makeSession(context: context, daysAgo: 3)
        let previousPerformance = TestDataFactory.makePerformance(context: context, session: previousSession, prescription: prescription, sets: [(weight: 97.5, reps: 7, rest: 90, type: .working)])

        let currentSession = TestDataFactory.makeSession(context: context)
        let currentPerformance = TestDataFactory.makePerformance(context: context, session: currentSession, prescription: prescription, sets: [(weight: 97.5, reps: 8, rest: 90, type: .working)])

        let suggestionContext = ExerciseSuggestionContext(session: currentSession, performance: currentPerformance, prescription: prescription, history: [previousPerformance], plan: plan, resolvedTrainingStyle: .straightSets, weightUnit: .kg)

        let suggestions = RuleEngine.evaluate(context: suggestionContext)
        let weightDecrease = flattenedChanges(from: suggestions).first(where: { $0.change.changeType == .decreaseWeight })

        #expect(weightDecrease != nil,
            "Reduced-load sessions should lower the prescription when at least one session still falls below the range floor")
        #expect(weightDecrease?.change.previousValue == 100)
        #expect(weightDecrease?.change.newValue == 97.5)
    }

    @Test @MainActor
    func reducedWeightToHitReps_usesHistoricalTargetWeight_notLiveTargetWeight() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 1, targetWeight: 95, targetReps: 10, targetRest: 90, repRangeMode: .range, lowerRange: 8, upperRange: 10)

        let previousSession = WorkoutSession(from: plan)
        context.insert(previousSession)
        guard let previousPerformance = previousSession.sortedExercises.first,
              let previousSet = previousPerformance.sortedSets.first else {
            Issue.record("Expected historical plan-backed performance.")
            return
        }

        previousSet.weight = 95
        previousSet.reps = 7
        previousSet.restSeconds = 90
        previousSet.complete = true
        previousSession.clearPrescriptionLinksForHistoricalUse()

        prescription.sortedSets[0].targetWeight = 100

        let currentSession = WorkoutSession(from: plan)
        context.insert(currentSession)
        guard let currentPerformance = currentSession.sortedExercises.first,
              let currentSet = currentPerformance.sortedSets.first else {
            Issue.record("Expected current plan-backed performance.")
            return
        }

        currentSet.weight = 95
        currentSet.reps = 8
        currentSet.restSeconds = 90
        currentSet.complete = true

        let suggestionContext = ExerciseSuggestionContext(session: currentSession, performance: currentPerformance, prescription: prescription, history: [previousPerformance], plan: plan, resolvedTrainingStyle: .straightSets, weightUnit: .kg)

        let suggestions = RuleEngine.evaluate(context: suggestionContext)
        let weightDecrease = flattenedChanges(from: suggestions).first(where: { $0.change.changeType == .decreaseWeight })

        #expect(weightDecrease == nil,
            "Historical sessions should be judged against their own target weight, not the current live target after a later plan increase")
    }
    
    @Test @MainActor
    func shortRestPerformanceDrop_increasesRestForTheIntervalBeforeTheFatiguingSet() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 2, targetWeight: 100, targetReps: 10, targetRest: 90, repRangeMode: .range, lowerRange: 8, upperRange: 10)
        
        let previousSession = TestDataFactory.makeSession(context: context, daysAgo: 3)
        let previousPerformance = TestDataFactory.makePerformance(context: context, session: previousSession, prescription: prescription, sets: [(weight: 100, reps: 10, rest: 60, type: .working), (weight: 100, reps: 7, rest: 90, type: .working)])
        
        let currentSession = TestDataFactory.makeSession(context: context)
        let currentPerformance = TestDataFactory.makePerformance(context: context, session: currentSession, prescription: prescription, sets: [(weight: 100, reps: 10, rest: 60, type: .working), (weight: 100, reps: 7, rest: 90, type: .working)])
        
        let suggestionContext = ExerciseSuggestionContext(session: currentSession, performance: currentPerformance, prescription: prescription, history: [previousPerformance], plan: plan, resolvedTrainingStyle: .straightSets, weightUnit: .kg)
        
        let suggestions = RuleEngine.evaluate(context: suggestionContext)
        let allChanges = flattenedChanges(from: suggestions)
        let restChange = allChanges.first(where: { $0.change.changeType == .increaseRest && $0.draft.targetSetPrescription?.index == 0 })

        #expect(restChange != nil)
        #expect(restChange?.change.previousValue == 90)
        #expect(restChange?.change.newValue == 105)
        #expect(allChanges.contains(where: { $0.change.changeType == .increaseRest && $0.draft.targetSetPrescription?.index == 1 }) == false)
    }

    @Test @MainActor
    func shortRestPerformanceDrop_doesNotTrigger_forNormalTwoRepDrop() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 2, targetWeight: 100, targetReps: 10, targetRest: 90, repRangeMode: .range, lowerRange: 8, upperRange: 10)

        let previousSession = TestDataFactory.makeSession(context: context, daysAgo: 3)
        let previousPerformance = TestDataFactory.makePerformance(
            context: context,
            session: previousSession,
            prescription: prescription,
            sets: [(weight: 100, reps: 10, rest: 60, type: .working), (weight: 100, reps: 8, rest: 90, type: .working)]
        )

        let currentSession = TestDataFactory.makeSession(context: context)
        let currentPerformance = TestDataFactory.makePerformance(
            context: context,
            session: currentSession,
            prescription: prescription,
            sets: [(weight: 100, reps: 10, rest: 60, type: .working), (weight: 100, reps: 8, rest: 90, type: .working)]
        )

        let suggestionContext = ExerciseSuggestionContext(session: currentSession, performance: currentPerformance, prescription: prescription, history: [previousPerformance], plan: plan, resolvedTrainingStyle: .straightSets, weightUnit: .kg)

        let suggestions = RuleEngine.evaluate(context: suggestionContext)
        let restChange = flattenedChanges(from: suggestions).first(where: { $0.change.changeType == .increaseRest })

        #expect(restChange == nil,
            "A normal two-rep drop under short rest should not increase prescribed rest on its own")
    }

    @Test @MainActor
    func shortRestPerformanceDrop_doesNotTrigger_whenLaggingSetStaysMidRange() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 2, targetWeight: 100, targetReps: 10, targetRest: 90, repRangeMode: .range, lowerRange: 8, upperRange: 12)

        let previousSession = TestDataFactory.makeSession(context: context, daysAgo: 3)
        let previousPerformance = TestDataFactory.makePerformance(
            context: context,
            session: previousSession,
            prescription: prescription,
            sets: [(weight: 100, reps: 12, rest: 60, type: .working), (weight: 100, reps: 9, rest: 90, type: .working)]
        )

        let currentSession = TestDataFactory.makeSession(context: context)
        let currentPerformance = TestDataFactory.makePerformance(
            context: context,
            session: currentSession,
            prescription: prescription,
            sets: [(weight: 100, reps: 12, rest: 60, type: .working), (weight: 100, reps: 9, rest: 90, type: .working)]
        )

        let suggestionContext = ExerciseSuggestionContext(session: currentSession, performance: currentPerformance, prescription: prescription, history: [previousPerformance], plan: plan, resolvedTrainingStyle: .straightSets, weightUnit: .kg)

        let suggestions = RuleEngine.evaluate(context: suggestionContext)
        let restChange = flattenedChanges(from: suggestions).first(where: { $0.change.changeType == .increaseRest })

        #expect(restChange == nil,
            "A repeated short-rest rep drop that still lands comfortably in range should not infer that more rest is needed")
    }

    @Test @MainActor
    func shortRestPerformanceDrop_requiresSameTargetSetAcrossSessions() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 3, targetWeight: 100, targetReps: 10, targetRest: 90, repRangeMode: .range, lowerRange: 8, upperRange: 10)

        let previousSession = TestDataFactory.makeSession(context: context, daysAgo: 3)
        let previousPerformance = TestDataFactory.makePerformance(
            context: context,
            session: previousSession,
            prescription: prescription,
            sets: [
                (weight: 100, reps: 10, rest: 90, type: .working),
                (weight: 100, reps: 10, rest: 60, type: .working),
                (weight: 100, reps: 6, rest: 90, type: .working)
            ]
        )

        let currentSession = TestDataFactory.makeSession(context: context)
        let currentPerformance = TestDataFactory.makePerformance(
            context: context,
            session: currentSession,
            prescription: prescription,
            sets: [
                (weight: 100, reps: 10, rest: 60, type: .working),
                (weight: 100, reps: 6, rest: 90, type: .working),
                (weight: 100, reps: 10, rest: 90, type: .working)
            ]
        )

        let suggestionContext = ExerciseSuggestionContext(session: currentSession, performance: currentPerformance, prescription: prescription, history: [previousPerformance], plan: plan, resolvedTrainingStyle: .straightSets, weightUnit: .kg)

        let suggestions = RuleEngine.evaluate(context: suggestionContext)
        let restChanges = flattenedChanges(from: suggestions).filter { $0.change.changeType == .increaseRest }

        #expect(restChanges.isEmpty,
            "Short-rest recovery suggestions should require repeated evidence on the same target set, not different sets across sessions")
    }

    @Test @MainActor
    func stagnationIncreaseRest_doesNotTrigger_whenAllProgressionSetsAreAtFloorPlusOne() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(
            context: context,
            workingSets: 3,
            targetWeight: 100,
            targetReps: 10,
            targetRest: 90,
            repRangeMode: .range,
            lowerRange: 8,
            upperRange: 12
        )

        let oldestSession = TestDataFactory.makeSession(context: context, daysAgo: 6)
        let oldestPerformance = TestDataFactory.makePerformance(
            context: context,
            session: oldestSession,
            prescription: prescription,
            sets: [
                (weight: 100, reps: 9, rest: 90, type: .working),
                (weight: 100, reps: 9, rest: 90, type: .working),
                (weight: 100, reps: 9, rest: 90, type: .working)
            ]
        )

        let previousSession = TestDataFactory.makeSession(context: context, daysAgo: 3)
        let previousPerformance = TestDataFactory.makePerformance(
            context: context,
            session: previousSession,
            prescription: prescription,
            sets: [
                (weight: 100, reps: 9, rest: 90, type: .working),
                (weight: 100, reps: 9, rest: 90, type: .working),
                (weight: 100, reps: 9, rest: 90, type: .working)
            ]
        )

        let currentSession = TestDataFactory.makeSession(context: context)
        let currentPerformance = TestDataFactory.makePerformance(
            context: context,
            session: currentSession,
            prescription: prescription,
            sets: [
                (weight: 100, reps: 9, rest: 90, type: .working),
                (weight: 100, reps: 9, rest: 90, type: .working),
                (weight: 100, reps: 9, rest: 90, type: .working)
            ]
        )

        let suggestionContext = ExerciseSuggestionContext(
            session: currentSession,
            performance: currentPerformance,
            prescription: prescription,
            history: [previousPerformance, oldestPerformance],
            plan: plan,
            resolvedTrainingStyle: .straightSets,
            weightUnit: .kg
        )

        let suggestions = RuleEngine.evaluate(context: suggestionContext)
        let restChange = flattenedChanges(from: suggestions).first(where: { $0.change.changeType == .increaseRest })

        #expect(restChange == nil,
            "Floor+1 performance across plateaued sessions should not count as struggling or trigger a rest increase")
    }

    @Test @MainActor
    func stagnationIncreaseRest_doesNotTrigger_fromPlateauAloneAtFloorWithoutRecoveryPattern() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(
            context: context,
            workingSets: 3,
            targetWeight: 100,
            targetReps: 10,
            targetRest: 90,
            repRangeMode: .range,
            lowerRange: 8,
            upperRange: 12
        )

        let oldestSession = TestDataFactory.makeSession(context: context, daysAgo: 6)
        let oldestPerformance = TestDataFactory.makePerformance(
            context: context,
            session: oldestSession,
            prescription: prescription,
            sets: [
                (weight: 100, reps: 8, rest: 90, type: .working),
                (weight: 100, reps: 8, rest: 90, type: .working),
                (weight: 100, reps: 8, rest: 90, type: .working)
            ]
        )

        let previousSession = TestDataFactory.makeSession(context: context, daysAgo: 3)
        let previousPerformance = TestDataFactory.makePerformance(
            context: context,
            session: previousSession,
            prescription: prescription,
            sets: [
                (weight: 100, reps: 8, rest: 90, type: .working),
                (weight: 100, reps: 8, rest: 90, type: .working),
                (weight: 100, reps: 8, rest: 90, type: .working)
            ]
        )

        let currentSession = TestDataFactory.makeSession(context: context)
        let currentPerformance = TestDataFactory.makePerformance(
            context: context,
            session: currentSession,
            prescription: prescription,
            sets: [
                (weight: 100, reps: 8, rest: 90, type: .working),
                (weight: 100, reps: 8, rest: 90, type: .working),
                (weight: 100, reps: 8, rest: 90, type: .working)
            ]
        )

        let suggestionContext = ExerciseSuggestionContext(
            session: currentSession,
            performance: currentPerformance,
            prescription: prescription,
            history: [previousPerformance, oldestPerformance],
            plan: plan,
            resolvedTrainingStyle: .straightSets,
            weightUnit: .kg
        )

        let suggestions = RuleEngine.evaluate(context: suggestionContext)
        let restChange = flattenedChanges(from: suggestions).first(where: { $0.change.changeType == .increaseRest })

        #expect(restChange == nil,
            "Plateau plus floor-level performance alone should not imply that prescribed rest is the limiting factor")
    }

    @Test @MainActor
    func stagnationIncreaseRest_targetsOnlyRepeatedRecoveryLimitedIntervals() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(
            context: context,
            workingSets: 3,
            targetWeight: 100,
            targetReps: 10,
            targetRest: 90,
            repRangeMode: .range,
            lowerRange: 8,
            upperRange: 12
        )

        let oldestSession = TestDataFactory.makeSession(context: context, daysAgo: 6)
        let oldestPerformance = TestDataFactory.makePerformance(
            context: context,
            session: oldestSession,
            prescription: prescription,
            sets: [
                (weight: 100, reps: 12, rest: 90, type: .working),
                (weight: 100, reps: 7, rest: 90, type: .working),
                (weight: 100, reps: 12, rest: 90, type: .working)
            ]
        )

        let previousSession = TestDataFactory.makeSession(context: context, daysAgo: 3)
        let previousPerformance = TestDataFactory.makePerformance(
            context: context,
            session: previousSession,
            prescription: prescription,
            sets: [
                (weight: 100, reps: 12, rest: 90, type: .working),
                (weight: 100, reps: 7, rest: 90, type: .working),
                (weight: 100, reps: 12, rest: 90, type: .working)
            ]
        )

        let currentSession = TestDataFactory.makeSession(context: context)
        let currentPerformance = TestDataFactory.makePerformance(
            context: context,
            session: currentSession,
            prescription: prescription,
            sets: [
                (weight: 100, reps: 12, rest: 90, type: .working),
                (weight: 100, reps: 7, rest: 90, type: .working),
                (weight: 100, reps: 12, rest: 90, type: .working)
            ]
        )

        let suggestionContext = ExerciseSuggestionContext(
            session: currentSession,
            performance: currentPerformance,
            prescription: prescription,
            history: [previousPerformance, oldestPerformance],
            plan: plan,
            resolvedTrainingStyle: .straightSets,
            weightUnit: .kg
        )

        let suggestions = RuleEngine.evaluate(context: suggestionContext)
        let restChanges = flattenedChanges(from: suggestions).filter { $0.change.changeType == .increaseRest }
        let targetedIndices = Set(restChanges.compactMap { $0.draft.targetSetPrescription?.index })

        #expect(targetedIndices == Set([0]),
            "Only intervals that repeatedly precede recovery-limited downstream sets should get extra rest")
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
        #expect(weightChange?.draft.targetSetPrescription?.index == 0)
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
        #expect(setTypeChange?.draft.targetSetPrescription?.index == 0)
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
        let setTypeChange = flattenedChanges(from: suggestions).first(where: { $0.change.changeType == .changeSetType && $0.draft.targetSetPrescription?.index == 0 })
        
        #expect(setTypeChange != nil)
        #expect(setTypeChange?.change.previousValue == Double(ExerciseSetType.warmup.rawValue))
        #expect(setTypeChange?.change.newValue == Double(ExerciseSetType.working.rawValue))
    }

    @Test @MainActor
    func warmupActingLikeWorkingSet_doesNotPromoteHeavyFeederWarmupInAscendingPyramid() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 2, targetWeight: 100, targetReps: 8, targetRest: 90, repRangeMode: .range, lowerRange: 6, upperRange: 10)
        prescription.sortedSets[0].type = .warmup
        prescription.sortedSets[0].targetWeight = 50

        let previousSession = TestDataFactory.makeSession(context: context, daysAgo: 3)
        let previousPerformance = TestDataFactory.makePerformance(context: context, session: previousSession, prescription: prescription, sets: [(weight: 90, reps: 3, rest: 60, type: .warmup), (weight: 100, reps: 8, rest: 90, type: .working)])

        let currentSession = TestDataFactory.makeSession(context: context)
        let currentPerformance = TestDataFactory.makePerformance(context: context, session: currentSession, prescription: prescription, sets: [(weight: 90, reps: 3, rest: 60, type: .warmup), (weight: 100, reps: 8, rest: 90, type: .working)])

        let suggestionContext = ExerciseSuggestionContext(session: currentSession, performance: currentPerformance, prescription: prescription, history: [previousPerformance], plan: plan, resolvedTrainingStyle: .ascending, weightUnit: .kg)

        let suggestions = RuleEngine.evaluate(context: suggestionContext)
        let setTypeChange = flattenedChanges(from: suggestions).first(where: { $0.change.changeType == .changeSetType && $0.draft.targetSetPrescription?.index == 0 })

        #expect(setTypeChange == nil,
            "A heavy feeder warmup with much lower reps than the top working set should stay a warmup")
    }

    @Test @MainActor
    func regularActingLikeWarmup_doesNotDemoteAscendingFeederWorkingSet() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 3, targetWeight: 100, targetReps: 8, targetRest: 90, repRangeMode: .range, lowerRange: 6, upperRange: 12)
        prescription.sortedSets[0].targetWeight = 60
        prescription.sortedSets[1].targetWeight = 80
        prescription.sortedSets[2].targetWeight = 100

        let previousSession = TestDataFactory.makeSession(context: context, daysAgo: 3)
        let previousPerformance = TestDataFactory.makePerformance(
            context: context,
            session: previousSession,
            prescription: prescription,
            sets: [
                (weight: 60, reps: 12, rest: 90, type: .working),
                (weight: 80, reps: 10, rest: 90, type: .working),
                (weight: 100, reps: 8, rest: 90, type: .working)
            ]
        )

        let currentSession = TestDataFactory.makeSession(context: context)
        let currentPerformance = TestDataFactory.makePerformance(
            context: context,
            session: currentSession,
            prescription: prescription,
            sets: [
                (weight: 60, reps: 12, rest: 90, type: .working),
                (weight: 80, reps: 10, rest: 90, type: .working),
                (weight: 100, reps: 8, rest: 90, type: .working)
            ]
        )

        let suggestionContext = ExerciseSuggestionContext(session: currentSession, performance: currentPerformance, prescription: prescription, history: [previousPerformance], plan: plan, resolvedTrainingStyle: .ascending, weightUnit: .kg)

        let suggestions = RuleEngine.evaluate(context: suggestionContext)
        let warmupDowngrade = flattenedChanges(from: suggestions).first(where: {
            $0.change.changeType == .changeSetType &&
            $0.change.newValue == Double(ExerciseSetType.warmup.rawValue) &&
            $0.draft.targetSetPrescription?.index == 0
        })

        #expect(warmupDowngrade == nil,
            "A feeder working set in a real ascending structure should not be downgraded to warmup")
    }

    @Test @MainActor
    func regularActingLikeWarmup_doesNotDemoteAscendingPyramidFeederWorkingSet() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 4, targetWeight: 100, targetReps: 8, targetRest: 90, repRangeMode: .range, lowerRange: 6, upperRange: 12)
        prescription.sortedSets[0].targetWeight = 60
        prescription.sortedSets[1].targetWeight = 90
        prescription.sortedSets[2].targetWeight = 100
        prescription.sortedSets[3].targetWeight = 90

        let previousSession = TestDataFactory.makeSession(context: context, daysAgo: 3)
        let previousPerformance = TestDataFactory.makePerformance(
            context: context,
            session: previousSession,
            prescription: prescription,
            sets: [
                (weight: 60, reps: 12, rest: 90, type: .working),
                (weight: 90, reps: 10, rest: 90, type: .working),
                (weight: 100, reps: 8, rest: 90, type: .working),
                (weight: 90, reps: 10, rest: 90, type: .working)
            ]
        )

        let currentSession = TestDataFactory.makeSession(context: context)
        let currentPerformance = TestDataFactory.makePerformance(
            context: context,
            session: currentSession,
            prescription: prescription,
            sets: [
                (weight: 60, reps: 12, rest: 90, type: .working),
                (weight: 90, reps: 10, rest: 90, type: .working),
                (weight: 100, reps: 8, rest: 90, type: .working),
                (weight: 90, reps: 10, rest: 90, type: .working)
            ]
        )

        let suggestionContext = ExerciseSuggestionContext(session: currentSession, performance: currentPerformance, prescription: prescription, history: [previousPerformance], plan: plan, resolvedTrainingStyle: .ascendingPyramid, weightUnit: .kg)

        let suggestions = RuleEngine.evaluate(context: suggestionContext)
        let warmupDowngrade = flattenedChanges(from: suggestions).first(where: {
            $0.change.changeType == .changeSetType &&
            $0.change.newValue == Double(ExerciseSetType.warmup.rawValue) &&
            $0.draft.targetSetPrescription?.index == 0
        })

        #expect(warmupDowngrade == nil,
            "A feeder working set in an ascending pyramid should not be downgraded to warmup")
    }

    @Test @MainActor
    func regularActingLikeWarmup_doesNotDemoteTopSetBackoffFeederWorkingSet() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 3, targetWeight: 200, targetReps: 6, targetRest: 120, repRangeMode: .target)
        prescription.sortedSets[0].targetWeight = 120
        prescription.sortedSets[1].targetWeight = 200
        prescription.sortedSets[2].targetWeight = 150

        let previousSession = TestDataFactory.makeSession(context: context, daysAgo: 3)
        let previousPerformance = TestDataFactory.makePerformance(
            context: context,
            session: previousSession,
            prescription: prescription,
            sets: [
                (weight: 120, reps: 8, rest: 90, type: .working),
                (weight: 200, reps: 6, rest: 120, type: .working),
                (weight: 150, reps: 10, rest: 120, type: .working)
            ]
        )

        let currentSession = TestDataFactory.makeSession(context: context)
        let currentPerformance = TestDataFactory.makePerformance(
            context: context,
            session: currentSession,
            prescription: prescription,
            sets: [
                (weight: 120, reps: 8, rest: 90, type: .working),
                (weight: 205, reps: 6, rest: 120, type: .working),
                (weight: 155, reps: 10, rest: 120, type: .working)
            ]
        )

        let suggestionContext = ExerciseSuggestionContext(session: currentSession, performance: currentPerformance, prescription: prescription, history: [previousPerformance], plan: plan, resolvedTrainingStyle: .topSetBackoffs, weightUnit: .kg)

        let suggestions = RuleEngine.evaluate(context: suggestionContext)
        let warmupDowngrade = flattenedChanges(from: suggestions).first(where: {
            $0.change.changeType == .changeSetType &&
            $0.change.newValue == Double(ExerciseSetType.warmup.rawValue) &&
            $0.draft.targetSetPrescription?.index == 0
        })

        #expect(warmupDowngrade == nil,
            "A feeder set in a top-set/backoff structure should not be downgraded to warmup")
    }

    @Test @MainActor
    func regularActingLikeWarmup_demotesIsolatedLightSetBeforeWorkingCluster() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 3, targetWeight: 100, targetReps: 8, targetRest: 90, repRangeMode: .range, lowerRange: 6, upperRange: 12)
        prescription.sortedSets[0].targetWeight = 50
        prescription.sortedSets[1].targetWeight = 100
        prescription.sortedSets[2].targetWeight = 100

        let previousSession = TestDataFactory.makeSession(context: context, daysAgo: 3)
        let previousPerformance = TestDataFactory.makePerformance(
            context: context,
            session: previousSession,
            prescription: prescription,
            sets: [
                (weight: 50, reps: 12, rest: 90, type: .working),
                (weight: 100, reps: 8, rest: 90, type: .working),
                (weight: 100, reps: 8, rest: 90, type: .working)
            ]
        )

        let currentSession = TestDataFactory.makeSession(context: context)
        let currentPerformance = TestDataFactory.makePerformance(
            context: context,
            session: currentSession,
            prescription: prescription,
            sets: [
                (weight: 50, reps: 12, rest: 90, type: .working),
                (weight: 100, reps: 8, rest: 90, type: .working),
                (weight: 100, reps: 8, rest: 90, type: .working)
            ]
        )

        let suggestionContext = ExerciseSuggestionContext(session: currentSession, performance: currentPerformance, prescription: prescription, history: [previousPerformance], plan: plan, resolvedTrainingStyle: .unknown, weightUnit: .kg)

        let suggestions = RuleEngine.evaluate(context: suggestionContext)
        let warmupDowngrade = flattenedChanges(from: suggestions).first(where: {
            $0.change.changeType == .changeSetType &&
            $0.change.newValue == Double(ExerciseSetType.warmup.rawValue) &&
            $0.draft.targetSetPrescription?.index == 0
        })

        #expect(warmupDowngrade != nil,
            "An isolated light first set before a stable heavy working cluster should still be eligible for warmup reclassification")
    }

    @Test @MainActor
    func warmupCalibration_increasesWarmupWeightWhenUserConsistentlyRampsHigher() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 2, targetWeight: 100, targetReps: 8, targetRest: 90, repRangeMode: .range, lowerRange: 6, upperRange: 10)
        prescription.sortedSets[0].type = .warmup
        prescription.sortedSets[0].targetWeight = 50

        let previousSession = TestDataFactory.makeSession(context: context, daysAgo: 3)
        let previousPerformance = TestDataFactory.makePerformance(context: context, session: previousSession, prescription: prescription, sets: [(weight: 60, reps: 8, rest: 60, type: .warmup), (weight: 100, reps: 8, rest: 90, type: .working)])

        let currentSession = TestDataFactory.makeSession(context: context)
        let currentPerformance = TestDataFactory.makePerformance(context: context, session: currentSession, prescription: prescription, sets: [(weight: 60, reps: 8, rest: 60, type: .warmup), (weight: 105, reps: 8, rest: 90, type: .working)])

        let suggestionContext = ExerciseSuggestionContext(session: currentSession, performance: currentPerformance, prescription: prescription, history: [previousPerformance], plan: plan, resolvedTrainingStyle: .straightSets, weightUnit: .kg)

        let suggestions = RuleEngine.evaluate(context: suggestionContext)
        let warmupChange = flattenedChanges(from: suggestions).first(where: { $0.draft.category == .warmupCalibration && $0.change.changeType == .increaseWeight && $0.draft.targetSetPrescription?.index == 0 })

        #expect(warmupChange != nil)
        #expect(warmupChange?.change.previousValue == 50)
        #expect(warmupChange?.change.newValue == 60)
    }

    @Test @MainActor
    func warmupCalibration_usesTopSetAnchorForTopSetBackoffStyle() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 3, targetWeight: 200, targetReps: 6, targetRest: 120, repRangeMode: .target)
        prescription.sortedSets[0].type = .warmup
        prescription.sortedSets[0].targetWeight = 100

        let previousSession = TestDataFactory.makeSession(context: context, daysAgo: 3)
        let previousPerformance = TestDataFactory.makePerformance(context: context, session: previousSession, prescription: prescription, sets: [(weight: 120, reps: 8, rest: 60, type: .warmup), (weight: 200, reps: 6, rest: 120, type: .working), (weight: 150, reps: 10, rest: 120, type: .working)])

        let currentSession = TestDataFactory.makeSession(context: context)
        let currentPerformance = TestDataFactory.makePerformance(context: context, session: currentSession, prescription: prescription, sets: [(weight: 120, reps: 8, rest: 60, type: .warmup), (weight: 205, reps: 6, rest: 120, type: .working), (weight: 155, reps: 10, rest: 120, type: .working)])

        let suggestionContext = ExerciseSuggestionContext(session: currentSession, performance: currentPerformance, prescription: prescription, history: [previousPerformance], plan: plan, resolvedTrainingStyle: .topSetBackoffs, weightUnit: .kg)

        let suggestions = RuleEngine.evaluate(context: suggestionContext)
        let warmupChange = flattenedChanges(from: suggestions).first(where: { $0.draft.category == .warmupCalibration && $0.change.changeType == .increaseWeight && $0.draft.targetSetPrescription?.index == 0 })

        #expect(warmupChange != nil)
        #expect(warmupChange?.change.newValue == 120)
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
        
        #expect(suggestions.contains { $0.targetSetPrescription == nil })
        #expect(exerciseChanges.contains { $0.changeType == .changeRepRangeMode })
        #expect(exerciseChanges.contains { $0.changeType == .increaseRepRangeLower && $0.newValue == 10 })
    }
    
    @Test @MainActor
    func targetRepRangeSuggestsRangeWhenRecentSessionsSpanABand() throws {
        let context = try TestDataFactory.makeContext()
        // 3 working sets so lowerMedian (median) can be >= target-1 even if one set is below.
        // This ensures confirmedProgressionTarget (allSatisfy reps >= target-1) doesn't fire
        // while still giving repEvidence a natural band of 7-10.
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 3, targetWeight: 100, targetReps: 8, targetRest: 90, repRangeMode: .target)
        prescription.repRange?.targetReps = 8

        // session1 (oldest): all sets above target
        let session1 = TestDataFactory.makeSession(context: context, daysAgo: 6)
        session1.statusValue = .done
        _ = TestDataFactory.makePerformance(context: context, session: session1, prescription: prescription, sets: [
            (weight: 100, reps: 8, rest: 90, type: .working),
            (weight: 100, reps: 9, rest: 90, type: .working),
            (weight: 100, reps: 10, rest: 90, type: .working)
        ])

        // session2: one set below target-1 → confirmedProgressionTarget allSatisfy fails → doesn't fire
        let session2 = TestDataFactory.makeSession(context: context, daysAgo: 3)
        session2.statusValue = .done
        _ = TestDataFactory.makePerformance(context: context, session: session2, prescription: prescription, sets: [
            (weight: 100, reps: 6, rest: 90, type: .working),
            (weight: 100, reps: 8, rest: 90, type: .working),
            (weight: 100, reps: 10, rest: 90, type: .working)
        ])

        // current session: floor=7 → robustFloor median of [7,6,8]=7 → desiredRange.lower=7
        let session3 = TestDataFactory.makeSession(context: context)
        let perf3 = TestDataFactory.makePerformance(context: context, session: session3, prescription: prescription, sets: [
            (weight: 100, reps: 7, rest: 90, type: .working),
            (weight: 100, reps: 8, rest: 90, type: .working),
            (weight: 100, reps: 10, rest: 90, type: .working)
        ])

        let suggestionContext = ExerciseSuggestionContext(session: session3, performance: perf3, prescription: prescription, history: [session2.sortedExercises.first!, session1.sortedExercises.first!], plan: plan, resolvedTrainingStyle: .straightSets, weightUnit: .kg)
        let suggestions = RuleEngine.evaluate(context: suggestionContext)
        let exerciseChanges = exerciseLevelChanges(from: suggestions)

        #expect(suggestions.contains { $0.targetSetPrescription == nil })
        #expect(exerciseChanges.contains { $0.changeType == .changeRepRangeMode })
        #expect(exerciseChanges.contains { $0.changeType == .increaseRepRangeLower && $0.newValue == 7 })
        #expect(exerciseChanges.contains { $0.changeType == .decreaseRepRangeUpper && $0.newValue == 10 })
    }

    @Test @MainActor
    func targetRepRangeSuggestsRangeFromRepeatedWithinSessionBand() throws {
        let context = try TestDataFactory.makeContext()
        // 3 working sets so lowerMedian (median of set reps) can be >= target-1 even if the
        // lowest set is below target-1, preventing confirmedProgressionTarget from firing.
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 3, targetWeight: 100, targetReps: 8, targetRest: 90, repRangeMode: .target)
        prescription.repRange?.targetReps = 8

        // session1 (oldest): all sets satisfying target-1
        let session1 = TestDataFactory.makeSession(context: context, daysAgo: 6)
        session1.statusValue = .done
        _ = TestDataFactory.makePerformance(context: context, session: session1, prescription: prescription, sets: [
            (weight: 100, reps: 8, rest: 90, type: .working),
            (weight: 100, reps: 8, rest: 90, type: .working),
            (weight: 100, reps: 10, rest: 90, type: .working)
        ])

        // session2: one set at 6 (below target-1=7) so confirmedProgressionTarget allSatisfy fails
        let session2 = TestDataFactory.makeSession(context: context, daysAgo: 3)
        session2.statusValue = .done
        _ = TestDataFactory.makePerformance(context: context, session: session2, prescription: prescription, sets: [
            (weight: 100, reps: 6, rest: 90, type: .working),
            (weight: 100, reps: 8, rest: 90, type: .working),
            (weight: 100, reps: 10, rest: 90, type: .working)
        ])

        // current: floor=7 → robustFloor median of [7,6,8]=7 → desiredRange.lower=7
        let session3 = TestDataFactory.makeSession(context: context)
        let perf3 = TestDataFactory.makePerformance(context: context, session: session3, prescription: prescription, sets: [
            (weight: 100, reps: 7, rest: 90, type: .working),
            (weight: 100, reps: 8, rest: 90, type: .working),
            (weight: 100, reps: 10, rest: 90, type: .working)
        ])

        let suggestionContext = ExerciseSuggestionContext(session: session3, performance: perf3, prescription: prescription, history: [session2.sortedExercises.first!, session1.sortedExercises.first!], plan: plan, resolvedTrainingStyle: .straightSets, weightUnit: .kg)
        let suggestions = RuleEngine.evaluate(context: suggestionContext)
        let exerciseChanges = exerciseLevelChanges(from: suggestions)

        #expect(suggestions.contains { $0.targetSetPrescription == nil })
        #expect(exerciseChanges.contains { $0.changeType == .changeRepRangeMode })
        #expect(exerciseChanges.contains { $0.changeType == .decreaseRepRangeUpper && $0.newValue == 10 })
        #expect(exerciseChanges.contains { $0.changeType == .increaseRepRangeLower && $0.newValue == 7 })
    }

    @Test @MainActor
    func targetRepRangeRobustFittingIgnoresSingleHighOutlierSet() throws {
        let context = try TestDataFactory.makeContext()
        // 3 working sets so lowerMedian can be >= target-1 even when one set is below,
        // preventing confirmedProgressionTarget from firing (same strategy as the other range tests).
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 3, targetWeight: 100, targetReps: 8, targetRest: 90, repRangeMode: .target)
        prescription.repRange?.targetReps = 8

        // session1 (oldest): outlier at 15. Robust fitting should ignore it → upper=10 not 15.
        let session1 = TestDataFactory.makeSession(context: context, daysAgo: 6)
        session1.statusValue = .done
        _ = TestDataFactory.makePerformance(context: context, session: session1, prescription: prescription, sets: [
            (weight: 100, reps: 7, rest: 90, type: .working),
            (weight: 100, reps: 10, rest: 90, type: .working),
            (weight: 100, reps: 15, rest: 90, type: .working)
        ])

        // session2: one set at 6 → confirmedProgressionTarget allSatisfy fails → doesn't block range
        let session2 = TestDataFactory.makeSession(context: context, daysAgo: 3)
        session2.statusValue = .done
        _ = TestDataFactory.makePerformance(context: context, session: session2, prescription: prescription, sets: [
            (weight: 100, reps: 6, rest: 90, type: .working),
            (weight: 100, reps: 8, rest: 90, type: .working),
            (weight: 100, reps: 10, rest: 90, type: .working)
        ])

        // current: floor=7 → robustFloor median of [7,6,7]=7 → desiredRange.lower=7
        let session3 = TestDataFactory.makeSession(context: context)
        let perf3 = TestDataFactory.makePerformance(context: context, session: session3, prescription: prescription, sets: [
            (weight: 100, reps: 7, rest: 90, type: .working),
            (weight: 100, reps: 8, rest: 90, type: .working),
            (weight: 100, reps: 10, rest: 90, type: .working)
        ])

        let suggestionContext = ExerciseSuggestionContext(session: session3, performance: perf3, prescription: prescription, history: [session2.sortedExercises.first!, session1.sortedExercises.first!], plan: plan, resolvedTrainingStyle: .straightSets, weightUnit: .kg)
        let suggestions = RuleEngine.evaluate(context: suggestionContext)
        let exerciseChanges = exerciseLevelChanges(from: suggestions)

        #expect(suggestions.contains { $0.targetSetPrescription == nil })
        #expect(exerciseChanges.contains { $0.changeType == .decreaseRepRangeUpper && $0.newValue == 10 })
        #expect(exerciseChanges.contains { $0.changeType == .increaseRepRangeUpper && $0.newValue == 15 } == false)
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
        
        #expect(suggestions.contains { $0.targetSetPrescription != nil })
        #expect(suggestions.contains { $0.targetSetPrescription == nil } == false)
    }
    
    @Test @MainActor
    func pendingSuggestionEventsAndGroupingUseEventAsGroupUnit() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 1, targetWeight: 135, targetReps: 10, repRangeMode: .range, lowerRange: 8, upperRange: 12)
        guard let set = prescription.sortedSets.first else {
            Issue.record("Expected plan set for grouping test.")
            return
        }
        
        let event = SuggestionEvent(catalogID: prescription.catalogID, sessionFrom: nil, targetExercisePrescription: prescription, targetSetPrescription: set, triggerTargetSetID: set.id, triggerPerformanceSnapshot: ExercisePerformanceSnapshot(date: .now, notes: "", repRange: RepRangeSnapshot(policy: prescription.repRange), sets: []), triggerTargetSnapshot: ExerciseTargetSnapshot(prescription: prescription), trainingStyle: .straightSets, changes: [])
        context.insert(event)
        
        let weightChange = PrescriptionChange(event: event, changeType: .increaseWeight, previousValue: 135, newValue: 140)
        let repChange = PrescriptionChange(event: event, changeType: .decreaseReps, previousValue: 10, newValue: 8)
        event.changes = [weightChange, repChange]
        prescription.suggestionEvents = [event]
        set.suggestionEvents = [event]
        
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

        let change = PrescriptionChange(changeType: .increaseWeight, previousValue: 95, newValue: 100)
        let event = SuggestionEvent(catalogID: prescription.catalogID, sessionFrom: nil, targetExercisePrescription: prescription, targetSetPrescription: setPrescription, triggerTargetSetID: setPrescription.id, triggerPerformanceSnapshot: ExercisePerformanceSnapshot(date: .now, notes: "", repRange: RepRangeSnapshot(policy: prescription.repRange), sets: []), triggerTargetSnapshot: ExerciseTargetSnapshot(prescription: prescription), trainingStyle: .straightSets, changes: [change])

        let matched = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: performance, trainingStyle: .straightSets)
        #expect(matched?.outcome == .good)

        set.prescription = nil

        let withoutLiveLink = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: performance, trainingStyle: .straightSets)
        #expect(withoutLiveLink == nil)
    }

    @Test @MainActor
    func outcomeRuleEngine_warmupCalibrationGoodWhenFollowedAndStillWarmup() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 2, targetWeight: 100, targetReps: 8, targetRest: 90, repRangeMode: .target)
        prescription.sortedSets[0].type = .warmup
        prescription.sortedSets[0].targetWeight = 50

        let workout = WorkoutSession(from: plan)
        context.insert(workout)

        guard let performance = workout.sortedExercises.first,
              performance.sortedSets.count >= 2,
              let warmupPrescription = prescription.sortedSets.first else {
            Issue.record("Expected plan-backed performance with warmup and working sets.")
            return
        }

        let warmupSet = performance.sortedSets[0]
        let workingSet = performance.sortedSets[1]
        warmupSet.type = .warmup
        warmupSet.weight = 60
        warmupSet.reps = 8
        warmupSet.complete = true

        workingSet.type = .working
        workingSet.weight = 100
        workingSet.reps = 8
        workingSet.complete = true

        let change = PrescriptionChange(changeType: .increaseWeight, previousValue: 50, newValue: 60)
        let event = SuggestionEvent(category: .warmupCalibration, catalogID: prescription.catalogID, sessionFrom: nil, targetExercisePrescription: prescription, targetSetPrescription: warmupPrescription, triggerTargetSetID: warmupPrescription.id, triggerPerformanceSnapshot: ExercisePerformanceSnapshot(date: .now, notes: "", repRange: RepRangeSnapshot(policy: prescription.repRange), sets: []), triggerTargetSnapshot: ExerciseTargetSnapshot(prescription: prescription), trainingStyle: .straightSets, changes: [change])

        let result = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: performance, trainingStyle: .straightSets)
        #expect(result?.outcome == .good)
    }

    @Test @MainActor
    func outcomeRuleEngine_warmupCalibrationTooAggressiveWhenWarmupBecomesTooHeavy() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 2, targetWeight: 100, targetReps: 8, targetRest: 90, repRangeMode: .target)
        prescription.sortedSets[0].type = .warmup
        prescription.sortedSets[0].targetWeight = 50

        let workout = WorkoutSession(from: plan)
        context.insert(workout)

        guard let performance = workout.sortedExercises.first,
              performance.sortedSets.count >= 2,
              let warmupPrescription = prescription.sortedSets.first else {
            Issue.record("Expected plan-backed performance with warmup and working sets.")
            return
        }

        let warmupSet = performance.sortedSets[0]
        let workingSet = performance.sortedSets[1]
        warmupSet.type = .warmup
        warmupSet.weight = 95
        warmupSet.reps = 8
        warmupSet.complete = true

        workingSet.type = .working
        workingSet.weight = 100
        workingSet.reps = 8
        workingSet.complete = true

        let change = PrescriptionChange(changeType: .increaseWeight, previousValue: 50, newValue: 60)
        let event = SuggestionEvent(category: .warmupCalibration, catalogID: prescription.catalogID, sessionFrom: nil, targetExercisePrescription: prescription, targetSetPrescription: warmupPrescription, triggerTargetSetID: warmupPrescription.id, triggerPerformanceSnapshot: ExercisePerformanceSnapshot(date: .now, notes: "", repRange: RepRangeSnapshot(policy: prescription.repRange), sets: []), triggerTargetSnapshot: ExerciseTargetSnapshot(prescription: prescription), trainingStyle: .straightSets, changes: [change])

        let result = OutcomeRuleEngine.evaluate(change: change, event: event, exercisePerf: performance, trainingStyle: .straightSets)
        #expect(result?.outcome == .tooAggressive)
    }

    @Test @MainActor
    func suggestionDeduplicator_keepsPerformanceAndRecoveryForSameSet() throws {
        let context = try TestDataFactory.makeContext()
        let (_, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 1, targetWeight: 100, targetReps: 8, targetRest: 90, repRangeMode: .target)
        guard let set = prescription.sortedSets.first else {
            Issue.record("Expected set.")
            return
        }

        let performance = SuggestionEventDraft(
            category: .performance,
            targetExercisePrescription: prescription,
            targetSetPrescription: set,
            changes: [PrescriptionChangeDraft(changeType: .increaseWeight, previousValue: 100, newValue: 102.5)]
        )
        let recovery = SuggestionEventDraft(
            category: .recovery,
            targetExercisePrescription: prescription,
            targetSetPrescription: set,
            changes: [PrescriptionChangeDraft(changeType: .increaseRest, previousValue: 90, newValue: 105)]
        )

        let result = SuggestionDeduplicator.process(suggestions: [performance, recovery])
        #expect(result.count == 2)
        #expect(Set(result.map(\.category)) == Set([.performance, .recovery]))
    }

    @Test @MainActor
    func suggestionDeduplicator_allowsWorkingSetReclassificationWithPerformanceForSameSet() throws {
        let context = try TestDataFactory.makeContext()
        let (_, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 1, targetWeight: 100, targetReps: 8, repRangeMode: .target)
        guard let set = prescription.sortedSets.first else {
            Issue.record("Expected set.")
            return
        }

        let structure = SuggestionEventDraft(
            category: .structure,
            targetExercisePrescription: prescription,
            targetSetPrescription: set,
            changes: [PrescriptionChangeDraft(changeType: .changeSetType, previousValue: Double(ExerciseSetType.warmup.rawValue), newValue: Double(ExerciseSetType.working.rawValue))]
        )
        let performance = SuggestionEventDraft(
            category: .performance,
            targetExercisePrescription: prescription,
            targetSetPrescription: set,
            changes: [PrescriptionChangeDraft(changeType: .increaseWeight, previousValue: 100, newValue: 102.5)]
        )

        let result = SuggestionDeduplicator.process(suggestions: [performance, structure])
        #expect(result.count == 2)
        #expect(Set(result.map(\.category)) == Set([.structure, .performance]))
    }

    @Test @MainActor
    func suggestionDeduplicator_structureToWarmupStillSuppressesPerformanceForSameSet() throws {
        let context = try TestDataFactory.makeContext()
        let (_, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 1, targetWeight: 100, targetReps: 8, repRangeMode: .target)
        guard let set = prescription.sortedSets.first else {
            Issue.record("Expected set.")
            return
        }

        let structure = SuggestionEventDraft(
            category: .structure,
            targetExercisePrescription: prescription,
            targetSetPrescription: set,
            changes: [PrescriptionChangeDraft(changeType: .changeSetType, previousValue: Double(ExerciseSetType.working.rawValue), newValue: Double(ExerciseSetType.warmup.rawValue))]
        )
        let performance = SuggestionEventDraft(
            category: .performance,
            targetExercisePrescription: prescription,
            targetSetPrescription: set,
            changes: [PrescriptionChangeDraft(changeType: .increaseWeight, previousValue: 100, newValue: 102.5)]
        )

        let result = SuggestionDeduplicator.process(suggestions: [performance, structure])
        #expect(result.count == 1)
        #expect(result.first?.category == .structure)
    }

    @Test @MainActor
    func suggestionDeduplicator_prefersStrongerEvidenceForSameRecoveryChange() throws {
        let context = try TestDataFactory.makeContext()
        let (_, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 1, targetWeight: 100, targetReps: 8, targetRest: 90, repRangeMode: .target)
        guard let set = prescription.sortedSets.first else {
            Issue.record("Expected set.")
            return
        }

        let plateauDriven = SuggestionEventDraft(
            category: .recovery,
            targetExercisePrescription: prescription,
            targetSetPrescription: set,
            ruleID: .stagnationIncreaseRest,
            evidenceStrength: .heuristic,
            changeReasoning: "Progress has plateaued.",
            changes: [PrescriptionChangeDraft(changeType: .increaseRest, previousValue: 90, newValue: 120)]
        )
        let directRecovery = SuggestionEventDraft(
            category: .recovery,
            targetExercisePrescription: prescription,
            targetSetPrescription: set,
            ruleID: .shortRestPerformanceDrop,
            evidenceStrength: .directTargetEvidence,
            changeReasoning: "Your rest periods are repeatedly shorter than prescribed.",
            changes: [PrescriptionChangeDraft(changeType: .increaseRest, previousValue: 90, newValue: 105)]
        )

        let result = SuggestionDeduplicator.process(suggestions: [plateauDriven, directRecovery])
        #expect(result.count == 1)
        #expect(result.first?.ruleID == .shortRestPerformanceDrop)
        #expect(result.first?.changes.first?.newValue == 105)
    }

    @Test @MainActor
    func suggestionDeduplicator_prefersLargerIncreaseWhenEvidenceStrengthIsEqual() throws {
        let context = try TestDataFactory.makeContext()
        let (_, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 1, targetWeight: 100, targetReps: 8, targetRest: 90, repRangeMode: .target)
        guard let set = prescription.sortedSets.first else {
            Issue.record("Expected set.")
            return
        }

        let smallerIncrease = SuggestionEventDraft(
            category: .recovery,
            targetExercisePrescription: prescription,
            targetSetPrescription: set,
            ruleID: .stagnationIncreaseRest,
            evidenceStrength: .pattern,
            changeReasoning: "Smaller increase.",
            changes: [PrescriptionChangeDraft(changeType: .increaseRest, previousValue: 90, newValue: 105)]
        )
        let largerIncrease = SuggestionEventDraft(
            category: .recovery,
            targetExercisePrescription: prescription,
            targetSetPrescription: set,
            ruleID: .shortRestPerformanceDrop,
            evidenceStrength: .pattern,
            changeReasoning: "Larger increase.",
            changes: [PrescriptionChangeDraft(changeType: .increaseRest, previousValue: 90, newValue: 120)]
        )

        let result = SuggestionDeduplicator.process(suggestions: [smallerIncrease, largerIncrease])
        #expect(result.count == 1)
        #expect(result.first?.changes.first?.newValue == 120)
    }

    @Test @MainActor
    func acceptGroup_hydratesPendingSessionSetValuesAndSnapshot() throws {
        let context = try TestDataFactory.makeContext()
        let settings = AppSettings()
        settings.weightUnit = .kg
        context.insert(settings)

        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 1, targetWeight: 100, targetReps: 8, targetRest: 90, repRangeMode: .range, lowerRange: 6, upperRange: 10)
        let workout = WorkoutSession(from: plan)
        workout.statusValue = .pending
        context.insert(workout)

        guard let performance = workout.sortedExercises.first,
              let setPrescription = prescription.sortedSets.first,
              let setPerformance = performance.sortedSets.first else {
            Issue.record("Expected pending plan-backed session with one linked set.")
            return
        }

        let weightChange = PrescriptionChange(changeType: .increaseWeight, previousValue: 100, newValue: 102.5)
        let repsChange = PrescriptionChange(changeType: .decreaseReps, previousValue: 8.0, newValue: 6.0)
        let event = SuggestionEvent(
            category: .performance,
            catalogID: prescription.catalogID,
            sessionFrom: nil,
            targetExercisePrescription: prescription,
            targetSetPrescription: setPrescription,
            triggerTargetSetID: setPrescription.id,
            triggerPerformanceSnapshot: .empty,
            triggerTargetSnapshot: ExerciseTargetSnapshot(prescription: prescription),
            trainingStyle: .straightSets,
            changes: [weightChange, repsChange]
        )
        context.insert(event)

        acceptGroup(SuggestionGroup(event: event), context: context)

        #expect(event.decision == .accepted)
        #expect(setPrescription.targetWeight == 102.5)
        #expect(setPrescription.targetReps == 6)
        #expect(setPerformance.weight == 102.5)
        #expect(setPerformance.reps == 6)
        #expect(performance.originalTargetSnapshot?.sets.first?.targetWeight == 102.5)
        #expect(performance.originalTargetSnapshot?.sets.first?.targetReps == 6)
    }

    @Test @MainActor
    func acceptGroup_hydratesPendingSessionRepRangeAndSnapshot() throws {
        let context = try TestDataFactory.makeContext()
        let settings = AppSettings()
        settings.weightUnit = .kg
        context.insert(settings)

        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 1, targetWeight: 100, targetReps: 8, targetRest: 90, repRangeMode: .range, lowerRange: 6, upperRange: 10)
        let workout = WorkoutSession(from: plan)
        workout.statusValue = .pending
        context.insert(workout)

        guard let performance = workout.sortedExercises.first else {
            Issue.record("Expected pending plan-backed exercise performance.")
            return
        }

        let lowerChange = PrescriptionChange(changeType: .increaseRepRangeLower, previousValue: 6.0, newValue: 8.0)
        let upperChange = PrescriptionChange(changeType: .increaseRepRangeUpper, previousValue: 10.0, newValue: 12.0)
        let event = SuggestionEvent(
            category: .repRangeConfiguration,
            catalogID: prescription.catalogID,
            sessionFrom: nil,
            targetExercisePrescription: prescription,
            triggerPerformanceSnapshot: .empty,
            triggerTargetSnapshot: ExerciseTargetSnapshot(prescription: prescription),
            trainingStyle: .straightSets,
            changes: [lowerChange, upperChange]
        )
        context.insert(event)

        acceptGroup(SuggestionGroup(event: event), context: context)

        #expect(event.decision == .accepted)
        #expect(prescription.repRange?.lowerRange == 8)
        #expect(prescription.repRange?.upperRange == 12)
        #expect(performance.repRange?.lowerRange == 8)
        #expect(performance.repRange?.upperRange == 12)
        #expect(performance.originalTargetSnapshot?.repRange.lower == 8)
        #expect(performance.originalTargetSnapshot?.repRange.upper == 12)
    }

    @Test @MainActor
    func acceptGroup_hydratesPendingSessionSetTypeAndClearsWarmupRPE() throws {
        let context = try TestDataFactory.makeContext()
        let settings = AppSettings()
        settings.weightUnit = .kg
        context.insert(settings)

        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 1, targetWeight: 100, targetReps: 8, targetRest: 90, repRangeMode: .target)
        let workout = WorkoutSession(from: plan)
        workout.statusValue = .pending
        context.insert(workout)

        guard let performance = workout.sortedExercises.first,
              let setPrescription = prescription.sortedSets.first,
              let setPerformance = performance.sortedSets.first else {
            Issue.record("Expected pending plan-backed session with one linked set.")
            return
        }

        setPerformance.rpe = 8

        let change = PrescriptionChange(changeType: .changeSetType, previousValue: Double(ExerciseSetType.working.rawValue), newValue: Double(ExerciseSetType.warmup.rawValue))
        let event = SuggestionEvent(
            category: .structure,
            catalogID: prescription.catalogID,
            sessionFrom: nil,
            targetExercisePrescription: prescription,
            targetSetPrescription: setPrescription,
            triggerTargetSetID: setPrescription.id,
            triggerPerformanceSnapshot: .empty,
            triggerTargetSnapshot: ExerciseTargetSnapshot(prescription: prescription),
            trainingStyle: .straightSets,
            changes: [change]
        )
        context.insert(event)

        acceptGroup(SuggestionGroup(event: event), context: context)

        #expect(event.decision == .accepted)
        #expect(setPrescription.type == .warmup)
        #expect(setPerformance.type == .warmup)
        #expect(setPerformance.rpe == 0)
        #expect(performance.originalTargetSnapshot?.sets.first?.type == .warmup)
    }

    @Test @MainActor
    func generateSuggestions_blocksSetScopedPerformanceWhenUnresolvedPerformanceExists() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 1, targetWeight: 100, targetReps: 10, targetRest: 90, repRangeMode: .range, lowerRange: 8, upperRange: 10)
        prescription.musclesTargeted = [.chest]
        prescription.equipmentType = .barbell

        guard let setPrescription = prescription.sortedSets.first else {
            Issue.record("Expected set prescription.")
            return
        }

        let priorEvent = SuggestionEvent(
            category: .performance,
            catalogID: prescription.catalogID,
            sessionFrom: nil,
            targetExercisePrescription: prescription,
            targetSetPrescription: setPrescription,
            triggerTargetSetID: setPrescription.id,
            decision: .accepted,
            outcome: .pending,
            triggerPerformanceSnapshot: ExercisePerformanceSnapshot(date: .now, notes: "", repRange: RepRangeSnapshot(policy: prescription.repRange), sets: []),
            triggerTargetSnapshot: ExerciseTargetSnapshot(prescription: prescription),
            trainingStyle: .straightSets,
            changes: [PrescriptionChange(changeType: .increaseWeight, previousValue: 100, newValue: 102.5)]
        )
        context.insert(priorEvent)

        let workout = WorkoutSession(from: plan)
        context.insert(workout)
        workout.statusValue = .summary

        guard let performance = workout.sortedExercises.first,
              let set = performance.sortedSets.first else {
            Issue.record("Expected plan-backed performance with one set.")
            return
        }

        set.weight = 100
        set.reps = 13
        set.restSeconds = 90
        set.complete = true

        let generated = await SuggestionGenerator.generateSuggestions(for: workout, context: context)
        #expect(generated.isEmpty)
    }

    @Test @MainActor
    func generateSuggestions_blocksSetScopedPerformanceWhenUnresolvedStructureExists() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 1, targetWeight: 100, targetReps: 10, targetRest: 90, repRangeMode: .range, lowerRange: 8, upperRange: 10)
        prescription.musclesTargeted = [.chest]
        prescription.equipmentType = .barbell

        guard let setPrescription = prescription.sortedSets.first else {
            Issue.record("Expected set prescription.")
            return
        }

        let priorEvent = SuggestionEvent(
            category: .structure,
            catalogID: prescription.catalogID,
            sessionFrom: nil,
            targetExercisePrescription: prescription,
            targetSetPrescription: setPrescription,
            triggerTargetSetID: setPrescription.id,
            decision: .accepted,
            outcome: .pending,
            triggerPerformanceSnapshot: ExercisePerformanceSnapshot(date: .now, notes: "", repRange: RepRangeSnapshot(policy: prescription.repRange), sets: []),
            triggerTargetSnapshot: ExerciseTargetSnapshot(prescription: prescription),
            trainingStyle: .straightSets,
            changes: [PrescriptionChange(changeType: .changeSetType, previousValue: Double(ExerciseSetType.warmup.rawValue), newValue: Double(ExerciseSetType.working.rawValue))]
        )
        context.insert(priorEvent)

        let workout = WorkoutSession(from: plan)
        context.insert(workout)
        workout.statusValue = .summary

        guard let performance = workout.sortedExercises.first,
              let set = performance.sortedSets.first else {
            Issue.record("Expected plan-backed performance with one set.")
            return
        }

        set.weight = 100
        set.reps = 13
        set.restSeconds = 90
        set.complete = true

        let generated = await SuggestionGenerator.generateSuggestions(for: workout, context: context)
        #expect(generated.isEmpty)
    }

    // MARK: - confirmedProgressionTarget / immediateProgressionTarget (Issue 2-A fix)

    /// Two sessions, both at target - 1 reps: confirmedProgressionTarget should fire.
    /// Before the fix, `>= target` was required, so a session at reps=7 (target=8) was blocked.
    /// After the fix, `>= target - 1` mirrors the `upper - 1` softening in confirmedProgressionRange.
    @Test @MainActor
    func confirmedProgressionTarget_firesWhenAllSetsAtTargetMinusOne_twoSessions() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(
            context: context, workingSets: 1, targetWeight: 100, targetReps: 8,
            targetRest: 90, repRangeMode: .target
        )
        // targetReps on RepRangePolicy defaults to 8; confirm explicitly.
        prescription.repRange?.targetReps = 8

        // Prior session: athlete hit target - 1 (reps = 7), marked done so history fetch picks it up.
        let priorSession = TestDataFactory.makeSession(context: context, daysAgo: 3)
        priorSession.statusValue = .done
        _ = TestDataFactory.makePerformance(
            context: context, session: priorSession, prescription: prescription,
            sets: [(weight: 100, reps: 7, rest: 90, type: .working)]
        )

        // Current session: same — reps = 7 (target - 1).
        let workout = WorkoutSession(from: plan)
        context.insert(workout)
        workout.statusValue = .summary
        guard let perf = workout.sortedExercises.first, let set = perf.sortedSets.first else {
            Issue.record("Expected plan-backed performance with one set.")
            return
        }
        set.weight = 100
        set.reps = 7
        set.restSeconds = 90
        set.complete = true

        let generated = await SuggestionGenerator.generateSuggestions(for: workout, context: context)

        let hasWeightIncrease = generated.contains { $0.sortedChanges.contains { $0.changeType == .increaseWeight } }
        #expect(hasWeightIncrease,
            "confirmedProgressionTarget should fire when both sessions are at target-1 (reps=7, target=8)")
    }

    /// Two sessions where reps are well below target — confirmedProgressionTarget must not fire.
    @Test @MainActor
    func confirmedProgressionTarget_doesNotFire_whenSetsFarBelowTarget() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(
            context: context, workingSets: 1, targetWeight: 100, targetReps: 8,
            targetRest: 90, repRangeMode: .target
        )
        prescription.repRange?.targetReps = 8

        // Prior session: reps = 5, well below target - 1 = 7.
        let priorSession = TestDataFactory.makeSession(context: context, daysAgo: 3)
        priorSession.statusValue = .done
        _ = TestDataFactory.makePerformance(
            context: context, session: priorSession, prescription: prescription,
            sets: [(weight: 100, reps: 5, rest: 90, type: .working)]
        )

        let workout = WorkoutSession(from: plan)
        context.insert(workout)
        workout.statusValue = .summary
        guard let perf = workout.sortedExercises.first, let set = perf.sortedSets.first else {
            Issue.record("Expected plan-backed performance with one set.")
            return
        }
        set.weight = 100
        set.reps = 5
        set.restSeconds = 90
        set.complete = true

        let generated = await SuggestionGenerator.generateSuggestions(for: workout, context: context)

        let hasWeightIncrease = generated.contains { $0.sortedChanges.contains { $0.changeType == .increaseWeight } }
        #expect(!hasWeightIncrease,
            "confirmedProgressionTarget must not fire when reps (5) are far below target-1 (7)")
    }

    // MARK: - Issue 2-B: matchActualWeight fixes

    /// Regression test for the 2-A/2-B target-mode sync gap:
    /// progressionWeightChangeIndices.overshootInBoth now uses >= target-1 (matching confirmedProgressionTarget).
    /// With reps at target-1 and weights consistently above prescription, only the progression
    /// suggestion (increaseWeight by one increment) should fire — NOT matchActualWeight's update
    /// to the actual weights used.
    @Test @MainActor
    func matchActualWeight_doesNotSuggestActualWeight_whenProgressionRulesBlockIt() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(
            context: context, workingSets: 1, targetWeight: 100, targetReps: 8,
            targetRest: 90, repRangeMode: .target
        )
        prescription.repRange?.targetReps = 8

        // Three sessions: all at reps=7 (target-1), all at weight=110 (> target+2.5).
        // overshootInBoth fires → progressionWeightChangeIndices blocks matchActualWeight.
        let oldest = TestDataFactory.makeSession(context: context, daysAgo: 6)
        let oldestPerf = TestDataFactory.makePerformance(context: context, session: oldest, prescription: prescription, sets: [(weight: 110, reps: 7, rest: 90, type: .working)])

        let previous = TestDataFactory.makeSession(context: context, daysAgo: 3)
        let previousPerf = TestDataFactory.makePerformance(context: context, session: previous, prescription: prescription, sets: [(weight: 110, reps: 7, rest: 90, type: .working)])

        let current = TestDataFactory.makeSession(context: context)
        let currentPerf = TestDataFactory.makePerformance(context: context, session: current, prescription: prescription, sets: [(weight: 110, reps: 7, rest: 90, type: .working)])

        let suggestionContext = ExerciseSuggestionContext(session: current, performance: currentPerf, prescription: prescription, history: [previousPerf, oldestPerf], plan: plan, resolvedTrainingStyle: .straightSets, weightUnit: .kg)

        let suggestions = RuleEngine.evaluate(context: suggestionContext)
        let hasMatchActualWeightSuggestion = flattenedChanges(from: suggestions)
            .contains { $0.change.changeType == .increaseWeight && $0.change.newValue == 110.0 }
        #expect(!hasMatchActualWeightSuggestion,
            "matchActualWeight must not suggest updating to actual weight (110) when progressionWeightChangeIndices already blocks the set")
    }

    /// Stability filter: three sessions with monotonically trending weights (spread > one increment)
    /// must not trigger matchActualWeight — the athlete is in active progression, not settled at a new load.
    @Test @MainActor
    func matchActualWeight_doesNotFire_whenWeightsTrending() throws {
        let context = try TestDataFactory.makeContext()
        // Range mode so no progression rule fires — isolates the stability filter behaviour.
        let (plan, prescription) = TestDataFactory.makePrescription(
            context: context, workingSets: 1, targetWeight: 100, targetReps: 8,
            targetRest: 90, repRangeMode: .range, lowerRange: 6, upperRange: 12
        )

        // Weights trending upward: [107.5, 110, 112.5] → spread=5.0 > increment=2.5 (barbell bench).
        let oldest = TestDataFactory.makeSession(context: context, daysAgo: 6)
        let oldestPerf = TestDataFactory.makePerformance(context: context, session: oldest, prescription: prescription, sets: [(weight: 107.5, reps: 8, rest: 90, type: .working)])

        let previous = TestDataFactory.makeSession(context: context, daysAgo: 3)
        let previousPerf = TestDataFactory.makePerformance(context: context, session: previous, prescription: prescription, sets: [(weight: 110, reps: 8, rest: 90, type: .working)])

        let current = TestDataFactory.makeSession(context: context)
        let currentPerf = TestDataFactory.makePerformance(context: context, session: current, prescription: prescription, sets: [(weight: 112.5, reps: 8, rest: 90, type: .working)])

        let suggestionContext = ExerciseSuggestionContext(session: current, performance: currentPerf, prescription: prescription, history: [previousPerf, oldestPerf], plan: plan, resolvedTrainingStyle: .straightSets, weightUnit: .kg)

        let suggestions = RuleEngine.evaluate(context: suggestionContext)
        let hasWeightChange = flattenedChanges(from: suggestions).contains { $0.change.changeType == .increaseWeight || $0.change.changeType == .decreaseWeight }
        #expect(!hasWeightChange,
            "matchActualWeight must not fire for trending weights (spread=5.0 > increment=2.5); athlete is in active progression")
    }

    /// Median replaces average: stable weights skewed high ([110, 112.5, 112.5]) should produce
    /// a suggestion of 112.5 (median), not 111.25 (roundToNearestPlate of average ≈ 111.67).
    @Test @MainActor
    func matchActualWeight_usesMedian_notAverage() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(
            context: context, workingSets: 1, targetWeight: 100, targetReps: 8,
            targetRest: 90, repRangeMode: .range, lowerRange: 6, upperRange: 12
        )

        // Weights: [110, 112.5, 112.5] — spread=2.5 == increment=2.5 → passes stability filter.
        // median=112.5, average≈111.67 → roundToNearestPlate(111.67)=111.25.
        let oldest = TestDataFactory.makeSession(context: context, daysAgo: 6)
        let oldestPerf = TestDataFactory.makePerformance(context: context, session: oldest, prescription: prescription, sets: [(weight: 110, reps: 8, rest: 90, type: .working)])

        let previous = TestDataFactory.makeSession(context: context, daysAgo: 3)
        let previousPerf = TestDataFactory.makePerformance(context: context, session: previous, prescription: prescription, sets: [(weight: 112.5, reps: 8, rest: 90, type: .working)])

        let current = TestDataFactory.makeSession(context: context)
        let currentPerf = TestDataFactory.makePerformance(context: context, session: current, prescription: prescription, sets: [(weight: 112.5, reps: 8, rest: 90, type: .working)])

        let suggestionContext = ExerciseSuggestionContext(session: current, performance: currentPerf, prescription: prescription, history: [previousPerf, oldestPerf], plan: plan, resolvedTrainingStyle: .straightSets, weightUnit: .kg)

        let suggestions = RuleEngine.evaluate(context: suggestionContext)
        let weightChange = flattenedChanges(from: suggestions).first(where: { $0.change.changeType == .increaseWeight && $0.change.previousValue == 100 })
        #expect(weightChange != nil, "matchActualWeight should fire for stable weights all above target")
        #expect(weightChange?.change.newValue == 112.5,
            "matchActualWeight should use median (112.5), not average-rounded (111.25)")
    }

    /// Single session at exactly the target (reps = target) — immediateProgressionTarget requires
    /// reps >= target + 1, so no weight increase should be suggested.
    @Test @MainActor
    func immediateProgressionTarget_doesNotFire_whenOnlyAtTarget() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(
            context: context, workingSets: 1, targetWeight: 100, targetReps: 8,
            targetRest: 90, repRangeMode: .target
        )
        prescription.repRange?.targetReps = 8

        // No prior history — single session at exactly target (8), not target + 1 (9).
        let workout = WorkoutSession(from: plan)
        context.insert(workout)
        workout.statusValue = .summary
        guard let perf = workout.sortedExercises.first, let set = perf.sortedSets.first else {
            Issue.record("Expected plan-backed performance with one set.")
            return
        }
        set.weight = 100
        set.reps = 8  // exactly target, not target + 1
        set.restSeconds = 90
        set.complete = true

        let generated = await SuggestionGenerator.generateSuggestions(for: workout, context: context)

        let hasWeightIncrease = generated.contains { $0.sortedChanges.contains { $0.changeType == .increaseWeight } }
        #expect(!hasWeightIncrease,
            "immediateProgressionTarget requires reps >= target+1; exactly at target must not trigger a weight increase")
    }
}
