import SwiftData
import Testing
@testable import VillainArc

struct ExerciseHistoryMetricsTests {
    @Test @MainActor
    func recalculateTracksRepBasedMetricsForBodyweightExercise() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)

        let session = WorkoutSession(status: .done)
        context.insert(session)

        let exercise = Exercise(from: ExerciseCatalog.byID["push_ups"]!)
        let performance = ExercisePerformance(exercise: exercise, workoutSession: session)
        context.insert(performance)
        session.exercises?.append(performance)

        for set in performance.sets ?? [] {
            context.delete(set)
        }
        performance.sets?.removeAll()

        let firstSet = SetPerformance(exercise: performance, setType: .working, weight: 0, reps: 24, restSeconds: 60, index: 0, complete: true)
        let secondSet = SetPerformance(exercise: performance, setType: .working, weight: 0, reps: 18, restSeconds: 60, index: 1, complete: true)
        context.insert(firstSet)
        context.insert(secondSet)
        performance.sets?.append(firstSet)
        performance.sets?.append(secondSet)

        let history = ExerciseHistory(catalogID: performance.catalogID)
        history.recalculate(using: [performance])

        #expect(history.totalSessions == 1)
        #expect(history.totalCompletedSets == 2)
        #expect(history.totalCompletedReps == 42)
        #expect(history.cumulativeVolume == 0)
        #expect(history.bestWeight == 0)
        #expect(history.bestVolume == 0)
        #expect(history.bestReps == 24)
        #expect(history.sortedProgressionPoints.count == 1)
        #expect(history.sortedProgressionPoints.first?.totalReps == 42)
        #expect(history.sortedProgressionPoints.first?.weight == 0)
        #expect(history.sortedProgressionPoints.first?.volume == 0)
    }
}
