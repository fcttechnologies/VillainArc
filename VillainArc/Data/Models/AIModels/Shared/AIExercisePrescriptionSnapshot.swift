import Foundation
import FoundationModels

@Generable
struct AIExercisePrescriptionSnapshot {
    @Guide(description: "Exercise.")
    let exercise: AIExerciseIdentitySnapshot
    @Guide(description: "Rep range.")
    let repRange: AIRepRangeSnapshot?
    @Guide(description: "Target sets.")
    let sets: [AISetPrescriptionSnapshot]

    init(exercise: AIExerciseIdentitySnapshot, repRange: AIRepRangeSnapshot?, sets: [AISetPrescriptionSnapshot]) {
        self.exercise = exercise
        self.repRange = repRange
        self.sets = sets
    }

    init(from prescription: ExercisePrescription) {
        exercise = AIExerciseIdentitySnapshot(prescription: prescription)
        repRange = AIRepRangeSnapshot(policy: prescription.repRange)
        sets = prescription.sortedSets.map { AISetPrescriptionSnapshot(from: $0) }
    }

    init(exercise: AIExerciseIdentitySnapshot, targetSnapshot: ExerciseTargetSnapshot) {
        self.exercise = exercise
        repRange = AIRepRangeSnapshot(snapshot: targetSnapshot.repRange)
        sets = targetSnapshot.sets.map { AISetPrescriptionSnapshot(snapshot: $0) }
    }
}

@Generable
struct AISetPrescriptionSnapshot {
    @Guide(description: "Set index.")
    let index: Int
    @Guide(description: "Set type.")
    let setType: AIExerciseSetType
    @Guide(description: "Target weight kg.")
    let targetWeight: Double
    @Guide(description: "Target reps.")
    let targetReps: Int
    @Guide(description: "Target rest sec.")
    let targetRest: Int

    init(index: Int, setType: AIExerciseSetType, targetWeight: Double, targetReps: Int, targetRest: Int) {
        self.index = index
        self.setType = setType
        self.targetWeight = targetWeight
        self.targetReps = targetReps
        self.targetRest = targetRest
    }

    init(from set: SetPrescription) {
        index = set.index
        setType = AIExerciseSetType(from: set.type)
        targetWeight = set.targetWeight
        targetReps = set.targetReps
        targetRest = set.targetRest
    }

    init(snapshot: SetTargetSnapshot) {
        index = snapshot.index
        setType = AIExerciseSetType(from: snapshot.type)
        targetWeight = snapshot.targetWeight
        targetReps = snapshot.targetReps
        targetRest = snapshot.targetRest
    }
}
