import SwiftData
import Foundation
import Testing
@testable import VillainArc

struct SuggestionSystemTests {

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
        let (plan, prescription) = TestDataFactory.makePrescription(
            context: context,
            workingSets: 3,
            targetWeight: 200,
            targetReps: 8,
            repRangeMode: .target
        )
        prescription.repRange.targetReps = 8
        prescription.musclesTargeted = [.chest]
        prescription.equipmentType = .barbell

        // Build 2 sessions where user exceeded target by 1+ rep
        let session1 = TestDataFactory.makeSession(context: context, daysAgo: 3)
        let perf1 = TestDataFactory.makePerformance(context: context, session: session1, prescription: prescription, sets: [
            (weight: 200, reps: 10, rest: 90, type: .working),
            (weight: 200, reps: 10, rest: 90, type: .working),
            (weight: 150, reps: 12, rest: 90, type: .working),
        ])

        let session2 = TestDataFactory.makeSession(context: context)
        let perf2 = TestDataFactory.makePerformance(context: context, session: session2, prescription: prescription, sets: [
            (weight: 200, reps: 10, rest: 90, type: .working),
            (weight: 200, reps: 10, rest: 90, type: .working),
            (weight: 150, reps: 12, rest: 90, type: .working),
        ])

        // Evaluate with straight sets style
        let straightContext = ExerciseSuggestionContext(session: session2, performance: perf2, prescription: prescription, history: [perf1], plan: plan, resolvedTrainingStyle: .straightSets)
        let straightSuggestions = RuleEngine.evaluate(context: straightContext)
        let straightWeightChanges = straightSuggestions.filter { $0.changeType == .increaseWeight }

        // Evaluate with top set backoffs style
        let topSetContext = ExerciseSuggestionContext(session: session2, performance: perf2, prescription: prescription, history: [perf1], plan: plan, resolvedTrainingStyle: .topSetBackoffs)
        let topSetSuggestions = RuleEngine.evaluate(context: topSetContext)
        let topSetWeightChanges = topSetSuggestions.filter { $0.changeType == .increaseWeight }

        // Both should produce weight increases
        #expect(straightWeightChanges.count == 3)
        #expect(topSetWeightChanges.count == 3)

        let straightValues = straightWeightChanges.compactMap(\.newValue)
        let topSetValues = topSetWeightChanges.compactMap(\.newValue)
        #expect(straightValues.allSatisfy { $0 == 205 })
        #expect(topSetValues.allSatisfy { $0 == 207.5 })
    }

    // MARK: - Volume Regression Rule Tests

    @Test @MainActor
    func volumeRegression_firesWhen3SessionsShort() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 4, targetWeight: 135, targetReps: 8)

        // 3 sessions where user only completes 3 of 4 prescribed working sets
        var history: [ExercisePerformance] = []
        for daysAgo in [3, 5, 7] {
            let session = TestDataFactory.makeSession(context: context, daysAgo: daysAgo)
            let perf = TestDataFactory.makePerformance(context: context, session: session, prescription: prescription, sets: [
                (weight: 135, reps: 8, rest: 90, type: .working),
                (weight: 135, reps: 7, rest: 90, type: .working),
                (weight: 135, reps: 6, rest: 90, type: .working),
            ])
            history.append(perf)
        }

        let currentSession = TestDataFactory.makeSession(context: context)
        let currentPerf = TestDataFactory.makePerformance(context: context, session: currentSession, prescription: prescription, sets: [
            (weight: 135, reps: 8, rest: 90, type: .working),
            (weight: 135, reps: 7, rest: 90, type: .working),
            (weight: 135, reps: 6, rest: 90, type: .working),
        ])

        let suggestionContext = ExerciseSuggestionContext(session: currentSession, performance: currentPerf, prescription: prescription, history: history, plan: plan, resolvedTrainingStyle: .straightSets)

        let suggestions = RuleEngine.evaluate(context: suggestionContext)
        let removeSetSuggestions = suggestions.filter { $0.changeType == .removeSet }

        #expect(removeSetSuggestions.count == 1)
        #expect(removeSetSuggestions.first?.previousValue == 4)
        #expect(removeSetSuggestions.first?.newValue == 3)
    }

    @Test @MainActor
    func volumeRegression_doesNotFireWhenSetsMatch() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 3, targetWeight: 135, targetReps: 8)

        // 3 sessions where user completes all 3 prescribed working sets
        var history: [ExercisePerformance] = []
        for daysAgo in [3, 5, 7] {
            let session = TestDataFactory.makeSession(context: context, daysAgo: daysAgo)
            let perf = TestDataFactory.makePerformance(context: context, session: session, prescription: prescription, sets: [
                (weight: 135, reps: 8, rest: 90, type: .working),
                (weight: 135, reps: 8, rest: 90, type: .working),
                (weight: 135, reps: 8, rest: 90, type: .working),
            ])
            history.append(perf)
        }

        let currentSession = TestDataFactory.makeSession(context: context)
        let currentPerf = TestDataFactory.makePerformance(context: context, session: currentSession, prescription: prescription, sets: [
            (weight: 135, reps: 8, rest: 90, type: .working),
            (weight: 135, reps: 8, rest: 90, type: .working),
            (weight: 135, reps: 8, rest: 90, type: .working),
        ])

        let suggestionContext = ExerciseSuggestionContext(session: currentSession, performance: currentPerf, prescription: prescription, history: history, plan: plan, resolvedTrainingStyle: .straightSets)

        let suggestions = RuleEngine.evaluate(context: suggestionContext)
        let removeSetSuggestions = suggestions.filter { $0.changeType == .removeSet }

        #expect(removeSetSuggestions.isEmpty)
    }

    @Test @MainActor
    func volumeRegression_doesNotFireWithFewerThan3PrescribedSets() throws {
        let context = try TestDataFactory.makeContext()
        // Only 2 working sets prescribed — should not suggest removing
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 2, targetWeight: 135, targetReps: 8)

        var history: [ExercisePerformance] = []
        for daysAgo in [3, 5, 7] {
            let session = TestDataFactory.makeSession(context: context, daysAgo: daysAgo)
            let perf = TestDataFactory.makePerformance(context: context, session: session, prescription: prescription, sets: [
                (weight: 135, reps: 8, rest: 90, type: .working),
            ])
            history.append(perf)
        }

        let currentSession = TestDataFactory.makeSession(context: context)
        let currentPerf = TestDataFactory.makePerformance(context: context, session: currentSession, prescription: prescription, sets: [
            (weight: 135, reps: 8, rest: 90, type: .working),
        ])

        let suggestionContext = ExerciseSuggestionContext(session: currentSession, performance: currentPerf, prescription: prescription, history: history, plan: plan, resolvedTrainingStyle: .straightSets)

        let suggestions = RuleEngine.evaluate(context: suggestionContext)
        let removeSetSuggestions = suggestions.filter { $0.changeType == .removeSet }

        #expect(removeSetSuggestions.isEmpty)
    }

    // MARK: - Outcome Rule Engine: removeSet

    @Test @MainActor
    func outcomeRuleEngine_removeSet_good_whenUserCompletesReducedCount() throws {
        let context = try TestDataFactory.makeContext()
        let (_, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 4, targetWeight: 135, targetReps: 8)

        let session = TestDataFactory.makeSession(context: context)
        let perf = TestDataFactory.makePerformance(context: context, session: session, prescription: prescription, sets: [
            (weight: 135, reps: 8, rest: 90, type: .working),
            (weight: 135, reps: 8, rest: 90, type: .working),
            (weight: 135, reps: 8, rest: 90, type: .working),
        ])

        let change = PrescriptionChange(catalogID: prescription.catalogID, targetExercisePrescription: prescription, changeType: .removeSet, previousValue: 4, newValue: 3)

        let signal = OutcomeRuleEngine.evaluate(change: change, exercisePerf: perf)

        #expect(signal != nil)
        #expect(signal?.outcome == .good)
    }

    @Test @MainActor
    func outcomeRuleEngine_removeSet_ignored_whenUserCompletesOriginalCount() throws {
        let context = try TestDataFactory.makeContext()
        let (_, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 4, targetWeight: 135, targetReps: 8)

        let session = TestDataFactory.makeSession(context: context)
        let perf = TestDataFactory.makePerformance(context: context, session: session, prescription: prescription, sets: [
            (weight: 135, reps: 8, rest: 90, type: .working),
            (weight: 135, reps: 8, rest: 90, type: .working),
            (weight: 135, reps: 8, rest: 90, type: .working),
            (weight: 135, reps: 8, rest: 90, type: .working),
        ])

        let change = PrescriptionChange(catalogID: prescription.catalogID, targetExercisePrescription: prescription, changeType: .removeSet, previousValue: 4, newValue: 3)

        let signal = OutcomeRuleEngine.evaluate(change: change, exercisePerf: perf)

        #expect(signal != nil)
        #expect(signal?.outcome == .ignored)
    }

    // MARK: - Deduplicator: removeSet

    @Test @MainActor
    func deduplicator_removeSet_survivesDedupe() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context)

        let session = TestDataFactory.makeSession(context: context)

        let change = PrescriptionChange(source: .rules, catalogID: prescription.catalogID, sessionFrom: session, targetExercisePrescription: prescription, targetPlan: plan, changeType: .removeSet, previousValue: 4, newValue: 3)
        context.insert(change)

        let result = SuggestionDeduplicator.process(suggestions: [change])

        #expect(result.count == 1)
        #expect(result.first?.changeType == .removeSet)
    }

    @Test @MainActor
    func deduplicator_removeSet_notConflictWithWeightChange() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context)
        let session = TestDataFactory.makeSession(context: context)

        let removeChange = PrescriptionChange(source: .rules, catalogID: prescription.catalogID, sessionFrom: session, targetExercisePrescription: prescription, targetPlan: plan, changeType: .removeSet, previousValue: 4, newValue: 3)
        context.insert(removeChange)

        let weightChange = PrescriptionChange(source: .rules, catalogID: prescription.catalogID, sessionFrom: session, targetExercisePrescription: prescription, targetSetPrescription: prescription.sortedSets.first, targetPlan: plan, changeType: .increaseWeight, previousValue: 135, newValue: 140)
        context.insert(weightChange)

        let result = SuggestionDeduplicator.process(suggestions: [removeChange, weightChange])

        // Both should survive since they target different properties
        #expect(result.count == 2)
    }

    // MARK: - ChangeType.policy for removeSet

    @Test
    func changeType_removeSet_hasStructurePolicy() {
        #expect(ChangeType.removeSet.policy == .structure)
    }

}

