import SwiftData
import SwiftUI

@MainActor
extension WorkoutPlan {
    func deleteWithSuggestionCleanup(context: ModelContext) {
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
        markPendingChangesAsUserOverride(comparedTo: copy)
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
            exercises?.removeAll { $0.id == exercise.id }
            context.delete(exercise)
        }

        for (index, exercise) in sortedExercises.enumerated() {
            exercise.index = index
        }
    }

    private func markPendingChangesAsUserOverride(comparedTo copy: WorkoutPlan) {
        let copyExercises = Dictionary(uniqueKeysWithValues: copy.sortedExercises.map { ($0.id, $0) })

        for originalExercise in sortedExercises {
            guard let copyExercise = copyExercises[originalExercise.id] else {
                continue
            }

            if originalExercise.catalogID != copyExercise.catalogID {
                originalExercise.markAllPendingChangesAsUserOverride()
                continue
            }

            markExercisePendingChangesAsUserOverride(original: originalExercise, copy: copyExercise)

            let copySets = Dictionary(uniqueKeysWithValues: copyExercise.sortedSets.map { ($0.id, $0) })
            for originalSet in originalExercise.sortedSets {
                guard let copySet = copySets[originalSet.id] else {
                    continue
                }
                markSetPendingChangesAsUserOverride(original: originalSet, copy: copySet)
            }
        }
    }

    private func markExercisePendingChangesAsUserOverride(original: ExercisePrescription, copy: ExercisePrescription) {
        guard let originalRepRange = original.repRange, let copyRepRange = copy.repRange else { return }

        let originalWorkingSetCount = original.sortedSets.filter { $0.type == .working }.count
        let copyWorkingSetCount = copy.sortedSets.filter { $0.type == .working }.count
        if originalWorkingSetCount != copyWorkingSetCount {
            original.markMatchingPendingChangesAsUserOverride(for: [.removeSet])
        }

        if originalRepRange.activeMode != copyRepRange.activeMode {
            original.markMatchingPendingChangesAsUserOverride(for: [.changeRepRangeMode])
        }
        if originalRepRange.lowerRange != copyRepRange.lowerRange {
            original.markMatchingPendingChangesAsUserOverride(for: [.increaseRepRangeLower, .decreaseRepRangeLower])
        }
        if originalRepRange.upperRange != copyRepRange.upperRange {
            original.markMatchingPendingChangesAsUserOverride(for: [.increaseRepRangeUpper, .decreaseRepRangeUpper])
        }
        if originalRepRange.targetReps != copyRepRange.targetReps {
            original.markMatchingPendingChangesAsUserOverride(for: [.increaseRepRangeTarget, .decreaseRepRangeTarget])
        }
    }

    private func markSetPendingChangesAsUserOverride(original: SetPrescription, copy: SetPrescription) {
        if original.type != copy.type {
            original.markMatchingPendingChangesAsUserOverride(for: [.changeSetType])
        }
        if original.targetWeight != copy.targetWeight {
            original.markMatchingPendingChangesAsUserOverride(for: [.increaseWeight, .decreaseWeight])
        }
        if original.targetReps != copy.targetReps {
            original.markMatchingPendingChangesAsUserOverride(for: [.increaseReps, .decreaseReps])
        }
        if original.targetRest != copy.targetRest {
            original.markMatchingPendingChangesAsUserOverride(for: [.increaseRest, .decreaseRest])
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
            originalExercise.sets?.removeAll { $0.id == set.id }
            context.delete(set)
        }

        originalExercise.reindexSets()
    }
}

// MARK: - User Override Marking

extension ExercisePrescription {
    func markMatchingPendingChangesAsUserOverride(for changeTypes: [ChangeType]) {
        for change in changes ?? [] where changeTypes.contains(change.changeType) {
            change.markAsUserOverride()
        }
    }

    func markAllPendingChangesAsUserOverride() {
        for change in changes ?? [] {
            change.markAsUserOverride()
        }
        for set in sortedSets {
            set.markAllPendingChangesAsUserOverride()
        }
    }
}

extension SetPrescription {
    func markMatchingPendingChangesAsUserOverride(for changeTypes: [ChangeType]) {
        for change in changes ?? [] where changeTypes.contains(change.changeType) {
            change.markAsUserOverride()
        }
    }

    func markAllPendingChangesAsUserOverride() {
        for change in changes ?? [] {
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
