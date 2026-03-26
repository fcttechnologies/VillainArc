import Foundation
import SwiftData
import Testing

@testable import VillainArc

struct SpotlightSummaryTests {
    @Test @MainActor func workoutSessionSpotlightSummaryUsesPlainSetCount() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)
        let session = WorkoutSession(title: "Push")
        context.insert(session)
        let bench = Exercise(from: ExerciseCatalog.byID["barbell_bench_press"]!)
        session.addExercise(bench)
        guard let performance = session.sortedExercises.first else {
            Issue.record("Expected one exercise performance")
            return
        }
        performance.addSet()  // total sets = 2

        let summary = session.spotlightSummary
        #expect(summary.contains("2x \(performance.name)"))
        #expect(summary.contains("Optional(") == false)
    }
    @Test @MainActor func workoutPlanSpotlightSummaryUsesPlainSetCount() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)
        let plan = WorkoutPlan(title: "Leg Day")
        context.insert(plan)
        let squat = Exercise(from: ExerciseCatalog.byID["barbell_squat"]!)
        let prescription = ExercisePrescription(exercise: squat, workoutPlan: plan)
        prescription.addSet()  // total sets = 2
        plan.exercises = [prescription]
        let summary = plan.spotlightSummary
        #expect(summary.contains("2x \(prescription.name)"))
        #expect(summary.contains("Optional(") == false)
    }
}
