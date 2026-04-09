import Foundation
import SwiftData
import Testing

@testable import VillainArc

struct WeightConversionTests {
    @Test func roundedWeightDisplayValue_limitsCopiedDisplayPrecision() {
        let roundedLbsValue = roundedWeightDisplayValue(12.5, unit: .lbs)
        #expect(roundedLbsValue == 27.56)

        let roundedKgValue = roundedWeightDisplayValue(12.3456, unit: .kg)
        #expect(roundedKgValue == 12.35)
    }

    @Test @MainActor func workoutSessionWeightRoundTrip_preservesCanonicalKg() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, _) = TestDataFactory.makePrescription(context: context, workingSets: 1, targetWeight: 100)
        let workout = WorkoutSession(from: plan)
        context.insert(workout)

        guard let set = workout.sortedExercises.first?.sortedSets.first else {
            Issue.record("Expected a plan-backed set.")
            return
        }

        #expect(abs(set.weight - 100) < 0.001)

        workout.convertSetWeightsFromKg(to: .lbs)
        #expect(abs(set.weight - 220.462) < 0.01)

        workout.convertSetWeightsToKg(from: .lbs)
        #expect(abs(set.weight - 100) < 0.01)
    }

    @Test @MainActor func workoutPlanWeightSaveConvertsUserEnteredLbsBackToKg() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 1, targetWeight: 100)

        plan.convertTargetWeightsFromKg(to: .lbs)
        #expect(abs(prescription.sortedSets[0].targetWeight - 220.462) < 0.01)

        prescription.sortedSets[0].targetWeight = 225
        plan.convertTargetWeightsToKg(from: .lbs)

        #expect(abs(prescription.sortedSets[0].targetWeight - 102.0582) < 0.01)
    }

    @Test @MainActor func freeformExerciseAddSetCopiesCurrentDisplayedWeightWithoutConvertingAgain() throws {
        let context = try TestDataFactory.makeContext()
        let workout = WorkoutSession()
        context.insert(workout)

        let exercise = ExercisePerformance(exercise: Exercise(from: ExerciseCatalog.byID["barbell_bench_press"]!), workoutSession: workout)
        context.insert(exercise)
        workout.exercises?.append(exercise)

        guard let firstSet = exercise.sortedSets.first else {
            Issue.record("Expected the auto-created first set.")
            return
        }

        firstSet.weight = 225
        firstSet.reps = 8
        firstSet.restSeconds = 90

        exercise.addSet(unit: .lbs)

        guard exercise.sortedSets.count == 2 else {
            Issue.record("Expected a copied second set.")
            return
        }

        let copiedSet = exercise.sortedSets[1]
        #expect(abs(copiedSet.weight - 225) < 0.001)
        #expect(copiedSet.reps == 8)
        #expect(copiedSet.restSeconds == 90)
    }

    @Test @MainActor func workoutFinishConvertsDisplayedLbsBackToCanonicalKgBeforeSave() throws {
        let context = try TestDataFactory.makeContext()
        let settings = AppSettings()
        settings.weightUnit = .lbs
        context.insert(settings)

        let workout = WorkoutSession()
        context.insert(workout)

        let exercise = ExercisePerformance(exercise: Exercise(from: ExerciseCatalog.byID["barbell_bench_press"]!), workoutSession: workout)
        context.insert(exercise)
        workout.exercises?.append(exercise)

        guard let set = exercise.sortedSets.first else {
            Issue.record("Expected the auto-created first set.")
            return
        }

        set.weight = 225
        set.reps = 8
        set.complete = true
        set.completedAt = Date()

        let result = workout.finish(action: .finish, context: context)

        #expect(result == .finished)
        #expect(workout.statusValue == .summary)

        let weightUnit = AppSettingsSnapshot(settings: (try? context.fetch(AppSettings.single))?.first).weightUnit
        workout.convertSetWeightsToKg(from: weightUnit)
        saveContext(context: context)

        let savedWorkout = try context.fetch(WorkoutSession.incomplete).first
        let savedSet = savedWorkout?.sortedExercises.first?.sortedSets.first

        #expect(abs((savedSet?.weight ?? 0) - 102.0582) < 0.01)
    }
}
