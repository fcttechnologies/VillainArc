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
    var equipmentType: EquipmentType = EquipmentType.bodyweight
    @Relationship(deleteRule: .cascade, inverse: \RepRangePolicy.exercisePerformance)
    var repRange: RepRangePolicy? = RepRangePolicy()
    var workoutSession: WorkoutSession?
    var activeInSession: WorkoutSession?
    @Relationship(deleteRule: .nullify, inverse: \ExercisePrescription.performances)
    var prescription: ExercisePrescription?
    var sourceChanges: [PrescriptionChange]? = [PrescriptionChange]()
    @Relationship(deleteRule: .cascade, inverse: \SetPerformance.exercise)
    var sets: [SetPerformance]? = [SetPerformance]()
    
    var sortedSets: [SetPerformance] {
        (sets ?? []).sorted { $0.index < $1.index }
    }
    
    var displayMuscle: String {
        return musclesTargeted.first?.rawValue ?? ""
    }
    
    // Adding exercise in session
    init(exercise: Exercise, workoutSession: WorkoutSession) {
        index = workoutSession.exercises?.count ?? 0
        catalogID = exercise.catalogID
        name = exercise.name
        musclesTargeted = exercise.musclesTargeted
        equipmentType = exercise.equipmentType
        self.workoutSession = workoutSession
        addSet()
    }

    // Test/sample initializer to reduce setup boilerplate.
    convenience init(exercise: Exercise, workoutSession: WorkoutSession, notes: String = "", index: Int? = nil, repRangeMode: RepRangeMode? = nil, lowerRange: Int = 0, upperRange: Int = 0, targetReps: Int = 0) {
        self.init(exercise: exercise, workoutSession: workoutSession)
        self.notes = notes
        if let index {
            self.index = index
        }
        if let repRangeMode, let repRange = self.repRange {
            repRange.activeMode = repRangeMode
            switch repRangeMode {
            case .range:
                repRange.lowerRange = lowerRange
                repRange.upperRange = upperRange
            case .target:
                repRange.targetReps = targetReps
            case .notSet:
                break
            }
        }
    }
    
    // Adding exercise from plan
    init(workoutSession: WorkoutSession, exercisePrescription: ExercisePrescription) {
        index = exercisePrescription.index
        catalogID = exercisePrescription.catalogID
        name = exercisePrescription.name
        notes = exercisePrescription.notes
        musclesTargeted = exercisePrescription.musclesTargeted
        equipmentType = exercisePrescription.equipmentType
        repRange = RepRangePolicy(copying: exercisePrescription.repRange)
        self.workoutSession = workoutSession
        prescription = exercisePrescription
        sets = exercisePrescription.sortedSets.map { SetPerformance(exercise: self, setPrescription: $0) }
    }

    func effectiveRestSeconds(after set: SetPerformance) -> Int {
        if let nextSet = sortedSets.first(where: { $0.index == set.index + 1 }),
           nextSet.type == .dropSet {
            return 0
        }
        return set.restSeconds
    }

    func addSet() {
        if let previous = sortedSets.last {
            sets?.append(SetPerformance(exercise: self, weight: previous.weight, reps: previous.reps, restSeconds: previous.restSeconds))
        } else {
            sets?.append(SetPerformance(exercise: self, restSeconds: RestTimeDefaults.restSeconds))
        }
    }

    func replaceWith(_ exercise: Exercise, keepSets: Bool) {
        catalogID = exercise.catalogID
        name = exercise.name
        musclesTargeted = exercise.musclesTargeted
        equipmentType = exercise.equipmentType
        prescription = nil
        if !keepSets {
            for set in sets ?? [] {
                modelContext?.delete(set)
            }
            sets?.removeAll()
            addSet()
        }
    }

    func deleteSet(_ set: SetPerformance) {
        sets?.removeAll(where: { $0 == set })
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
    var bestEstimated1RM: Double? {
        sets?.compactMap(\.estimated1RM).max()
    }

    var bestWeight: Double? {
        let maxWeight = sets?.map(\.weight).max() ?? 0
        return maxWeight > 0 ? maxWeight : nil
    }

    var totalVolume: Double {
        sets?.reduce(0) { $0 + $1.volume } ?? 0
    }

    static func historicalBestEstimated1RM(in performances: [ExercisePerformance]) -> Double? {
        performances.compactMap(\.bestEstimated1RM).max()
    }

    static func historicalBestWeight(in performances: [ExercisePerformance]) -> Double? {
        performances.compactMap(\.bestWeight).max()
    }

    static func historicalBestVolume(in performances: [ExercisePerformance]) -> Double? {
        let maxVolume = performances.map(\.totalVolume).max() ?? 0
        return maxVolume > 0 ? maxVolume : nil
    }

    static func lastCompleted(for exercise: ExercisePerformance) -> FetchDescriptor<ExercisePerformance> {
        let catalogID = exercise.catalogID
        let done = SessionStatus.done.rawValue
        let predicate = #Predicate<ExercisePerformance> { item in
            item.catalogID == catalogID && item.workoutSession?.status == done
        }
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\ExercisePerformance.date, order: .reverse)])
        descriptor.fetchLimit = 1
        return descriptor
    }
    
    static func matching(catalogID: String) -> FetchDescriptor<ExercisePerformance> {
        let done = SessionStatus.done.rawValue
        let predicate = #Predicate<ExercisePerformance> { item in
            item.catalogID == catalogID && item.workoutSession?.status == done
        }
        return FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\ExercisePerformance.date, order: .reverse)])
    }

    static var completedAll: FetchDescriptor<ExercisePerformance> {
        let done = SessionStatus.done.rawValue
        let predicate = #Predicate<ExercisePerformance> { item in
            item.workoutSession?.status == done
        }
        return FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\ExercisePerformance.date, order: .reverse)])
    }
}
