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

    // MARK: - RecentExercisesSectionView
    static let homeRecentExercisesSection = "homeRecentExercisesSection"
    static let homeExercisesLink = "homeExercisesLink"
    static let recentExercisesEmptyState = "recentExercisesEmptyState"

    static func recentExerciseRow(_ exercise: Exercise) -> String {
        "recentExerciseRow-\(exercise.catalogID)"
    }

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

    static func workoutDetailExerciseNotes(_ exercise: ExercisePerformance) -> String {
        "workoutDetailExerciseNotes-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)"
    }

    static let workoutDetailList = "workoutDetailList"

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

    static func workoutPlanExerciseReplaceButton(_ exercise: ExercisePrescription) -> String {
        "workoutPlanExerciseReplaceButton-\(String(describing: exercise.workoutPlan?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)"
    }

    static func workoutPlanExerciseDeleteButton(_ exercise: ExercisePrescription) -> String {
        "workoutPlanExerciseDeleteButton-\(String(describing: exercise.workoutPlan?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)"
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

    static func workoutPlanDetailExerciseNotes(_ exercise: ExercisePrescription) -> String {
        "workoutPlanDetailExerciseNotes-\(String(describing: exercise.workoutPlan?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)"
    }

    static func workoutPlanDetailSuggestionCount(_ exercise: ExercisePrescription) -> String {
        "workoutPlanDetailSuggestionCount-\(exercise.id.uuidString)"
    }

    static let workoutPlanDetailList = "workoutPlanDetailList"

    static func workoutPlanExerciseHistoryButton(_ exercise: ExercisePrescription) -> String {
        "workoutPlanExerciseHistoryButton-\(exercise.catalogID)-\(exercise.index)"
    }

    static func exerciseListRow(_ exercise: Exercise) -> String {
        "exerciseListRow-\(exercise.catalogID)"
    }

    // MARK: - ExercisesListView
    static let exercisesListEmptyState = "exercisesListEmptyState"
    static let exercisesListNoFavoritesState = "exercisesListNoFavoritesState"
    static let exercisesListSearchEmptyState = "exercisesListSearchEmptyState"
    static let exercisesListScrollView = "exercisesListScrollView"
    static let exercisesListFavoritesToggle = "exercisesListFavoritesToggle"
    static let exercisesListOptionsMenu = "exercisesListOptionsMenu"

    // MARK: - ExerciseDetailView
    static let exerciseDetailEmptyState = "exerciseDetailEmptyState"
    static let exerciseDetailScrollView = "exerciseDetailScrollView"
    static let exerciseDetailRefreshHistoryButton = "exerciseDetailRefreshHistoryButton"
    static let exerciseDetailOptionsMenu = "exerciseDetailOptionsMenu"
    static let exerciseDetailHistoryButton = "exerciseDetailHistoryButton"

    // MARK: - ExerciseHistoryView
    static let exerciseHistoryEmptyState = "exerciseHistoryEmptyState"
    static let exerciseHistoryList = "exerciseHistoryList"

    // MARK: - AddExerciseView
    static let addExerciseCloseButton = "addExerciseCloseButton"
    static let addExerciseDiscardSelectionsButton = "addExerciseDiscardSelectionsButton"
    static let addExerciseConfirmButton = "addExerciseConfirmButton"
    static let addExerciseSortMenu = "addExerciseSortMenu"
    static let addExerciseSelectedToggle = "addExerciseSelectedToggle"
    static let addExerciseFavoritesToggle = "addExerciseFavoritesToggle"
    static let addExerciseMuscleFiltersButton = "addExerciseMuscleFiltersButton"
    static let addExerciseFiltersMenu = "addExerciseFiltersMenu"
    static let addExerciseListContainer = "addExerciseListContainer"

    // MARK: - Navbar
    static let navBarCloseButton = "navBarCloseButton"

    // MARK: - TimerDurationPicker
    static let timerDurationPicker = "timerDurationPicker"

    static let workoutPlanPickerList = "workoutPlanPickerList"
    static let workoutPlanPickerClearButton = "workoutPlanPickerClearButton"
    static let workoutPlanPickerCreateButton = "workoutPlanPickerCreateButton"
    static let workoutPlanDetailSelectButton = "workoutPlanDetailSelectButton"
    static let workoutPlanDetailUseButton = "workoutPlanDetailUseButton"
    static let workoutPlanDetailNotesText = "workoutPlanDetailNotesText"
    static let workoutPlanDetailSuggestionsButton = "workoutPlanDetailSuggestionsButton"
    static let workoutPlanDetailEditButton = "workoutPlanDetailEditButton"
    static let workoutPlanDetailDeleteButton = "workoutPlanDetailDeleteButton"
    static let workoutPlanDetailOptionsMenu = "workoutPlanDetailOptionsMenu"
    static let workoutPlanDetailConfirmDeleteButton = "workoutPlanDetailConfirmDeleteButton"
    static let workoutPlanDetailFavoriteButton = "workoutPlanDetailFavoriteButton"
    static let workoutPlanDetailStartWorkoutButton = "workoutPlanDetailStartWorkoutButton"
    static let workoutPlanCancelButton = "workoutPlanCancelButton"
    static let workoutPlanConfirmCancelButton = "workoutPlanConfirmCancelButton"
    static let workoutPlanSaveButton = "workoutPlanSaveButton"
    static let workoutPlanEditExercisesButton = "workoutPlanEditExercisesButton"
    static let workoutPlanAddExerciseButton = "workoutPlanAddExerciseButton"
    static let workoutPlanExercisesEmptyState = "workoutPlanExercisesEmptyState"
    static let workoutPlanEditingForm = "workoutPlanEditingForm"
    static let workoutPlanExerciseList = "workoutPlanExerciseList"

    static func workoutPlanExerciseView(_ exercise: ExercisePrescription) -> String {
        "workoutPlanExerciseView-\(exercise.catalogID)-\(exercise.index)"
    }

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

    // MARK: - WorkoutView
    static let workoutRestTimerButton = "workoutRestTimerButton"
    static let workoutAddExerciseButton = "workoutAddExerciseButton"
    static let workoutExercisesEmptyState = "workoutExercisesEmptyState"
    static let workoutExercisePager = "workoutExercisePager"
    static let workoutExerciseList = "workoutExerciseList"
    static let workoutDeleteEmptyButton = "workoutDeleteEmptyButton"
    static let workoutOptionsMenu = "workoutOptionsMenu"
    static let workoutSettingsButton = "workoutSettingsButton"
    static let workoutEditExercisesButton = "workoutEditExercisesButton"
    static let workoutFinishButton = "workoutFinishButton"
    static let workoutDeleteButton = "workoutDeleteButton"
    static let workoutConfirmDeleteButton = "workoutConfirmDeleteButton"
    static let workoutFinishMarkSetsCompleteButton = "workoutFinishMarkSetsCompleteButton"
    static let workoutFinishDeleteIncompleteSetsButton = "workoutFinishDeleteIncompleteSetsButton"
    static let workoutFinishDeleteEmptySetsButton = "workoutFinishDeleteEmptySetsButton"
    static let workoutFinishGoBackButton = "workoutFinishGoBackButton"
    static let workoutFinishConfirmButton = "workoutFinishConfirmButton"
    static let workoutFinishEffortSheet = "workoutFinishEffortSheet"
    static let workoutFinishEffortSkipButton = "workoutFinishEffortSkipButton"
    static let workoutFinishEffortConfirmButton = "workoutFinishEffortConfirmButton"
    static let workoutFinishEffortCloseButton = "workoutFinishEffortCloseButton"
    static let workoutFinishEffortSelectionSummary = "workoutFinishEffortSelectionSummary"

    static func workoutFinishEffortCard(_ value: Int) -> String {
        "workoutFinishEffortCard-\(value)"
    }

    // MARK: - WorkoutSummaryView
    static let workoutSummaryTitleButton = "workoutSummaryTitleButton"
    static let workoutSummaryNotesButton = "workoutSummaryNotesButton"
    static let workoutSummarySaveAsPlanButton = "workoutSummarySaveAsPlanButton"
    static let workoutSummaryDoneButton = "workoutSummaryDoneButton"
    static let workoutSummaryPRSection = "workoutSummaryPRSection"
    static let workoutSummaryPlanSavedRow = "workoutSummaryPlanSavedRow"

    static func workoutSummaryEffortCard(_ value: Int) -> String {
        "workoutSummaryEffortCard-\(value)"
    }

    static let workoutTitleEditorField = "workoutTitleEditorField"
    static let workoutNotesEditorField = "workoutNotesEditorField"
    static let workoutPlanTitleEditorField = "workoutPlanTitleEditorField"
    static let workoutPlanNotesEditorField = "workoutPlanNotesEditorField"
    static let workoutPreMoodButton = "workoutPreMoodButton"
    static let preWorkoutMoodSheet = "preWorkoutMoodSheet"
    static let preWorkoutMoodNotesField = "preWorkoutMoodNotesField"
    static let preWorkoutEnergyDrinkCard = "preWorkoutEnergyDrinkCard"
    static let replaceExerciseCloseButton = "replaceExerciseCloseButton"
    static let replaceExerciseConfirmButton = "replaceExerciseConfirmButton"
    static let replaceExerciseFavoritesToggle = "replaceExerciseFavoritesToggle"
    static let replaceExerciseMuscleFiltersButton = "replaceExerciseMuscleFiltersButton"
    static let replaceExerciseFiltersMenu = "replaceExerciseFiltersMenu"
    static let workoutDetailNotesText = "workoutDetailNotesText"
    static let workoutDetailOpenWorkoutPlanButton = "workoutDetailOpenWorkoutPlanButton"
    static let workoutDetailSaveWorkoutPlanButton = "workoutDetailSaveWorkoutPlanButton"
    static let workoutDetailDeleteButton = "workoutDetailDeleteButton"
    static let workoutDetailOptionsMenu = "workoutDetailOptionsMenu"
    static let workoutDetailConfirmDeleteButton = "workoutDetailConfirmDeleteButton"
    static let workoutDetailPreWorkoutContextButton = "workoutDetailPreWorkoutContextButton"
    static let workoutDetailPreWorkoutDrinkButton = "workoutDetailPreWorkoutDrinkButton"
    static let workoutDetailPreWorkoutNotesButton = "workoutDetailPreWorkoutNotesButton"
    static let workoutDetailEffortDisplay = "workoutDetailEffortDisplay"
    static let muscleFilterAdvancedToggle = "muscleFilterAdvancedToggle"
    static let muscleFilterClearButton = "muscleFilterClearButton"
    static let muscleFilterCloseButton = "muscleFilterCloseButton"
    static let muscleFilterConfirmButton = "muscleFilterConfirmButton"
    static let muscleFilterSheet = "muscleFilterSheet"
    static let restTimeEmptySetsMessage = "restTimeEmptySetsMessage"
    static let restTimeEditorForm = "restTimeEditorForm"
    static let repRangeModePicker = "repRangeModePicker"
    static let repRangeTargetStepper = "repRangeTargetStepper"
    static let repRangeLowerStepper = "repRangeLowerStepper"
    static let repRangeUpperStepper = "repRangeUpperStepper"
    static let repRangeForm = "repRangeForm"

    static func preWorkoutMoodOption(_ mood: MoodLevel) -> String {
        "preWorkoutMoodOption-\(slug(mood.displayName))"
    }

    static func restTimerRecentRow(_ history: RestTimeHistory) -> String {
        let timestamp = Int(history.lastUsed.timeIntervalSince1970)
        return "restTimerRecent-\(history.seconds)-\(timestamp)"
    }

    static func restTimerRecentStartButton(_ history: RestTimeHistory) -> String {
        "restTimerRecentStartButton-\(history.seconds)"
    }

    static func exerciseHistoryButton(_ exercise: ExercisePerformance) -> String {
        "exerciseHistoryButton-\(exercise.catalogID)-\(exercise.index)"
    }

    static let filteredExerciseList = "filteredExerciseList"
    static let filteredExerciseEmptySelectedState = "filteredExerciseEmptySelectedState"
    static let filteredExerciseEmptyFavoritesSelectedState = "filteredExerciseEmptyFavoritesSelectedState"
    static let filteredExerciseEmptyFavoritesState = "filteredExerciseEmptyFavoritesState"
    static let filteredExerciseEmptySearchState = "filteredExerciseEmptySearchState"

    // MARK: - WorkoutSettingsView
    static let workoutSettingsAutoStartTimerToggle = "workoutSettingsAutoStartTimerToggle"
    static let workoutSettingsAutoCompleteAfterRPEToggle = "workoutSettingsAutoCompleteAfterRPEToggle"
    static let workoutSettingsPreWorkoutPromptToggle = "workoutSettingsPreWorkoutPromptToggle"
    static let workoutSettingsPostWorkoutEffortToggle = "workoutSettingsPostWorkoutEffortToggle"
    static let workoutSettingsRetainPerformanceSnapshotsToggle = "workoutSettingsRetainPerformanceSnapshotsToggle"
    static let workoutSettingsNotificationsToggle = "workoutSettingsNotificationsToggle"
    static let workoutSettingsLiveActivitiesToggle = "workoutSettingsLiveActivitiesToggle"
    static let workoutSettingsRestartLiveActivityButton = "workoutSettingsRestartLiveActivityButton"

    static func restTimerAdjustButton(deltaSeconds: Int) -> String {
        let direction = deltaSeconds < 0 ? "minus" : "plus"
        return "restTimerAdjustButton-\(direction)-\(abs(deltaSeconds))"
    }

    static let restTimerCountdown = "restTimerCountdown"
    static let restTimerDurationPicker = "restTimerDurationPicker"
    static let restTimerList = "restTimerList"
    static let restTimerCloseButton = "restTimerCloseButton"
    static let restTimerStopButton = "restTimerStopButton"
    static let restTimerPauseButton = "restTimerPauseButton"
    static let restTimerResumeButton = "restTimerResumeButton"
    static let restTimerStartButton = "restTimerStartButton"
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
    private static func localized(_ key: String.LocalizationValue) -> String {
        String(localized: key)
    }

    // MARK: - ContentView
    static let homeWorkoutSplitLabel = localized("Workout split")
    static let homeWorkoutSplitHint = localized("Shows your active workout split.")
    static let homeRecentWorkoutLabel = localized("Recent workout")
    static let homeRecentWorkoutHint = localized("Shows your most recent workout.")
    static let homeRecentWorkoutPlanLabel = localized("Recent workout plan")
    static let homeRecentWorkoutPlanHint = localized("Shows your most recent workout plan.")
    static let homeOptionsMenuLabel = localized("Options")
    static let homeOptionsMenuHint = localized("Shows workout and workout plan options.")
    static let homeStartWorkoutLabel = localized("Start empty workout")
    static let homeStartWorkoutHint = localized("Starts a new workout session.")
    static let homeCreatePlanLabel = localized("Create workout plan")
    static let homeCreatePlanHint = localized("Creates a new workout plan.")

    // MARK: - WorkoutSplitSectionView
    static let workoutSplitHeaderHint = localized("Shows your workout split settings.")
    static let workoutSplitUnavailableHint = localized("Opens workout split settings.")
    static let workoutSplitActiveRowHint = localized("Shows workout split details.")
    static let workoutSplitPlanButtonLabel = localized("Open workout plan")
    static let workoutSplitPlanButtonHint = localized("Opens the workout plan for today.")

    // MARK: - RecentWorkoutSectionView
    static let workoutHistoryHeaderHint = localized("Shows your workout history.")
    static let recentWorkoutRowHint = localized("Shows details for your most recent workout.")

    // MARK: - RecentWorkoutPlanSectionView
    static let workoutPlansHeaderHint = localized("Shows all your workout plans.")
    static let recentWorkoutPlanRowHint = localized("Shows details for your most recent workout plan.")

    // MARK: - RecentExercisesSectionView
    static let recentExercisesHeaderHint = localized("Shows all tracked exercises.")
    static let recentExercisesUnavailableLabel = localized("No Exercises Used")
    static let recentExercisesUnavailableValue = localized("Complete exercises in workouts to track progress here.")
    static let recentExercisesUnavailableHint = localized("Shows all tracked exercises.")

    // MARK: - WorkoutsListView
    static let workoutRowHint = localized("Shows workout details.")
    static let workoutsDeleteAllHint = localized("Deletes all completed workouts.")
    static let workoutsDoneEditingHint = localized("Exits edit mode.")
    static let workoutsEditHint = localized("Enters edit mode.")

    // MARK: - WorkoutPlansListView
    static let workoutPlanRowHint = localized("Shows workout plan details.")
    static let workoutPlansDeleteAllHint = localized("Deletes all workout plans.")
    static let workoutPlansDoneEditingHint = localized("Exits edit mode.")
    static let workoutPlansOptionsMenuLabel = localized("Options")
    static let workoutPlansOptionsMenuHint = localized("Workout plans list options.")
    static let workoutPlansEditHint = localized("Enters edit mode.")
    static let workoutPlansFavoritesToggleHint = localized("Filters to favorite workout plans.")

    // MARK: - WorkoutDetailView
    static let workoutDetailOpenWorkoutPlanHint = localized("Opens the linked workout plan.")
    static let workoutDetailSaveWorkoutPlanHint = localized("Saves this workout as a workout plan.")
    static let workoutDetailDeleteHint = localized("Deletes this workout.")
    static let workoutDetailOptionsMenuHint = localized("Workout actions.")
    static let workoutDetailPreWorkoutContextLabel = localized("Pre workout context")
    static let workoutDetailPreWorkoutContextHint = localized("Shows pre workout details.")
    static let workoutDetailEffortLabel = localized("Post workout effort")
    static let workoutPreMoodHint = localized("Updates your pre-workout energy.")
    static let workoutDeleteEmptyLabel = localized("Delete Workout")

    // MARK: - WorkoutPlanDetailView
    static let workoutPlanDetailSuggestionsLabel = localized("AI suggestions")
    static let workoutPlanDetailSuggestionsHint = localized("Shows suggested changes and pending outcomes for this workout plan.")
    static let workoutPlanDetailSelectHint = localized("Selects this workout plan.")
    static let workoutPlanDetailEditHint = localized("Edits this workout plan.")
    static let workoutPlanDetailDeleteHint = localized("Deletes this workout plan.")
    static let workoutPlanDetailOptionsMenuHint = localized("Workout plan actions.")
    static let workoutPlanDetailFavoriteHint = localized("Toggles favorite.")
    static let workoutPlanDetailStartWorkoutHint = localized("Starts a workout from this plan.")

    static func workoutPlanDetailSuggestionCountLabel(count: Int) -> String {
        count == 1 ? localized("1 suggestion to review") : localized("\(count) suggestions to review")
    }

    static func workoutPlanDetailFavoriteLabel(isFavorite: Bool) -> String {
        isFavorite ? localized("Remove from favorites") : localized("Add to favorites")
    }

    // MARK: - WorkoutPlanPickerView
    static let workoutPlanPickerClearHint = localized("Removes the selected workout plan.")
    static let workoutPlanPickerCreateHint = localized("Creates a new workout plan to select.")

    // MARK: - WorkoutPlanView
    static let workoutPlanEditExercisesHint = localized("Shows the list of exercises.")
    static let workoutPlanAddExerciseHint = localized("Adds an exercise.")
    static let workoutPlanExerciseAddSetHint = localized("Adds a new set.")
    static let workoutPlanExerciseHistoryHint = localized("Shows prior performances for this exercise.")
    static let workoutPlanExerciseRestTimesHint = localized("Edits rest times.")
    static let workoutPlanExerciseReplaceHint = localized("Replaces this exercise with another.")
    static let workoutPlanExerciseDeleteHint = localized("Deletes this exercise.")

    // MARK: - ExercisesListView
    static let exercisesListFavoritesToggleHint = localized("Filters to favorite exercises.")

    // MARK: - WorkoutSplitView
    static let workoutSplitRowHint = localized("Shows split details.")
    static let workoutSplitCreateHint = localized("Creates a new workout split.")
    static let workoutSplitActiveActionsLabel = localized("Split actions")
    static let workoutSplitActiveActionsHint = localized("Shows actions for the active split.")
    static let workoutSplitMissedDayHint = localized("Moves the weekly split back by one day.")
    static let workoutSplitResetOffsetHint = localized("Resets the weekly split offset to today.")
    static let workoutSplitRotationPreviousHint = localized("Moves back one day in the rotation.")
    static let workoutSplitRotationAdvanceHint = localized("Moves forward one day in the rotation.")
    static let workoutSplitSetActiveHint = localized("Makes this split active.")
    static let workoutSplitSetInactiveHint = localized("Makes this split inactive.")
    static let workoutSplitSelectPlanHint = localized("Selects a workout plan for this day.")
    static let workoutSplitSelectPlanLabel = localized("Select workout plan")
    static let workoutSplitSelectPlanValue = localized("No plan selected for this day.")

    // MARK: - WorkoutSplitCreationView
    static let workoutSplitSwapCancelHint = localized("Cancels swapping days.")
    static let workoutSplitSwapConfirmHint = localized("Swaps the selected days.")
    static let workoutSplitSwapModeHint = localized("Pick two days to swap.")
    static let workoutSplitRotationSetCurrentDayHint = localized("Sets this day as the current rotation day.")
    static let workoutSplitCapsuleHint = localized("Shows split day details.")
    static let workoutSplitAddRotationDayHint = localized("Adds a new rotation day.")
    static let workoutSplitAddRotationDayLabel = localized("Add day")
    static let workoutSplitDeleteDayHint = localized("Deletes this day.")
    static let workoutSplitOptionsMenuLabel = localized("Split options")
    static let workoutSplitOptionsMenuHint = localized("Shows split actions.")
    static let workoutSplitRotateMenuHint = localized("Rotates all split days by one.")
    static let workoutSplitRotateBackwardHint = localized("Moves the split schedule back one day.")
    static let workoutSplitRotateForwardHint = localized("Moves the split schedule forward one day.")
    static let workoutSplitDeleteHint = localized("Deletes this split.")

    static func workoutSplitWeekdayCapsuleLabel(_ weekdayName: String) -> String {
        localized("Select \(weekdayName)")
    }

    static func workoutSplitRotationCapsuleLabel(dayNumber: Int) -> String {
        localized("Day \(dayNumber)")
    }

    // MARK: - WorkoutSplitDayView
    static let workoutSplitRestDayToggleHint = localized("Marks this day as a rest day.")
    static let workoutSplitDayNameHint = localized("Names this split day.")
    static let workoutSplitDayPlanButtonHint = localized("Selects a workout plan for this day.")
    static let workoutSplitTargetMusclesLabel = localized("Target muscles")
    static let workoutSplitTargetMusclesHint = localized("Selects the target muscles for this day.")

    static func workoutSplitPlanButtonLabel(hasPlan: Bool) -> String {
        hasPlan ? localized("Change workout plan") : localized("Select workout plan")
    }

    static func workoutRowLabel(for workout: WorkoutSession) -> String {
        let dateText = workout.startedAt.formatted(.dateTime.month(.abbreviated).day().year())
        return localized("\(workout.title), \(dateText)")
    }

    static func workoutRowValue(for workout: WorkoutSession) -> String {
        let count = workout.exercises?.count ?? 0
        return count == 1 ? localized("1 exercise") : localized("\(count) exercises")
    }

    static func exerciseSetLabel(for set: SetPerformance) -> String {
        set.type == .working ? localized("Set \(set.index + 1)") : set.type.displayName
    }

    static func exerciseSetLabel(for set: SetPrescription) -> String {
        set.type == .working ? localized("Set \(set.index + 1)") : set.type.displayName
    }

    static func exerciseSetValue(for set: SetPerformance, unit: WeightUnit) -> String {
        let repsText = set.reps == 1 ? localized("1 rep") : localized("\(set.reps) reps")
        let weightText = unit.display(set.weight)
        if let visibleRPE = set.visibleRPE {
            return localized("\(repsText), \(weightText), RPE \(visibleRPE)")
        }
        return localized("\(repsText), \(weightText)")
    }

    static func exerciseSetValue(for set: SetPrescription, unit: WeightUnit) -> String {
        let hasReps = set.targetReps > 0
        let hasWeight = set.targetWeight > 0
        let hasTargetRPE = set.visibleTargetRPE != nil
        guard hasReps || hasWeight || hasTargetRPE else { return localized("No target set") }

        let repsText = hasReps ? (set.targetReps == 1 ? localized("1 rep") : localized("\(set.targetReps) reps")) : localized("No reps target")
        let weightText = hasWeight ? unit.display(set.targetWeight) : localized("No weight target")
        if let visibleTargetRPE = set.visibleTargetRPE {
            return localized("\(repsText), \(weightText), target RPE \(visibleTargetRPE)")
        }
        return localized("\(repsText), \(weightText)")
    }

    static func exerciseSetMenuLabel(for set: SetPerformance) -> String {
        localized("Set \(set.index + 1)")
    }

    static func exerciseSetMenuValue(for set: SetPerformance) -> String {
        if let visibleRPE = set.visibleRPE {
            return localized("\(set.type.displayName), RPE \(visibleRPE)")
        }
        return set.type.displayName
    }

    static func exerciseSetMenuLabel(for set: SetPrescription) -> String {
        localized("Set \(set.index + 1)")
    }

    static func exerciseSetMenuValue(for set: SetPrescription) -> String {
        if let visibleTargetRPE = set.visibleTargetRPE {
            return localized("\(set.type.displayName), target RPE \(visibleTargetRPE)")
        }
        return set.type.displayName
    }

    static func exerciseSetCompletionLabel(isComplete: Bool) -> String {
        isComplete ? localized("Mark incomplete") : localized("Mark complete")
    }

    static func exerciseSetCountText(_ count: Int) -> String {
        count == 1 ? localized("1 set") : localized("\(count) sets")
    }

    static func workoutExerciseListValue(for exercise: ExercisePerformance) -> String {
        let totalSets = exercise.sortedSets.count
        let completedSets = exercise.sortedSets.filter { $0.complete }.count
        let setsText: String
        if totalSets > 0, completedSets == totalSets {
            setsText = localized("All sets complete")
        } else if completedSets > 0 {
            setsText = localized("\(completedSets)/\(totalSets) sets complete")
        } else {
            setsText = exerciseSetCountText(totalSets)
        }
        return localized("\(exercise.equipmentType.displayName), \(setsText)")
    }

    static func workoutPlanExerciseListValue(for exercise: ExercisePrescription) -> String {
        let setsText = exerciseSetCountText(exercise.sortedSets.count)
        return localized("\(exercise.equipmentType.displayName), \(setsText)")
    }

    static func exerciseCatalogValue(for exercise: Exercise, isSelected: Bool) -> String {
        var parts: [String] = []

        parts.append(exercise.equipmentType.displayName)

        if exercise.favorite {
            parts.append(localized("Favorite"))
        }

        if isSelected {
            parts.append(localized("Selected"))
        }

        return parts.joined(separator: ", ")
    }

    // MARK: - WorkoutView
    static let workoutRestTimerHint = localized("Shows the rest timer.")
    static let workoutAddExerciseHint = localized("Adds an exercise.")
    static let workoutDeleteEmptyHint = localized("Deletes this workout.")
    static let workoutOptionsMenuHint = localized("Workout actions.")
    static let workoutSettingsHint = localized("Shows workout settings.")
    static let workoutEditExercisesHint = localized("Shows the list of exercises.")
    static let workoutFinishHint = localized("Finishes and saves the workout.")
    static let workoutDeleteHint = localized("Deletes this workout.")
    static let workoutExerciseListRowHint = localized("Shows the exercise in the workout.")
    static let workoutFinishEffortSkipHint = localized("Skips recording effort and continues to summary.")
    static let workoutFinishEffortConfirmHint = localized("Saves the selected effort and continues to summary.")
    static let workoutFinishEffortCloseHint = localized("Closes the effort prompt and returns to the workout.")
    static let workoutFinishEffortCardHint = localized("Selects this workout effort score.")

    // MARK: - WorkoutSummaryView
    static let workoutSummaryTitleHint = localized("Edits the workout title.")
    static let workoutSummaryNotesHint = localized("Edits the workout notes.")
    static let workoutSummaryNotesLabel = localized("Notes")
    static let workoutSummarySaveAsPlanHint = localized("Saves this workout as a reusable plan.")
    static let workoutSummaryDoneHint = localized("Saves and closes the workout summary.")
    static let workoutSummaryDoneLabel = localized("Done")
    static let workoutSummaryPRSectionLabel = localized("Personal Records")
    static let workoutSummaryPlanSavedLabel = localized("Saved as Workout Plan")

    static func workoutSummaryEffortLabel(value: Int) -> String {
        localized("Effort \(value)")
    }

    static func workoutSummaryEffortValue(value: Int, isSelected: Bool) -> String {
        isSelected ? localized("Selected") : localized("Not selected")
    }

    static func workoutSummaryNotesValue(hasNotes: Bool, notes: String) -> String {
        hasNotes ? notes : localized("No notes added.")
    }

    static func workoutSummaryPRSectionValue(count: Int) -> String {
        count == 1 ? localized("1 personal record") : localized("\(count) personal records")
    }

    // MARK: - SuggestionGroupRow
    static let suggestionRejectHint = localized("Rejects this suggestion group.")
    static let suggestionAcceptHint = localized("Accepts this suggestion group.")
    static let suggestionDeferLabel = localized("Later")
    static let suggestionDeferHint = localized("Defers this suggestion to review before the next workout.")
    static func suggestionConfidenceLabel(_ label: String) -> String { localized("Suggestion strength \(label)") }

    // MARK: - DeferredSuggestionsView
    static let deferredSuggestionsSkipLabel = localized("Skip")
    static let deferredSuggestionsSkipHint = localized("Rejects all remaining suggestions and starts the workout.")
    static let deferredSuggestionsAcceptAllLabel = localized("Accept All")
    static let deferredSuggestionsAcceptAllHint = localized("Applies all pending suggestions and starts the workout.")

    // MARK: - SummaryStatCard
    static func summaryStatCardLabel(title: String, value: String) -> String {
        localized("\(title), \(value)")
    }

    // MARK: - ExerciseSummaryRow
    static let exerciseSummaryRowHint = localized("Shows exercise history and details.")

    static func exerciseSummaryRowValue(lastUsed: String, sessions: String?, record: String?) -> String {
        var parts = [lastUsed]
        if let sessions { parts.append(sessions) }
        if let record { parts.append(record) }
        return localized("\(parts.joined(separator: ", "))")
    }

    // MARK: - WorkoutPlanCardView
    static func workoutPlanCardValue(exerciseCount: Int, muscles: String) -> String {
        let exerciseText = exerciseCount == 1 ? localized("1 exercise") : localized("\(exerciseCount) exercises")
        return localized("\(exerciseText), \(muscles)")
    }

    // MARK: - Navbar
    static let closeButtonHint = localized("Closes the sheet.")

    // MARK: - TimerDurationPicker
    static let timerDurationPickerLabel = localized("Timer duration")

    // MARK: - RepRangeButton
    static let repRangeButtonLabel = localized("Rep range")
    static let repRangeButtonHint = localized("Edits the rep range.")

    // MARK: - ExerciseSetRowView
    static let exerciseSetRepsLabel = localized("Reps")
    static let exerciseSetWeightLabel = localized("Weight")
    static let exerciseSetMenuHint = localized("Opens set options.")

    // MARK: - ExerciseDetailView
    static let exerciseDetailOptionsMenuHint = localized("Exercise actions.")

    // MARK: - AddExerciseView
    static let addExerciseCloseLabel = localized("Close")
    static let addExerciseConfirmLabel = localized("Add Exercises")
    static let addExerciseMuscleFiltersHint = localized("Shows muscle filter options.")
    static let addExerciseFiltersHint = localized("Shows filter options.")
    static let exerciseSelectionRemoveHint = localized("Removes this exercise from your selection.")
    static let exerciseSelectionAddHint = localized("Adds this exercise to your selection.")

    // MARK: - ReplaceExerciseView
    static let replaceExerciseCloseLabel = localized("Close")
    static let replaceExerciseConfirmHint = localized("Replaces the current exercise with the selected one.")

    // MARK: - PreWorkoutContextView
    static let preWorkoutEnergyDrinkLabel = localized("Pre-workout energy drink")
    static let preWorkoutEnergyDrinkHint = localized("Toggles whether you took a pre-workout drink.")
    static let preWorkoutMoodHint = localized("Sets your pre-workout mood.")

    static func yesNoValue(_ isTrue: Bool) -> String {
        isTrue ? localized("Yes") : localized("No")
    }

    // MARK: - MuscleFilterSheetView
    static let muscleFilterAdvancedLabel = localized("Advanced muscles")
    static let muscleFilterAdvancedHint = localized("Shows minor muscles.")
    static let muscleFilterClearHint = localized("Clears all selected muscles.")
    static let muscleFilterCloseLabel = localized("Close")
    static let muscleFilterApplyLabel = localized("Apply Filters")
    static let muscleFilterChipHint = localized("Toggles this muscle filter.")

    static func muscleFilterAdvancedValue(isExpanded: Bool) -> String {
        isExpanded ? localized("Expanded") : localized("Collapsed")
    }

    // MARK: - RestTimeEditorView
    static let restTimeRowHint = localized("Shows duration picker.")
    static let copyActionLabel = localized("Copy")
    static let pasteActionLabel = localized("Paste")

    // MARK: - RepRangeEditorView
    static let repRangeSuggestionLabel = localized("Rep range suggestion")
    static let repRangeSuggestionHint = localized("Applies this rep range.")

    // MARK: - OnboardingView
    static let onboardingRetryHint = localized("Retries the current setup step.")
    static let onboardingContinueWithoutiCloudHint = localized("Continues setup without iCloud sync.")
    static let onboardingEnableICloudHint = localized("Opens iOS Settings to enable iCloud.")

    // MARK: - WorkoutSettingsView
    static let workoutSettingsAutoStartTimerHint = localized("Automatically starts rest timer when a set is marked complete.")
    static let workoutSettingsAutoCompleteAfterRPEHint = localized("Automatically marks a set complete after selecting an RPE rating.")
    static let workoutSettingsPreWorkoutPromptHint = localized("Prompts for pre workout context when you open a new workout.")
    static let workoutSettingsPostWorkoutEffortHint = localized("Prompts for post workout effort before summary when the workout is being saved.")
    static let workoutSettingsRetainPerformanceSnapshotsHint = localized("Keeps deleted completed workouts hidden instead of permanently removing the performance snapshots used for suggestion learning.")
    static let workoutSettingsNotificationsHint = localized("Sends a local notification when rest timer finishes.")
    static let workoutSettingsLiveActivitiesHint = localized("Shows a live activity on the Lock Screen during your workout.")
    static let workoutSettingsRestartLiveActivityHint = localized("Restarts the workout live activity if you dismissed it.")

    // MARK: - RestTimerView
    static let restTimerLabel = localized("Rest timer")
    static let restTimerValueReady = localized("Ready")
    static let restTimerValueRunning = localized("Running")
    static let restTimerValuePaused = localized("Paused")
    static let restTimerCloseLabel = localized("Close")
    static let restTimerNextSetLabel = localized("Next set")
    static let restTimerCompleteSetLabel = localized("Complete set")
    static let restTimerStartHint = localized("Starts the rest timer.")
    static let restTimerStopHint = localized("Stops the rest timer.")
    static let restTimerPauseHint = localized("Pauses the rest timer.")
    static let restTimerResumeHint = localized("Resumes the rest timer.")
    static let restTimerAdjustHint = localized("Adjusts the rest timer.")
    static let restTimerCompleteAndRestartHint = localized("Marks the next set complete and restarts the timer.")

    static func restTimerAdjustLabel(deltaSeconds: Int) -> String {
        deltaSeconds < 0 ? localized("Decrease rest time by 15 seconds") : localized("Increase rest time by 15 seconds")
    }

    static func restTimerRecentStartLabel(seconds: Int, secondsToTime: (Int) -> String) -> String {
        localized("Start a timer for \(secondsToTime(seconds))")
    }

}
