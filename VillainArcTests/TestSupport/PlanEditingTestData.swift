import SwiftData
import Foundation
@testable import VillainArc

@MainActor
struct PlanEditingTestData {
    let plan: WorkoutPlan
    let bench: ExercisePrescription
    let benchSet1: SetPrescription
    let benchSet2: SetPrescription
    let incline: ExercisePrescription
    let flys: ExercisePrescription
    let changes: [PrescriptionChange]
}

@MainActor
func makePlanWithRuleSuggestions(in context: ModelContext) -> PlanEditingTestData {
    func makeEvent(for exercise: ExercisePrescription, changes: [PrescriptionChange], targetSet: SetPrescription? = nil, category: SuggestionCategory = .performance, reasoning: String? = nil) -> SuggestionEvent {
        let event = SuggestionEvent(category: category, catalogID: exercise.catalogID, sessionFrom: nil, targetExercisePrescription: exercise, targetSetPrescription: targetSet, triggerTargetSetID: targetSet?.id, triggerPerformanceSnapshot: ExercisePerformanceSnapshot(date: .now, notes: "", repRange: RepRangeSnapshot(policy: exercise.repRange), sets: []), triggerTargetSnapshot: ExerciseTargetSnapshot(prescription: exercise), trainingStyle: .straightSets, changeReasoning: reasoning, changes: changes)
        context.insert(event)
        for change in changes {
            change.event = event
        }
        return event
    }
    
    let plan = WorkoutPlan(title: "Chest Growth")
    context.insert(plan)
    
    // Exercise 1: Bench Press with two sets and set-level suggestions.
    let benchExercise = Exercise(from: ExerciseCatalog.byID["barbell_bench_press"]!)
    let bench = ExercisePrescription(exercise: benchExercise, workoutPlan: plan)
    bench.sets = []
    
    let benchSet1 = SetPrescription(exercisePrescription: bench, setType: .warmup, targetWeight: 135, targetReps: 10, targetRest: 60)
    let benchSet2 = SetPrescription(exercisePrescription: bench, setType: .working, targetWeight: 155, targetReps: 8, targetRest: 90)
    
    bench.sets = [benchSet1, benchSet2]
    bench.reindexSets()
    plan.exercises?.append(bench)
    
    let change1 = PrescriptionChange(changeType: .increaseWeight, previousValue: 135, newValue: 145)
    context.insert(change1)
    
    let change2 = PrescriptionChange(changeType: .decreaseReps, previousValue: 10, newValue: 8)
    context.insert(change2)
    
    let change3 = PrescriptionChange(changeType: .increaseWeight, previousValue: 155, newValue: 160)
    context.insert(change3)
    _ = makeEvent(for: bench, changes: [change1, change2], targetSet: benchSet1)
    _ = makeEvent(for: bench, changes: [change3], targetSet: benchSet2)
    
    // Exercise 2: Incline DB with rep range suggestions.
    let inclineExercise = Exercise(from: ExerciseCatalog.byID["dumbbell_incline_bench_press"]!)
    let incline = ExercisePrescription(exercise: inclineExercise, workoutPlan: plan)
    if let repRange = incline.repRange {
        repRange.activeMode = .target
        repRange.targetReps = 8
    }
    plan.exercises?.append(incline)
    
    let change4 = PrescriptionChange(changeType: .changeRepRangeMode, previousValue: Double(RepRangeMode.target.rawValue), newValue: Double(RepRangeMode.range.rawValue))
    context.insert(change4)
    
    let change5 = PrescriptionChange(changeType: .increaseRepRangeLower, previousValue: 8, newValue: 10)
    context.insert(change5)
    
    let change6 = PrescriptionChange(changeType: .increaseRepRangeUpper, previousValue: 10, newValue: 12)
    context.insert(change6)
    _ = makeEvent(for: incline, changes: [change4, change5, change6], category: .repRangeConfiguration)
    
    // Exercise 3: Flys with rest time suggestion.
    let flysExercise = Exercise(from: ExerciseCatalog.byID["cable_bench_chest_fly"]!)
    let flys = ExercisePrescription(exercise: flysExercise, workoutPlan: plan)
    if let firstSet = flys.sortedSets.first {
        firstSet.targetRest = 60
    }
    plan.exercises?.append(flys)
    
    let flysSet = flys.sortedSets.first!
    let change7 = PrescriptionChange(changeType: .increaseRest, previousValue: 60, newValue: 90)
    context.insert(change7)
    _ = makeEvent(for: flys, changes: [change7], targetSet: flysSet, category: .recovery, reasoning: "Recovery needs increased")
    
    for (index, exercise) in (plan.exercises ?? []).enumerated() {
        exercise.index = index
    }
    
    return PlanEditingTestData(plan: plan, bench: bench, benchSet1: benchSet1, benchSet2: benchSet2, incline: incline, flys: flys, changes: [change1, change2, change3, change4, change5, change6, change7])
}
