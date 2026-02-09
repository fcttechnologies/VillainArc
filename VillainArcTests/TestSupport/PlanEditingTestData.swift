import SwiftData
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
    let plan = WorkoutPlan()
    plan.title = "Chest Growth"
    context.insert(plan)

    // Exercise 1: Bench Press with two sets and set-level suggestions.
    let benchExercise = Exercise(from: ExerciseCatalog.byID["barbell_bench_press"]!)
    let bench = ExercisePrescription(exercise: benchExercise, workoutPlan: plan)
    bench.sets = []

    let benchSet1 = SetPrescription(exercisePrescription: bench)
    benchSet1.type = .warmup
    benchSet1.targetWeight = 135
    benchSet1.targetReps = 10
    benchSet1.targetRest = 60

    let benchSet2 = SetPrescription(exercisePrescription: bench)
    benchSet2.type = .working
    benchSet2.targetWeight = 155
    benchSet2.targetReps = 8
    benchSet2.targetRest = 90

    bench.sets = [benchSet1, benchSet2]
    bench.reindexSets()
    plan.exercises.append(bench)

    let change1 = PrescriptionChange()
    change1.source = .rules
    change1.changeType = .increaseWeight
    change1.previousValue = 135
    change1.newValue = 145
    change1.targetSetPrescription = benchSet1
    change1.targetExercisePrescription = bench
    change1.catalogID = bench.catalogID
    context.insert(change1)

    let change2 = PrescriptionChange()
    change2.source = .rules
    change2.changeType = .decreaseReps
    change2.previousValue = 10
    change2.newValue = 8
    change2.targetSetPrescription = benchSet1
    change2.targetExercisePrescription = bench
    change2.catalogID = bench.catalogID
    context.insert(change2)

    let change3 = PrescriptionChange()
    change3.source = .rules
    change3.changeType = .increaseWeight
    change3.previousValue = 155
    change3.newValue = 160
    change3.targetSetPrescription = benchSet2
    change3.targetExercisePrescription = bench
    change3.catalogID = bench.catalogID
    context.insert(change3)

    // Exercise 2: Incline DB with rep range suggestions.
    let inclineExercise = Exercise(from: ExerciseCatalog.byID["dumbbell_incline_bench_press"]!)
    let incline = ExercisePrescription(exercise: inclineExercise, workoutPlan: plan)
    incline.repRange.activeMode = .target
    incline.repRange.targetReps = 8
    plan.exercises.append(incline)

    let change4 = PrescriptionChange()
    change4.source = .rules
    change4.changeType = .changeRepRangeMode
    change4.previousValue = Double(RepRangeMode.target.rawValue)
    change4.newValue = Double(RepRangeMode.range.rawValue)
    change4.targetExercisePrescription = incline
    change4.catalogID = incline.catalogID
    context.insert(change4)

    let change5 = PrescriptionChange()
    change5.source = .rules
    change5.changeType = .increaseRepRangeLower
    change5.previousValue = 8
    change5.newValue = 10
    change5.targetExercisePrescription = incline
    change5.catalogID = incline.catalogID
    context.insert(change5)

    let change6 = PrescriptionChange()
    change6.source = .rules
    change6.changeType = .increaseRepRangeUpper
    change6.previousValue = 10
    change6.newValue = 12
    change6.targetExercisePrescription = incline
    change6.catalogID = incline.catalogID
    context.insert(change6)

    // Exercise 3: Flys with rest time suggestion.
    let flysExercise = Exercise(from: ExerciseCatalog.byID["cable_bench_chest_fly"]!)
    let flys = ExercisePrescription(exercise: flysExercise, workoutPlan: plan)
    flys.restTimePolicy.activeMode = .allSame
    flys.restTimePolicy.allSameSeconds = 60
    plan.exercises.append(flys)

    let change7 = PrescriptionChange()
    change7.source = .rules
    change7.changeType = .increaseRestTimeSeconds
    change7.previousValue = 60
    change7.newValue = 90
    change7.targetExercisePrescription = flys
    change7.catalogID = flys.catalogID
    context.insert(change7)

    for (index, exercise) in plan.exercises.enumerated() {
        exercise.index = index
    }

    return PlanEditingTestData(
        plan: plan,
        bench: bench,
        benchSet1: benchSet1,
        benchSet2: benchSet2,
        incline: incline,
        flys: flys,
        changes: [change1, change2, change3, change4, change5, change6, change7]
    )
}
