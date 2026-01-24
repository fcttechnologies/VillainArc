import Foundation

enum AccessibilityIdentifiers {
    static func workoutRow(_ workout: Workout) -> String {
        let timestamp = Int(workout.startTime.timeIntervalSince1970)
        return "workoutsListRow-\(timestamp)-\(workout.title)"
    }

    static func workoutDetailExercise(_ exercise: WorkoutExercise) -> String {
        "workoutDetailExercise-\(exercise.catalogID)"
    }

    static func workoutDetailExerciseHeader(_ exercise: WorkoutExercise) -> String {
        "workoutDetailExerciseHeader-\(exercise.catalogID)"
    }

    static func workoutDetailSet(_ exercise: WorkoutExercise, set: ExerciseSet) -> String {
        "workoutDetailSet-\(exercise.catalogID)-\(set.index)"
    }

    static func workoutExercisePage(_ exercise: WorkoutExercise) -> String {
        "workoutExercisePage-\(exercise.catalogID)-\(exercise.index)"
    }

    static func workoutExerciseListRow(_ exercise: WorkoutExercise) -> String {
        "workoutExerciseListRow-\(exercise.catalogID)-\(exercise.index)"
    }

    static func exerciseRepRangeButton(_ exercise: WorkoutExercise) -> String {
        "exerciseRepRangeButton-\(exercise.catalogID)"
    }

    static func exerciseNotesButton(_ exercise: WorkoutExercise) -> String {
        "exerciseNotesButton-\(exercise.catalogID)"
    }

    static func exerciseNotesField(_ exercise: WorkoutExercise) -> String {
        "exerciseNotesField-\(exercise.catalogID)"
    }

    static func exerciseRestTimesButton(_ exercise: WorkoutExercise) -> String {
        "exerciseRestTimesButton-\(exercise.catalogID)"
    }

    static func exerciseAddSetButton(_ exercise: WorkoutExercise) -> String {
        "exerciseAddSetButton-\(exercise.catalogID)"
    }

    static func exerciseSetMenu(_ exercise: WorkoutExercise, set: ExerciseSet) -> String {
        "exerciseSetMenu-\(exercise.catalogID)-\(set.index)"
    }

    static func exerciseSetRepsField(_ exercise: WorkoutExercise, set: ExerciseSet) -> String {
        "exerciseSetRepsField-\(exercise.catalogID)-\(set.index)"
    }

    static func exerciseSetWeightField(_ exercise: WorkoutExercise, set: ExerciseSet) -> String {
        "exerciseSetWeightField-\(exercise.catalogID)-\(set.index)"
    }

    static func exerciseSetPreviousValue(_ exercise: WorkoutExercise, set: ExerciseSet) -> String {
        "exerciseSetPreviousValue-\(exercise.catalogID)-\(set.index)"
    }

    static func exerciseSetCompleteButton(_ exercise: WorkoutExercise, set: ExerciseSet) -> String {
        "exerciseSetCompleteButton-\(exercise.catalogID)-\(set.index)"
    }

    static func exerciseSetDeleteButton(_ exercise: WorkoutExercise, set: ExerciseSet) -> String {
        "exerciseSetDeleteButton-\(exercise.catalogID)-\(set.index)"
    }

    static func exerciseSetUsePreviousButton(_ exercise: WorkoutExercise, set: ExerciseSet) -> String {
        "exerciseSetUsePreviousButton-\(exercise.catalogID)-\(set.index)"
    }

    static func exerciseSetReplaceTimerButton(_ exercise: WorkoutExercise, set: ExerciseSet) -> String {
        "exerciseSetReplaceTimerButton-\(exercise.catalogID)-\(set.index)"
    }

    static func exerciseSetCancelReplaceTimerButton(_ exercise: WorkoutExercise, set: ExerciseSet) -> String {
        "exerciseSetCancelReplaceTimerButton-\(exercise.catalogID)-\(set.index)"
    }

    static func restTimerRecentRow(_ history: RestTimeHistory) -> String {
        "restTimerRecent-\(history.seconds)"
    }

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
    static func workoutRowLabel(for workout: Workout) -> String {
        let dateText = workout.startTime.formatted(.dateTime.month(.abbreviated).day().year())
        return "\(workout.title), \(dateText)"
    }

    static func workoutRowValue(for workout: Workout) -> String {
        let count = workout.sortedExercises.count
        return count == 1 ? "1 exercise" : "\(count) exercises"
    }

    static func exerciseSetLabel(for set: ExerciseSet) -> String {
        set.type == .regular ? "Set \(set.index + 1)" : set.type.rawValue
    }

    static func exerciseSetValue(for set: ExerciseSet) -> String {
        let repsText = set.reps == 1 ? "1 rep" : "\(set.reps) reps"
        let weightText = set.weight.formatted(.number)
        return "\(repsText), \(weightText) pounds"
    }

    static func exerciseSetMenuLabel(for set: ExerciseSet) -> String {
        "Set \(set.index + 1)"
    }

    static func exerciseSetMenuValue(for set: ExerciseSet) -> String {
        set.type.rawValue
    }

    static func exerciseSetCompletionLabel(isComplete: Bool) -> String {
        isComplete ? "Mark incomplete" : "Mark complete"
    }

    static func exerciseSetCountText(_ count: Int) -> String {
        count == 1 ? "1 set" : "\(count) sets"
    }

    static func workoutExerciseListValue(for exercise: WorkoutExercise) -> String {
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
