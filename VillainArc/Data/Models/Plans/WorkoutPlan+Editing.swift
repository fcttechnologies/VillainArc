import SwiftData
import SwiftUI

@MainActor
extension WorkoutPlan {
    func deleteWithSuggestionCleanup(context: ModelContext) {
        deletePendingOutcomeChanges(context: context)
        context.delete(self)
    }

    func createEditingCopy(context: ModelContext) -> WorkoutPlan {
        let copy = WorkoutPlan(title: title, notes: notes, favorite: favorite, completed: false, origin: origin)
        copy.isEditing = true
        copy.exercises = sortedExercises.map { ExercisePrescription(copying: $0, workoutPlan: copy) }
        context.insert(copy)
        return copy
    }

    func applyEditingCopy(_ copy: WorkoutPlan, context: ModelContext) {
        reconcilePendingChanges(comparedTo: copy, context: context)
        title = copy.title
        notes = copy.notes
        origin = copy.origin

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
            deletePendingOutcomeChanges(for: exercise, context: context)
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
                deletePendingOutcomeChanges(for: originalExercise, context: context)
                continue
            }

            reconcileExercisePendingChanges(original: originalExercise, copy: copyExercise, context: context)

            let copySets = Dictionary(uniqueKeysWithValues: copyExercise.sortedSets.map { ($0.id, $0) })
            for originalSet in originalExercise.sortedSets {
                guard let copySet = copySets[originalSet.id] else {
                    continue
                }
                reconcileSetPendingChanges(original: originalSet, copy: copySet, context: context)
            }
        }
    }

    private func reconcileExercisePendingChanges(original: ExercisePrescription, copy: ExercisePrescription, context: ModelContext) {
        guard let originalRepRange = original.repRange, let copyRepRange = copy.repRange else { return }

        if originalRepRange.activeMode != copyRepRange.activeMode {
            deleteMatchingPendingOutcomeChanges(for: original, changeTypes: [.changeRepRangeMode], context: context)
        }
        if originalRepRange.lowerRange != copyRepRange.lowerRange {
            deleteMatchingPendingOutcomeChanges(for: original, changeTypes: [.increaseRepRangeLower, .decreaseRepRangeLower], context: context)
        }
        if originalRepRange.upperRange != copyRepRange.upperRange {
            deleteMatchingPendingOutcomeChanges(for: original, changeTypes: [.increaseRepRangeUpper, .decreaseRepRangeUpper], context: context)
        }
        if originalRepRange.targetReps != copyRepRange.targetReps {
            deleteMatchingPendingOutcomeChanges(for: original, changeTypes: [.increaseRepRangeTarget, .decreaseRepRangeTarget], context: context)
        }
    }

    private func reconcileSetPendingChanges(original: SetPrescription, copy: SetPrescription, context: ModelContext) {
        if original.type != copy.type {
            deleteMatchingPendingOutcomeChanges(for: original, changeTypes: [.changeSetType], context: context)
        }
        if original.targetWeight != copy.targetWeight {
            deleteMatchingPendingOutcomeChanges(for: original, changeTypes: [.increaseWeight, .decreaseWeight], context: context)
        }
        if original.targetReps != copy.targetReps {
            deleteMatchingPendingOutcomeChanges(for: original, changeTypes: [.increaseReps, .decreaseReps], context: context)
        }
        if original.targetRest != copy.targetRest {
            deleteMatchingPendingOutcomeChanges(for: original, changeTypes: [.increaseRest, .decreaseRest], context: context)
        }
    }

    private func applyExerciseValues(from copyExercise: ExercisePrescription, to originalExercise: ExercisePrescription, context: ModelContext) {
        if originalExercise.catalogID != copyExercise.catalogID {
            originalExercise.clearLinkedPerformanceReferences()
        }
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
            originalSet.targetRPE = copySet.targetRPE
        }

        let setsToDelete = originalExercise.sets?.filter { copySets[$0.id] == nil } ?? []
        for set in setsToDelete {
            deletePendingOutcomeChanges(for: set, context: context)
            originalExercise.sets?.removeAll { $0.id == set.id }
            context.delete(set)
        }

        originalExercise.reindexSets()
    }
}

// MARK: - Pending Change Reconciliation

extension WorkoutPlan {
    func deletePendingOutcomeChanges(context: ModelContext) {
        let exerciseChanges = sortedExercises.flatMap { Array($0.changes ?? []) }
        let setChanges = sortedExercises.flatMap { $0.sortedSets.flatMap { Array($0.changes ?? []) } }
        deleteUnresolvedChanges(exerciseChanges + setChanges, context: context)
    }

    func deletePendingOutcomeChanges(for exercise: ExercisePrescription, context: ModelContext) {
        let exerciseChanges = Array(exercise.changes ?? [])
        let setChanges = exercise.sortedSets.flatMap { $0.changes ?? [] }
        deleteUnresolvedChanges(exerciseChanges + setChanges, context: context)
    }

    func deletePendingOutcomeChanges(for set: SetPrescription, context: ModelContext) {
        deleteUnresolvedChanges(Array(set.changes ?? []), context: context)
    }

    func deleteMatchingPendingOutcomeChanges(for exercise: ExercisePrescription, changeTypes: [ChangeType], context: ModelContext) {
        let matching = Array(exercise.changes ?? []).filter { changeTypes.contains($0.changeType) }
        deleteUnresolvedChanges(matching, context: context)
    }

    func deleteMatchingPendingOutcomeChanges(for set: SetPrescription, changeTypes: [ChangeType], context: ModelContext) {
        let matching = Array(set.changes ?? []).filter { changeTypes.contains($0.changeType) }
        deleteUnresolvedChanges(matching, context: context)
    }

    private func deleteUnresolvedChanges(_ changes: [PrescriptionChange], context: ModelContext) {
        var seenChangeIDs = Set<UUID>()
        var seenEventIDs = Set<UUID>()
        for change in changes where seenChangeIDs.insert(change.id).inserted {
            deleteUnresolvedChange(change, seenEventIDs: &seenEventIDs, context: context)
        }
    }

    private func deleteUnresolvedChange(_ change: PrescriptionChange, seenEventIDs: inout Set<UUID>, context: ModelContext) {
        if let event = change.event {
            guard event.outcome == .pending else { return }
            guard seenEventIDs.insert(event.id).inserted else { return }
            context.delete(event)
        } else {
            context.delete(change)
        }
    }
}
