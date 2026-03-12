import SwiftData
import Testing
@testable import VillainArc

struct DataManagerCatalogSyncTests {
    @Test @MainActor
    func syncExerciseSnapshotsUpdatesMatchingPrescriptionsAndPerformances() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)
        
        let exercise = Exercise(from: ExerciseCatalog.byID["barbell_bench_press"]!)
        context.insert(exercise)
        
        let plan = WorkoutPlan(title: "Push")
        context.insert(plan)
        let prescription = ExercisePrescription(exercise: exercise, workoutPlan: plan)
        plan.exercises = [prescription]
        
        let session = WorkoutSession(from: plan)
        context.insert(session)
        
        guard let performance = session.sortedExercises.first else {
            Issue.record("Expected one performance copied from the plan")
            return
        }
        
        let updatedCatalogItem = ExerciseCatalogItem(
            id: exercise.catalogID,
            name: "Bench Press Renamed",
            musclesTargeted: [.chest, .upperChest, .triceps, .frontDelt],
            equipmentType: .smithMachine
        )
        
        let didChange = try DataManager.syncExerciseSnapshots(for: updatedCatalogItem, context: context)
        
        #expect(didChange)
        #expect(prescription.name == updatedCatalogItem.name)
        #expect(prescription.musclesTargeted == updatedCatalogItem.musclesTargeted)
        #expect(prescription.equipmentType == updatedCatalogItem.equipmentType)
        #expect(performance.name == updatedCatalogItem.name)
        #expect(performance.musclesTargeted == updatedCatalogItem.musclesTargeted)
        #expect(performance.equipmentType == updatedCatalogItem.equipmentType)
    }
    
    @Test @MainActor
    func syncExerciseSnapshotsLeavesUnrelatedExercisesUntouched() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)
        
        let bench = Exercise(from: ExerciseCatalog.byID["barbell_bench_press"]!)
        let squat = Exercise(from: ExerciseCatalog.byID["barbell_squat"]!)
        context.insert(bench)
        context.insert(squat)
        
        let plan = WorkoutPlan(title: "Mixed")
        context.insert(plan)
        let benchPrescription = ExercisePrescription(exercise: bench, workoutPlan: plan)
        let squatPrescription = ExercisePrescription(exercise: squat, workoutPlan: plan)
        plan.exercises = [benchPrescription, squatPrescription]
        
        let session = WorkoutSession(from: plan)
        context.insert(session)
        let performancesByID = Dictionary(uniqueKeysWithValues: session.sortedExercises.map { ($0.catalogID, $0) })
        guard let squatPerformance = performancesByID[squat.catalogID] else {
            Issue.record("Expected squat performance in session")
            return
        }
        
        let updatedBench = ExerciseCatalogItem(
            id: bench.catalogID,
            name: "Bench Press Renamed",
            musclesTargeted: [.chest, .upperChest, .triceps, .frontDelt],
            equipmentType: .smithMachine
        )
        
        _ = try DataManager.syncExerciseSnapshots(for: updatedBench, context: context)
        
        #expect(squatPrescription.name == squat.name)
        #expect(squatPrescription.musclesTargeted == squat.musclesTargeted)
        #expect(squatPrescription.equipmentType == squat.equipmentType)
        #expect(squatPerformance.name == squat.name)
        #expect(squatPerformance.musclesTargeted == squat.musclesTargeted)
        #expect(squatPerformance.equipmentType == squat.equipmentType)
    }
}
