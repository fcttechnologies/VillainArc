import Foundation
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
        let sessionStart = Date(timeIntervalSince1970: 1_000)
        let firstCompletedAt = sessionStart.addingTimeInterval(120)
        let secondCompletedAt = sessionStart.addingTimeInterval(240)
        performance.date = sessionStart
        context.insert(performance)
        session.exercises?.append(performance)

        for set in performance.sets ?? [] {
            context.delete(set)
        }
        performance.sets?.removeAll()

        let firstSet = SetPerformance(exercise: performance, setType: .working, weight: 0, reps: 24, restSeconds: 60, index: 0, complete: true, completedAt: firstCompletedAt)
        let secondSet = SetPerformance(exercise: performance, setType: .working, weight: 0, reps: 18, restSeconds: 60, index: 1, complete: true, completedAt: secondCompletedAt)
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
        #expect(history.lastCompletedAt == secondCompletedAt)
        #expect(history.sortedProgressionPoints.count == 1)
        #expect(history.sortedProgressionPoints.first?.date == secondCompletedAt)
        #expect(history.sortedProgressionPoints.first?.totalReps == 42)
        #expect(history.sortedProgressionPoints.first?.weight == 0)
        #expect(history.sortedProgressionPoints.first?.volume == 0)
    }
    
    @Test @MainActor
    func recalculateResetsLastCompletedAtWhenHistoryIsEmpty() {
        let history = ExerciseHistory(catalogID: "push_ups")
        history.lastCompletedAt = .now
        
        history.recalculate(using: [])
        
        #expect(history.lastCompletedAt == nil)
    }

    @Test @MainActor
    func recalculateCollapsesDuplicateExerciseRowsFromSameWorkoutIntoOneSession() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)

        let session = WorkoutSession(status: .done)
        context.insert(session)

        let exercise = Exercise(from: ExerciseCatalog.byID["barbell_bench_press"]!)
        let firstPerformance = ExercisePerformance(exercise: exercise, workoutSession: session)
        let secondPerformance = ExercisePerformance(exercise: exercise, workoutSession: session)
        context.insert(firstPerformance)
        context.insert(secondPerformance)
        session.exercises?.append(firstPerformance)
        session.exercises?.append(secondPerformance)

        for performance in [firstPerformance, secondPerformance] {
            for set in performance.sets ?? [] {
                context.delete(set)
            }
            performance.sets?.removeAll()
        }

        let firstSet = SetPerformance(exercise: firstPerformance, setType: .working, weight: 185, reps: 5, restSeconds: 120, index: 0, complete: true)
        let secondSet = SetPerformance(exercise: secondPerformance, setType: .working, weight: 165, reps: 8, restSeconds: 120, index: 0, complete: true)
        context.insert(firstSet)
        context.insert(secondSet)
        firstPerformance.sets?.append(firstSet)
        secondPerformance.sets?.append(secondSet)

        let history = ExerciseHistory(catalogID: firstPerformance.catalogID)
        let expectedVolume = (185.0 * 5.0) + (165.0 * 8.0)
        history.recalculate(using: [firstPerformance, secondPerformance])

        #expect(history.totalSessions == 1)
        #expect(history.totalCompletedSets == 2)
        #expect(history.totalCompletedReps == 13)
        #expect(history.cumulativeVolume == expectedVolume)
        #expect(history.bestWeight == 185)
        #expect(history.bestVolume == expectedVolume)
        #expect(history.bestReps == 8)
        #expect(history.lastCompletedAt != nil)
        #expect(history.sortedProgressionPoints.count == 1)
        #expect(history.sortedProgressionPoints.first?.totalReps == 13)
        #expect(history.sortedProgressionPoints.first?.weight == 185)
        #expect(history.sortedProgressionPoints.first?.volume == expectedVolume)
    }
}
