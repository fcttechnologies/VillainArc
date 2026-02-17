import Foundation

enum AccessibilityIdentifiers {
    // MARK: - ContentView
    static let homeWorkoutSplitSection = "homeWorkoutSplitSection"
    static let homeRecentWorkoutSection = "homeRecentWorkoutSection"
    static let homeRecentWorkoutPlanSection = "homeRecentWorkoutPlanSection"
    static let homeOptionsMenu = "homeOptionsMenu"
    static let homeStartWorkoutButton = "homeStartWorkoutButton"
    static let homeCreatePlanButton = "homeCreatePlanButton"

    // MARK: - WorkoutSplitSectionView
    static let workoutSplitLink = "workoutSplitLink"
    static let recentWorkoutSplitEmptyState = "recentWorkoutSplitEmptyState"
    static let recentWorkoutSplitActiveRow = "recentWorkoutSplitActiveRow"
    static let recentWorkoutSplitNoDayState = "recentWorkoutSplitNoDayState"
    static let recentWorkoutSplitNoActiveState = "recentWorkoutSplitNoActiveState"

    static func recentWorkoutSplitPlanButton(_ plan: WorkoutPlan) -> String {
        "recentWorkoutSplitPlanButton-\(plan.id)"
    }

    // MARK: - RecentWorkoutSectionView
    static let workoutHistoryLink = "workoutHistoryLink"
    static let recentWorkoutEmptyState = "recentWorkoutEmptyState"
    static let recentWorkoutRow = "recentWorkoutRow"

    // MARK: - RecentWorkoutPlanSectionView
    static let allWorkoutPlansLink = "allWorkoutPlansLink"
    static let recentWorkoutPlanEmptyState = "recentWorkoutPlanEmptyState"

    // MARK: - WorkoutsListView
    static let workoutsList = "workoutsList"
    static let workoutsDeleteAllButton = "workoutsDeleteAllButton"
    static let workoutsDeleteAllConfirmButton = "workoutsDeleteAllConfirmButton"
    static let workoutsDoneEditingButton = "workoutsDoneEditingButton"
    static let workoutsEditButton = "workoutsEditButton"
    static let workoutsEmptyState = "workoutsEmptyState"

    // MARK: - WorkoutPlansListView
    static let workoutPlansList = "workoutPlansList"
    static let workoutPlansDeleteAllButton = "workoutPlansDeleteAllButton"
    static let workoutPlansDeleteAllConfirmButton = "workoutPlansDeleteAllConfirmButton"
    static let workoutPlansDoneEditingButton = "workoutPlansDoneEditingButton"
    static let workoutPlansEditButton = "workoutPlansEditButton"
    static let workoutPlansOptionsMenu = "workoutPlansOptionsMenu"
    static let workoutPlansFavoritesToggle = "workoutPlansFavoritesToggle"
    static let workoutPlansEmptyState = "workoutPlansEmptyState"
    static let workoutPlansNoFavoritesState = "workoutPlansNoFavoritesState"

    static func workoutRow(_ workout: WorkoutSession) -> String {
        "workoutsListRow-\(workout.id.uuidString)"
    }

    static func workoutPlanRow(_ workoutPlan: WorkoutPlan) -> String {
        "workoutPlanRow-\(workoutPlan.id)"
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
        "workoutPlanExerciseListRow-\(String(describing: exercise.workoutPlan?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)"
    }

    static func exerciseRepRangeButton(_ exercise: ExercisePerformance) -> String {
        "exerciseRepRangeButton-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)"
    }

    static let repRangeSuggestionsSection = "repRangeSuggestionsSection"

    static func repRangeSuggestionButton(catalogID: String, index: Int) -> String {
        "repRangeSuggestionButton-\(slug(catalogID))-\(index)"
    }

    static func workoutPlanExerciseRepRangeButton(_ exercise: ExercisePrescription) -> String {
        "workoutPlanExerciseRepRangeButton-\(String(describing: exercise.workoutPlan?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)"
    }

    static func exerciseNotesButton(_ exercise: ExercisePerformance) -> String {
        "exerciseNotesButton-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)"
    }

    static func workoutPlanExerciseNotesButton(_ exercise: ExercisePrescription) -> String {
        "workoutPlanExerciseNotesButton-\(String(describing: exercise.workoutPlan?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)"
    }

    static func exerciseNotesField(_ exercise: ExercisePerformance) -> String {
        "exerciseNotesField-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)"
    }

    static func workoutPlanExerciseNotesField(_ exercise: ExercisePrescription) -> String {
        "workoutPlanExerciseNotesField-\(String(describing: exercise.workoutPlan?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)"
    }

    static func exerciseRestTimesButton(_ exercise: ExercisePerformance) -> String {
        "exerciseRestTimesButton-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)"
    }

    static func workoutPlanExerciseRestTimesButton(_ exercise: ExercisePrescription) -> String {
        "workoutPlanExerciseRestTimesButton-\(String(describing: exercise.workoutPlan?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)"
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
        "workoutPlanExerciseAddSetButton-\(String(describing: exercise.workoutPlan?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)"
    }

    static func exerciseSetMenu(_ exercise: ExercisePerformance, set: SetPerformance) -> String {
        "exerciseSetMenu-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)-\(set.index)"
    }

    static func workoutPlanSetMenu(_ exercise: ExercisePrescription, set: SetPrescription) -> String {
        "workoutPlanSetMenu-\(String(describing: exercise.workoutPlan?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)-\(set.index)"
    }

    static func exerciseSetRepsField(_ exercise: ExercisePerformance, set: SetPerformance) -> String {
        "exerciseSetRepsField-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)-\(set.index)"
    }

    static func workoutPlanSetRepsField(_ exercise: ExercisePrescription, set: SetPrescription) -> String {
        "workoutPlanSetRepsField-\(String(describing: exercise.workoutPlan?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)-\(set.index)"
    }

    static func exerciseSetWeightField(_ exercise: ExercisePerformance, set: SetPerformance) -> String {
        "exerciseSetWeightField-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)-\(set.index)"
    }

    static func workoutPlanSetWeightField(_ exercise: ExercisePrescription, set: SetPrescription) -> String {
        "workoutPlanSetWeightField-\(String(describing: exercise.workoutPlan?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)-\(set.index)"
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
        "workoutPlanSetDeleteButton-\(String(describing: exercise.workoutPlan?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)-\(set.index)"
    }

    static func workoutPlanDetailExercise(_ exercise: ExercisePrescription) -> String {
        "workoutPlanDetailExercise-\(String(describing: exercise.workoutPlan?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)"
    }

    static func workoutPlanDetailExerciseHeader(_ exercise: ExercisePrescription) -> String {
        "workoutPlanDetailExerciseHeader-\(String(describing: exercise.workoutPlan?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)"
    }

    static let workoutPlanPickerList = "workoutPlanPickerList"
    static let workoutPlanPickerClearButton = "workoutPlanPickerClearButton"
    static let workoutPlanPickerCreateButton = "workoutPlanPickerCreateButton"
    static let workoutPlanDetailSelectButton = "workoutPlanDetailSelectButton"
    static let workoutPlanDetailUseButton = "workoutPlanDetailUseButton"

    // MARK: - WorkoutSplitView
    static let workoutSplitList = "workoutSplitList"
    static let workoutSplitActiveRow = "workoutSplitActiveRow"
    static let workoutSplitNoActiveView = "workoutSplitNoActiveView"
    static let workoutSplitCreateButton = "workoutSplitCreateButton"
    static let workoutSplitEmptyState = "workoutSplitEmptyState"
    static let workoutSplitRestDayUnavailable = "workoutSplitRestDayUnavailable"
    static let workoutSplitActivePlanRow = "workoutSplitActivePlanRow"
    static let workoutSplitNoDayConfigured = "workoutSplitNoDayConfigured"
    static let workoutSplitActiveSummary = "workoutSplitActiveSummary"
    static let workoutSplitSelectPlanButton = "workoutSplitSelectPlanButton"
    static let workoutSplitMissedDayButton = "workoutSplitMissedDayButton"
    static let workoutSplitResetOffsetButton = "workoutSplitResetOffsetButton"
    static let workoutSplitRotationPreviousButton = "workoutSplitRotationPreviousButton"
    static let workoutSplitRotationAdvanceButton = "workoutSplitRotationAdvanceButton"
    static let workoutSplitSetInactiveButton = "workoutSplitSetInactiveButton"
    static let workoutSplitSetActiveButton = "workoutSplitSetActiveButton"

    static func workoutSplitInactiveRow(_ split: WorkoutSplit) -> String {
        "workoutSplitInactiveRow-\(split.title)"
    }

    // MARK: - WorkoutSplitCreationView
    static let workoutSplitCreationView = "workoutSplitCreationView"

    static func workoutSplitRenameButton(_ split: WorkoutSplit) -> String {
        "workoutSplitRenameButton-\(split.title)"
    }

    static let workoutSplitOptionsMenu = "workoutSplitOptionsMenu"
    static let workoutSplitRotateMenu = "workoutSplitRotateMenu"
    static let workoutSplitRotateBackwardButton = "workoutSplitRotateBackwardButton"
    static let workoutSplitRotateForwardButton = "workoutSplitRotateForwardButton"
    static let workoutSplitSwapModeButton = "workoutSplitSwapModeButton"
    static let workoutSplitSwapCancelButton = "workoutSplitSwapCancelButton"
    static let workoutSplitSwapConfirmButton = "workoutSplitSwapConfirmButton"
    static let workoutSplitDeleteButton = "workoutSplitDeleteButton"
    static let workoutSplitDeleteConfirmButton = "workoutSplitDeleteConfirmButton"
    static let workoutSplitActiveActionsButton = "workoutSplitActiveActionsButton"
    static let workoutSplitTitleEditorField = "workoutSplitTitleEditorField"

    static let workoutSplitAddRotationDayCapsule = "addRotationDayCapsule"

    static func workoutSplitWeekdayCapsule(_ day: WorkoutSplitDay) -> String {
        "weekdayCapsule-\(day.weekday)"
    }

    static func workoutSplitRotationCapsule(_ day: WorkoutSplitDay) -> String {
        "rotationCapsule-\(day.index)"
    }

    static func workoutSplitRotationSetCurrentDayButton(_ day: WorkoutSplitDay) -> String {
        "workoutSplitRotationSetCurrentDayButton-\(day.index)"
    }

    static func workoutSplitDeleteDayButton(_ day: WorkoutSplitDay) -> String {
        "workoutSplitDeleteDayButton-\(day.index)"
    }

    // MARK: - WorkoutSplitDayView
    static let workoutSplitDayRestToggle = "workoutSplitDayRestToggle"
    static let workoutSplitDayNameField = "workoutSplitDayNameField"
    static let workoutSplitDayPlanButton = "workoutSplitDayPlanButton"
    static let workoutSplitDayRestUnavailable = "workoutSplitDayRestUnavailable"
    static let workoutSplitTargetMusclesButton = "workoutSplitTargetMusclesButton"

    // MARK: - SplitBuilderView
    static let splitBuilderSheet = "splitBuilderSheet"
    static let splitBuilderScratchButton = "splitBuilderScratchButton"
    static let splitBuilderModeWeekly = "splitBuilderModeWeekly"
    static let splitBuilderModeRotation = "splitBuilderModeRotation"
    static let splitBuilderWeekendsYes = "splitBuilderWeekendsYes"
    static let splitBuilderWeekendsNo = "splitBuilderWeekendsNo"
    static let splitBuilderRestAfterEach = "splitBuilderRestAfterEach"
    static let splitBuilderRestForTwoDays = "splitBuilderRestForTwoDays"
    static let splitBuilderRestNone = "splitBuilderRestNone"
    static let splitBuilderRestAfterCycle = "splitBuilderRestAfterCycle"
    static let splitBuilderRestInBetween = "splitBuilderRestInBetween"

    static func splitBuilderType(_ type: SplitPresetType) -> String {
        "splitBuilderType-\(type.rawValue)"
    }

    static func splitBuilderDays(_ days: Int) -> String {
        "splitBuilderDays-\(days)"
    }

    static func workoutPlanDetailSet(_ exercise: ExercisePrescription, set: SetPrescription) -> String {
        "workoutPlanDetailSet-\(String(describing: exercise.workoutPlan?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)-\(set.index)"
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
    static let workoutPreMoodButton = "workoutPreMoodButton"
    static let preWorkoutMoodSheet = "preWorkoutMoodSheet"
    static let preWorkoutMoodNotesField = "preWorkoutMoodNotesField"
    static let preWorkoutEnergyDrinkCard = "preWorkoutEnergyDrinkCard"

    static func preWorkoutMoodOption(_ mood: MoodLevel) -> String {
        "preWorkoutMoodOption-\(slug(mood.displayName))"
    }

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
    // MARK: - ContentView
    static let homeWorkoutSplitLabel = "Workout split"
    static let homeWorkoutSplitHint = "Shows your active workout split."
    static let homeRecentWorkoutLabel = "Recent workout"
    static let homeRecentWorkoutHint = "Shows your most recent workout."
    static let homeRecentWorkoutPlanLabel = "Recent workout plan"
    static let homeRecentWorkoutPlanHint = "Shows your most recent workout plan."
    static let homeOptionsMenuLabel = "Options"
    static let homeOptionsMenuHint = "Shows workout and workout plan options."
    static let homeStartWorkoutLabel = "Start empty workout"
    static let homeStartWorkoutHint = "Starts a new workout session."
    static let homeCreatePlanLabel = "Create workout plan"
    static let homeCreatePlanHint = "Creates a new workout plan."

    // MARK: - WorkoutSplitSectionView
    static let workoutSplitHeaderHint = "Shows your workout split settings."
    static let workoutSplitUnavailableHint = "Opens workout split settings."
    static let workoutSplitActiveRowHint = "Shows workout split details."
    static let workoutSplitPlanButtonLabel = "Open workout plan"
    static let workoutSplitPlanButtonHint = "Opens the workout plan for today."

    // MARK: - RecentWorkoutSectionView
    static let workoutHistoryHeaderHint = "Shows your workout history."
    static let recentWorkoutRowHint = "Shows details for your most recent workout."

    // MARK: - RecentWorkoutPlanSectionView
    static let workoutPlansHeaderHint = "Shows all your workout plans."
    static let recentWorkoutPlanRowHint = "Shows details for your most recent workout plan."

    // MARK: - WorkoutsListView
    static let workoutRowHint = "Shows workout details."
    static let workoutsDeleteAllHint = "Deletes all completed workouts."
    static let workoutsDoneEditingHint = "Exits edit mode."
    static let workoutsEditHint = "Enters edit mode."

    // MARK: - WorkoutPlansListView
    static let workoutPlanRowHint = "Shows workout plan details."
    static let workoutPlansDeleteAllHint = "Deletes all workout plans."
    static let workoutPlansDoneEditingHint = "Exits edit mode."
    static let workoutPlansOptionsMenuLabel = "Options"
    static let workoutPlansOptionsMenuHint = "Workout plans list options."
    static let workoutPlansEditHint = "Enters edit mode."
    static let workoutPlansFavoritesToggleHint = "Filters to favorite workout plans."

    // MARK: - WorkoutSplitView
    static let workoutSplitRowHint = "Shows split details."
    static let workoutSplitCreateHint = "Creates a new workout split."
    static let workoutSplitActiveActionsLabel = "Split actions"
    static let workoutSplitActiveActionsHint = "Shows actions for the active split."
    static let workoutSplitMissedDayHint = "Moves the weekly split back by one day."
    static let workoutSplitResetOffsetHint = "Resets the weekly split offset to today."
    static let workoutSplitRotationPreviousHint = "Moves back one day in the rotation."
    static let workoutSplitRotationAdvanceHint = "Moves forward one day in the rotation."
    static let workoutSplitSetActiveHint = "Makes this split active."
    static let workoutSplitSetInactiveHint = "Makes this split inactive."
    static let workoutSplitSelectPlanHint = "Selects a workout plan for this day."
    static let workoutSplitSelectPlanLabel = "Select workout plan"
    static let workoutSplitSelectPlanValue = "No plan selected for this day."

    // MARK: - WorkoutSplitCreationView
    static let workoutSplitSwapCancelHint = "Cancels swapping days."
    static let workoutSplitSwapConfirmHint = "Swaps the selected days."
    static let workoutSplitSwapModeHint = "Pick two days to swap."
    static let workoutSplitRotationSetCurrentDayHint = "Sets this day as the current rotation day."
    static let workoutSplitCapsuleHint = "Shows split day details."
    static let workoutSplitAddRotationDayHint = "Adds a new rotation day."
    static let workoutSplitAddRotationDayLabel = "Add day"
    static let workoutSplitDeleteDayHint = "Deletes this day."
    static let workoutSplitOptionsMenuLabel = "Split options"
    static let workoutSplitOptionsMenuHint = "Shows split actions."
    static let workoutSplitRotateMenuHint = "Rotates all split days by one."
    static let workoutSplitRotateBackwardHint = "Moves the split schedule back one day."
    static let workoutSplitRotateForwardHint = "Moves the split schedule forward one day."
    static let workoutSplitDeleteHint = "Deletes this split."

    static func workoutSplitWeekdayCapsuleLabel(_ weekdayName: String) -> String {
        "Select \(weekdayName)"
    }

    static func workoutSplitRotationCapsuleLabel(dayNumber: Int) -> String {
        "Day \(dayNumber)"
    }

    // MARK: - WorkoutSplitDayView
    static let workoutSplitRestDayToggleHint = "Marks this day as a rest day."
    static let workoutSplitDayNameHint = "Names this split day."
    static let workoutSplitDayPlanButtonHint = "Selects a workout plan for this day."
    static let workoutSplitTargetMusclesLabel = "Target muscles"
    static let workoutSplitTargetMusclesHint = "Selects the target muscles for this day."

    static func workoutSplitPlanButtonLabel(hasPlan: Bool) -> String {
        hasPlan ? "Change workout plan" : "Select workout plan"
    }

    static func workoutRowLabel(for workout: WorkoutSession) -> String {
        let dateText = workout.startedAt.formatted(.dateTime.month(.abbreviated).day().year())
        return "\(workout.title), \(dateText)"
    }

    static func workoutRowValue(for workout: WorkoutSession) -> String {
        let count = workout.exercises?.count ?? 0
        return count == 1 ? "1 exercise" : "\(count) exercises"
    }

    static func exerciseSetLabel(for set: SetPerformance) -> String {
        set.type == .working ? "Set \(set.index + 1)" : set.type.displayName
    }

    static func exerciseSetLabel(for set: SetPrescription) -> String {
        set.type == .working ? "Set \(set.index + 1)" : set.type.displayName
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
        set.type.displayName
    }

    static func exerciseSetMenuLabel(for set: SetPrescription) -> String {
        "Set \(set.index + 1)"
    }

    static func exerciseSetMenuValue(for set: SetPrescription) -> String {
        set.type.displayName
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
