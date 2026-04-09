import Foundation
import SwiftData

enum AccessibilityIdentifiers {
    // MARK: - ContentView
    static let homeWorkoutSplitSection = "homeWorkoutSplitSection"
    static let homeRecentWorkoutSection = "homeRecentWorkoutSection"
    static let homeRecentWorkoutPlanSection = "homeRecentWorkoutPlanSection"
    static let homeSettingsButton = "homeSettingsButton"
    static let morphingToolbarToggleButton = "morphingToolbarToggleButton"
    static let morphingStartWorkoutButton = "morphingStartWorkoutButton"
    static let morphingCreatePlanButton = "morphingCreatePlanButton"
    static let morphingAddWeightButton = "morphingAddWeightButton"
    static let healthAddWeightEntryButton = "healthAddWeightEntryButton"
    static let healthAddWeightEntryConfirmButton = "healthAddWeightEntryConfirmButton"
    static let healthAddWeightEntryWeightField = "healthAddWeightEntryWeightField"
    static let healthAddWeightEntryDatePicker = "healthAddWeightEntryDatePicker"
    static let healthAddWeightEntryTimePicker = "healthAddWeightEntryTimePicker"
    static let healthWeightGoalSummaryButton = "healthWeightGoalSummaryButton"
    static let healthWeightGoalHistoryList = "healthWeightGoalHistoryList"
    static let healthWeightGoalHistoryAddButton = "healthWeightGoalHistoryAddButton"
    static let healthNewWeightGoalSaveButton = "healthNewWeightGoalSaveButton"
    static let healthNewWeightGoalTypePicker = "healthNewWeightGoalTypePicker"
    static let healthNewWeightGoalStartWeightField = "healthNewWeightGoalStartWeightField"
    static let healthNewWeightGoalTargetWeightField = "healthNewWeightGoalTargetWeightField"
    static let healthNewWeightGoalTargetRateField = "healthNewWeightGoalTargetRateField"
    static let healthNewWeightGoalTargetDateToggle = "healthNewWeightGoalTargetDateToggle"
    static let healthNewWeightGoalTargetDatePicker = "healthNewWeightGoalTargetDatePicker"
    static let healthWeightHistoryAllEntriesLink = "healthWeightHistoryAllEntriesLink"
    static let healthWeightEntriesList = "healthWeightEntriesList"
    static let healthWeightEntriesDeleteAllButton = "healthWeightEntriesDeleteAllButton"
    static let healthWeightEntriesDeleteAllConfirmButton = "healthWeightEntriesDeleteAllConfirmButton"
    static let healthWeightEntriesEditButton = "healthWeightEntriesEditButton"
    static let healthWeightEntriesDoneEditingButton = "healthWeightEntriesDoneEditingButton"
    static let healthWeightEntriesEmptyState = "healthWeightEntriesEmptyState"
    static let healthNewWeightGoalCustomStartDateToggle = "healthNewWeightGoalCustomStartDateToggle"
    static let healthNewWeightGoalStartDatePicker = "healthNewWeightGoalStartDatePicker"
    static let healthWeightSectionCard = "healthWeightSectionCard"
    static let healthTrainingConditionSectionCard = "healthTrainingConditionSectionCard"
    static let healthSleepSectionCard = "healthSleepSectionCard"
    static let healthSleepHistoryChart = "healthSleepHistoryChart"
    static let healthWeightHistoryChart = "healthWeightHistoryChart"
    static let healthStepsSectionCard = "healthStepsSectionCard"
    static let healthEnergySectionCard = "healthEnergySectionCard"
    static let healthStepsHistoryChart = "healthStepsHistoryChart"
    static let healthEnergyHistoryChart = "healthEnergyHistoryChart"
    static let healthTrainingConditionHistoryAddButton = "healthTrainingConditionHistoryAddButton"
    static let healthTrainingConditionSaveButton = "healthTrainingConditionSaveButton"
    static let healthTrainingConditionKindPicker = "healthTrainingConditionKindPicker"
    static let healthTrainingConditionImpactPicker = "healthTrainingConditionImpactPicker"
    static let healthTrainingConditionStartDatePicker = "healthTrainingConditionStartDatePicker"
    static let healthTrainingConditionEndDateToggle = "healthTrainingConditionEndDateToggle"
    static let healthTrainingConditionEndDatePicker = "healthTrainingConditionEndDatePicker"
    static let healthTrainingConditionAffectedMusclesButton = "healthTrainingConditionAffectedMusclesButton"
    static let muscleDistributionChart = "muscleDistributionChart"

    static func healthTrainingConditionRow(_ period: TrainingConditionPeriod) -> String { "healthTrainingConditionRow-\(period.persistentModelID)" }

    static func healthWeightEntryRow(_ entry: WeightEntry) -> String { "healthWeightEntryRow-\(entry.id.uuidString)" }

    static func healthWeightGoalRow(_ goal: WeightGoal) -> String { "healthWeightGoalRow-\(goal.id.uuidString)" }

    static func muscleDistributionLegendRow(_ muscle: Muscle) -> String { "muscleDistributionLegendRow-\(slug(muscle.rawValue))" }

    // MARK: - WorkoutSplitSectionView
    static let workoutSplitLink = "workoutSplitLink"
    static let recentWorkoutSplitEmptyState = "recentWorkoutSplitEmptyState"
    static let recentWorkoutSplitActiveRow = "recentWorkoutSplitActiveRow"
    static let recentWorkoutSplitNoDayState = "recentWorkoutSplitNoDayState"
    static let recentWorkoutSplitNoActiveState = "recentWorkoutSplitNoActiveState"

    static func recentWorkoutSplitPlanButton(_ plan: WorkoutPlan) -> String { "recentWorkoutSplitPlanButton-\(plan.id)" }

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

    static func recentExerciseRow(_ exercise: Exercise) -> String { "recentExerciseRow-\(exercise.catalogID)" }

    // MARK: - WorkoutsListView
    static let workoutsList = "workoutsList"
    static let workoutsDeleteAllButton = "workoutsDeleteAllButton"
    static let workoutsDeleteAllConfirmButton = "workoutsDeleteAllConfirmButton"
    static let workoutsDoneEditingButton = "workoutsDoneEditingButton"
    static let workoutsEditButton = "workoutsEditButton"
    static let workoutsEmptyState = "workoutsEmptyState"
    static let healthWorkoutRow = "healthWorkoutRow"

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

    static func workoutRow(_ workout: WorkoutSession) -> String { "workoutsListRow-\(workout.id.uuidString)" }

    static func workoutPlanRow(_ workoutPlan: WorkoutPlan) -> String { "workoutPlanRow-\(workoutPlan.id)" }

    static func workoutDetailExercise(_ exercise: ExercisePerformance) -> String { "workoutDetailExercise-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)" }

    static func workoutDetailExerciseHeader(_ exercise: ExercisePerformance) -> String { "workoutDetailExerciseHeader-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)" }

    static func workoutDetailExerciseNotes(_ exercise: ExercisePerformance) -> String { "workoutDetailExerciseNotes-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)" }

    static let workoutDetailList = "workoutDetailList"

    static func workoutDetailSet(_ exercise: ExercisePerformance, set: SetPerformance) -> String { "workoutDetailSet-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)-\(set.index)" }

    static func workoutExercisePage(_ exercise: ExercisePerformance) -> String { "workoutExercisePage-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)" }

    static func workoutExerciseListRow(_ exercise: ExercisePerformance) -> String { "workoutExerciseListRow-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)" }

    static func workoutPlanExerciseListRow(_ exercise: ExercisePrescription) -> String { "workoutPlanExerciseListRow-\(String(describing: exercise.workoutPlan?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)" }

    static func exerciseRepRangeButton(_ exercise: ExercisePerformance) -> String { "exerciseRepRangeButton-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)" }

    static let repRangeSuggestionsSection = "repRangeSuggestionsSection"

    static func repRangeSuggestionButton(catalogID: String, index: Int) -> String { "repRangeSuggestionButton-\(slug(catalogID))-\(index)" }

    static func workoutPlanExerciseRepRangeButton(_ exercise: ExercisePrescription) -> String { "workoutPlanExerciseRepRangeButton-\(String(describing: exercise.workoutPlan?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)" }

    static func exerciseNotesButton(_ exercise: ExercisePerformance) -> String { "exerciseNotesButton-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)" }

    static func workoutPlanExerciseNotesButton(_ exercise: ExercisePrescription) -> String { "workoutPlanExerciseNotesButton-\(String(describing: exercise.workoutPlan?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)" }

    static func exerciseNotesField(_ exercise: ExercisePerformance) -> String { "exerciseNotesField-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)" }

    static func workoutPlanExerciseNotesField(_ exercise: ExercisePrescription) -> String { "workoutPlanExerciseNotesField-\(String(describing: exercise.workoutPlan?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)" }

    static func exerciseRestTimesButton(_ exercise: ExercisePerformance) -> String { "exerciseRestTimesButton-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)" }

    static func workoutPlanExerciseRestTimesButton(_ exercise: ExercisePrescription) -> String { "workoutPlanExerciseRestTimesButton-\(String(describing: exercise.workoutPlan?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)" }

    static func exerciseAddSetButton(_ exercise: ExercisePerformance) -> String { "exerciseAddSetButton-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)" }

    static func exerciseReplaceButton(_ exercise: ExercisePerformance) -> String { "exerciseReplaceButton-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)" }

    static func exerciseDeleteButton(_ exercise: ExercisePerformance) -> String { "exerciseDeleteButton-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)" }

    static func workoutPlanExerciseAddSetButton(_ exercise: ExercisePrescription) -> String { "workoutPlanExerciseAddSetButton-\(String(describing: exercise.workoutPlan?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)" }

    static func workoutPlanExerciseReplaceButton(_ exercise: ExercisePrescription) -> String { "workoutPlanExerciseReplaceButton-\(String(describing: exercise.workoutPlan?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)" }

    static func workoutPlanExerciseDeleteButton(_ exercise: ExercisePrescription) -> String { "workoutPlanExerciseDeleteButton-\(String(describing: exercise.workoutPlan?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)" }

    static func exerciseSetMenu(_ exercise: ExercisePerformance, set: SetPerformance) -> String { "exerciseSetMenu-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)-\(set.index)" }

    static func workoutPlanSetMenu(_ exercise: ExercisePrescription, set: SetPrescription) -> String { "workoutPlanSetMenu-\(String(describing: exercise.workoutPlan?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)-\(set.index)" }

    static func exerciseSetRepsField(_ exercise: ExercisePerformance, set: SetPerformance) -> String { "exerciseSetRepsField-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)-\(set.index)" }

    static func workoutPlanSetRepsField(_ exercise: ExercisePrescription, set: SetPrescription) -> String { "workoutPlanSetRepsField-\(String(describing: exercise.workoutPlan?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)-\(set.index)" }

    static func exerciseSetWeightField(_ exercise: ExercisePerformance, set: SetPerformance) -> String { "exerciseSetWeightField-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)-\(set.index)" }

    static func workoutPlanSetWeightField(_ exercise: ExercisePrescription, set: SetPrescription) -> String { "workoutPlanSetWeightField-\(String(describing: exercise.workoutPlan?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)-\(set.index)" }

    static func exerciseSetPreviousValue(_ exercise: ExercisePerformance, set: SetPerformance) -> String { "exerciseSetPreviousValue-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)-\(set.index)" }

    static func exerciseSetCompleteButton(_ exercise: ExercisePerformance, set: SetPerformance) -> String { "exerciseSetCompleteButton-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)-\(set.index)" }

    static func exerciseSetDeleteButton(_ exercise: ExercisePerformance, set: SetPerformance) -> String { "exerciseSetDeleteButton-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)-\(set.index)" }

    static func workoutPlanSetDeleteButton(_ exercise: ExercisePrescription, set: SetPrescription) -> String { "workoutPlanSetDeleteButton-\(String(describing: exercise.workoutPlan?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)-\(set.index)" }

    static func workoutPlanDetailExercise(_ exercise: ExercisePrescription) -> String { "workoutPlanDetailExercise-\(String(describing: exercise.workoutPlan?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)" }

    static func workoutPlanDetailExerciseHeader(_ exercise: ExercisePrescription) -> String { "workoutPlanDetailExerciseHeader-\(String(describing: exercise.workoutPlan?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)" }

    static func workoutPlanDetailExerciseNotes(_ exercise: ExercisePrescription) -> String { "workoutPlanDetailExerciseNotes-\(String(describing: exercise.workoutPlan?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)" }

    static func workoutPlanDetailSuggestionCount(_ exercise: ExercisePrescription) -> String { "workoutPlanDetailSuggestionCount-\(exercise.id.uuidString)" }

    static let workoutPlanDetailList = "workoutPlanDetailList"

    static func workoutPlanExerciseHistoryButton(_ exercise: ExercisePrescription) -> String { "workoutPlanExerciseHistoryButton-\(exercise.catalogID)-\(exercise.index)" }

    static func exerciseListRow(_ exercise: Exercise) -> String { "exerciseListRow-\(exercise.catalogID)" }

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
    static let exerciseDetailHistoryButton = "exerciseDetailHistoryButton"
    static let exerciseDetailSuggestionSettingsButton = "exerciseDetailSuggestionSettingsButton"
    static let exerciseProgressionStepValueField = "exerciseProgressionStepValueField"
    static let exerciseSuggestionSettingsSaveButton = "exerciseSuggestionSettingsSaveButton"

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
    static let textEntryEditorField = "textEntryEditorField"

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

    static func workoutPlanExerciseView(_ exercise: ExercisePrescription) -> String { "workoutPlanExerciseView-\(exercise.catalogID)-\(exercise.index)" }

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

    static func workoutSplitInactiveRow(_ split: WorkoutSplit) -> String { "workoutSplitInactiveRow-\(split.title)" }

    // MARK: - WorkoutSplitCreationView
    static let workoutSplitCreationView = "workoutSplitCreationView"

    static func workoutSplitRenameButton(_ split: WorkoutSplit) -> String { "workoutSplitRenameButton-\(split.title)" }

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

    static func workoutSplitWeekdayCapsule(_ day: WorkoutSplitDay) -> String { "weekdayCapsule-\(day.weekday)" }

    static func workoutSplitRotationCapsule(_ day: WorkoutSplitDay) -> String { "rotationCapsule-\(day.index)" }

    static func workoutSplitRotationSetCurrentDayButton(_ day: WorkoutSplitDay) -> String { "workoutSplitRotationSetCurrentDayButton-\(day.index)" }

    static func workoutSplitDeleteDayButton(_ day: WorkoutSplitDay) -> String { "workoutSplitDeleteDayButton-\(day.index)" }

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

    static func splitBuilderType(_ type: SplitPresetType) -> String { "splitBuilderType-\(type.rawValue)" }

    static func splitBuilderDays(_ days: Int) -> String { "splitBuilderDays-\(days)" }

    static func workoutPlanDetailSet(_ exercise: ExercisePrescription, set: SetPrescription) -> String { "workoutPlanDetailSet-\(String(describing: exercise.workoutPlan?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)-\(set.index)" }

    static func exerciseSetUsePreviousButton(_ exercise: ExercisePerformance, set: SetPerformance) -> String { "exerciseSetUsePreviousButton-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)-\(set.index)" }

    static func exerciseSetReplaceTimerButton(_ exercise: ExercisePerformance, set: SetPerformance) -> String { "exerciseSetReplaceTimerButton-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)-\(set.index)" }

    static func exerciseSetCancelReplaceTimerButton(_ exercise: ExercisePerformance, set: SetPerformance) -> String { "exerciseSetCancelReplaceTimerButton-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)-\(set.index)" }

    // MARK: - WorkoutView
    static let workoutRestTimerButton = "workoutRestTimerButton"
    static let workoutLiveHealthButton = "workoutLiveHealthButton"
    static let workoutLiveHealthSheet = "workoutLiveHealthSheet"
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

    static func workoutFinishEffortCard(_ value: Int) -> String { "workoutFinishEffortCard-\(value)" }

    // MARK: - WorkoutSummaryView
    static let workoutSummaryTitleButton = "workoutSummaryTitleButton"
    static let workoutSummaryNotesButton = "workoutSummaryNotesButton"
    static let workoutSummaryHealthStatsSection = "workoutSummaryHealthStatsSection"
    static let workoutSummarySaveAsPlanButton = "workoutSummarySaveAsPlanButton"
    static let workoutSummaryDoneButton = "workoutSummaryDoneButton"
    static let workoutSummaryPRSection = "workoutSummaryPRSection"
    static let workoutSummaryPlanSavedRow = "workoutSummaryPlanSavedRow"

    static func workoutSummaryEffortCard(_ value: Int) -> String { "workoutSummaryEffortCard-\(value)" }

    static let workoutTitleEditorField = "workoutTitleEditorField"
    static let workoutNotesEditorField = "workoutNotesEditorField"
    static let workoutPlanTitleEditorField = "workoutPlanTitleEditorField"
    static let workoutPlanNotesEditorField = "workoutPlanNotesEditorField"
    static let workoutPreMoodButton = "workoutPreMoodButton"
    static let preWorkoutMoodSheet = "preWorkoutMoodSheet"
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
    static let workoutDetailPreWorkoutContextCard = "workoutDetailPreWorkoutContextCard"
    static let workoutDetailEffortDisplay = "workoutDetailEffortDisplay"
    static let healthWorkoutDetailEffortDisplay = "healthWorkoutDetailEffortDisplay"
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

    static func preWorkoutMoodOption(_ mood: MoodLevel) -> String { "preWorkoutMoodOption-\(slug(mood.displayName))" }

    static func restTimerRecentRow(_ history: RestTimeHistory) -> String {
        let timestamp = Int(history.lastUsed.timeIntervalSince1970)
        return "restTimerRecent-\(history.seconds)-\(timestamp)"
    }

    static func restTimerRecentStartButton(_ history: RestTimeHistory) -> String { "restTimerRecentStartButton-\(history.seconds)" }

    static func exerciseHistoryButton(_ exercise: ExercisePerformance) -> String { "exerciseHistoryButton-\(exercise.catalogID)-\(exercise.index)" }

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

    static func restTimeRowButton(_ title: String) -> String { "restTimeRowButton-\(slug(title))" }

    static func restTimeRowPicker(_ title: String) -> String { "restTimeRowPicker-\(slug(title))" }

    static func exerciseCatalogRow(_ exercise: Exercise) -> String { "exerciseCatalogRow-\(exercise.catalogID)" }

    static func exerciseFavoriteToggle(_ exercise: Exercise) -> String { "exerciseFavoriteToggle-\(exercise.catalogID)" }

    static func muscleFilterChip(_ muscle: Muscle) -> String { "muscleFilterChip-\(slug(muscle.rawValue))" }

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
    private static func localized(_ key: String.LocalizationValue) -> String { String(localized: key) }

    // MARK: - ContentView
    static let homeWorkoutSplitLabel = localized("Workout split")
    static let homeWorkoutSplitHint = localized("Shows your active workout split.")
    static let homeRecentWorkoutLabel = localized("Recent workout")
    static let homeRecentWorkoutHint = localized("Shows your most recent workout.")
    static let homeRecentWorkoutPlanLabel = localized("Recent workout plan")
    static let homeRecentWorkoutPlanHint = localized("Shows your most recent workout plan.")
    static let homeSettingsLabel = localized("Settings")
    static let homeSettingsHint = localized("Shows app settings.")
    static let morphingExpandToolbarLabel = localized("Show quick actions")
    static let morphingCollapseToolbarLabel = localized("Hide quick actions")
    static let morphingToolbarHint = localized("Shows or hides the quick action toolbar.")
    static let morphingStartWorkoutHint = localized("Starts a new workout session.")
    static let morphingCreatePlanHint = localized("Creates a new workout plan.")
    static let morphingAddWeightHint = localized("Creates a new weight entry.")
    static let healthAddWeightEntryLabel = localized("Add weight entry")
    static let healthAddWeightEntryHint = localized("Creates a new weight entry.")
    static let healthAddWeightEntryConfirmHint = localized("Saves the new weight entry.")
    static let healthWeightGoalSummaryHint = localized("Creates a weight goal or shows your goal history.")
    static let healthWeightGoalHistoryAddLabel = localized("Add weight goal")
    static let healthWeightGoalHistoryAddHint = localized("Creates a new weight goal.")
    static let healthNewWeightGoalSaveHint = localized("Saves the new weight goal.")
    static let healthWeightHistoryAllEntriesHint = localized("Shows all saved weight entries.")
    static let healthWeightEntryRowHint = localized("Shows the saved date and weight entry details.")
    static let healthWeightGoalRowHint = localized("Shows weight goal details.")
    static let healthWeightEntriesDeleteAllHint = localized("Deletes all app-created weight entries.")
    static let healthWeightEntriesEditHint = localized("Enters edit mode.")
    static let healthWeightEntriesDoneEditingHint = localized("Exits edit mode.")
    static let healthWeightSectionHint = localized("Opens detailed weight history.")
    static let healthTrainingConditionSectionHint = localized("Updates your current training condition.")
    static let healthSleepSectionHint = localized("Shows your latest synced sleep summary.")
    static let healthStepsSectionHint = localized("Opens detailed steps history.")
    static let healthStepsGoalHistoryAddLabel = localized("Add steps goal")
    static let healthStepsGoalHistoryAddHint = localized("Creates a new steps goal.")
    static let healthEnergySectionHint = localized("Opens detailed energy history.")
    static let healthTrainingConditionHistoryAddLabel = localized("Add training condition")
    static let healthTrainingConditionHistoryAddHint = localized("Adds or replaces a training condition.")
    static let healthTrainingConditionSaveHint = localized("Saves this training condition.")
    static let healthTrainingConditionAffectedMusclesHint = localized("Selects the muscles affected by this condition.")
    static let healthWeightHistoryChartLabel = localized("Weight history chart")
    static let healthSleepHistoryChartLabel = localized("Sleep history chart")
    static let healthStepsHistoryChartLabel = localized("Steps history chart")
    static let healthEnergyHistoryChartLabel = localized("Energy history chart")
    static let healthStepsWeekdayChartLabel = localized("Weekday average steps chart")
    static let healthEnergyWeekdayChartLabel = localized("Weekday average active energy chart")
    static let healthSleepWeekdayChartLabel = localized("Weekday average sleep chart")
    static let healthWeightSectionEmptyValue = localized("Weight. No weight entries yet.")
    static let healthTrainingConditionSectionEmptyValue = localized("Training condition. Training normally.")
    static let healthSleepSectionEmptyValue = localized("Sleep. Update Apple Health permissions so your sleep summaries appear here.")
    static let healthWeightGoalSummaryEmptyValue = localized("No active goal")
    static let healthStepsSectionEmptyValue = localized("Steps. Update Apple Health permissions so your health metrics appear here.")
    static let healthEnergySectionEmptyValue = localized("Energy. Update Apple Health permissions so your health metrics appear here.")
    static let healthWeightEntryRowLabel = localized("Weight entry")
    static let muscleDistributionChartLabel = localized("Muscle distribution chart")
    static let healthHistoryNoHealthDataTitle = localized("No Health Data")
    static let healthHistoryNoHealthDataDescription = localized("Update Apple Health permissions so your health metrics appear here.")
    static let healthStepsHistoryEmptyTitle = localized("No Step Data")
    static let healthEnergyHistoryEmptyTitle = localized("No Energy Data")
    static let healthWeightHistoryEmptyTitle = localized("No Weight Entries")
    static let healthSleepHistoryEmptyTitle = localized("No Sleep Data")

    static func healthWeightHistoryChartValue(dateText: String, weightText: String) -> String { localized("\(dateText), \(weightText)") }

    static func healthWeightHistoryEmptyDescription(for range: TimeSeriesRangeFilter) -> String {
        switch range {
        case .day:
            return localized("No weight entries were recorded for this day.")
        case .week:
            return localized("No weight entries were recorded in the last 7 days.")
        case .month:
            return localized("No weight entries were recorded in the last month.")
        case .sixMonths:
            return localized("No weight entries were recorded in the last 6 months.")
        case .year:
            return localized("No weight entries were recorded in the last year.")
        case .all:
            return localized("No weight entries have been recorded yet.")
        }
    }

    static func healthWeightSectionValue(dateText: String, weightText: String, goalText: String?) -> String {
        var parts = [localized("Weight"), localized("Latest entry \(dateText)"), localized("Latest weight \(weightText)")]
        if let goalText { parts.append(goalText) }
        return parts.joined(separator: ". ") + "."
    }

    static func healthTrainingConditionSectionValue(titleText: String, subtitleText: String?) -> String {
        var parts = [localized("Training condition"), titleText]
        if let subtitleText { parts.append(subtitleText) }
        return parts.joined(separator: ". ") + "."
    }

    static func healthSleepSectionValue(dateText: String, sleepText: String, timingText: String?, secondaryText: String?) -> String {
        var parts = [localized("Sleep"), localized("Latest sleep summary \(dateText)"), localized("\(sleepText) asleep")]
        if let timingText { parts.append(timingText) }
        if let secondaryText { parts.append(secondaryText) }
        parts.append(localized("Recent entries chart"))
        return parts.joined(separator: ". ") + "."
    }

    static func healthSleepHistoryEmptyDescription(for range: TimeSeriesRangeFilter) -> String {
        switch range {
        case .day:
            return localized("No sleep data was recorded for this day.")
        case .week:
            return localized("No sleep data was recorded in the last 7 days.")
        case .month:
            return localized("No sleep data was recorded in the last month.")
        case .sixMonths:
            return localized("No sleep data was recorded in the last 6 months.")
        case .year:
            return localized("No sleep data was recorded in the last year.")
        case .all:
            return localized("No sleep data has been recorded yet.")
        }
    }

    static func healthStepsSectionValue(dateText: String, stepCount: Int) -> String {
        localized("Latest steps entry \(dateText). \(stepCount.formatted(.number)) steps. Recent entries chart.")
    }

    static func healthStepsHistoryEmptyDescription(for range: TimeSeriesRangeFilter) -> String {
        switch range {
        case .day:
            return localized("No step data was recorded for this day.")
        case .week:
            return localized("No step data was recorded in the last 7 days.")
        case .month:
            return localized("No step data was recorded in the last month.")
        case .sixMonths:
            return localized("No step data was recorded in the last 6 months.")
        case .year:
            return localized("No step data was recorded in the last year.")
        case .all:
            return localized("No step data has been recorded yet.")
        }
    }

    static func healthEnergySectionValue(dateText: String, totalEnergyText: String, activeEnergyText: String) -> String {
        localized("Latest energy entry \(dateText). \(totalEnergyText) total energy. \(activeEnergyText) active energy. Recent entries chart.")
    }

    static func healthEnergyHistoryEmptyDescription(for range: TimeSeriesRangeFilter) -> String {
        switch range {
        case .day:
            return localized("No energy data was recorded for this day.")
        case .week:
            return localized("No energy data was recorded in the last 7 days.")
        case .month:
            return localized("No energy data was recorded in the last month.")
        case .sixMonths:
            return localized("No energy data was recorded in the last 6 months.")
        case .year:
            return localized("No energy data was recorded in the last year.")
        case .all:
            return localized("No energy data has been recorded yet.")
        }
    }

    static func healthWeightEntryRowValue(weightText: String, dateText: String, isImportedFromHealth: Bool) -> String {
        var parts = [weightText, dateText]
        if isImportedFromHealth { parts.append(localized("Imported from Apple Health")) }
        return localized("\(parts.joined(separator: ", "))")
    }

    static func healthWeightGoalSummaryValue(goalTitle: String, statusText: String?, progressText: String?, chartSummary: String?) -> String {
        var parts = [goalTitle]
        if let statusText { parts.append(statusText) }
        if let progressText { parts.append(progressText) }
        if let chartSummary { parts.append(chartSummary) }
        return localized("\(parts.joined(separator: ", "))")
    }

    static func healthWeightGoalRowLabel(typeTitle: String) -> String { localized("\(typeTitle) weight goal") }

    static func healthWeightGoalRowValue(targetText: String, startedText: String, endedText: String?, targetDateText: String?, progressText: String?, chartSummary: String?, isActive: Bool) -> String {
        var parts = [localized("Target \(targetText)"), localized("Started \(startedText)")]
        if let endedText {
            parts.append(localized("Ended \(endedText)"))
        } else if isActive {
            parts.append(localized("Active"))
        }
        if let targetDateText { parts.append(localized("Target date \(targetDateText)")) }
        if let progressText { parts.append(progressText) }
        if let chartSummary { parts.append(chartSummary) }
        return localized("\(parts.joined(separator: ", "))")
    }

    static func healthStepsHistoryChartValue(dateText: String, stepsText: String) -> String { localized("\(dateText), \(stepsText)") }
    static func healthStepsWeekdayChartValue(summaryText: String) -> String { localized("\(summaryText)") }

    static func healthEnergyHistoryChartValue(dateText: String, totalText: String, activeText: String) -> String { localized("\(dateText), \(totalText), \(activeText)") }
    static func healthEnergyWeekdayChartValue(summaryText: String) -> String { localized("\(summaryText)") }
    static func healthSleepWeekdayChartValue(summaryText: String) -> String { localized("\(summaryText)") }

    static func muscleDistributionChartValue(rows: [String]) -> String { localized("\(rows.joined(separator: ", "))") }

    static func muscleDistributionLegendRowValue(muscleName: String, percentageText: String) -> String { localized("\(muscleName), \(percentageText)") }

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
    static let healthWorkoutDetailEffortLabel = localized("Workout effort")
    static let workoutPreMoodHint = localized("Updates your pre-workout energy.")
    static let workoutDeleteEmptyLabel = localized("Delete Workout")
    static func workoutDetailEffortValue(score: Int, description: String) -> String { localized("\(score)/10. \(description)") }
    static let exerciseDetailSuggestionSettingsHint = localized("Opens exercise suggestion settings.")

    // MARK: - WorkoutPlanDetailView
    static let workoutPlanDetailSuggestionsLabel = localized("AI suggestions")
    static let workoutPlanDetailSuggestionsHint = localized("Shows suggested changes and pending outcomes for this workout plan.")
    static let workoutPlanDetailSelectHint = localized("Selects this workout plan.")
    static let workoutPlanDetailEditHint = localized("Edits this workout plan.")
    static let workoutPlanDetailDeleteHint = localized("Deletes this workout plan.")
    static let workoutPlanDetailOptionsMenuHint = localized("Workout plan actions.")
    static let workoutPlanDetailFavoriteHint = localized("Toggles favorite.")
    static let workoutPlanDetailStartWorkoutHint = localized("Starts a workout from this plan.")

    static func workoutPlanDetailSuggestionCountLabel(count: Int) -> String { count == 1 ? localized("1 suggestion to review") : localized("\(count) suggestions to review") }

    static func workoutPlanDetailFavoriteLabel(isFavorite: Bool) -> String { isFavorite ? localized("Remove from favorites") : localized("Add to favorites") }

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
    static let exerciseSuggestionSettingsSaveHint = localized("Saves exercise suggestion settings.")

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

    static func workoutSplitWeekdayCapsuleLabel(_ weekdayName: String) -> String { localized("Select \(weekdayName)") }
    static func workoutSplitWeekdayCapsuleValue(isToday: Bool) -> String { isToday ? localized("Today") : "" }

    static func workoutSplitRotationCapsuleLabel(dayNumber: Int) -> String { localized("Day \(dayNumber)") }
    static func workoutSplitRotationCapsuleValue(isCurrentDay: Bool) -> String { isCurrentDay ? localized("Current day") : "" }

    // MARK: - WorkoutSplitDayView
    static let workoutSplitRestDayToggleHint = localized("Marks this day as a rest day.")
    static let workoutSplitDayNameHint = localized("Names this split day.")
    static let workoutSplitDayPlanButtonHint = localized("Selects a workout plan for this day.")
    static let workoutSplitTargetMusclesLabel = localized("Target muscles")
    static let workoutSplitTargetMusclesHint = localized("Selects the target muscles for this day.")
    static let workoutSplitTargetMusclesNoneValue = localized("Select muscles")
    static func workoutSplitTargetMusclesCountValue(_ count: Int) -> String { count == 1 ? localized("1 muscle") : localized("\(count) muscles") }

    static func workoutSplitPlanButtonLabel(hasPlan: Bool) -> String { hasPlan ? localized("Change workout plan") : localized("Select workout plan") }
    static func workoutSplitCapsuleValue(isCurrentDay: Bool) -> String { isCurrentDay ? localized("Current day") : "" }

    static func workoutRowLabel(for workout: WorkoutSession) -> String {
        let dateText = formattedRecentDay(workout.startedAt)
        return localized("\(workout.title), \(dateText)")
    }

    static func workoutRowValue(for workout: WorkoutSession) -> String {
        let count = workout.exercises?.count ?? 0
        return count == 1 ? localized("1 exercise") : localized("\(count) exercises")
    }

    static func exerciseSetLabel(for set: SetPerformance) -> String { set.type == .working ? localized("Set \(set.index + 1)") : set.type.displayName }

    static func exerciseSetLabel(for set: SetPrescription) -> String { set.type == .working ? localized("Set \(set.index + 1)") : set.type.displayName }

    static func exerciseSetValue(for set: SetPerformance, unit: WeightUnit) -> String {
        let repsText = set.reps == 1 ? localized("1 rep") : localized("\(set.reps) reps")
        let weightText = unit.display(set.weight)
        if let visibleRPE = set.visibleRPE { return localized("\(repsText), \(weightText), RPE \(visibleRPE)") }
        return localized("\(repsText), \(weightText)")
    }

    static func exerciseSetValue(for set: SetPrescription, unit: WeightUnit) -> String {
        let hasReps = set.targetReps > 0
        let hasWeight = set.targetWeight > 0
        let hasTargetRPE = set.visibleTargetRPE != nil
        guard hasReps || hasWeight || hasTargetRPE else { return localized("No target set") }

        let repsText = hasReps ? (set.targetReps == 1 ? localized("1 rep") : localized("\(set.targetReps) reps")) : localized("No reps target")
        let weightText = hasWeight ? unit.display(set.targetWeight) : localized("No weight target")
        if let visibleTargetRPE = set.visibleTargetRPE { return localized("\(repsText), \(weightText), target RPE \(visibleTargetRPE)") }
        return localized("\(repsText), \(weightText)")
    }

    static func exerciseSetMenuLabel(for set: SetPerformance) -> String { localized("Set \(set.index + 1)") }

    static func exerciseSetMenuValue(for set: SetPerformance) -> String {
        if let visibleRPE = set.visibleRPE { return localized("\(set.type.displayName), RPE \(visibleRPE)") }
        return set.type.displayName
    }

    static func exerciseSetMenuLabel(for set: SetPrescription) -> String { localized("Set \(set.index + 1)") }

    static func exerciseSetMenuValue(for set: SetPrescription) -> String {
        if let visibleTargetRPE = set.visibleTargetRPE { return localized("\(set.type.displayName), target RPE \(visibleTargetRPE)") }
        return set.type.displayName
    }

    static func exerciseSetCompletionLabel(isComplete: Bool) -> String { isComplete ? localized("Mark incomplete") : localized("Mark complete") }

    static func exerciseSetCountText(_ count: Int) -> String { count == 1 ? localized("1 set") : localized("\(count) sets") }

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

        if exercise.favorite { parts.append(localized("Favorite")) }

        if isSelected { parts.append(localized("Selected")) }

        return parts.joined(separator: ", ")
    }

    // MARK: - WorkoutView
    static let workoutRestTimerHint = localized("Shows the rest timer.")
    static let workoutLiveHealthLabel = localized("Live Health stats")
    static let workoutLiveHealthHint = localized("Shows your current Apple Health workout stats.")
    static let workoutLiveHealthWaitingValue = localized("Waiting for Apple Health data.")
    static let workoutLiveHealthUnavailableValue = localized("Unavailable")
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
    static let workoutSummaryHealthStatsLabel = localized("Apple Health stats")
    static let workoutSummarySaveAsPlanHint = localized("Saves this workout as a reusable plan.")
    static let workoutSummaryDoneHint = localized("Saves and closes the workout summary.")
    static let workoutSummaryDoneLabel = localized("Done")
    static let workoutSummaryPRSectionLabel = localized("Personal Records")
    static let workoutSummaryPlanSavedLabel = localized("Saved as Workout Plan")
    static let workoutSummaryEffortCardLabel = localized("Workout effort")

    static func workoutSummaryEffortLabel(value: Int) -> String { localized("Effort \(value)") }

    static func workoutSummaryEffortValue(value: Int, isSelected: Bool) -> String { isSelected ? localized("Selected") : localized("Not selected") }

    static func workoutSummaryNotesValue(hasNotes: Bool, notes: String) -> String { hasNotes ? notes : localized("No notes added.") }

    static func workoutSummaryPRSectionValue(count: Int) -> String { count == 1 ? localized("1 personal record") : localized("\(count) personal records") }
    static func workoutSummaryEffortCardValue(score: Int, description: String) -> String { localized("\(score)/10. \(description)") }

    static func workoutLiveHealthValue(heartRate: String, activeEnergy: String, totalEnergy: String) -> String { localized("Heart rate \(heartRate), active energy \(activeEnergy), total energy \(totalEnergy)") }

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
    static func summaryStatCardLabel(title: String, value: String) -> String { localized("\(title), \(value)") }

    // MARK: - ExerciseSummaryRow
    static let exerciseSummaryRowHint = localized("Shows exercise history and details.")

    static func exerciseSummaryRowValue(lastUsed: String, sessions: String?, record: String?) -> String {
        var parts = [lastUsed]
        if let sessions { parts.append(sessions) }
        if let record { parts.append(record) }
        return localized("\(parts.joined(separator: ", "))")
    }

    // MARK: - WorkoutPlanCardView
    static func workoutPlanCardValue(exerciseCount: Int, muscles: String, isFavorite: Bool) -> String {
        let exerciseText = exerciseCount == 1 ? localized("1 exercise") : localized("\(exerciseCount) exercises")
        let favoriteText = isFavorite ? localized("Favorite") : localized("Not favorite")
        return localized("\(exerciseText), \(muscles), \(favoriteText)")
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
    static let exerciseSetReferenceLabel = localized("Reference")
    static let exerciseSetTargetLabel = localized("Target")
    static let exerciseSetReferenceActionHint = localized("Long-press for options.")
    static let exerciseSetReferenceNoActionHint = localized("No quick-fill options.")

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

    static func yesNoValue(_ isTrue: Bool) -> String { isTrue ? localized("Yes") : localized("No") }

    // MARK: - MuscleFilterSheetView
    static let muscleFilterAdvancedLabel = localized("Advanced muscles")
    static let muscleFilterAdvancedHint = localized("Shows minor muscles.")
    static let muscleFilterClearHint = localized("Clears all selected muscles.")
    static let muscleFilterCloseLabel = localized("Close")
    static let muscleFilterApplyLabel = localized("Apply Filters")
    static let muscleFilterChipHint = localized("Toggles this muscle filter.")

    static func muscleFilterAdvancedValue(isExpanded: Bool) -> String { isExpanded ? localized("Expanded") : localized("Collapsed") }

    // MARK: - RestTimeEditorView
    static let restTimeRowHint = localized("Shows duration picker.")
    static let copyActionLabel = localized("Copy")
    static let pasteActionLabel = localized("Paste")

    // MARK: - RepRangeEditorView
    static let repRangeSuggestionLabel = localized("Rep range suggestion")
    static let repRangeSuggestionHint = localized("Applies this rep range.")

    // MARK: - OnboardingView
    static let onboardingConnectHealthHint = localized("Requests Apple Health read and write access for workouts.")
    static let onboardingSkipHealthHint = localized("Skips Apple Health for now and continues into the app.")
    static let onboardingRetryHint = localized("Retries the current setup step.")
    static let onboardingContinueWithoutiCloudHint = localized("Continues setup without iCloud sync.")
    static let onboardingEnableICloudHint = localized("Opens iOS Settings to enable iCloud.")
    static let onboardingGenderOptionHint = localized("Selects this gender option.")
    static let onboardingGenderContinueHint = localized("Saves your selected gender and continues to the next profile step.")

    static func onboardingGenderOptionValue(isSelected: Bool) -> String { isSelected ? localized("Selected") : localized("Not selected") }

    // MARK: - HealthWorkoutDetailView
    static let healthWorkoutRouteMapLabel = localized("Workout route map")
    static let healthWorkoutHeartRateChartLabel = localized("Heart rate chart")
    static let workoutEffortDialLabel = localized("Workout effort dial")

    static func healthWorkoutRouteMapValue(pointCount: Int) -> String { localized("Route plotted with \(pointCount) points.") }

    static func healthWorkoutHeartRateChartValue(summary: String) -> String { summary }

    static func healthWorkoutZoneValue(durationText: String, percentageText: String, rangeText: String) -> String { localized("\(durationText), \(percentageText), \(rangeText)") }

    static func healthWorkoutSplitValue(paceText: String, heartRateText: String) -> String {
        let heartRateValue = heartRateText == "-" ? localized("unavailable") : localized("\(heartRateText) beats per minute")
        return localized("Pace \(paceText), heart rate \(heartRateValue)")
    }
    
    static func workoutEffortDialValue(score: Int?) -> String {
        guard let score else { return localized("No effort selected") }
        return localized("\(score.formatted(.number.precision(.fractionLength(0)))) out of 10")
    }

    // MARK: - WorkoutSettingsView
    static let workoutSettingsAutoStartTimerHint = localized("Automatically starts rest timer when a set is marked complete.")
    static let workoutSettingsAutoCompleteAfterRPEHint = localized("Automatically marks a set complete after selecting an RPE rating.")
    static let workoutSettingsPreWorkoutPromptHint = localized("Prompts for pre workout context when you open a new workout.")
    static let workoutSettingsPostWorkoutEffortHint = localized("Prompts for post workout effort before summary when the workout is being saved.")
    static let workoutSettingsRetainPerformanceSnapshotsHint = localized("Keeps deleted completed workouts hidden instead of permanently removing the performance snapshots used for suggestion learning.")
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

    static func restTimerAdjustLabel(deltaSeconds: Int) -> String { deltaSeconds < 0 ? localized("Decrease rest time by 15 seconds") : localized("Increase rest time by 15 seconds") }

    static func restTimerRecentStartLabel(seconds: Int, secondsToTime: (Int) -> String) -> String { localized("Start a timer for \(secondsToTime(seconds))") }
    static func healthTrainingConditionRowValue(subtitleText: String, periodText: String) -> String { localized("\(subtitleText). \(periodText)") }

}
