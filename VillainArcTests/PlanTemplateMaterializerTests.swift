import Foundation
import SwiftData
import Testing

@testable import VillainArc

struct PlanTemplateMaterializerTests {
    @Test @MainActor
    // Materializing a single template day should produce an incomplete WorkoutPlan with the
    // template's notes, target-rep range, set count, rest, and RPE — and a zero target weight so
    // the user fills loads themselves.
    func makeIncompletePlan_copiesTemplateExercisesToPrescription() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)
        try seedCatalog(into: context)

        let template = PlanTemplate(
            id: "test_ppl",
            name: "Test Push",
            summary: "Test summary",
            icon: "figure.strengthtraining.traditional",
            level: .intermediate,
            days: [
                PlanTemplateDay(
                    id: "test_push",
                    name: "Push",
                    muscleGroups: [.chest, .triceps],
                    notes: "Heavy compound first.",
                    exercises: [
                        .init("barbell_bench_press", sets: 4, repsLow: 6, repsHigh: 8, restSeconds: 180, rpe: 8),
                        .init("dumbbell_lateral_raises", sets: 3, reps: 15, restSeconds: 60, rpe: 9),
                    ]
                )
            ]
        )

        let plan = PlanTemplateMaterializer.makeIncompletePlan(template: template, day: template.trainingDays[0], context: context)

        #expect(plan.completed == false)
        #expect(plan.notes == "Heavy compound first.")
        let prescriptions = plan.sortedExercises
        #expect(prescriptions.count == 2)

        // First exercise: rep range 6...8 with 4 working sets, no target weight, RPE 8, rest 180.
        let bench = prescriptions[0]
        #expect(bench.catalogID == "barbell_bench_press")
        #expect(bench.repRange?.activeMode == .range)
        #expect(bench.repRange?.lowerRange == 6)
        #expect(bench.repRange?.upperRange == 8)
        let benchSets = bench.sortedSets
        #expect(benchSets.count == 4)
        #expect(benchSets.allSatisfy { $0.targetWeight == 0 })
        #expect(benchSets.allSatisfy { $0.targetReps == 8 })
        #expect(benchSets.allSatisfy { $0.targetRest == 180 })
        #expect(benchSets.allSatisfy { $0.targetRPE == 8 })

        // Second exercise: fixed-rep 15 (low == high → target mode), 3 working sets.
        let lateral = prescriptions[1]
        #expect(lateral.catalogID == "dumbbell_lateral_raises")
        #expect(lateral.repRange?.activeMode == .target)
        #expect(lateral.repRange?.targetReps == 15)
        let lateralSets = lateral.sortedSets
        #expect(lateralSets.count == 3)
        #expect(lateralSets.allSatisfy { $0.targetReps == 15 })
        #expect(lateralSets.allSatisfy { $0.targetRest == 60 })
    }

    @Test @MainActor
    // Materializing a full program should create one completed WorkoutPlan per training day, a
    // rotation split linking each day, and activate the new split when `activate: true`.
    func materializeProgram_buildsAllPlansAndActiveSplit() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)
        try seedCatalog(into: context)

        let template = PlanTemplate(
            id: "test_ul",
            name: "Test Upper/Lower",
            summary: "Two days",
            icon: "figure.strengthtraining.traditional",
            level: .beginner,
            days: [
                PlanTemplateDay(
                    id: "test_upper",
                    name: "Upper",
                    muscleGroups: [.chest, .back],
                    exercises: [.init("barbell_bench_press", sets: 3, reps: 8, restSeconds: 120, rpe: 8)]
                ),
                PlanTemplateDay(
                    id: "test_lower",
                    name: "Lower",
                    muscleGroups: [.quads, .hamstrings],
                    exercises: [.init("barbell_squat", sets: 3, reps: 8, restSeconds: 180, rpe: 8)]
                ),
            ]
        )

        let split = PlanTemplateMaterializer.materializeProgram(template: template, activate: true, context: context)
        #expect(split.title == "Test Upper/Lower")
        #expect(split.mode == .rotation)
        #expect(split.isActive == true)

        let days = split.sortedDays
        #expect(days.count == 2)
        #expect(days.allSatisfy { $0.workoutPlan != nil })
        #expect(days.allSatisfy { $0.workoutPlan?.completed == true })
        #expect(days[0].workoutPlan?.title == "Test Upper/Lower — Upper")
        #expect(days[1].workoutPlan?.title == "Test Upper/Lower — Lower")
    }

    @Test @MainActor
    // Activating a new program should deactivate any previously active split. The previous split
    // stays in the store but its isActive flag flips off.
    func materializeProgram_deactivatesPreviousActiveSplit() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)
        try seedCatalog(into: context)

        let previous = WorkoutSplit(title: "Old Split", mode: .weekly, isActive: true)
        context.insert(previous)
        saveContext(context: context)

        let template = PlanTemplate(
            id: "test_fb",
            name: "Full Body",
            summary: "One day",
            icon: "figure.strengthtraining.traditional",
            level: .beginner,
            days: [
                PlanTemplateDay(
                    id: "test_fb_day",
                    name: "Full Body",
                    muscleGroups: [.chest],
                    exercises: [.init("barbell_bench_press", sets: 3, reps: 8, restSeconds: 120, rpe: 8)]
                ),
            ]
        )

        _ = PlanTemplateMaterializer.materializeProgram(template: template, activate: true, context: context)
        #expect(previous.isActive == false)
    }

    // MARK: - Helpers

    @MainActor
    private func seedCatalog(into context: ModelContext) throws {
        // PlanTemplateMaterializer looks up Exercise rows by catalog ID. Seed the rows the
        // template references so the resolver can find them.
        for catalogItem in ExerciseCatalog.all where ["barbell_bench_press", "dumbbell_lateral_raises", "barbell_squat"].contains(catalogItem.id) {
            let exercise = Exercise(from: catalogItem)
            context.insert(exercise)
        }
        saveContext(context: context)
    }
}
