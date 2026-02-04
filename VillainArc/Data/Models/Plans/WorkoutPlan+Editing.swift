import SwiftData
import SwiftUI

@MainActor
extension WorkoutPlan {
    
    // Creates a copy for editing. User edits the copy, original stays untouched until save.
    func createEditingCopy(context: ModelContext) -> WorkoutPlan {
        let copy = WorkoutPlan()
        copy.originalPlan = self
        copy.isEditing = true
        copy.title = title
        copy.notes = notes
        copy.favorite = favorite
        copy.completed = false
        
        // Copy exercises with same IDs
        for exercise in sortedExercises {
            let exerciseCopy = ExercisePrescription(copying: exercise, workoutPlan: copy)
            copy.exercises.append(exerciseCopy)
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
        
        saveContext(context: context)
    }
    
    // Called on the COPY when user cancels. Deletes copy, original untouched.
    func cancelEditing(context: ModelContext) {
        context.delete(self)
        saveContext(context: context)
    }
    
    // Called when user deletes the last exercise. Deletes both copy and original.
    func deletePlanEntirely(context: ModelContext) {
        if let original = originalPlan {
            SpotlightIndexer.deleteWorkoutPlan(id: original.id)
            context.delete(original)
        }
        context.delete(self)
        saveContext(context: context)
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
            
            // Detect exercise-level changes (rep range, rest time mode)
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
        if original.repRange.activeMode != copy.repRange.activeMode {
            createChange(
                type: .changeRepRangeMode,
                previousValue: Double(original.repRange.activeMode.rawValue),
                newValue: Double(copy.repRange.activeMode.rawValue),
                exercise: original,
                set: nil,
                context: context
            )
            markMatchingPendingChanges(exercise: original, changeType: .changeRepRangeMode)
        }
        
        // Rep Range Lower
        if original.repRange.lowerRange != copy.repRange.lowerRange {
            let changeType: ChangeType = copy.repRange.lowerRange > original.repRange.lowerRange
                ? .increaseRepRangeLower
                : .decreaseRepRangeLower
            createChange(
                type: changeType,
                previousValue: Double(original.repRange.lowerRange),
                newValue: Double(copy.repRange.lowerRange),
                exercise: original,
                set: nil,
                context: context
            )
            markMatchingPendingChanges(exercise: original, changeTypes: [.increaseRepRangeLower, .decreaseRepRangeLower])
        }
        
        // Rep Range Upper
        if original.repRange.upperRange != copy.repRange.upperRange {
            let changeType: ChangeType = copy.repRange.upperRange > original.repRange.upperRange
                ? .increaseRepRangeUpper
                : .decreaseRepRangeUpper
            createChange(
                type: changeType,
                previousValue: Double(original.repRange.upperRange),
                newValue: Double(copy.repRange.upperRange),
                exercise: original,
                set: nil,
                context: context
            )
            markMatchingPendingChanges(exercise: original, changeTypes: [.increaseRepRangeUpper, .decreaseRepRangeUpper])
        }
        
        // Rest Time Mode
        if original.restTimePolicy.activeMode != copy.restTimePolicy.activeMode {
            createChange(
                type: .changeRestTimeMode,
                previousValue: Double(original.restTimePolicy.activeMode.rawValue),
                newValue: Double(copy.restTimePolicy.activeMode.rawValue),
                exercise: original,
                set: nil,
                context: context
            )
            markMatchingPendingChanges(exercise: original, changeType: .changeRestTimeMode)
        }
        
        // Rep Range Target (when mode is .target)
        if original.repRange.targetReps != copy.repRange.targetReps {
            let changeType: ChangeType = copy.repRange.targetReps > original.repRange.targetReps
                ? .increaseRepRangeTarget
                : .decreaseRepRangeTarget
            createChange(
                type: changeType,
                previousValue: Double(original.repRange.targetReps),
                newValue: Double(copy.repRange.targetReps),
                exercise: original,
                set: nil,
                context: context
            )
            markMatchingPendingChanges(exercise: original, changeTypes: [.increaseRepRangeTarget, .decreaseRepRangeTarget])
        }
        
        // Rest Time Seconds (when mode is .allSame)
        if original.restTimePolicy.allSameSeconds != copy.restTimePolicy.allSameSeconds {
            let changeType: ChangeType = copy.restTimePolicy.allSameSeconds > original.restTimePolicy.allSameSeconds
                ? .increaseRestTimeSeconds
                : .decreaseRestTimeSeconds
            createChange(
                type: changeType,
                previousValue: Double(original.restTimePolicy.allSameSeconds),
                newValue: Double(copy.restTimePolicy.allSameSeconds),
                exercise: original,
                set: nil,
                context: context
            )
            markMatchingPendingChanges(exercise: original, changeTypes: [.increaseRestTimeSeconds, .decreaseRestTimeSeconds])
        }
    }
    
    // MARK: Set-Level Changes
    
    private func detectSetChanges(original: SetPrescription, copy: SetPrescription, exercise: ExercisePrescription, context: ModelContext) {
        // Weight
        if original.targetWeight != copy.targetWeight {
            let changeType: ChangeType = copy.targetWeight > original.targetWeight
                ? .increaseWeight
                : .decreaseWeight
            createChange(
                type: changeType,
                previousValue: original.targetWeight,
                newValue: copy.targetWeight,
                exercise: exercise,
                set: original,
                context: context
            )
            markMatchingPendingChanges(set: original, changeTypes: [.increaseWeight, .decreaseWeight])
        }
        
        // Reps
        if original.targetReps != copy.targetReps {
            let changeType: ChangeType = copy.targetReps > original.targetReps
                ? .increaseReps
                : .decreaseReps
            createChange(
                type: changeType,
                previousValue: Double(original.targetReps),
                newValue: Double(copy.targetReps),
                exercise: exercise,
                set: original,
                context: context
            )
            markMatchingPendingChanges(set: original, changeTypes: [.increaseReps, .decreaseReps])
        }
        
        // Rest
        if original.targetRest != copy.targetRest {
            let changeType: ChangeType = copy.targetRest > original.targetRest
                ? .increaseRest
                : .decreaseRest
            createChange(
                type: changeType,
                previousValue: Double(original.targetRest),
                newValue: Double(copy.targetRest),
                exercise: exercise,
                set: original,
                context: context
            )
            markMatchingPendingChanges(set: original, changeTypes: [.increaseRest, .decreaseRest])
        }
        
        // Set Type
        if original.type != copy.type {
            createChange(
                type: .changeSetType,
                previousValue: Double(original.type.rawValue),
                newValue: Double(copy.type.rawValue),
                exercise: exercise,
                set: original,
                context: context
            )
            markMatchingPendingChanges(set: original, changeType: .changeSetType)
        }
    }
    
    @discardableResult
    private func createChange(type: ChangeType, previousValue: Double, newValue: Double, exercise: ExercisePrescription, set: SetPrescription?, context: ModelContext) -> PrescriptionChange {
        let change = PrescriptionChange()
        change.source = .user
        change.decision = .accepted
        change.outcome = .pending
        change.changeType = type
        change.previousValue = previousValue
        change.newValue = newValue
        change.targetExercisePrescription = exercise
        change.targetSetPrescription = set
        change.catalogID = exercise.catalogID
        change.createdAt = Date()
        
        context.insert(change)
        return change
    }
}

extension WorkoutPlan {
    // Called when an exercise is deleted. Marks ALL its pending changes.
    private func markPendingAsUserOverride(exercise: ExercisePrescription) {
        for change in exercise.changes {
            markChangeAsUserOverride(change)
        }
        for set in exercise.sets {
            markPendingAsUserOverride(set: set)
        }
    }
    
    // Called when a set is deleted. Marks ALL its pending changes.
    private func markPendingAsUserOverride(set: SetPrescription) {
        for change in set.changes {
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
        for change in exercise.changes where changeTypes.contains(change.changeType) {
            markChangeAsUserOverride(change)
        }
    }
    
    // Marks pending changes that match specific change types for a set
    private func markMatchingPendingChanges(set: SetPrescription, changeType: ChangeType) {
        markMatchingPendingChanges(set: set, changeTypes: [changeType])
    }
    
    private func markMatchingPendingChanges(set: SetPrescription, changeTypes: [ChangeType]) {
        for change in set.changes where changeTypes.contains(change.changeType) {
            markChangeAsUserOverride(change)
        }
    }
}

extension WorkoutPlan {
    // Applies all values from self (copy) to original
    func applyToOriginal(_ original: WorkoutPlan, context: ModelContext) {
        // Update plan-level properties
        original.title = title
        original.notes = notes
        
        let copyExercises = Dictionary(uniqueKeysWithValues: sortedExercises.map { ($0.id, $0) })
        let originalExerciseIDs = Set(original.exercises.map { $0.id })
        
        // ─────────────────────────────────────────────────────────
        // 1. ADD new exercises (move from copy to original)
        // ─────────────────────────────────────────────────────────
        for copyExercise in sortedExercises where !originalExerciseIDs.contains(copyExercise.id) {
            // Move exercise from copy to original by changing relationship
            copyExercise.workoutPlan = original
            original.exercises.append(copyExercise)
            // Sets come along automatically since they're linked to the exercise
        }
        
        // ─────────────────────────────────────────────────────────
        // 2. UPDATE existing exercises
        // ─────────────────────────────────────────────────────────
        for origExercise in original.exercises {
            guard let copyExercise = copyExercises[origExercise.id] else {
                // Will be deleted in step 3
                continue
            }
            
            // Update exercise values
            origExercise.index = copyExercise.index
            origExercise.notes = copyExercise.notes
            origExercise.repRange.activeMode = copyExercise.repRange.activeMode
            origExercise.repRange.lowerRange = copyExercise.repRange.lowerRange
            origExercise.repRange.upperRange = copyExercise.repRange.upperRange
            origExercise.repRange.targetReps = copyExercise.repRange.targetReps
            origExercise.restTimePolicy.activeMode = copyExercise.restTimePolicy.activeMode
            origExercise.restTimePolicy.allSameSeconds = copyExercise.restTimePolicy.allSameSeconds
            
            let copySets = Dictionary(uniqueKeysWithValues: copyExercise.sortedSets.map { ($0.id, $0) })
            let originalSetIDs = Set(origExercise.sets.map { $0.id })
            
            // Add new sets (move from copy)
            for copySet in copyExercise.sortedSets where !originalSetIDs.contains(copySet.id) {
                copySet.exercise = origExercise
                origExercise.sets.append(copySet)
            }
            
            // Update existing sets
            for origSet in origExercise.sets {
                if let copySet = copySets[origSet.id] {
                    origSet.index = copySet.index
                    origSet.type = copySet.type
                    origSet.targetWeight = copySet.targetWeight
                    origSet.targetReps = copySet.targetReps
                    origSet.targetRest = copySet.targetRest
                }
            }
            
            // Delete removed sets (pending already handled in detectChanges)
            let setsToDelete = origExercise.sets.filter { copySets[$0.id] == nil }
            for set in setsToDelete {
                origExercise.sets.removeAll { $0.id == set.id }
                context.delete(set)
            }
            
            // Reindex sets after adding/deleting
            origExercise.reindexSets()
        }
        
        // ─────────────────────────────────────────────────────────
        // 3. DELETE removed exercises (pending already handled in detectChanges)
        // ─────────────────────────────────────────────────────────
        let exercisesToDelete = original.exercises.filter { copyExercises[$0.id] == nil }
        for exercise in exercisesToDelete {
            original.exercises.removeAll { $0.id == exercise.id }
            context.delete(exercise)
        }
        
        // Reindex exercises
        for (i, exercise) in original.sortedExercises.enumerated() {
            exercise.index = i
        }
        
        // Clear editing flag
        original.isEditing = false
    }
}
