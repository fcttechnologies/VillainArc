import Foundation
import SwiftData

@Model
class ExercisePerformance {
    var id: UUID = UUID()
    var index: Int = 0
    var date: Date = Date()
    var catalogID: String = ""
    var name: String = ""
    var notes: String = ""
    var musclesTargeted: [Muscle] = []
    @Relationship(deleteRule: .cascade)
    var repRange: RepRangePolicy = RepRangePolicy()
    @Relationship(deleteRule: .cascade)
    var restTimePolicy: RestTimePolicy = RestTimePolicy()
    var workoutSession: WorkoutSession?
    @Relationship(deleteRule: .nullify)
    var prescription: ExercisePrescription?
    @Relationship(deleteRule: .cascade, inverse: \SetPerformance.exercise)
    var sets: [SetPerformance] = []
    
    var sortedSets: [SetPerformance] {
        sets.sorted { $0.index < $1.index }
    }
    
    var displayMuscle: String {
        return musclesTargeted.first?.rawValue ?? ""
    }
    
    // Adding exercise in session
    init(exercise: Exercise, workoutSession: WorkoutSession) {
        index = workoutSession.exercises.count
        catalogID = exercise.catalogID
        name = exercise.name
        musclesTargeted = exercise.musclesTargeted
        self.workoutSession = workoutSession
        addSet()
    }
    
    // Adding exercise from plan
    init(workoutSession: WorkoutSession, exercisePrescription: ExercisePrescription) {
        index = exercisePrescription.index
        catalogID = exercisePrescription.catalogID
        name = exercisePrescription.name
        notes = exercisePrescription.notes
        musclesTargeted = exercisePrescription.musclesTargeted
        repRange = RepRangePolicy(copying: exercisePrescription.repRange)
        restTimePolicy = RestTimePolicy(copying: exercisePrescription.restTimePolicy)
        self.workoutSession = workoutSession
        prescription = exercisePrescription
        sets = exercisePrescription.sortedSets.map { SetPerformance(exercise: self, setPrescription: $0) }
    }

    func effectiveRestSeconds(after set: SetPerformance) -> Int {
        if let nextSet = sortedSets.first(where: { $0.index == set.index + 1 }),
           nextSet.type == .dropSet || nextSet.type == .superSet {
            return 0
        }
        return restTimePolicy.seconds(for: set)
    }

    func addSet() {
        if let previous = sortedSets.last {
            sets.append(SetPerformance(exercise: self, weight: previous.weight, reps: previous.reps, restSeconds: previous.restSeconds))
        } else {
            sets.append(SetPerformance(exercise: self, restSeconds: restTimePolicy.defaultRegularSeconds()))
        }
    }

    func replaceWith(_ exercise: Exercise, keepSets: Bool) {
        catalogID = exercise.catalogID
        name = exercise.name
        musclesTargeted = exercise.musclesTargeted
        if !keepSets {
            for set in sets {
                modelContext?.delete(set)
            }
            sets.removeAll()
            addSet()
        }
    }

    func deleteSet(_ set: SetPerformance) {
        sets.removeAll(where: { $0 == set })
        reindexSets()
    }

    func reindexSets() {
        let sortSets = sortedSets
        for (index, set) in sortSets.enumerated() {
            set.index = index
        }
    }
}

extension ExercisePerformance: RestTimeEditable {}

extension ExercisePerformance {
    static func lastCompleted(for exercise: ExercisePerformance) -> FetchDescriptor<ExercisePerformance> {
        let catalogID = exercise.catalogID
        let done = SessionStatus.done
        let predicate = #Predicate<ExercisePerformance> { item in
            item.catalogID == catalogID && item.workoutSession?.status == done
        }
        var descriptor = FetchDescriptor(
            predicate: predicate,
            sortBy: [SortDescriptor(\ExercisePerformance.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return descriptor
    }
    
    static func matching(catalogID: String) -> FetchDescriptor<ExercisePerformance> {
        let done = SessionStatus.done
        let predicate = #Predicate<ExercisePerformance> { item in
            item.catalogID == catalogID && item.workoutSession?.status == done
        }
        return FetchDescriptor(
            predicate: predicate,
            sortBy: [SortDescriptor(\ExercisePerformance.date, order: .reverse)]
        )
    }

    static var completedAll: FetchDescriptor<ExercisePerformance> {
        let done = SessionStatus.done
        let predicate = #Predicate<ExercisePerformance> { item in
            item.workoutSession?.status == done
        }
        return FetchDescriptor(
            predicate: predicate,
            sortBy: [SortDescriptor(\ExercisePerformance.date, order: .reverse)]
        )
    }
}
