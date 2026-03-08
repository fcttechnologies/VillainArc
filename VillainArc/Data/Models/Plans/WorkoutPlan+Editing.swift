import SwiftData
import SwiftUI

@MainActor
extension WorkoutPlan {
    func deleteWithSuggestionCleanup(context: ModelContext) {
        deletePendingOutcomeChanges(context: context)
        context.delete(self)
    }

    func createEditingCopy(context: ModelContext) -> WorkoutPlan {
        let copy = WorkoutPlan(title: title, notes: notes, favorite: favorite, completed: false)
        copy.isEditing = true
        copy.exercises = sortedExercises.map { ExercisePrescription(copying: $0, workoutPlan: copy) }
        context.insert(copy)
        return copy
    }

    func applyEditingCopy(_ copy: WorkoutPlan, context: ModelContext) {
        reconcilePendingChanges(comparedTo: copy, context: context)
        title = copy.title
        notes = copy.notes

        let copyExercises = Dictionary(uniqueKeysWithValues: copy.sortedExercises.map { ($0.id, $0) })
        let originalExerciseIDs = Set((exercises ?? []).map(\.id))

        for copyExercise in copy.sortedExercises where !originalExerciseIDs.contains(copyExercise.id) {
            copyExercise.workoutPlan = self
            exercises?.append(copyExercise)
        }

        for originalExercise in exercises ?? [] {
            guard let copyExercise = copyExercises[originalExercise.id] else {
                continue
            }
            applyExerciseValues(from: copyExercise, to: originalExercise, context: context)
        }

        let exercisesToDelete = exercises?.filter { copyExercises[$0.id] == nil } ?? []
        for exercise in exercisesToDelete {
            deletePendingOutcomeChanges(forExerciseID: exercise.id, context: context)
            exercises?.removeAll { $0.id == exercise.id }
            context.delete(exercise)
        }

        for (index, exercise) in sortedExercises.enumerated() {
            exercise.index = index
        }
    }

    private func reconcilePendingChanges(comparedTo copy: WorkoutPlan, context: ModelContext) {
        let copyExercises = Dictionary(uniqueKeysWithValues: copy.sortedExercises.map { ($0.id, $0) })

        for originalExercise in sortedExercises {
            guard let copyExercise = copyExercises[originalExercise.id] else {
                continue
            }

            if originalExercise.catalogID != copyExercise.catalogID {
                deletePendingOutcomeChanges(forExerciseID: originalExercise.id, context: context)
                continue
            }

            reconcileExercisePendingChanges(original: originalExercise, copy: copyExercise)

            let copySets = Dictionary(uniqueKeysWithValues: copyExercise.sortedSets.map { ($0.id, $0) })
            for originalSet in originalExercise.sortedSets {
                guard let copySet = copySets[originalSet.id] else {
                    continue
                }
                reconcileSetPendingChanges(original: originalSet, copy: copySet)
            }
        }
    }

    private func reconcileExercisePendingChanges(original: ExercisePrescription, copy: ExercisePrescription) {
        guard let originalRepRange = original.repRange, let copyRepRange = copy.repRange else { return }

        if originalRepRange.activeMode != copyRepRange.activeMode {
            markMatchingPendingChangesAsUserOverride(forExerciseID: original.id, changeTypes: [.changeRepRangeMode])
        }
        if originalRepRange.lowerRange != copyRepRange.lowerRange {
            markMatchingPendingChangesAsUserOverride(forExerciseID: original.id, changeTypes: [.increaseRepRangeLower, .decreaseRepRangeLower])
        }
        if originalRepRange.upperRange != copyRepRange.upperRange {
            markMatchingPendingChangesAsUserOverride(forExerciseID: original.id, changeTypes: [.increaseRepRangeUpper, .decreaseRepRangeUpper])
        }
        if originalRepRange.targetReps != copyRepRange.targetReps {
            markMatchingPendingChangesAsUserOverride(forExerciseID: original.id, changeTypes: [.increaseRepRangeTarget, .decreaseRepRangeTarget])
        }
    }

    private func reconcileSetPendingChanges(original: SetPrescription, copy: SetPrescription) {
        if original.type != copy.type {
            markMatchingPendingChangesAsUserOverride(forSetID: original.id, changeTypes: [.changeSetType])
        }
        if original.targetWeight != copy.targetWeight {
            markMatchingPendingChangesAsUserOverride(forSetID: original.id, changeTypes: [.increaseWeight, .decreaseWeight])
        }
        if original.targetReps != copy.targetReps {
            markMatchingPendingChangesAsUserOverride(forSetID: original.id, changeTypes: [.increaseReps, .decreaseReps])
        }
        if original.targetRest != copy.targetRest {
            markMatchingPendingChangesAsUserOverride(forSetID: original.id, changeTypes: [.increaseRest, .decreaseRest])
        }
    }

    private func applyExerciseValues(from copyExercise: ExercisePrescription, to originalExercise: ExercisePrescription, context: ModelContext) {
        originalExercise.index = copyExercise.index
        originalExercise.catalogID = copyExercise.catalogID
        originalExercise.name = copyExercise.name
        originalExercise.notes = copyExercise.notes
        originalExercise.musclesTargeted = copyExercise.musclesTargeted
        originalExercise.equipmentType = copyExercise.equipmentType
        if let originalRepRange = originalExercise.repRange, let copyRepRange = copyExercise.repRange {
            originalRepRange.activeMode = copyRepRange.activeMode
            originalRepRange.lowerRange = copyRepRange.lowerRange
            originalRepRange.upperRange = copyRepRange.upperRange
            originalRepRange.targetReps = copyRepRange.targetReps
        }

        syncSets(from: copyExercise, to: originalExercise, context: context)
    }

    private func syncSets(from copyExercise: ExercisePrescription, to originalExercise: ExercisePrescription, context: ModelContext) {
        let copySets = Dictionary(uniqueKeysWithValues: copyExercise.sortedSets.map { ($0.id, $0) })
        let originalSetIDs = Set((originalExercise.sets ?? []).map(\.id))

        for copySet in copyExercise.sortedSets where !originalSetIDs.contains(copySet.id) {
            copySet.exercise = originalExercise
            originalExercise.sets?.append(copySet)
        }

        for originalSet in originalExercise.sets ?? [] {
            guard let copySet = copySets[originalSet.id] else {
                continue
            }
            originalSet.index = copySet.index
            originalSet.type = copySet.type
            originalSet.targetWeight = copySet.targetWeight
            originalSet.targetReps = copySet.targetReps
            originalSet.targetRest = copySet.targetRest
        }

        let setsToDelete = originalExercise.sets?.filter { copySets[$0.id] == nil } ?? []
        for set in setsToDelete {
            deletePendingOutcomeChanges(forSetID: set.id, context: context)
            originalExercise.sets?.removeAll { $0.id == set.id }
            context.delete(set)
        }

        originalExercise.reindexSets()
    }
}

// MARK: - Pending Change Reconciliation

extension WorkoutPlan {
    func deletePendingOutcomeChanges(context: ModelContext) {
        for change in targetedChanges ?? [] where change.outcome == .pending {
            context.delete(change)
        }
    }

    func deletePendingOutcomeChanges(forExerciseID exerciseID: UUID, context: ModelContext) {
        for change in targetedChanges ?? [] where change.outcome == .pending && change.targetExercisePrescription?.id == exerciseID {
            context.delete(change)
        }
    }

    func deletePendingOutcomeChanges(forSetID setID: UUID, context: ModelContext) {
        for change in targetedChanges ?? [] where change.outcome == .pending && change.targetSetPrescription?.id == setID {
            context.delete(change)
        }
    }

    func markMatchingPendingChangesAsUserOverride(forExerciseID exerciseID: UUID, changeTypes: [ChangeType]) {
        for change in targetedChanges ?? [] where change.targetExercisePrescription?.id == exerciseID && changeTypes.contains(change.changeType) {
            change.markAsUserOverride()
        }
    }

    func markMatchingPendingChangesAsUserOverride(forSetID setID: UUID, changeTypes: [ChangeType]) {
        for change in targetedChanges ?? [] where change.targetSetPrescription?.id == setID && changeTypes.contains(change.changeType) {
            change.markAsUserOverride()
        }
    }
}

extension PrescriptionChange {
    func markAsUserOverride() {
        guard source != .user else { return }
        if decision == .deferred || decision == .pending {
            decision = .userOverride
        }
        if outcome == .pending {
            outcome = .userModified
        }
    }
}
