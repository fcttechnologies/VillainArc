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
        prescription.repRange?.targetReps = 8
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

        // Straight sets progresses every working set.
        #expect(straightWeightChanges.count == 3)

        // Top-set/backoff style should only progress the heavy cluster, not the lighter backoff set.
        #expect(topSetWeightChanges.count == 2)

        let straightValues = straightWeightChanges.compactMap(\.newValue)
        let topSetValues = topSetWeightChanges.compactMap(\.newValue)
        #expect(straightValues.allSatisfy { $0 == 205 })
        #expect(topSetValues.allSatisfy { $0 == 207.5 })

        let topSetIndices = Set(topSetWeightChanges.compactMap { $0.targetSetPrescription?.index })
        #expect(topSetIndices == Set([0, 1]))
    }

    @Test @MainActor
    func generatedSuggestionsAttachTargetPlan() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(
            context: context,
            workingSets: 3,
            targetWeight: 200,
            targetReps: 8,
            repRangeMode: .target
        )
        prescription.repRange?.targetReps = 8
        prescription.musclesTargeted = [.chest]
        prescription.equipmentType = .barbell

        let previousSession = TestDataFactory.makeSession(context: context, daysAgo: 3)
        previousSession.statusValue = .done
        _ = TestDataFactory.makePerformance(context: context, session: previousSession, prescription: prescription, sets: [
            (weight: 200, reps: 10, rest: 90, type: .working),
            (weight: 200, reps: 10, rest: 90, type: .working),
            (weight: 200, reps: 10, rest: 90, type: .working),
        ])

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
        #expect(generated.allSatisfy { $0.targetPlan?.id == plan.id })
        #expect(generated.allSatisfy { $0.sessionFrom?.id == workout.id })
    }

}
