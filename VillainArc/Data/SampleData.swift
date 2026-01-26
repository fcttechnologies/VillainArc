import SwiftUI
import SwiftData

@MainActor
class PreviewDataContainer {
    var modelContainer: ModelContainer
    
    var context: ModelContext {
        modelContainer.mainContext
    }
    
    init(includeIncompleteWorkout: Bool = false) {
        let schema = Schema([
            Workout.self,
            WorkoutExercise.self,
            ExerciseSet.self,
            Exercise.self,
            RepRangePolicy.self,
            RestTimePolicy.self,
            RestTimeHistory.self,
            WorkoutTemplate.self,
            TemplateExercise.self,
            TemplateSet.self,
            WorkoutSplit.self,
            WorkoutSplitDay.self
        ])

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [.init(schema: schema, isStoredInMemoryOnly: true)])
            
            loadSampleData()
            loadSampleTemplates()
            syncExercises()
            if includeIncompleteWorkout {
                loadIncompleteWorkout()
            }

            try context.save()
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
    
    private func loadSampleData() {
        for workout in Workout.sampleData {
            context.insert(workout)
        }
    }

    private func syncExercises() {
        for catalogItem in ExerciseCatalog.all {
            context.insert(Exercise(from: catalogItem))
        }
    }

    private func loadIncompleteWorkout() {
        let workout = Workout(title: "Sample Workout")
        workout.exercises = WorkoutExercise.incompleteChestDay(for: workout)
        context.insert(workout)
    }
    
    private func loadSampleTemplates() {
        for template in WorkoutTemplate.sampleData {
            context.insert(template)
        }
    }
}

private let sampleContainer = PreviewDataContainer()
private let sampleContainerWithIncomplete = PreviewDataContainer(includeIncompleteWorkout: true)

@MainActor
func sampleCompletedWorkout() -> Workout {
    let workouts = (try? sampleContainer.context.fetch(Workout.completedWorkouts)) ?? []
    if let workout = workouts.first {
        return workout
    }

    let fallback = Workout(title: "Chest Day", notes: "Testing sample", completed: true, startTime: .now, endTime: .now)
    sampleContainer.context.insert(fallback)
    return fallback
}

@MainActor
func sampleIncompleteWorkout() -> Workout {
    let workouts = (try? sampleContainerWithIncomplete.context.fetch(Workout.incomplete)) ?? []
    if let workout = workouts.first {
        return workout
    }

    let workout = Workout()
    workout.exercises = WorkoutExercise.incompleteChestDay(for: workout)
    sampleContainerWithIncomplete.context.insert(workout)
    return workout
}

@MainActor
func sampleTemplate() -> WorkoutTemplate {
    let descriptor = FetchDescriptor<WorkoutTemplate>()
    let templates = (try? sampleContainer.context.fetch(descriptor)) ?? []
    if let template = templates.first {
        return template
    }
    
    let fallback = WorkoutTemplate(name: "Push Day")
    sampleContainer.context.insert(fallback)
    return fallback
}

extension View {
    func sampleDataConainer() -> some View {
        self
            .modelContainer(sampleContainer.modelContainer)
    }

    func sampleDataContainerIncomplete() -> some View {
        self
            .modelContainer(sampleContainerWithIncomplete.modelContainer)
    }
}

extension Workout {
    static var sampleData: [Workout] {
        func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
            let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
            return Calendar.current.date(from: components) ?? Date.now
        }

        let chest = Workout(title: "Chest Day", notes: "Testing sample", completed: true, startTime: date(2026, 1, 5, 8, 15), endTime: date(2026, 1, 5, 9, 5))
        chest.exercises = WorkoutExercise.chestDay(for: chest)
        
        let back = Workout(title: "Back Day", notes: "Testing sample", completed: true, startTime: date(2026, 1, 6, 11, 30), endTime: date(2026, 1, 6, 13, 0))
        back.exercises = WorkoutExercise.backDay(for: back)
        
        let shoulder = Workout(title: "Shoulder Day", notes: "Testing sample", completed: true, startTime: date(2026, 2, 10, 23, 0), endTime: date(2026, 2, 11, 0, 30))
        shoulder.exercises = WorkoutExercise.shoulderDay(for: shoulder)
        
        let arm = Workout(title: "Arm Day", notes: "Testing sample", completed: true, startTime: date(2026, 3, 31, 23, 10), endTime: date(2026, 4, 1, 0, 20))
        arm.exercises = WorkoutExercise.armDay(for: arm)
        
        let leg = Workout(title: "Leg Day", notes: "Testing sample", completed: true, startTime: date(2026, 12, 31, 22, 15), endTime: date(2027, 1, 1, 0, 5))
        leg.exercises = WorkoutExercise.legDay(for: leg)
        
        return [chest, back, shoulder, arm, leg]
    }
}


extension WorkoutExercise {
    private static func catalogItem(for id: String) -> ExerciseCatalogItem {
        guard let item = ExerciseCatalog.byID[id] else {
            preconditionFailure("Missing catalog item for id: \(id)")
        }
        return item
    }

    private static func makeExercise(index: Int, id: String, workout: Workout, notes: String = "", repRange: RepRangePolicy = RepRangePolicy()) -> WorkoutExercise {
        let item = catalogItem(for: id)
        return WorkoutExercise(index: index, name: item.name, notes: notes, repRange: repRange, musclesTargeted: item.musclesTargeted, workout: workout, catalogID: item.id)
    }

    static func chestDay(for workout: Workout) -> [WorkoutExercise] {
        let e1 = makeExercise(index: 0, id: "barbell_bench_press", workout: workout, notes: "Warm-up + 3x5 @ RPE 8")
        e1.sets = ExerciseSet.sampleCompleteSet(for: e1)

        let e2 = makeExercise(index: 1, id: "dumbbell_incline_bench_press", workout: workout, repRange: RepRangePolicy(activeMode: .range, lowerRange: 8, upperRange: 10))
        e2.sets = ExerciseSet.sampleCompleteSet(for: e2)

        let e3 = makeExercise(index: 2, id: "cable_bench_chest_fly", workout: workout, notes: "slow eccentric", repRange: RepRangePolicy(activeMode: .range, lowerRange: 12, upperRange: 15))
        e3.sets = ExerciseSet.sampleCompleteSet(for: e3)

        let e4 = makeExercise(index: 3, id: "push_ups", workout: workout, notes: "2xAMRAP", repRange: RepRangePolicy(activeMode: .untilFailure))
        e4.sets = ExerciseSet.sampleCompleteSet(for: e4)

        return [e1, e2, e3, e4]
    }
    
    static func backDay(for workout: Workout) -> [WorkoutExercise] {
        let e1 = makeExercise(index: 0, id: "barbell_deadlift", workout: workout, notes: "Warm-up + 3x3 @ RPE 8", repRange: RepRangePolicy(activeMode: .target, targetReps: 3))
        e1.sets = ExerciseSet.sampleCompleteSet(for: e1)

        let e2 = makeExercise(index: 1, id: "barbell_bent_over_row", workout: workout, notes: "straps optional")
        e2.sets = ExerciseSet.sampleCompleteSet(for: e2)

        let e3 = makeExercise(index: 2, id: "cable_lat_pulldown", workout: workout, repRange: RepRangePolicy(activeMode: .range, lowerRange: 10, upperRange: 12))
        e3.sets = ExerciseSet.sampleCompleteSet(for: e3)

        let e4 = makeExercise(index: 3, id: "cable_rope_face_pulls", workout: workout, notes: "focus on scapular movement", repRange: RepRangePolicy(activeMode: .target, targetReps: 15))
        e4.sets = ExerciseSet.sampleCompleteSet(for: e4)

        return [e1, e2, e3, e4]
    }
    
    static func shoulderDay(for workout: Workout) -> [WorkoutExercise] {
        let e1 = makeExercise(index: 0, id: "barbell_shoulder_press", workout: workout, notes: "5x5, full ROM", repRange: RepRangePolicy(activeMode: .target, targetReps: 5))
        e1.sets = ExerciseSet.sampleCompleteSet(for: e1)

        let e2 = makeExercise(index: 1, id: "dumbbell_lateral_raises", workout: workout, notes: "4x12–15, controlled tempo")
        e2.sets = ExerciseSet.sampleCompleteSet(for: e2)

        let e3 = makeExercise(index: 2, id: "dumbbell_rear_delt_fly", workout: workout, notes: "3x12–15", repRange: RepRangePolicy(activeMode: .range, lowerRange: 12, upperRange: 15))
        e3.sets = ExerciseSet.sampleCompleteSet(for: e3)

        let e4 = makeExercise(index: 3, id: "barbell_upright_row", workout: workout, notes: "3x10", repRange: RepRangePolicy(activeMode: .target, targetReps: 10))
        e4.sets = ExerciseSet.sampleCompleteSet(for: e4)

        return [e1, e2, e3, e4]
    }
    
    static func legDay(for workout: Workout) -> [WorkoutExercise] {
        let e1 = makeExercise(index: 0, id: "barbell_squat", workout: workout, notes: "5x5, belt as needed")
        e1.sets = ExerciseSet.sampleCompleteSet(for: e1)

        let e2 = makeExercise(index: 1, id: "barbell_romanian_deadlift", workout: workout, notes: "3x8–10", repRange: RepRangePolicy(activeMode: .range, lowerRange: 8, upperRange: 10))
        e2.sets = ExerciseSet.sampleCompleteSet(for: e2)

        let e3 = makeExercise(index: 2, id: "leg_press", workout: workout, notes: "3x12, full lockout optional", repRange: RepRangePolicy(activeMode: .target, targetReps: 12))
        e3.sets = ExerciseSet.sampleCompleteSet(for: e3)

        let e4 = makeExercise(index: 3, id: "barbell_standing_calf_raises", workout: workout, notes: "4x12–15, pause at top", repRange: RepRangePolicy(activeMode: .range, lowerRange: 12, upperRange: 15))
        e4.sets = ExerciseSet.sampleCompleteSet(for: e4)

        return [e1, e2, e3, e4]
    }
    
    static func armDay(for workout: Workout) -> [WorkoutExercise] {
        let e1 = makeExercise(index: 0, id: "barbell_curls", workout: workout, notes: "4x10, strict form", repRange: RepRangePolicy(activeMode: .target, targetReps: 10))
        e1.sets = ExerciseSet.sampleCompleteSet(for: e1)

        let e2 = makeExercise(index: 1, id: "cable_bar_pushdown", workout: workout, notes: "4x10–12", repRange: RepRangePolicy(activeMode: .range, lowerRange: 10, upperRange: 12))
        e2.sets = ExerciseSet.sampleCompleteSet(for: e2)

        let e3 = makeExercise(index: 2, id: "dumbbell_hammer_curls", workout: workout, notes: "3x12")
        e3.sets = ExerciseSet.sampleCompleteSet(for: e3)

        let e4 = makeExercise(index: 3, id: "barbell_skullcrushers", workout: workout, notes: "3x10", repRange: RepRangePolicy(activeMode: .target, targetReps: 10))
        e4.sets = ExerciseSet.sampleCompleteSet(for: e4)

        return [e1, e2, e3, e4]
    }

    static func incompleteChestDay(for workout: Workout) -> [WorkoutExercise] {
        let e1 = makeExercise(index: 0, id: "barbell_bench_press", workout: workout, notes: "Warm-up + 3x5 @ RPE 8")
        e1.sets = ExerciseSet.sampleIncompleteSet(for: e1)

        let e2 = makeExercise(index: 1, id: "dumbbell_incline_bench_press", workout: workout, repRange: RepRangePolicy(activeMode: .range, lowerRange: 8, upperRange: 10))
        e2.sets = ExerciseSet.sampleIncompleteSet(for: e2)

        let e3 = makeExercise(index: 2, id: "cable_bench_chest_fly", workout: workout, notes: "slow eccentric", repRange: RepRangePolicy(activeMode: .range, lowerRange: 12, upperRange: 15))
        e3.sets = ExerciseSet.sampleIncompleteSet(for: e3)

        let e4 = makeExercise(index: 3, id: "push_ups", workout: workout, notes: "2xAMRAP", repRange: RepRangePolicy(activeMode: .untilFailure))
        e4.sets = ExerciseSet.sampleIncompleteSet(for: e4)

        return [e1, e2, e3, e4]
    }
}

extension ExerciseSet {
    static func sampleCompleteSet(for exercise: WorkoutExercise) -> [ExerciseSet] {
        [
            ExerciseSet(index: 0, type: .warmup, weight: 45, reps: 12, complete: true, exercise: exercise),
            ExerciseSet(index: 1, type: .regular, weight: 75, reps: 10, complete: true, exercise: exercise),
            ExerciseSet(index: 2, type: .regular, weight: 95, reps: 8, complete: true, exercise: exercise)
        ]
    }

    static func sampleIncompleteSet(for exercise: WorkoutExercise) -> [ExerciseSet] {
        [
            ExerciseSet(index: 0, type: .warmup, weight: 45, reps: 12, complete: false, exercise: exercise),
            ExerciseSet(index: 1, type: .regular, weight: 75, reps: 10, complete: false, exercise: exercise),
            ExerciseSet(index: 2, type: .regular, weight: 95, reps: 8, complete: false, exercise: exercise)
        ]
    }
}

extension TemplateExercise {
    private static func catalogItem(for id: String) -> ExerciseCatalogItem {
        guard let item = ExerciseCatalog.byID[id] else {
            preconditionFailure("Missing catalog item for id: \(id)")
        }
        return item
    }
    
    private static func makeExercise(index: Int, id: String, template: WorkoutTemplate, notes: String = "", repRange: RepRangePolicy = RepRangePolicy()) -> TemplateExercise {
        let item = catalogItem(for: id)
        let exercise = TemplateExercise(index: index, name: item.name, notes: notes, repRange: repRange, musclesTargeted: item.musclesTargeted, template: template, catalogID: item.id)
        exercise.sets = TemplateSet.sampleSets(for: exercise)
        return exercise
    }
    
    static func samplePushDay(for template: WorkoutTemplate) -> [TemplateExercise] {
        let e1 = makeExercise(index: 0, id: "barbell_bench_press", template: template, notes: "Warm-up + 3x5 @ RPE 8")
        let e2 = makeExercise(index: 1, id: "dumbbell_incline_bench_press", template: template, repRange: RepRangePolicy(activeMode: .range, lowerRange: 8, upperRange: 10))
        let e3 = makeExercise(index: 2, id: "cable_bench_chest_fly", template: template, notes: "slow eccentric", repRange: RepRangePolicy(activeMode: .range, lowerRange: 12, upperRange: 15))
        let e4 = makeExercise(index: 3, id: "cable_bar_pushdown", template: template, notes: "triceps finisher", repRange: RepRangePolicy(activeMode: .range, lowerRange: 10, upperRange: 12))
        return [e1, e2, e3, e4]
    }
}

extension TemplateSet {
    static func sampleSets(for exercise: TemplateExercise) -> [TemplateSet] {
        [
            TemplateSet(index: 0, type: .warmup, restSeconds: 60, exercise: exercise),
            TemplateSet(index: 1, type: .regular, restSeconds: 90, exercise: exercise),
            TemplateSet(index: 2, type: .regular, restSeconds: 90, exercise: exercise)
        ]
    }
}

extension WorkoutTemplate {
    static var sampleData: [WorkoutTemplate] {
        let pushDay = WorkoutTemplate(name: "Push Day")
        pushDay.notes = "Chest and triceps focus"
        pushDay.exercises = TemplateExercise.samplePushDay(for: pushDay)
        pushDay.isFavorite = true
        
        let pushDay2 = WorkoutTemplate(name: "Push Day")
        pushDay2.notes = "Chest and triceps focus"
        pushDay2.exercises = TemplateExercise.samplePushDay(for: pushDay2)
        pushDay2.lastUsed = Date()
        
        return [pushDay, pushDay2]
    }
}
