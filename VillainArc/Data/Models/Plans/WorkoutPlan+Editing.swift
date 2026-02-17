import SwiftData
import SwiftUI

@MainActor
extension WorkoutPlan {
    
    // Creates a copy for editing. User edits the copy, original stays untouched until save.
    func createEditingCopy(context: ModelContext) -> WorkoutPlan {
        let copy = WorkoutPlan(title: title, notes: notes, favorite: favorite, completed: false)
        copy.originalPlan = self
        copy.isEditing = true
        
        // Copy exercises with same IDs
        for exercise in sortedExercises {
            let exerciseCopy = ExercisePrescription(copying: exercise, workoutPlan: copy)
            copy.exercises?.append(exerciseCopy)
        }
        
        context.insert(copy)
        return copy
    }
    
    // Called on the COPY when user taps Done/Save.
    // Detects changes, applies to original, deletes copy.
    func finishEditing(context: ModelContext) {
        guard let original = originalPlan else {
            // This is not a copy, shouldn't happen
            return
        }
        
        // 1. Detect changes and create PrescriptionChange records
        detectChanges(comparedTo: original, context: context)
        
        // 2. Apply modifications to original
        applyToOriginal(original, context: context)
        
        // 3. Delete self (the copy)
        context.delete(self)
    }
    
    // Called on the COPY when user cancels. Deletes copy, original untouched.
    func cancelEditing(context: ModelContext) {
        context.delete(self)
    }
    
    // Called when user deletes the last exercise. Deletes both copy and original.
    func deletePlanEntirely(context: ModelContext) {
        if let original = originalPlan {
            SpotlightIndexer.deleteWorkoutPlan(id: original.id)
            context.delete(original)
        }
        context.delete(self)
    }
}

extension WorkoutPlan {
    
    // Compares self (copy) to original, creates PrescriptionChange for each difference.
    // Also marks pending changes as userOverride for deleted items.
    func detectChanges(comparedTo original: WorkoutPlan, context: ModelContext) {
        // Build lookups by ID
        let copyExercises = Dictionary(uniqueKeysWithValues: sortedExercises.map { ($0.id, $0) })
        let originalExercises = Dictionary(uniqueKeysWithValues: original.sortedExercises.map { ($0.id, $0) })
        
        // Check each original exercise
        for (exerciseID, origExercise) in originalExercises {
            guard let copyExercise = copyExercises[exerciseID] else {
                // Exercise was DELETED in copy
                // Mark all its pending changes as userOverride
                markPendingAsUserOverride(exercise: origExercise)
                continue
            }
            
            // Detect exercise-level changes (rep range)
            detectExerciseChanges(original: origExercise, copy: copyExercise, context: context)
            
            // Check sets
            let copySets = Dictionary(uniqueKeysWithValues: copyExercise.sortedSets.map { ($0.id, $0) })
            let originalSets = Dictionary(uniqueKeysWithValues: origExercise.sortedSets.map { ($0.id, $0) })
            
            for (setID, origSet) in originalSets {
                guard let copySet = copySets[setID] else {
                    // Set was DELETED in copy
                    markPendingAsUserOverride(set: origSet)
                    continue
                }
                
                // Detect set-level changes (weight, reps, rest, type)
                detectSetChanges(original: origSet, copy: copySet, exercise: origExercise, context: context)
            }
        }
    }
    
    // MARK: Exercise-Level Changes
    
    private func detectExerciseChanges(original: ExercisePrescription, copy: ExercisePrescription, context: ModelContext) {
        // Rep Range Mode
        guard original.repRange != nil, copy.repRange != nil else { return }
        if original.repRange!.activeMode != copy.repRange!.activeMode {
            createChange(type: .changeRepRangeMode, previousValue: Double(original.repRange!.activeMode.rawValue), newValue: Double(copy.repRange!.activeMode.rawValue), exercise: original, set: nil, context: context)
            markMatchingPendingChanges(exercise: original, changeType: .changeRepRangeMode)
        }
        
        // Rep Range Lower
        if original.repRange!.lowerRange != copy.repRange!.lowerRange {
            let changeType: ChangeType = copy.repRange!.lowerRange > original.repRange!.lowerRange
                ? .increaseRepRangeLower
                : .decreaseRepRangeLower
            createChange(type: changeType, previousValue: Double(original.repRange!.lowerRange), newValue: Double(copy.repRange!.lowerRange), exercise: original, set: nil, context: context)
            markMatchingPendingChanges(exercise: original, changeTypes: [.increaseRepRangeLower, .decreaseRepRangeLower])
        }
        
        // Rep Range Upper
        if original.repRange!.upperRange != copy.repRange!.upperRange {
            let changeType: ChangeType = copy.repRange!.upperRange > original.repRange!.upperRange
                ? .increaseRepRangeUpper
                : .decreaseRepRangeUpper
            createChange(type: changeType, previousValue: Double(original.repRange!.upperRange), newValue: Double(copy.repRange!.upperRange), exercise: original, set: nil, context: context)
            markMatchingPendingChanges(exercise: original, changeTypes: [.increaseRepRangeUpper, .decreaseRepRangeUpper])
        }
        
        // Rep Range Target (when mode is .target)
        if original.repRange!.targetReps != copy.repRange!.targetReps {
            let changeType: ChangeType = copy.repRange!.targetReps > original.repRange!.targetReps
                ? .increaseRepRangeTarget
                : .decreaseRepRangeTarget
            createChange(type: changeType, previousValue: Double(original.repRange!.targetReps), newValue: Double(copy.repRange!.targetReps), exercise: original, set: nil, context: context)
            markMatchingPendingChanges(exercise: original, changeTypes: [.increaseRepRangeTarget, .decreaseRepRangeTarget])
        }
        
    }
    
    // MARK: Set-Level Changes
    
    private func detectSetChanges(original: SetPrescription, copy: SetPrescription, exercise: ExercisePrescription, context: ModelContext) {
        // Weight
        if original.targetWeight != copy.targetWeight {
            let changeType: ChangeType = copy.targetWeight > original.targetWeight
                ? .increaseWeight
                : .decreaseWeight
            createChange(type: changeType, previousValue: original.targetWeight, newValue: copy.targetWeight, exercise: exercise, set: original, context: context)
            markMatchingPendingChanges(set: original, changeTypes: [.increaseWeight, .decreaseWeight])
        }
        
        // Reps
        if original.targetReps != copy.targetReps {
            let changeType: ChangeType = copy.targetReps > original.targetReps
                ? .increaseReps
                : .decreaseReps
            createChange(type: changeType, previousValue: Double(original.targetReps), newValue: Double(copy.targetReps), exercise: exercise, set: original, context: context)
            markMatchingPendingChanges(set: original, changeTypes: [.increaseReps, .decreaseReps])
        }
        
        // Rest
        if original.targetRest != copy.targetRest {
            let changeType: ChangeType = copy.targetRest > original.targetRest
                ? .increaseRest
                : .decreaseRest
            createChange(type: changeType, previousValue: Double(original.targetRest), newValue: Double(copy.targetRest), exercise: exercise, set: original, context: context)
            markMatchingPendingChanges(set: original, changeTypes: [.increaseRest, .decreaseRest])
        }
        
        // Set Type
        if original.type != copy.type {
            createChange(type: .changeSetType, previousValue: Double(original.type.rawValue), newValue: Double(copy.type.rawValue), exercise: exercise, set: original, context: context)
            markMatchingPendingChanges(set: original, changeType: .changeSetType)
        }
    }
    
    @discardableResult
    private func createChange(type: ChangeType, previousValue: Double, newValue: Double, exercise: ExercisePrescription, set: SetPrescription?, context: ModelContext) -> PrescriptionChange {
        let change = PrescriptionChange(source: .user, catalogID: exercise.catalogID, targetExercisePrescription: exercise, targetSetPrescription: set, changeType: type, previousValue: previousValue, newValue: newValue, decision: .accepted)
        
        context.insert(change)
        return change
    }
}

extension WorkoutPlan {
    // Called when an exercise is deleted. Marks ALL its pending changes.
    private func markPendingAsUserOverride(exercise: ExercisePrescription) {
        for change in exercise.changes ?? [] {
            markChangeAsUserOverride(change)
        }
        for set in exercise.sets ?? [] {
            markPendingAsUserOverride(set: set)
        }
    }
    
    // Called when a set is deleted. Marks ALL its pending changes.
    private func markPendingAsUserOverride(set: SetPrescription) {
        for change in set.changes ?? [] {
            markChangeAsUserOverride(change)
        }
    }
    
    private func markChangeAsUserOverride(_ change: PrescriptionChange) {
        guard change.source != .user else { return }
        // Deferred decisions → user overrode without accepting/rejecting
        if change.decision == .deferred || change.decision == .pending {
            change.decision = .userOverride
        }
        // Any pending outcome → user modified the baseline
        if change.outcome == .pending {
            change.outcome = .userModified
        }
    }
    
    // Marks pending changes that match specific change types for an exercise
    private func markMatchingPendingChanges(exercise: ExercisePrescription, changeType: ChangeType) {
        markMatchingPendingChanges(exercise: exercise, changeTypes: [changeType])
    }
    
    private func markMatchingPendingChanges(exercise: ExercisePrescription, changeTypes: [ChangeType]) {
        for change in exercise.changes ?? [] where changeTypes.contains(change.changeType) {
            markChangeAsUserOverride(change)
        }
    }
    
    // Marks pending changes that match specific change types for a set
    private func markMatchingPendingChanges(set: SetPrescription, changeType: ChangeType) {
        markMatchingPendingChanges(set: set, changeTypes: [changeType])
    }
    
    private func markMatchingPendingChanges(set: SetPrescription, changeTypes: [ChangeType]) {
        for change in set.changes ?? [] where changeTypes.contains(change.changeType) {
            markChangeAsUserOverride(change)
        }
    }
}

extension WorkoutPlan {
    // Applies all values from self (copy) to original
    func applyToOriginal(_ original: WorkoutPlan, context: ModelContext) {
        applyPlanMetadata(to: original)
        
        let copyExercises = Dictionary(uniqueKeysWithValues: sortedExercises.map { ($0.id, $0) })
        var originalExerciseIDs: Set<UUID> = []
        for exercise in original.exercises ?? [] {
            originalExerciseIDs.insert(exercise.id)
        }
        
        moveNewExercises(to: original, originalExerciseIDs: originalExerciseIDs)
        updateExistingExercises(in: original, copyExercises: copyExercises, context: context)
        deleteRemovedExercises(from: original, copyExercises: copyExercises, context: context)
        reindexExercises(in: original)
        
        original.isEditing = false
    }

    private func applyPlanMetadata(to original: WorkoutPlan) {
        original.title = title
        original.notes = notes
    }

    private func moveNewExercises(to original: WorkoutPlan, originalExerciseIDs: Set<UUID>) {
        for copyExercise in sortedExercises where !originalExerciseIDs.contains(copyExercise.id) {
            copyExercise.workoutPlan = original
            original.exercises?.append(copyExercise)
        }
    }

    private func updateExistingExercises(in original: WorkoutPlan, copyExercises: [UUID: ExercisePrescription], context: ModelContext) {
        for origExercise in original.exercises ?? [] {
            guard let copyExercise = copyExercises[origExercise.id] else {
                continue
            }
            applyExerciseValues(from: copyExercise, to: origExercise)
            syncSets(from: copyExercise, to: origExercise, context: context)
        }
    }

    private func applyExerciseValues(from copyExercise: ExercisePrescription, to originalExercise: ExercisePrescription) {
        originalExercise.index = copyExercise.index
        originalExercise.notes = copyExercise.notes
        guard originalExercise.repRange != nil, copyExercise.repRange != nil else { return }
        originalExercise.repRange!.activeMode = copyExercise.repRange!.activeMode
        originalExercise.repRange!.lowerRange = copyExercise.repRange!.lowerRange
        originalExercise.repRange!.upperRange = copyExercise.repRange!.upperRange
        originalExercise.repRange!.targetReps = copyExercise.repRange!.targetReps
    }

    private func syncSets(from copyExercise: ExercisePrescription, to originalExercise: ExercisePrescription, context: ModelContext) {
        let copySets = Dictionary(uniqueKeysWithValues: copyExercise.sortedSets.map { ($0.id, $0) })
        var originalSetIDs: Set<UUID> = []
        for set in originalExercise.sets ?? [] {
            originalSetIDs.insert(set.id)
        }
        
        for copySet in copyExercise.sortedSets where !originalSetIDs.contains(copySet.id) {
            copySet.exercise = originalExercise
            originalExercise.sets?.append(copySet)
        }
        
        for origSet in originalExercise.sets ?? [] {
            if let copySet = copySets[origSet.id] {
                applySetValues(from: copySet, to: origSet)
            }
        }
        
        let setsToDelete = originalExercise.sets?.filter { copySets[$0.id] == nil }
        for set in setsToDelete ?? [] {
            originalExercise.sets?.removeAll { $0.id == set.id }
            context.delete(set)
        }
        
        originalExercise.reindexSets()
    }

    private func applySetValues(from copySet: SetPrescription, to originalSet: SetPrescription) {
        originalSet.index = copySet.index
        originalSet.type = copySet.type
        originalSet.targetWeight = copySet.targetWeight
        originalSet.targetReps = copySet.targetReps
        originalSet.targetRest = copySet.targetRest
    }

    private func deleteRemovedExercises(from original: WorkoutPlan, copyExercises: [UUID: ExercisePrescription], context: ModelContext) {
        let exercisesToDelete = original.exercises?.filter { copyExercises[$0.id] == nil } ?? []
        for exercise in exercisesToDelete {
            original.exercises?.removeAll { $0.id == exercise.id }
            context.delete(exercise)
        }
    }

    private func reindexExercises(in original: WorkoutPlan) {
        for (i, exercise) in original.sortedExercises.enumerated() {
            exercise.index = i
        }
    }
}
