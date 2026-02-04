import SwiftUI
import SwiftData

@MainActor
class PreviewDataContainer {
    var modelContainer: ModelContainer

    var context: ModelContext {
        modelContainer.mainContext
    }

    init(includeIncompleteData: Bool = false) {
        let schema = Schema([
            WorkoutSession.self,
            PreWorkoutMood.self,
            PostWorkoutEffort.self,
            ExercisePerformance.self,
            SetPerformance.self,
            Exercise.self,
            RepRangePolicy.self,
            RestTimePolicy.self,
            RestTimeHistory.self,
            WorkoutPlan.self,
            ExercisePrescription.self,
            SetPrescription.self,
            WorkoutSplit.self,
            WorkoutSplitDay.self,
            PrescriptionChange.self
        ])

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [.init(schema: schema, isStoredInMemoryOnly: true)])

            syncExercises()
            loadCompletedPlan()
            loadCompletedSession()
            loadSampleSplits()
            if includeIncompleteData {
                loadIncompleteSession()
                loadIncompletePlan()
            }

            try context.save()
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    private func syncExercises() {
        for catalogItem in ExerciseCatalog.all {
            context.insert(Exercise(from: catalogItem))
        }
    }

    // MARK: - Completed Plan (Push Day)

    private func loadCompletedPlan() {
        let plan = WorkoutPlan()
        plan.title = "Push Day"
        plan.notes = "Chest and triceps focus"
        plan.completed = true
        plan.favorite = true
        plan.lastUsed = date(2026, 1, 5, 8, 15)
        context.insert(plan)

        let exercises: [(id: String, notes: String, sets: [(type: ExerciseSetType, weight: Double, reps: Int, rest: Int)])] = [
            ("barbell_bench_press", "Warm-up + 3x5 @ RPE 8", [
                (.warmup, 45, 12, 60),
                (.regular, 135, 10, 90),
                (.regular, 155, 8, 90)
            ]),
            ("dumbbell_incline_bench_press", "", [
                (.warmup, 25, 12, 60),
                (.regular, 55, 10, 90),
                (.regular, 60, 8, 90)
            ]),
            ("cable_bench_chest_fly", "slow eccentric", [
                (.regular, 30, 12, 90),
                (.regular, 35, 10, 90),
                (.regular, 35, 10, 90)
            ]),
            ("cable_bar_pushdown", "triceps finisher", [
                (.regular, 50, 12, 60),
                (.regular, 55, 10, 60),
                (.regular, 60, 8, 60)
            ])
        ]

        for ex in exercises {
            let exercise = Exercise(from: ExerciseCatalog.byID[ex.id]!)
            let prescription = ExercisePrescription(exercise: exercise, workoutPlan: plan)
            prescription.notes = ex.notes

            if ex.id == "dumbbell_incline_bench_press" {
                prescription.repRange.activeMode = .range
                prescription.repRange.lowerRange = 8
                prescription.repRange.upperRange = 10
            } else if ex.id == "cable_bench_chest_fly" {
                prescription.repRange.activeMode = .range
                prescription.repRange.lowerRange = 12
                prescription.repRange.upperRange = 15
            } else if ex.id == "cable_bar_pushdown" {
                prescription.repRange.activeMode = .range
                prescription.repRange.lowerRange = 10
                prescription.repRange.upperRange = 12
            }

            for s in ex.sets {
                let setPrescription = SetPrescription(exercisePrescription: prescription)
                setPrescription.type = s.type
                setPrescription.targetWeight = s.weight
                setPrescription.targetReps = s.reps
                setPrescription.targetRest = s.rest
                prescription.sets.append(setPrescription)
            }

            plan.exercises.append(prescription)
        }
    }

    // MARK: - Completed Session (Chest Day)

    private func loadCompletedSession() {
        let session = WorkoutSession()
        session.title = "Chest Day"
        session.notes = "Testing sample"
        session.status = SessionStatus.done.rawValue
        session.startedAt = date(2026, 1, 5, 8, 15)
        session.endedAt = date(2026, 1, 5, 9, 5)
        context.insert(session)

        let postEffort = PostWorkoutEffort(rpe: 7, notes: "Felt strong", workoutSession: session)
        session.postEffort = postEffort

        let exercises: [(id: String, notes: String, sets: [(type: ExerciseSetType, weight: Double, reps: Int)])] = [
            ("barbell_bench_press", "Warm-up + 3x5 @ RPE 8", [
                (.warmup, 45, 12),
                (.regular, 135, 10),
                (.regular, 155, 8)
            ]),
            ("dumbbell_incline_bench_press", "", [
                (.warmup, 25, 12),
                (.regular, 55, 10),
                (.regular, 60, 8)
            ]),
            ("cable_bench_chest_fly", "slow eccentric", [
                (.regular, 30, 12),
                (.regular, 35, 10),
                (.regular, 35, 10)
            ]),
            ("push_ups", "2xAMRAP", [
                (.regular, 0, 25),
                (.failure, 0, 18)
            ])
        ]

        for (i, ex) in exercises.enumerated() {
            let exercise = Exercise(from: ExerciseCatalog.byID[ex.id]!)
            let performance = ExercisePerformance(exercise: exercise, workoutSession: session)
            performance.notes = ex.notes

            if ex.id == "dumbbell_incline_bench_press" {
                performance.repRange.activeMode = .range
                performance.repRange.lowerRange = 8
                performance.repRange.upperRange = 10
            } else if ex.id == "cable_bench_chest_fly" {
                performance.repRange.activeMode = .range
                performance.repRange.lowerRange = 12
                performance.repRange.upperRange = 15
            } else if ex.id == "push_ups" {
                performance.repRange.activeMode = .untilFailure
            }

            for (j, s) in ex.sets.enumerated() {
                let setPerf = SetPerformance(exercise: performance)
                setPerf.type = s.type
                setPerf.weight = s.weight
                setPerf.reps = s.reps
                setPerf.restSeconds = s.type == .warmup ? 60 : 90
                setPerf.complete = true
                setPerf.completedAt = session.startedAt.addingTimeInterval(Double((i * 3 + j + 1) * 120))
                performance.sets.append(setPerf)
            }

            session.exercises.append(performance)
        }
    }

    // MARK: - Incomplete Session

    private func loadIncompleteSession() {
        let session = WorkoutSession()
        session.title = "Sample Workout"
        context.insert(session)

        let exercises: [(id: String, notes: String)] = [
            ("barbell_bench_press", "Warm-up + 3x5 @ RPE 8"),
            ("dumbbell_incline_bench_press", ""),
            ("cable_bench_chest_fly", "slow eccentric"),
            ("barbell_bent_over_row", "Back focus")
        ]

        let sampleReps = [12, 10, 8]
        let sampleWeights: [String: [Double]] = [
            "barbell_bench_press": [45, 135, 165],
            "dumbbell_incline_bench_press": [25, 60, 65],
            "cable_bench_chest_fly": [20, 35, 40],
            "barbell_bent_over_row": [45, 95, 115]
        ]

        for ex in exercises {
            let exercise = Exercise(from: ExerciseCatalog.byID[ex.id]!)
            let performance = ExercisePerformance(exercise: exercise, workoutSession: session)
            performance.notes = ex.notes

            for index in 0..<3 {
                let setPerf = SetPerformance(exercise: performance)
                setPerf.type = index == 0 ? .warmup : .regular
                setPerf.restSeconds = index == 0 ? 60 : 90
                setPerf.reps = sampleReps[index]
                if let weights = sampleWeights[ex.id], index < weights.count {
                    setPerf.weight = weights[index]
                }
                performance.sets.append(setPerf)
            }

            session.exercises.append(performance)
        }
    }

    // MARK: - Incomplete Plan

    private func loadIncompletePlan() {
        let plan = WorkoutPlan()
        plan.title = "Back Day"
        context.insert(plan)

        let exercise = Exercise(from: ExerciseCatalog.byID["barbell_bent_over_row"]!)
        let prescription = ExercisePrescription(exercise: exercise, workoutPlan: plan)

        let set1 = SetPrescription(exercisePrescription: prescription)
        set1.type = .warmup
        set1.targetRest = 60
        prescription.sets.append(set1)

        let set2 = SetPrescription(exercisePrescription: prescription)
        set2.targetRest = 90
        prescription.sets.append(set2)

        plan.exercises.append(prescription)
    }

    // MARK: - Splits

    private func loadSampleSplits() {
        let weeklySplit = WorkoutSplit(mode: .weekly)
        weeklySplit.title = "PPL Split"
        weeklySplit.isActive = true
        weeklySplit.days = (1...7).map { weekday in
            let day = WorkoutSplitDay(weekday: weekday, split: weeklySplit)
            day.isRestDay = (weekday == 1 || weekday == 4)
            return day
        }
        context.insert(weeklySplit)

        let rotationSplit = WorkoutSplit(mode: .rotation)
        rotationSplit.title = "Upper/Lower"
        rotationSplit.days = [
            WorkoutSplitDay(index: 0, split: rotationSplit),
            WorkoutSplitDay(index: 1, split: rotationSplit),
            WorkoutSplitDay(index: 2, split: rotationSplit)
        ]
        rotationSplit.days[0].name = "Upper Body"
        rotationSplit.days[1].name = "Lower Body"
        rotationSplit.days[2].name = "Rest"
        rotationSplit.days[2].isRestDay = true
        context.insert(rotationSplit)
    }

    // MARK: - Session with Suggestions
    
    func loadSessionWithSuggestions() {
        let session = WorkoutSession()
        session.title = "Suggestions Test"
        session.status = SessionStatus.pending.rawValue
        context.insert(session)
        
        let plan = WorkoutPlan()
        plan.title = "Chest Growth"
        context.insert(plan)
        session.workoutPlan = plan
        
        // Exercise 1: Bench Press (Groups: Set 1, Set 2)
        let bench = Exercise(from: ExerciseCatalog.byID["barbell_bench_press"]!)
        let benchPrescription = ExercisePrescription(exercise: bench, workoutPlan: plan)
        plan.exercises.append(benchPrescription)
        
        // Set 1 changes
        let s1 = SetPrescription(exercisePrescription: benchPrescription)
        s1.type = .warmup
        s1.targetWeight = 1135
        s1.targetReps = 10
        s1.index = 0
        benchPrescription.sets.append(s1)
        
        // Set 2 changes
        let s2 = SetPrescription(exercisePrescription: benchPrescription)
        s2.type = .regular
        s2.targetWeight = 155
        s2.targetReps = 8
        s2.index = 1
        benchPrescription.sets.append(s2)
        
        let change1 = PrescriptionChange()
        change1.changeType = .increaseWeight
        change1.previousValue = 135
        change1.newValue = 145
        change1.targetSetPrescription = s1
        change1.targetExercisePrescription = benchPrescription
        change1.catalogID = bench.catalogID
        change1.changeReasoning = "Hit all reps last 3 sessions"
        context.insert(change1)
        
        let change2 = PrescriptionChange()
        change2.changeType = .decreaseReps
        change2.previousValue = 10
        change2.newValue = 8
        change2.targetSetPrescription = s1
        change2.targetExercisePrescription = benchPrescription
        change2.catalogID = bench.catalogID
        context.insert(change2)
        
        let change3 = PrescriptionChange()
        change3.changeType = .increaseWeight
        change3.previousValue = 155
        change3.newValue = 160
        change3.targetSetPrescription = s2
        change3.targetExercisePrescription = benchPrescription
        change3.catalogID = bench.catalogID
        context.insert(change3)
        
        // Exercise 2: Incline DB (Group: Rep Range)
        let incline = Exercise(from: ExerciseCatalog.byID["dumbbell_incline_bench_press"]!)
        let inclinePrescription = ExercisePrescription(exercise: incline, workoutPlan: plan)
        inclinePrescription.repRange.activeMode = .target
        inclinePrescription.repRange.targetReps = 8
        plan.exercises.append(inclinePrescription)
        
        let change4 = PrescriptionChange()
        change4.changeType = .changeRepRangeMode
        change4.previousValue = Double(RepRangeMode.target.rawValue)
        change4.newValue = Double(RepRangeMode.range.rawValue)
        change4.targetExercisePrescription = inclinePrescription
        change4.catalogID = incline.catalogID
        change4.changeReasoning = "Switching to range for hypertrophy phase"
        context.insert(change4)
        
        let change5 = PrescriptionChange()
        change5.changeType = .increaseRepRangeLower
        change5.previousValue = 8
        change5.newValue = 10
        change5.targetExercisePrescription = inclinePrescription
        change5.catalogID = incline.catalogID
        context.insert(change5)
        
        let change6 = PrescriptionChange()
        change6.changeType = .increaseRepRangeUpper
        change6.previousValue = 10
        change6.newValue = 12
        change6.targetExercisePrescription = inclinePrescription
        change6.catalogID = incline.catalogID
        context.insert(change6)
        
        // Exercise 3: Flys (Group: Rest Time)
        let flys = Exercise(from: ExerciseCatalog.byID["cable_bench_chest_fly"]!)
        let flysPrescription = ExercisePrescription(exercise: flys, workoutPlan: plan)
        flysPrescription.restTimePolicy.activeMode = .allSame
        flysPrescription.restTimePolicy.allSameSeconds = 60
        plan.exercises.append(flysPrescription)
        
        let change7 = PrescriptionChange()
        change7.changeType = .increaseRestTimeSeconds
        change7.previousValue = 60
        change7.newValue = 90
        change7.targetExercisePrescription = flysPrescription
        change7.catalogID = flys.catalogID
        change7.changeReasoning = "Recovery needs increased"
        context.insert(change7)
    }

    // MARK: - Helpers

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        return Calendar.current.date(from: components) ?? .now
    }
}

// MARK: - Shared Containers

private let sampleContainer = PreviewDataContainer()
private let sampleContainerWithIncomplete = PreviewDataContainer(includeIncompleteData: true)
private let sampleContainerWithSuggestions: PreviewDataContainer = {
    let container = PreviewDataContainer()
    container.loadSessionWithSuggestions()
    return container
}()

// MARK: - Sample Accessors

@MainActor
func sampleCompletedSession() -> WorkoutSession {
    let sessions = (try? sampleContainer.context.fetch(WorkoutSession.completedSession)) ?? []
    if let session = sessions.first {
        return session
    }

    let fallback = WorkoutSession()
    fallback.title = "Chest Day"
    fallback.status = SessionStatus.done.rawValue
    fallback.endedAt = .now
    sampleContainer.context.insert(fallback)
    return fallback
}

@MainActor
func sampleIncompleteSession() -> WorkoutSession {
    let sessions = (try? sampleContainerWithIncomplete.context.fetch(WorkoutSession.incomplete)) ?? []
    if let session = sessions.first {
        return session
    }

    let fallback = WorkoutSession()
    sampleContainerWithIncomplete.context.insert(fallback)
    return fallback
}

@MainActor
func sampleCompletedPlan() -> WorkoutPlan {
    let descriptor = FetchDescriptor(predicate: WorkoutPlan.completedPredicate)
    let plans = (try? sampleContainer.context.fetch(descriptor)) ?? []
    if let plan = plans.first {
        return plan
    }

    let fallback = WorkoutPlan()
    fallback.title = "Push Day"
    fallback.completed = true
    sampleContainer.context.insert(fallback)
    return fallback
}

@MainActor
func sampleIncompletePlan() -> WorkoutPlan {
    let plans = (try? sampleContainerWithIncomplete.context.fetch(WorkoutPlan.incomplete)) ?? []
    if let plan = plans.first {
        return plan
    }

    let fallback = WorkoutPlan()
    fallback.title = "Back Day"
    sampleContainerWithIncomplete.context.insert(fallback)
    return fallback
}

@MainActor
func sampleEditingPlan() -> WorkoutPlan {
    let plan = sampleCompletedPlan()
    plan.isEditing = true
    return plan
}

@MainActor
func sampleWeeklySplit() -> WorkoutSplit {
    let descriptor = FetchDescriptor<WorkoutSplit>()
    let splits = (try? sampleContainer.context.fetch(descriptor)) ?? []
    if let split = splits.first(where: { $0.mode == .weekly }) {
        return split
    }

    let fallback = WorkoutSplit(mode: .weekly)
    fallback.days = (1...7).map { WorkoutSplitDay(weekday: $0, split: fallback) }
    sampleContainer.context.insert(fallback)
    return fallback
}

@MainActor
func sampleRotationSplit() -> WorkoutSplit {
    let descriptor = FetchDescriptor<WorkoutSplit>()
    let splits = (try? sampleContainer.context.fetch(descriptor)) ?? []
    if let split = splits.first(where: { $0.mode == .rotation }) {
        return split
    }

    let fallback = WorkoutSplit(mode: .rotation)
    fallback.title = "Upper/Lower"
    for i in 0..<3 {
        let day = WorkoutSplitDay(index: i, split: fallback)
        day.name = "Day \(i + 1)"
        fallback.days.append(day)
    }
    sampleContainer.context.insert(fallback)
    return fallback
}

@MainActor
func sampleSessionWithSuggestions() -> WorkoutSession {
    let sessions = (try? sampleContainerWithSuggestions.context.fetch(WorkoutSession.incomplete)) ?? []
    if let session = sessions.first {
        return session
    }
    // Should have been created
    let fallback = WorkoutSession()
    fallback.title = "Suggestions Test (Fallback)"
    sampleContainerWithSuggestions.context.insert(fallback)
    return fallback
}

// MARK: - View Modifiers

extension View {
    func sampleDataContainer() -> some View {
        self.modelContainer(sampleContainer.modelContainer)
    }

    func sampleDataContainerIncomplete() -> some View {
        self.modelContainer(sampleContainerWithIncomplete.modelContainer)
    }
    
    func sampleDataContainerSuggestions() -> some View {
        self.modelContainer(sampleContainerWithSuggestions.modelContainer)
    }
}
