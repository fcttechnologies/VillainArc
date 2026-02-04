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

    // MARK: - Helpers

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        return Calendar.current.date(from: components) ?? .now
    }
}

// MARK: - Shared Containers

private let sampleContainer = PreviewDataContainer()
private let sampleContainerWithIncomplete = PreviewDataContainer(includeIncompleteData: true)

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

// MARK: - View Modifiers

extension View {
    func sampleDataContainer() -> some View {
        self.modelContainer(sampleContainer.modelContainer)
    }

    func sampleDataContainerIncomplete() -> some View {
        self.modelContainer(sampleContainerWithIncomplete.modelContainer)
    }
}
