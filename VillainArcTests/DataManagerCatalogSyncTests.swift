import SwiftData
import Testing

@testable import VillainArc

struct DataManagerCatalogSyncTests {
    @MainActor
    private func makePlanBackedSession(
        context: ModelContext,
        exercises: [Exercise],
        planTitle: String
    ) -> (plan: WorkoutPlan, session: WorkoutSession, prescriptions: [ExercisePrescription]) {
        let plan = WorkoutPlan(title: planTitle)
        context.insert(plan)

        let prescriptions = exercises.map { ExercisePrescription(exercise: $0, workoutPlan: plan) }
        plan.exercises = prescriptions

        let session = WorkoutSession(from: plan)
        context.insert(session)
        return (plan, session, prescriptions)
    }

    @Test @MainActor func syncExerciseSnapshotsUpdatesMatchingPrescriptionsAndPerformances() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)
        let exercise = Exercise(from: ExerciseCatalog.byID["barbell_bench_press"]!)
        context.insert(exercise)
        let (_, session, prescriptions) = makePlanBackedSession(context: context, exercises: [exercise], planTitle: "Push")
        let prescription = try #require(prescriptions.first)
        let performance = try #require(session.sortedExercises.first)

        let updatedCatalogItem = ExerciseCatalogItem(id: exercise.catalogID, name: "Bench Press Renamed", musclesTargeted: [.chest, .upperChest, .triceps, .frontDelt], equipmentType: .smithMachine)
        let didChange = try DataManager.syncExerciseSnapshots(for: updatedCatalogItem, context: context)
        try context.save()

        let savedPrescription = try #require(
            try context.fetch(FetchDescriptor<ExercisePrescription>()).first(where: { $0.id == prescription.id })
        )
        let savedPerformance = try #require(
            try context.fetch(FetchDescriptor<ExercisePerformance>()).first(where: { $0.id == performance.id })
        )

        #expect(didChange)
        #expect(savedPrescription.name == updatedCatalogItem.name)
        #expect(savedPrescription.musclesTargeted == updatedCatalogItem.musclesTargeted)
        #expect(savedPrescription.equipmentType == updatedCatalogItem.equipmentType)
        #expect(savedPerformance.name == updatedCatalogItem.name)
        #expect(savedPerformance.musclesTargeted == updatedCatalogItem.musclesTargeted)
        #expect(savedPerformance.equipmentType == updatedCatalogItem.equipmentType)
    }

    @Test @MainActor func syncExerciseSnapshotsLeavesUnrelatedExercisesUntouched() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)
        let bench = Exercise(from: ExerciseCatalog.byID["barbell_bench_press"]!)
        let squat = Exercise(from: ExerciseCatalog.byID["barbell_squat"]!)
        context.insert(bench)
        context.insert(squat)
        let (_, session, prescriptions) = makePlanBackedSession(context: context, exercises: [bench, squat], planTitle: "Mixed")
        let benchPrescription = try #require(prescriptions.first(where: { $0.catalogID == bench.catalogID }))
        let squatPrescription = try #require(prescriptions.first(where: { $0.catalogID == squat.catalogID }))
        let performancesByID = Dictionary(uniqueKeysWithValues: session.sortedExercises.map { ($0.catalogID, $0) })
        let squatPerformance = try #require(performancesByID[squat.catalogID])
        let benchPerformance = try #require(performancesByID[bench.catalogID])
        let updatedBench = ExerciseCatalogItem(id: bench.catalogID, name: "Bench Press Renamed", musclesTargeted: [.chest, .upperChest, .triceps, .frontDelt], equipmentType: .smithMachine)
        let didChange = try DataManager.syncExerciseSnapshots(for: updatedBench, context: context)
        try context.save()

        let savedSquatPrescription = try #require(
            try context.fetch(FetchDescriptor<ExercisePrescription>()).first(where: { $0.id == squatPrescription.id })
        )
        let savedSquatPerformance = try #require(
            try context.fetch(FetchDescriptor<ExercisePerformance>()).first(where: { $0.id == squatPerformance.id })
        )
        let savedBenchPrescription = try #require(
            try context.fetch(FetchDescriptor<ExercisePrescription>()).first(where: { $0.id == benchPrescription.id })
        )
        let savedBenchPerformance = try #require(
            try context.fetch(FetchDescriptor<ExercisePerformance>()).first(where: { $0.id == benchPerformance.id })
        )

        #expect(didChange)
        #expect(squatPrescription.name == squat.name)
        #expect(squatPrescription.musclesTargeted == squat.musclesTargeted)
        #expect(squatPrescription.equipmentType == squat.equipmentType)
        #expect(savedSquatPrescription.name == squat.name)
        #expect(savedSquatPrescription.musclesTargeted == squat.musclesTargeted)
        #expect(savedSquatPrescription.equipmentType == squat.equipmentType)
        #expect(savedSquatPerformance.name == squat.name)
        #expect(savedSquatPerformance.musclesTargeted == squat.musclesTargeted)
        #expect(savedSquatPerformance.equipmentType == squat.equipmentType)
        #expect(savedBenchPrescription.name == updatedBench.name)
        #expect(savedBenchPerformance.name == updatedBench.name)
    }

    @Test @MainActor func syncExerciseSnapshotsReturnsFalseWhenCatalogDataIsUnchanged() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)
        let exercise = Exercise(from: ExerciseCatalog.byID["barbell_bench_press"]!)
        context.insert(exercise)
        let (_, _, prescriptions) = makePlanBackedSession(context: context, exercises: [exercise], planTitle: "Push")
        let prescription = try #require(prescriptions.first)

        let unchangedCatalogItem = ExerciseCatalogItem(
            id: exercise.catalogID,
            name: exercise.name,
            musclesTargeted: exercise.musclesTargeted,
            equipmentType: exercise.equipmentType
        )

        let didChange = try DataManager.syncExerciseSnapshots(for: unchangedCatalogItem, context: context)
        try context.save()

        let savedPrescription = try #require(
            try context.fetch(FetchDescriptor<ExercisePrescription>()).first(where: { $0.id == prescription.id })
        )

        #expect(didChange == false)
        #expect(savedPrescription.name == exercise.name)
        #expect(savedPrescription.musclesTargeted == exercise.musclesTargeted)
        #expect(savedPrescription.equipmentType == exercise.equipmentType)
    }
}
