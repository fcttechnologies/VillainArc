import Foundation
import SwiftData

@Model
class WorkoutExercise {
    var index: Int
    var catalogID: String
    var name: String = ""
    var notes: String = ""
    @Relationship(deleteRule: .cascade)
    var repRange: RepRangePolicy = RepRangePolicy()
    var date: Date = Date.now
    var musclesTargeted: [Muscle] = []
    @Relationship(deleteRule: .cascade)
    var restTimePolicy: RestTimePolicy = RestTimePolicy()
    var workout: Workout
    @Relationship(deleteRule: .cascade)
    var sets: [ExerciseSet] = []
    
    var displayMuscle: String {
        if let major = musclesTargeted.first(where: \.isMajor) {
            return major.rawValue
        }
        return musclesTargeted.first?.rawValue ?? ""
    }
    
    var sortedSets: [ExerciseSet] {
        sets.sorted { $0.index < $1.index }
    }
    
    init(from exercise: Exercise, workout: Workout, markSetsComplete: Bool = false) {
        index = workout.exercises.count
        catalogID = exercise.catalogID
        name = exercise.name
        musclesTargeted = exercise.musclesTargeted
        self.workout = workout
        addSet(complete: markSetsComplete)
    }

    init(previous exercise: WorkoutExercise, workout: Workout) {
        index = exercise.index
        catalogID = exercise.catalogID
        name = exercise.name
        notes = exercise.notes
        repRange = RepRangePolicy(previous: exercise.repRange)
        musclesTargeted = exercise.musclesTargeted
        restTimePolicy = RestTimePolicy(previous: exercise.restTimePolicy)
        self.workout = workout
        sets = exercise.sortedSets.map { ExerciseSet(previous: $0, exercise: self) }
    }

    init(from templateExercise: TemplateExercise, workout: Workout) {
        index = templateExercise.index
        catalogID = templateExercise.catalogID
        name = templateExercise.name
        notes = templateExercise.notes
        repRange = RepRangePolicy(previous: templateExercise.repRange)
        musclesTargeted = templateExercise.musclesTargeted
        restTimePolicy = RestTimePolicy(previous: templateExercise.restTimePolicy)
        self.workout = workout
        sets = templateExercise.sortedSets.map { ExerciseSet(from: $0, exercise: self) }
    }
    
    func addSet(complete: Bool = false) {
        if let previous = sortedSets.last {
            sets.append(ExerciseSet(index: sets.count, weight: previous.weight, reps: previous.reps, complete: complete, restSeconds: previous.restSeconds, exercise: self))
        } else {
            let restSeconds = restTimePolicy.defaultRegularSeconds()
            sets.append(ExerciseSet(index: sets.count, complete: complete, restSeconds: restSeconds, exercise: self))
        }
    }
    
    func removeSet(_ set: ExerciseSet) {
        sets.removeAll { $0 == set }
        
        for (index, exerciseSet) in sortedSets.enumerated() {
            exerciseSet.index = index
        }
    }
    
    func effectiveRestSeconds(after set: ExerciseSet) -> Int {
        if let nextSet = sortedSets.first(where: { $0.index == set.index + 1 }), isImmediateSequenceType(nextSet.type) {
            return 0
        }
        
        return restTimePolicy.seconds(for: set)
    }
    
    private func isImmediateSequenceType(_ type: ExerciseSetType) -> Bool {
        type == .dropSet || type == .superSet
    }
    
    // Testing
    init(index: Int, name: String, notes: String = "", repRange: RepRangePolicy = RepRangePolicy(), musclesTargeted: [Muscle], workout: Workout, catalogID: String) {
        self.index = index
        self.catalogID = catalogID
        self.name = name
        self.notes = notes
        self.repRange = repRange
        self.musclesTargeted = musclesTargeted
        self.workout = workout
    }
}

extension WorkoutExercise {
    static func lastCompleted(for exercise: WorkoutExercise) -> FetchDescriptor<WorkoutExercise> {
        let catalogID = exercise.catalogID
        let predicate = #Predicate<WorkoutExercise> { item in
            item.catalogID == catalogID && item.workout.completed
        }
        var descriptor = FetchDescriptor(
            predicate: predicate,
            sortBy: [SortDescriptor(\WorkoutExercise.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return descriptor
    }
}

extension WorkoutExercise: RestTimeEditable {}
