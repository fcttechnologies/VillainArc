import Foundation
import Testing

@testable import VillainArc

struct WorkoutShareSummaryTests {
    @Test @MainActor
    func statsIncludeStrengthTotalsAndEffort() {
        let workout = sampleWorkout()
        workout.postEffort = 8

        let stats = WorkoutShareSummary.stats(for: workout, weightUnit: .kg)

        #expect(stats.map(\.id) == ["exercises", "sets", "volume", "effort"])
        #expect(stats[0].value == "1")
        #expect(stats[1].value == "2")
        #expect(stats[2].value == "1,300 kg")
        #expect(stats[3].value == "8/10")
    }

    @Test @MainActor
    func exerciseDetailUsesCompletedSetsAndTopVolumeSet() {
        let workout = sampleWorkout()
        let exercise = workout.sortedExercises[0]

        #expect(WorkoutShareSummary.exerciseDetail(for: exercise, weightUnit: .kg) == "2 sets - 10 x 80 kg")
    }

    @MainActor
    private func sampleWorkout() -> WorkoutSession {
        let workout = WorkoutSession(title: "Push Day", status: .done, startedAt: Date(timeIntervalSince1970: 0), endedAt: Date(timeIntervalSince1970: 3_600))
        let exercise = ExercisePerformance(exercise: Exercise(from: ExerciseCatalog.byID["barbell_bench_press"]!), workoutSession: workout)

        let firstSet = exercise.sortedSets[0]
        firstSet.weight = 100
        firstSet.reps = 5
        firstSet.complete = true

        let secondSet = SetPerformance(exercise: exercise, setType: .working, weight: 80, reps: 10, index: 1, complete: true)
        exercise.sets?.append(secondSet)
        workout.exercises?.append(exercise)

        return workout
    }
}
