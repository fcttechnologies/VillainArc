import Foundation
import SwiftData
import Testing

@testable import VillainArc

struct WorkoutActiveExerciseTests {
    @MainActor
    private func makePlanBackedSession(context: ModelContext) -> WorkoutSession {
        let plan = WorkoutPlan(title: "Push Day")
        context.insert(plan)

        let bench = ExercisePrescription(exercise: Exercise(from: ExerciseCatalog.byID["barbell_bench_press"]!), workoutPlan: plan)
        bench.sets = [
            SetPrescription(exercisePrescription: bench, setType: .working, targetWeight: 135, targetReps: 8, targetRest: 90, index: 0),
            SetPrescription(exercisePrescription: bench, setType: .working, targetWeight: 135, targetReps: 8, targetRest: 90, index: 1),
        ]

        let press = ExercisePrescription(exercise: Exercise(from: ExerciseCatalog.byID["barbell_squat"]!), workoutPlan: plan)
        press.index = 1
        press.sets = [
            SetPrescription(exercisePrescription: press, setType: .working, targetWeight: 95, targetReps: 8, targetRest: 90, index: 0)
        ]

        plan.exercises = [bench, press]

        let session = WorkoutSession(from: plan)
        context.insert(session)
        session.activeExercise = session.sortedExercises.first
        return session
    }

    @Test @MainActor
    func completingLastSetOfPlanExerciseAdvancesActiveExercise() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)
        let session = makePlanBackedSession(context: context)
        let firstExercise = try #require(session.sortedExercises.first)
        let secondExercise = try #require(session.sortedExercises.dropFirst().first)

        session.completeSet(firstExercise.sortedSets[0])
        #expect(session.activeExercise?.id == firstExercise.id)

        session.completeSet(firstExercise.sortedSets[1])
        #expect(session.activeExercise?.id == secondExercise.id)
    }

    @Test @MainActor
    func completingLastSetOfStandaloneExerciseDoesNotAdvanceActiveExercise() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)
        let session = WorkoutSession()
        context.insert(session)

        let bench = ExercisePerformance(exercise: Exercise(from: ExerciseCatalog.byID["barbell_bench_press"]!), workoutSession: session)
        let squat = ExercisePerformance(exercise: Exercise(from: ExerciseCatalog.byID["barbell_squat"]!), workoutSession: session)
        squat.index = 1
        context.insert(bench)
        context.insert(squat)
        session.exercises = [bench, squat]
        session.activeExercise = bench

        session.completeSet(try #require(bench.sortedSets.first))

        #expect(session.activeExercise?.id == bench.id)
    }
}
