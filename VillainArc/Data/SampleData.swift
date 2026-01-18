import SwiftUI
import SwiftData

@MainActor
class SampleDataContainer {
    var modelContainer: ModelContainer
    
    var context: ModelContext {
        modelContainer.mainContext
    }
    
    init() {
        let schema = Schema([Workout.self, WorkoutExercise.self, ExerciseSet.self, Exercise.self, RepRangePolicy.self, RestTimePolicy.self, RestTimeHistory.self])

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [.init(schema: schema, isStoredInMemoryOnly: true)])
            
            loadSampleData()
            syncExercises()

        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
    
    private func loadSampleData() {
        for workout in Workout.sampleData {
            context.insert(workout)
        }
    }

    private func seedExercisesIfNeeded() {
        let catalogVersion = ExerciseDetails.allCases.count
        print("Catalog version: \(catalogVersion)")
        let storedVersion = UserDefaults.standard.integer(forKey: "exerciseCatalogVersion")
        print("Stored version: \(storedVersion)")

        if storedVersion != catalogVersion {
            syncExercises()
            UserDefaults.standard.set(catalogVersion, forKey: "exerciseCatalogVersion")
        }
    }

    private func syncExercises() {
        
        for exerciseDetail in ExerciseDetails.allCases {
            let name = exerciseDetail.rawValue
            let predicate = #Predicate<Exercise> {
                $0.name == name
            }
            let descriptor = FetchDescriptor(predicate: predicate)

            if (try? context.fetch(descriptor))?.isEmpty ?? true {
                context.insert(Exercise(from: exerciseDetail))
            }
        }
    }
}

private let sampleContainer = SampleDataContainer()

@MainActor
func sampleWorkout(at index: Int = 0) -> Workout {
    let descriptor = FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.title)])
    let workouts = (try? sampleContainer.context.fetch(descriptor)) ?? []
    if workouts.indices.contains(index) {
        return workouts[index]
    }

    let fallback = Workout(title: "Sample Workout")
    sampleContainer.context.insert(fallback)
    return fallback
}

extension View {
    func sampleDataConainer() -> some View {
        self
            .modelContainer(sampleContainer.modelContainer)
    }
}

extension Workout {
    static var sampleData: [Workout] {
        let now = Date()
        func end(after minutes: Int) -> Date {
            Calendar.current.date(byAdding: .minute, value: minutes, to: now) ?? now
        }
        
        let chest = Workout(title: "Chest Day", notes: "Testing sample", completed: true, endTime: end(after: 60))
        chest.exercises = WorkoutExercise.chestDay(for: chest)
        
        let back = Workout(title: "Back Day", notes: "Testing sample", completed: true, endTime: end(after: 65))
        back.exercises = WorkoutExercise.backDay(for: back)
        
        let shoulder = Workout(title: "Shoulder Day", notes: "Testing sample", completed: true, endTime: end(after: 50))
        shoulder.exercises = WorkoutExercise.shoulderDay(for: shoulder)
        
        let arm = Workout(title: "Arm Day", notes: "Testing sample", completed: true, endTime: end(after: 45))
        arm.exercises = WorkoutExercise.armDay(for: arm)
        
        let leg = Workout(title: "Leg Day", notes: "Testing sample", completed: true, endTime: end(after: 1000))
        leg.exercises = WorkoutExercise.legDay(for: leg)
        
        return [chest, back, shoulder, arm, leg]
    }
}


extension WorkoutExercise {
    static func chestDay(for workout: Workout) -> [WorkoutExercise] {
        let e1 = WorkoutExercise(index: 0, name: "Barbell Bench Press", notes: "Warm-up + 3x5 @ RPE 8", musclesTargeted: [.chest, .midChest, .frontDelt, .triceps], workout: workout)
        e1.sets = ExerciseSet.sampleSet1(for: e1)

        let e2 = WorkoutExercise(index: 1, name: "Incline Dumbbell Press", repRange: RepRangePolicy(activeMode: .range, lowerRange: 8, upperRange: 10), musclesTargeted: [.upperChest, .chest, .frontDelt, .triceps], workout: workout)
        e2.sets = ExerciseSet.sampleSet2(for: e2)

        let e3 = WorkoutExercise(index: 2, name: "Cable Chest Fly", notes: "slow eccentric", repRange: RepRangePolicy(activeMode: .range, lowerRange: 12, upperRange: 15), musclesTargeted: [.chest, .midChest, .frontDelt], workout: workout)
        e3.sets = ExerciseSet.sampleSet3(for: e3)

        let e4 = WorkoutExercise(index: 3, name: "Push-ups", notes: "2xAMRAP", repRange: RepRangePolicy(activeMode: .untilFailure), musclesTargeted: [.chest, .midChest, .frontDelt, .triceps], workout: workout)
        e4.sets = ExerciseSet.sampleSet4(for: e4)

        return [e1, e2, e3, e4]
    }
    
    static func backDay(for workout: Workout) -> [WorkoutExercise] {
        let e1 = WorkoutExercise(index: 0, name: "Deadlift", notes: "Warm-up + 3x3 @ RPE 8", repRange: RepRangePolicy(activeMode: .target, targetReps: 3), musclesTargeted: [.hamstrings, .glutes, .lowerBack, .back], workout: workout)
        e1.sets = ExerciseSet.sampleSet1(for: e1)

        let e2 = WorkoutExercise(index: 1, name: "Bent-Over Row", notes: "straps optional", musclesTargeted: [.back, .lats, .rhomboids, .rearDelt], workout: workout)
        e2.sets = ExerciseSet.sampleSet2(for: e2)

        let e3 = WorkoutExercise(index: 2, name: "Lat Pulldown", repRange: RepRangePolicy(activeMode: .range, lowerRange: 10, upperRange: 12), musclesTargeted: [.lats, .back, .biceps], workout: workout)
        e3.sets = ExerciseSet.sampleSet3(for: e3)

        let e4 = WorkoutExercise(index: 3, name: "Face Pull", notes: "focus on scapular movement", repRange: RepRangePolicy(activeMode: .target, targetReps: 15), musclesTargeted: [.rearDelt, .rhomboids, .shoulders], workout: workout)
        e4.sets = ExerciseSet.sampleSet4(for: e4)

        return [e1, e2, e3, e4]
    }
    
    static func shoulderDay(for workout: Workout) -> [WorkoutExercise] {
        let e1 = WorkoutExercise(index: 0, name: "Overhead Press", notes: "5x5, full ROM", repRange: RepRangePolicy(activeMode: .target, targetReps: 5), musclesTargeted: [.shoulders, .frontDelt, .triceps], workout: workout)
        e1.sets = ExerciseSet.sampleSet1(for: e1)

        let e2 = WorkoutExercise(index: 1, name: "Lateral Raise", notes: "4x12–15, controlled tempo", musclesTargeted: [.sideDelt, .shoulders], workout: workout)
        e2.sets = ExerciseSet.sampleSet2(for: e2)

        let e3 = WorkoutExercise(index: 2, name: "Rear Delt Fly", notes: "3x12–15", repRange: RepRangePolicy(activeMode: .range, lowerRange: 12, upperRange: 15), musclesTargeted: [.rearDelt, .shoulders, .rhomboids], workout: workout)
        e3.sets = ExerciseSet.sampleSet3(for: e3)

        let e4 = WorkoutExercise(index: 3, name: "Upright Row", notes: "3x10", repRange: RepRangePolicy(activeMode: .target, targetReps: 10), musclesTargeted: [.upperTraps, .sideDelt, .shoulders, .biceps], workout: workout)
        e4.sets = ExerciseSet.sampleSet4(for: e4)

        return [e1, e2, e3, e4]
    }
    
    static func legDay(for workout: Workout) -> [WorkoutExercise] {
        let e1 = WorkoutExercise(index: 0, name: "Back Squat", notes: "5x5, belt as needed", musclesTargeted: [.quads, .glutes, .hamstrings], workout: workout)
        e1.sets = ExerciseSet.sampleSet1(for: e1)

        let e2 = WorkoutExercise(index: 1, name: "Romanian Deadlift", notes: "3x8–10", repRange: RepRangePolicy(activeMode: .range, lowerRange: 8, upperRange: 10), musclesTargeted: [.hamstrings, .glutes, .lowerBack], workout: workout)
        e2.sets = ExerciseSet.sampleSet2(for: e2)

        let e3 = WorkoutExercise(index: 2, name: "Leg Press", notes: "3x12, full lockout optional", repRange: RepRangePolicy(activeMode: .target, targetReps: 12), musclesTargeted: [.quads, .glutes], workout: workout)
        e3.sets = ExerciseSet.sampleSet3(for: e3)

        let e4 = WorkoutExercise(index: 3, name: "Standing Calf Raise", notes: "4x12–15, pause at top", repRange: RepRangePolicy(activeMode: .range, lowerRange: 12, upperRange: 15), musclesTargeted: [.calves], workout: workout)
        e4.sets = ExerciseSet.sampleSet4(for: e4)

        return [e1, e2, e3, e4]
    }
    
    static func armDay(for workout: Workout) -> [WorkoutExercise] {
        let e1 = WorkoutExercise(index: 0, name: "Barbell Curl", notes: "4x10, strict form", repRange: RepRangePolicy(activeMode: .target, targetReps: 10), musclesTargeted: [.biceps, .brachialis, .forearms], workout: workout)
        e1.sets = ExerciseSet.sampleSet1(for: e1)

        let e2 = WorkoutExercise(index: 1, name: "Triceps Pushdown", notes: "4x10–12", repRange: RepRangePolicy(activeMode: .range, lowerRange: 10, upperRange: 12), musclesTargeted: [.triceps, .lateralHeadTriceps], workout: workout)
        e2.sets = ExerciseSet.sampleSet2(for: e2)

        let e3 = WorkoutExercise(index: 2, name: "Hammer Curl", notes: "3x12", musclesTargeted: [.brachialis, .biceps, .forearms], workout: workout)
        e3.sets = ExerciseSet.sampleSet3(for: e3)

        let e4 = WorkoutExercise(index: 3, name: "Skull Crushers", notes: "3x10", repRange: RepRangePolicy(activeMode: .target, targetReps: 10), musclesTargeted: [.triceps, .longHeadTriceps], workout: workout)
        e4.sets = ExerciseSet.sampleSet4(for: e4)

        return [e1, e2, e3, e4]
    }
}

extension ExerciseSet {
    static func sampleSet1(for exercise: WorkoutExercise) -> [ExerciseSet] {
        [
            ExerciseSet(index: 0, type: .warmup, weight: 135, reps: 10, exercise: exercise),
            ExerciseSet(index: 1, type: .regular, weight: 185, reps: 8, exercise: exercise),
            ExerciseSet(index: 2, type: .regular, weight: 205, reps: 6, exercise: exercise)
        ]
    }
    
    static func sampleSet2(for exercise: WorkoutExercise) -> [ExerciseSet] {
        [
            ExerciseSet(index: 0, type: .warmup, weight: 45, reps: 12, exercise: exercise),
            ExerciseSet(index: 1, type: .regular, weight: 95, reps: 10, exercise: exercise),
            ExerciseSet(index: 2, type: .regular, weight: 115, reps: 8, exercise: exercise)
        ]
    }
    
    static func sampleSet3(for exercise: WorkoutExercise) -> [ExerciseSet] {
        [
            ExerciseSet(index: 0, type: .regular, weight: 50, reps: 15, exercise: exercise),
            ExerciseSet(index: 1, type: .regular, weight: 60, reps: 12, exercise: exercise),
            ExerciseSet(index: 2, type: .failure, weight: 60, reps: 10, exercise: exercise)
        ]
    }
    
    static func sampleSet4(for exercise: WorkoutExercise) -> [ExerciseSet] {
        [
            ExerciseSet(index: 0, type: .regular, weight: 25, reps: 12, exercise: exercise),
            ExerciseSet(index: 1, type: .regular, weight: 30, reps: 10, exercise: exercise),
            ExerciseSet(index: 2, type: .dropSet, weight: 20, reps: 12, exercise: exercise)
        ]
    }
    
    static func sampleSet5(for exercise: WorkoutExercise) -> [ExerciseSet] {
        [
            ExerciseSet(index: 0, type: .regular, weight: 100, reps: 5, exercise: exercise),
            ExerciseSet(index: 1, type: .regular, weight: 120, reps: 5, exercise: exercise),
            ExerciseSet(index: 2, type: .regular, weight: 135, reps: 5, exercise: exercise)
        ]
    }
}
