import Foundation
import SwiftData

@Model
class WorkoutExercise {
    var index: Int
    var name: String = ""
    var notes: String = ""
    @Relationship(deleteRule: .cascade)
    var repRange: RepRangePolicy = RepRangePolicy()
    var date: Date = Date.now
    var musclesTargeted: [Muscle] = []
    var restTimePolicy: RestTimePolicy = RestTimePolicy.defaultPolicy
    var workout: Workout?
    @Relationship(deleteRule: .cascade)
    var sets: [ExerciseSet] = []
    
    var displayMuscle: String {
        musclesTargeted.filter(\.isMajor).first?.rawValue ?? ""
    }
    
    var sortedSets: [ExerciseSet] {
        sets.sorted { $0.index < $1.index }
    }
    
    init(from exercise: Exercise, workout: Workout?) {
        index = workout?.exercises.count ?? 0
        name = exercise.name
        musclesTargeted = exercise.musclesTargeted
        self.workout = workout
        addSet()
    }
    
    func addSet() {
        let restSeconds = defaultRestSeconds(for: .regular)
        if let previous = sortedSets.last {
            sets.append(ExerciseSet(index: sets.count, weight: previous.weight, reps: previous.reps, restSeconds: restSeconds))
        } else {
            sets.append(ExerciseSet(index: sets.count, restSeconds: restSeconds))
        }
    }
    
    func removeSet(_ set: ExerciseSet) {
        sets.removeAll { $0 == set }
        
        for (index, exerciseSet) in sortedSets.enumerated() {
            exerciseSet.index = index
        }
    }
    
    func setRestTimePolicy(_ newPolicy: RestTimePolicy) {
        let oldPolicy = restTimePolicy
        
        switch (oldPolicy, newPolicy) {
        case (.individual, .allSame):
            restTimePolicy = .allSame(seconds: RestTimePolicy.defaultAllSameSeconds)
            syncSetRestSeconds(using: restTimePolicy)
        case (.individual, .byType):
            restTimePolicy = .byType(RestTimeByType.defaultValues)
            syncSetRestSeconds(using: restTimePolicy)
        case (_, .individual):
            if case .individual = oldPolicy {
                restTimePolicy = .individual
                return
            }
            
            syncSetRestSeconds(using: oldPolicy)
            restTimePolicy = .individual
        default:
            restTimePolicy = newPolicy
            syncSetRestSeconds(using: restTimePolicy)
        }
    }
    
    func updateRestSecondsForSetTypeChange(_ set: ExerciseSet) {
        if case .individual = restTimePolicy {
            return
        }
        
        set.restSeconds = restSeconds(for: set.type, policy: restTimePolicy)
    }
    
    func effectiveRestSeconds(after set: ExerciseSet) -> Int {
        if let nextSet = sortedSets.first(where: { $0.index == set.index + 1 }),
           isImmediateSequenceType(nextSet.type) {
            return 0
        }
        
        return baseRestSeconds(for: set)
    }
    
    private func baseRestSeconds(for set: ExerciseSet) -> Int {
        switch restTimePolicy {
        case .allSame(let seconds):
            return seconds
        case .byType(let byType):
            return byType.seconds(for: set.type)
        case .individual:
            return set.restSeconds
        }
    }
    
    private func defaultRestSeconds(for type: ExerciseSetType) -> Int {
        restSeconds(for: type, policy: restTimePolicy)
    }
    
    private func restSeconds(for type: ExerciseSetType, policy: RestTimePolicy) -> Int {
        switch policy {
        case .allSame(let seconds):
            return seconds
        case .byType(let byType):
            return byType.seconds(for: type)
        case .individual:
            return RestTimeByType.defaultValues.seconds(for: type)
        }
    }
    
    private func syncSetRestSeconds(using policy: RestTimePolicy) {
        if case .individual = policy {
            return
        }
        
        for set in sets {
            set.restSeconds = restSeconds(for: set.type, policy: policy)
        }
    }
    
    private func isImmediateSequenceType(_ type: ExerciseSetType) -> Bool {
        type == .dropSet || type == .superSet
    }
    
    // Testing
    init(index: Int, name: String, notes: String = "", repRange: RepRangePolicy = RepRangePolicy(), musclesTargeted: [Muscle], workout: Workout?, sets: [ExerciseSet], restTimePolicy: RestTimePolicy = RestTimePolicy.defaultPolicy) {
        self.index = index
        self.name = name
        self.notes = notes
        self.repRange = repRange
        self.musclesTargeted = musclesTargeted
        self.workout = workout
        self.restTimePolicy = restTimePolicy
        self.sets = sets
        
        syncSetRestSeconds(using: restTimePolicy)
    }
}
