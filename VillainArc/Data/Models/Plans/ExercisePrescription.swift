import Foundation
import SwiftData

@Model
final class ExercisePrescription {
    #Index<ExercisePrescription>([\.catalogID])
    
    var id: UUID = UUID()
    var index: Int = 0
    var catalogID: String = ""
    var name: String = ""
    var notes: String = ""
    var musclesTargeted: [Muscle] = []
    var equipmentType: EquipmentType = EquipmentType.bodyweight
    @Relationship(deleteRule: .cascade, inverse: \RepRangePolicy.exercisePrescription)
    var repRange: RepRangePolicy? = RepRangePolicy()
    var workoutPlan: WorkoutPlan?
    @Relationship(deleteRule: .nullify)
    var activePerformance: ExercisePerformance?
    @Relationship(deleteRule: .cascade, inverse: \SetPrescription.exercise)
    var sets: [SetPrescription]? = [SetPrescription]()

    @Relationship(deleteRule: .nullify)
    var suggestionEvents: [SuggestionEvent]? = [SuggestionEvent]()

    var sortedSets: [SetPrescription] {
        (sets ?? []).sorted { $0.index < $1.index }
    }

    var totalVolume: Double {
        sortedSets.reduce(0) { $0 + $1.volume }
    }

    // Adding exercise in workout plan creation
    init(exercise: Exercise, workoutPlan: WorkoutPlan) {
        index = workoutPlan.exercises?.count ?? 0
        catalogID = exercise.catalogID
        name = exercise.name
        musclesTargeted = exercise.musclesTargeted
        equipmentType = exercise.equipmentType
        repRange = RepRangePolicy()
        self.workoutPlan = workoutPlan
        addSet()
    }
    
    // Creating from session performance
    init(workoutPlan: WorkoutPlan, exercisePerformance: ExercisePerformance) {
        index = exercisePerformance.index
        catalogID = exercisePerformance.catalogID
        name = exercisePerformance.name
        notes = exercisePerformance.notes
        musclesTargeted = exercisePerformance.musclesTargeted
        equipmentType = exercisePerformance.equipmentType
        repRange = RepRangePolicy(copying: exercisePerformance.repRange)
        self.workoutPlan = workoutPlan
        exercisePerformance.prescription = self
        sets = exercisePerformance.sortedSets.map { SetPrescription(exercisePrescription: self, setPerformance: $0) }
    }
    
    // Creates a copy with the same ID for edit tracking
    init(copying original: ExercisePrescription, workoutPlan: WorkoutPlan) {
        id = original.id  // Same ID enables matching for change detection
        index = original.index
        catalogID = original.catalogID
        name = original.name
        notes = original.notes
        musclesTargeted = original.musclesTargeted
        equipmentType = original.equipmentType
        repRange = RepRangePolicy(copying: original.repRange)
        self.workoutPlan = workoutPlan
        // Copy sets with same IDs - NO changes copied (changes stay on original)
        sets = original.sortedSets.map { SetPrescription(copying: $0, exercise: self) }
    }

    func addSet(restoringFrom originalExercise: ExercisePrescription? = nil) {
        if let restoredSet = nextRestorableTailSet(from: originalExercise) {
            sets?.append(SetPrescription(copying: restoredSet, exercise: self))
            reindexSets()
            return
        }

        if let previous = sortedSets.last {
            sets?.append(SetPrescription(exercisePrescription: self, targetWeight: previous.targetWeight, targetReps: previous.targetReps, targetRest: previous.targetRest, targetRPE: previous.targetRPE))
        } else {
            sets?.append(SetPrescription(exercisePrescription: self, targetRest: RestTimeDefaults.restSeconds))
        }
    }

    func clearLinkedPerformanceReferences() {
        guard let performance = activePerformance else { return }
        performance.clearPrescriptionLinksForHistoricalUse()
    }
    
    func replaceWith(_ exercise: Exercise, keepSets: Bool) {
        guard catalogID != exercise.catalogID else { return }
        clearLinkedPerformanceReferences()
        catalogID = exercise.catalogID
        name = exercise.name
        musclesTargeted = exercise.musclesTargeted
        equipmentType = exercise.equipmentType
        exercise.updateLastAddedAt()

        if !keepSets {
            for set in sets ?? [] {
                modelContext?.delete(set)
            }
            sets?.removeAll()
            addSet()
        }
    }

    func deleteSet(_ set: SetPrescription) {
        sets?.removeAll(where: { $0 == set })
        reindexSets()
    }
    
    func reindexSets() {
        for (index, set) in sortedSets.enumerated() {
            set.index = index
        }
    }

    private func nextRestorableTailSet(from originalExercise: ExercisePrescription?) -> SetPrescription? {
        guard let originalExercise else { return nil }

        let originalSets = originalExercise.sortedSets
        guard !originalSets.isEmpty else { return nil }

        let originalSetIDs = Set(originalSets.map(\.id))
        let usedOriginalSetIDs = Set(sortedSets.map(\.id)).intersection(originalSetIDs)
        let originalSetByID = Dictionary(uniqueKeysWithValues: originalSets.map { ($0.id, $0) })
        let maxLinkedOriginalIndex = sortedSets.compactMap { originalSetByID[$0.id]?.index }.max() ?? -1

        return originalSets.first { set in
            !usedOriginalSetIDs.contains(set.id) && set.index > maxLinkedOriginalIndex
        }
    }

    @discardableResult
    func applyCatalogMetadata(name: String, musclesTargeted: [Muscle], equipmentType: EquipmentType) -> Bool {
        var didChange = false

        if self.name != name {
            self.name = name
            didChange = true
        }
        if self.musclesTargeted != musclesTargeted {
            self.musclesTargeted = musclesTargeted
            didChange = true
        }
        if self.equipmentType != equipmentType {
            self.equipmentType = equipmentType
            didChange = true
        }

        return didChange
    }
}

extension ExercisePrescription: RestTimeEditable {}

extension ExercisePrescription {
    static func matching(catalogID: String) -> FetchDescriptor<ExercisePrescription> {
        let predicate = #Predicate<ExercisePrescription> { $0.catalogID == catalogID }
        return FetchDescriptor(predicate: predicate)
    }
}
