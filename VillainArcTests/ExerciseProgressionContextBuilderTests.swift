import Foundation
import SwiftData
import Testing
@testable import VillainArc

struct ExerciseProgressionContextBuilderTests {
    @Test @MainActor
    func buildReturnsNilBelowMinimumSessionThreshold() throws {
        let context = try TestDataFactory.makeContext()
        let exercise = Exercise(from: ExerciseCatalog.byID["barbell_bench_press"]!)
        let history = ExerciseHistory(catalogID: exercise.catalogID)
        history.totalSessions = ExerciseProgressionContextBuilder.minimumSessionCount - 1

        let session = WorkoutSession(status: .done)
        context.insert(session)
        let performance = ExercisePerformance(exercise: exercise, workoutSession: session)
        context.insert(performance)
        session.exercises?.append(performance)

        let result = ExerciseProgressionContextBuilder.build(
            exercise: exercise,
            history: history,
            performances: [performance]
        )

        #expect(result == nil)
    }

    @Test @MainActor
    func buildCapsRecentPerformancesAndPreservesNewestFirst() throws {
        let context = try TestDataFactory.makeContext()
        let exercise = Exercise(from: ExerciseCatalog.byID["barbell_bench_press"]!)
        let history = ExerciseHistory(catalogID: exercise.catalogID)
        history.totalSessions = 8
        history.latestEstimated1RM = 250
        history.bestEstimated1RM = 265
        history.bestWeight = 225
        history.bestReps = 10

        var performances: [ExercisePerformance] = []

        for daysAgo in 0..<7 {
            let session = WorkoutSession(status: .done, startedAt: Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)!)
            context.insert(session)
            let performance = ExercisePerformance(exercise: exercise, workoutSession: session)
            performance.date = session.startedAt
            context.insert(performance)
            session.exercises?.append(performance)
            performances.append(performance)
        }

        let result = ExerciseProgressionContextBuilder.build(
            exercise: exercise,
            history: history,
            performances: performances.shuffled(),
            starterQuestion: "Am I stalling?"
        )

        #expect(result != nil)
        #expect(result?.historySummary.totalSessions == 8)
        #expect(result?.historySummary.bestWeight == 225)
        #expect(result?.recentPerformances.count == ExerciseProgressionContextBuilder.maximumRecentPerformances)
        #expect(result?.starterQuestion == "Am I stalling?")

        let sortedDates = result?.recentPerformances.map(\.date) ?? []
        #expect(sortedDates == sortedDates.sorted(by: >))
    }
}
