import Foundation
import Testing

@testable import VillainArc

struct WorkoutPlanShareSummaryTests {
    @Test @MainActor
    func statsIncludePlanTargetsAndCompletedRuns() {
        let plan = samplePlan()

        let stats = WorkoutPlanShareSummary.stats(for: plan, completedSessionCount: 3, weightUnit: .kg)

        #expect(stats.map(\.id) == ["exercises", "sets", "volume", "runs"])
        #expect(stats[0].value == "1")
        #expect(stats[1].value == "2")
        #expect(stats[2].value == "1,300 kg")
        #expect(stats[3].value == "3")
    }

    @Test @MainActor
    func exerciseDetailUsesTargetSetWithHighestVolume() {
        let plan = samplePlan()
        let exercise = plan.sortedExercises[0]

        #expect(WorkoutPlanShareSummary.exerciseDetail(for: exercise, weightUnit: .kg) == "2 sets - 10 x 80 kg")
    }

    @MainActor
    private func samplePlan() -> WorkoutPlan {
        let plan = WorkoutPlan(title: "Upper Power", completed: true)
        let exercise = ExercisePrescription(exercise: Exercise(from: ExerciseCatalog.byID["barbell_bench_press"]!), workoutPlan: plan)

        let firstSet = exercise.sortedSets[0]
        firstSet.targetWeight = 100
        firstSet.targetReps = 5

        let secondSet = SetPrescription(exercisePrescription: exercise, setType: .working, targetWeight: 80, targetReps: 10, index: 1)
        exercise.sets?.append(secondSet)
        plan.exercises?.append(exercise)

        return plan
    }
}
