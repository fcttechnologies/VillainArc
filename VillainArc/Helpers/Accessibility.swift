import Foundation

enum AccessibilityIdentifiers {
    static func workoutRow(_ workout: WorkoutSession) -> String {
        "workoutsListRow-\(workout.id.uuidString)"
    }

    static func workoutDetailExercise(_ exercise: ExercisePerformance) -> String {
        "workoutDetailExercise-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)"
    }

    static func workoutDetailExerciseHeader(_ exercise: ExercisePerformance) -> String {
        "workoutDetailExerciseHeader-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)"
    }

    static func workoutDetailSet(_ exercise: ExercisePerformance, set: SetPerformance) -> String {
        "workoutDetailSet-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)-\(set.index)"
    }

    static func workoutExercisePage(_ exercise: ExercisePerformance) -> String {
        "workoutExercisePage-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)"
    }

    static func workoutExerciseListRow(_ exercise: ExercisePerformance) -> String {
        "workoutExerciseListRow-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)"
    }

    static func workoutPlanExerciseListRow(_ exercise: ExercisePrescription) -> String {
        "workoutPlanExerciseListRow-\(String(describing: exercise.planSnapshot?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)"
    }

    static func exerciseRepRangeButton(_ exercise: ExercisePerformance) -> String {
        "exerciseRepRangeButton-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)"
    }

    static let repRangeSuggestionsSection = "repRangeSuggestionsSection"

    static func repRangeSuggestionButton(catalogID: String, index: Int) -> String {
        "repRangeSuggestionButton-\(slug(catalogID))-\(index)"
    }

    static func workoutPlanExerciseRepRangeButton(_ exercise: ExercisePrescription) -> String {
        "workoutPlanExerciseRepRangeButton-\(String(describing: exercise.planSnapshot?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)"
    }

    static func exerciseNotesButton(_ exercise: ExercisePerformance) -> String {
        "exerciseNotesButton-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)"
    }

    static func workoutPlanExerciseNotesButton(_ exercise: ExercisePrescription) -> String {
        "workoutPlanExerciseNotesButton-\(String(describing: exercise.planSnapshot?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)"
    }

    static func exerciseNotesField(_ exercise: ExercisePerformance) -> String {
        "exerciseNotesField-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)"
    }

    static func workoutPlanExerciseNotesField(_ exercise: ExercisePrescription) -> String {
        "workoutPlanExerciseNotesField-\(String(describing: exercise.planSnapshot?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)"
    }

    static func exerciseRestTimesButton(_ exercise: ExercisePerformance) -> String {
        "exerciseRestTimesButton-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)"
    }

    static func workoutPlanExerciseRestTimesButton(_ exercise: ExercisePrescription) -> String {
        "workoutPlanExerciseRestTimesButton-\(String(describing: exercise.planSnapshot?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)"
    }

    static func exerciseAddSetButton(_ exercise: ExercisePerformance) -> String {
        "exerciseAddSetButton-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)"
    }

    static func exerciseReplaceButton(_ exercise: ExercisePerformance) -> String {
        "exerciseReplaceButton-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)"
    }

    static func exerciseDeleteButton(_ exercise: ExercisePerformance) -> String {
        "exerciseDeleteButton-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)"
    }

    static func workoutPlanExerciseAddSetButton(_ exercise: ExercisePrescription) -> String {
        "workoutPlanExerciseAddSetButton-\(String(describing: exercise.planSnapshot?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)"
    }

    static func exerciseSetMenu(_ exercise: ExercisePerformance, set: SetPerformance) -> String {
        "exerciseSetMenu-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)-\(set.index)"
    }

    static func workoutPlanSetMenu(_ exercise: ExercisePrescription, set: SetPrescription) -> String {
        "workoutPlanSetMenu-\(String(describing: exercise.planSnapshot?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)-\(set.index)"
    }

    static func exerciseSetRepsField(_ exercise: ExercisePerformance, set: SetPerformance) -> String {
        "exerciseSetRepsField-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)-\(set.index)"
    }

    static func workoutPlanSetRepsField(_ exercise: ExercisePrescription, set: SetPrescription) -> String {
        "workoutPlanSetRepsField-\(String(describing: exercise.planSnapshot?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)-\(set.index)"
    }

    static func exerciseSetWeightField(_ exercise: ExercisePerformance, set: SetPerformance) -> String {
        "exerciseSetWeightField-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)-\(set.index)"
    }

    static func workoutPlanSetWeightField(_ exercise: ExercisePrescription, set: SetPrescription) -> String {
        "workoutPlanSetWeightField-\(String(describing: exercise.planSnapshot?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)-\(set.index)"
    }

    static func exerciseSetPreviousValue(_ exercise: ExercisePerformance, set: SetPerformance) -> String {
        "exerciseSetPreviousValue-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)-\(set.index)"
    }

    static func exerciseSetCompleteButton(_ exercise: ExercisePerformance, set: SetPerformance) -> String {
        "exerciseSetCompleteButton-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)-\(set.index)"
    }

    static func exerciseSetDeleteButton(_ exercise: ExercisePerformance, set: SetPerformance) -> String {
        "exerciseSetDeleteButton-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)-\(set.index)"
    }

    static func workoutPlanSetDeleteButton(_ exercise: ExercisePrescription, set: SetPrescription) -> String {
        "workoutPlanSetDeleteButton-\(String(describing: exercise.planSnapshot?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)-\(set.index)"
    }

    static func workoutPlanDetailExercise(_ exercise: ExercisePrescription) -> String {
        "workoutPlanDetailExercise-\(String(describing: exercise.planSnapshot?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)"
    }

    static func workoutPlanDetailExerciseHeader(_ exercise: ExercisePrescription) -> String {
        "workoutPlanDetailExerciseHeader-\(String(describing: exercise.planSnapshot?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)"
    }

    static let workoutPlanPickerList = "workoutPlanPickerList"
    static let workoutPlanPickerClearButton = "workoutPlanPickerClearButton"
    static let workoutPlanDetailSelectButton = "workoutPlanDetailSelectButton"

    static func workoutSplitRenameButton(_ split: WorkoutSplit) -> String {
        "workoutSplitRenameButton-\(split.title)"
    }

    static let workoutSplitTitleEditorField = "workoutSplitTitleEditorField"

    static func workoutPlanDetailSet(_ exercise: ExercisePrescription, set: SetPrescription) -> String {
        "workoutPlanDetailSet-\(String(describing: exercise.planSnapshot?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)-\(set.index)"
    }

    static func exerciseSetUsePreviousButton(_ exercise: ExercisePerformance, set: SetPerformance) -> String {
        "exerciseSetUsePreviousButton-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)-\(set.index)"
    }

    static func exerciseSetReplaceTimerButton(_ exercise: ExercisePerformance, set: SetPerformance) -> String {
        "exerciseSetReplaceTimerButton-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)-\(set.index)"
    }

    static func exerciseSetCancelReplaceTimerButton(_ exercise: ExercisePerformance, set: SetPerformance) -> String {
        "exerciseSetCancelReplaceTimerButton-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)-\(set.index)"
    }

    static let workoutTitleEditorField = "workoutTitleEditorField"
    static let workoutNotesEditorField = "workoutNotesEditorField"
    static let workoutPlanTitleEditorField = "workoutPlanTitleEditorField"
    static let workoutPlanNotesEditorField = "workoutPlanNotesEditorField"

    static func restTimerRecentRow(_ history: RestTimeHistory) -> String {
        let timestamp = Int(history.lastUsed.timeIntervalSince1970)
        return "restTimerRecent-\(history.seconds)-\(timestamp)"
    }

    static func restTimerAdjustButton(deltaSeconds: Int) -> String {
        let direction = deltaSeconds < 0 ? "minus" : "plus"
        return "restTimerAdjustButton-\(direction)-\(abs(deltaSeconds))"
    }

    static let restTimerNextSet = "restTimerNextSet"
    static let restTimerCompleteSetButton = "restTimerCompleteSetButton"

    static func restTimeRowButton(_ title: String) -> String {
        "restTimeRowButton-\(slug(title))"
    }

    static func restTimeRowPicker(_ title: String) -> String {
        "restTimeRowPicker-\(slug(title))"
    }

    static func exerciseCatalogRow(_ exercise: Exercise) -> String {
        "exerciseCatalogRow-\(exercise.catalogID)"
    }

    static func exerciseFavoriteToggle(_ exercise: Exercise) -> String {
        "exerciseFavoriteToggle-\(exercise.catalogID)"
    }

    static func muscleFilterChip(_ muscle: Muscle) -> String {
        "muscleFilterChip-\(slug(muscle.rawValue))"
    }

    private static func slug(_ text: String) -> String {
        let lowercase = text.lowercased()
        var result = ""
        var previousWasDash = false

        for scalar in lowercase.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                result.append(Character(scalar))
                previousWasDash = false
            } else if !previousWasDash {
                result.append("-")
                previousWasDash = true
            }
        }

        return result.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}

enum AccessibilityText {
    static func workoutRowLabel(for workout: WorkoutSession) -> String {
        let dateText = workout.startedAt.formatted(.dateTime.month(.abbreviated).day().year())
        return "\(workout.title), \(dateText)"
    }

    static func workoutRowValue(for workout: WorkoutSession) -> String {
        let count = workout.exercises.count
        return count == 1 ? "1 exercise" : "\(count) exercises"
    }

    static func exerciseSetLabel(for set: SetPerformance) -> String {
        set.type == .regular ? "Set \(set.index + 1)" : set.type.rawValue
    }

    static func exerciseSetLabel(for set: SetPrescription) -> String {
        set.type == .regular ? "Set \(set.index + 1)" : set.type.rawValue
    }

    static func exerciseSetValue(for set: SetPerformance) -> String {
        let repsText = set.reps == 1 ? "1 rep" : "\(set.reps) reps"
        let weightText = set.weight.formatted(.number)
        return "\(repsText), \(weightText) pounds"
    }

    static func exerciseSetValue(for set: SetPrescription) -> String {
        let hasReps = set.targetReps > 0
        let hasWeight = set.targetWeight > 0
        guard hasReps || hasWeight else { return "No target set" }

        let repsText = hasReps ? (set.targetReps == 1 ? "1 rep" : "\(set.targetReps) reps") : "No reps target"
        let weightText = hasWeight ? "\(set.targetWeight.formatted(.number)) pounds" : "No weight target"
        return "\(repsText), \(weightText)"
    }

    static func exerciseSetMenuLabel(for set: SetPerformance) -> String {
        "Set \(set.index + 1)"
    }

    static func exerciseSetMenuValue(for set: SetPerformance) -> String {
        set.type.rawValue
    }

    static func exerciseSetMenuLabel(for set: SetPrescription) -> String {
        "Set \(set.index + 1)"
    }

    static func exerciseSetMenuValue(for set: SetPrescription) -> String {
        set.type.rawValue
    }

    static func exerciseSetCompletionLabel(isComplete: Bool) -> String {
        isComplete ? "Mark incomplete" : "Mark complete"
    }

    static func exerciseSetCountText(_ count: Int) -> String {
        count == 1 ? "1 set" : "\(count) sets"
    }

    static func workoutExerciseListValue(for exercise: ExercisePerformance) -> String {
        let totalSets = exercise.sortedSets.count
        let completedSets = exercise.sortedSets.filter { $0.complete }.count
        let setsText: String
        if totalSets > 0, completedSets == totalSets {
            setsText = "All sets complete"
        } else if completedSets > 0 {
            setsText = "\(completedSets)/\(totalSets) sets complete"
        } else {
            setsText = exerciseSetCountText(totalSets)
        }
        guard !exercise.displayMuscle.isEmpty else {
            return setsText
        }
        return "\(exercise.displayMuscle), \(setsText)"
    }

    static func workoutPlanExerciseListValue(for exercise: ExercisePrescription) -> String {
        let setsText = exerciseSetCountText(exercise.sortedSets.count)
        guard !exercise.displayMuscle.isEmpty else {
            return setsText
        }
        return "\(exercise.displayMuscle), \(setsText)"
    }

    static func exerciseCatalogValue(for exercise: Exercise, isSelected: Bool) -> String {
        var parts: [String] = []

        if !exercise.displayMuscles.isEmpty {
            parts.append(exercise.displayMuscles)
        }

        if exercise.favorite {
            parts.append("Favorite")
        }

        if isSelected {
            parts.append("Selected")
        }

        return parts.joined(separator: ", ")
    }
}
