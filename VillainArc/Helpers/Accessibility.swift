import Foundation
import SwiftData

enum AccessibilityIdentifiers {
    // MARK: - Subscription
    //
    // The paywall itself is `FCTStoreKit`'s `SubscriptionPaywallView`; what this app still owns is
    // the route into it from Settings, and the locked row that offers it.
    static let settingsSubscriptionRow = "settingsSubscriptionRow"
    static let settingsSubscriptionGetProButton = "settingsSubscriptionGetProButton"
    static let settingsSubscriptionManageButton = "settingsSubscriptionManageButton"
    static let settingsSubscriptionRestoreButton = "settingsSubscriptionRestoreButton"
    static let aiReplacementLockedRow = "aiReplacementLockedRow"

    // MARK: - ContentView
    static let homeWorkoutSplitSection = "homeWorkoutSplitSection"
    static let homeRecentWorkoutSection = "homeRecentWorkoutSection"
    static let homeRecentWorkoutPlanSection = "homeRecentWorkoutPlanSection"
    static let homeSettingsButton = "homeSettingsButton"
    static let healthSettingsButton = "healthSettingsButton"
    static let homeProfileButton = "homeProfileButton"
    static let healthProfileButton = "healthProfileButton"
    static let profileSheetCloseButton = "profileSheetCloseButton"
    static let profileSheetSettingsButton = "profileSheetSettingsButton"
    static let profileSheetAvatar = "profileSheetAvatar"
    static let muscleDistributionRangePicker = "muscleDistributionRangePicker"
    static let profileSheetName = "profileSheetName"
    static let profileSheetGenderRow = "profileSheetGenderRow"
    static let profileSheetHeightRow = "profileSheetHeightRow"
    static let profileSheetDetailsCard = "profileSheetDetailsCard"
    static let profileSheetFitnessLevelRow = "profileSheetFitnessLevelRow"
    static let profileSheetTrainingGoalRow = "profileSheetTrainingGoalRow"
    static let profileSheetReviewRow = "profileSheetReviewRow"
    static let profileSheetLegalCard = "profileSheetLegalCard"
    static let profileSheetPrivacyPolicyRow = "profileSheetPrivacyPolicyRow"
    static let profileSheetTermsOfServiceRow = "profileSheetTermsOfServiceRow"
    static let settingsAppleHealthLink = "settingsAppleHealthLink"
    static let settingsAppleHealthActionButton = "settingsAppleHealthActionButton"
    static let settingsAppleHealthKeepRemovedDataToggle = "settingsAppleHealthKeepRemovedDataToggle"
    static let settingsNotificationsLink = "settingsNotificationsLink"
    static let settingsUnitsLink = "settingsUnitsLink"
    static let settingsSyncStatusRow = "settingsSyncStatusRow"
    static let settingsDebugLink = "settingsDebugLink"
    static let debugRenderDebugStoreToggle = "debugRenderDebugStoreToggle"
    static let debugResetAppDataButton = "debugResetAppDataButton"
    static let debugResetAppDataConfirmButton = "debugResetAppDataConfirmButton"
    static let debugResyncExerciseCatalogButton = "debugResyncExerciseCatalogButton"
    static let debugResyncHealthDataButton = "debugResyncHealthDataButton"
    static let debugReindexSpotlightButton = "debugReindexSpotlightButton"
    static let debugHealthKitStatusValue = "debugHealthKitStatusValue"
    static let debugSeedDemoDataButton = "debugSeedDemoDataButton"
    static let debugSeedWorkoutDataButton = "debugSeedWorkoutDataButton"
    static let debugTouchAllModelsButton = "debugTouchAllModelsButton"
    static let debugTestAccountSignInButton = "debugTestAccountSignInButton"
    static let debugTestAccountStatusLabel = "debugTestAccountStatusLabel"
    static let morphingToolbarToggleButton = "morphingToolbarToggleButton"
    static let morphingStartWorkoutButton = "morphingStartWorkoutButton"
    static let morphingStartTodaysWorkoutButton = "morphingStartTodaysWorkoutButton"
    static let morphingCreatePlanButton = "morphingCreatePlanButton"
    static let morphingAddWeightButton = "morphingAddWeightButton"
    static let morphingUsePlanButton = "morphingUsePlanButton"
    static let morphingSaveWorkoutPlanButton = "morphingSaveWorkoutPlanButton"
    static let morphingOpenWorkoutPlanButton = "morphingOpenWorkoutPlanButton"
    static let morphingEditPlanButton = "morphingEditPlanButton"
    static let morphingCreateSplitButton = "morphingCreateSplitButton"
    static let morphingNewWeightGoalButton = "morphingNewWeightGoalButton"
    static let morphingNewStepsGoalButton = "morphingNewStepsGoalButton"
    static let morphingNewSleepGoalButton = "morphingNewSleepGoalButton"
    static let activeWorkoutResumeBarButton = "activeWorkoutResumeBarButton"
    static let activeWorkoutResumeCompleteSetButton = "activeWorkoutResumeCompleteSetButton"
    static let activeWorkoutResumeOpenButton = "activeWorkoutResumeOpenButton"
    static let activePlanResumeBarButton = "activePlanResumeBarButton"
    static let activePlanResumeOpenButton = "activePlanResumeOpenButton"
    static let healthAddWeightEntryButton = "healthAddWeightEntryButton"
    static let healthAddWeightEntryConfirmButton = "healthAddWeightEntryConfirmButton"
    static let healthAddWeightEntryWeightField = "healthAddWeightEntryWeightField"
    static let healthAddWeightEntryDatePicker = "healthAddWeightEntryDatePicker"
    static let healthAddWeightEntryTimePicker = "healthAddWeightEntryTimePicker"
    static let healthWeightGoalSummaryButton = "healthWeightGoalSummaryButton"
    static let healthWeightGoalHistoryList = "healthWeightGoalHistoryList"
    static let healthWeightGoalHistoryAddButton = "healthWeightGoalHistoryAddButton"
    static let healthStepsGoalHistoryAddButton = "healthStepsGoalHistoryAddButton"
    static let healthSleepGoalHistoryAddButton = "healthSleepGoalHistoryAddButton"
    static let healthNewWeightGoalSaveButton = "healthNewWeightGoalSaveButton"
    static let healthNewWeightGoalTypePicker = "healthNewWeightGoalTypePicker"
    static let healthNewWeightGoalStartWeightField = "healthNewWeightGoalStartWeightField"
    static let healthNewWeightGoalTargetWeightField = "healthNewWeightGoalTargetWeightField"
    static let healthNewWeightGoalTargetRateField = "healthNewWeightGoalTargetRateField"
    static let healthNewWeightGoalTargetRateSignToggle = "healthNewWeightGoalTargetRateSignToggle"
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
    static let healthTrendsSectionCard = "healthTrendsSectionCard"
    static let healthSleepTimingLink = "healthSleepTimingLink"
    static let sleepTimingInsightsRoot = "sleepTimingInsightsRoot"
    static let healthCorrelationLink = "healthCorrelationLink"
    static let correlationInsightsRoot = "correlationInsightsRoot"

    static func healthTrendCard(_ metricRawValue: String) -> String { "healthTrendCard-\(metricRawValue)" }

    // MARK: - CardioTabView / CardioActiveSessionView
    static let cardioRouteRangeMenu = "cardioRouteRangeMenu"
    static func cardioStart(kindRawValue: String) -> String { "cardioStart-\(kindRawValue)" }
    static let cardioStartConfirm = "cardioStartConfirm"
    static let cardioActiveCancel = "cardioActiveCancel"
    static let cardioActiveFinish = "cardioActiveFinish"
    static let cardioActivePause = "cardioActivePause"
    static let cardioActiveResume = "cardioActiveResume"
    static let cardioTreadmillIntervalAdd = "cardioTreadmillIntervalAdd"
    static func cardioMetricTile(_ metricTitle: String) -> String { "cardioMetricTile-\(slug(metricTitle))" }
    static func cardioHistoryRow(sessionID: String) -> String { "cardioHistoryRow-\(sessionID)" }

    static let cardioConnectAppleHealthButton = "cardioConnectAppleHealthButton"
    static let cardioTreadmillSpeedField = "cardioTreadmillSpeedField"
    static let cardioTreadmillInclineField = "cardioTreadmillInclineField"
    static let cardioTreadmillIntervalDeleteButton = "cardioTreadmillIntervalDeleteButton"
    static let cardioCancelSessionConfirmButton = "cardioCancelSessionConfirmButton"
    static let cardioCancelSessionKeepGoingButton = "cardioCancelSessionKeepGoingButton"
    static let cardioSessionDetailCloseButton = "cardioSessionDetailCloseButton"
    static let cardioSessionDetailBackButton = "cardioSessionDetailBackButton"
    static let cardioSessionDetailShareButton = "cardioSessionDetailShareButton"
    static let cardioRouteViewFullyButton = "cardioRouteViewFullyButton"
    static let cardioViewAllHistoryButton = "cardioViewAllHistoryButton"

    static func cardioCaptureModeCard(_ title: String) -> String { "cardioCaptureModeCard-\(slug(title))" }

    static func cardioStartPermissionRow(_ title: String) -> String { "cardioStartPermissionRow-\(slug(title))" }

    static func cardioRouteMarker(_ routeID: String) -> String { "cardioRouteMarker-\(slug(routeID))" }

    static func cardioHealthWorkoutHistoryRow(uuid: String) -> String { "cardioHealthWorkoutHistoryRow-\(uuid)" }

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
    /// Shown in place of any account-claim empty state until the first pull lands.
    static let accountRestoringState = "accountRestoringState"
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

    static func workoutDetailExerciseNotesSyncButton(_ exercise: ExercisePerformance) -> String { "workoutDetailExerciseNotesSyncButton-\(String(describing: exercise.workoutSession?.id.uuidString))-\(exercise.catalogID)-\(exercise.index)" }

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
    static let exercisesListMuscleFiltersButton = "exercisesListMuscleFiltersButton"
    static let exercisesListOptionsMenu = "exercisesListOptionsMenu"

    // MARK: - ExerciseDetailView
    static let exerciseDetailEmptyState = "exerciseDetailEmptyState"
    static let exerciseDetailScrollView = "exerciseDetailScrollView"
    static let exerciseDetailAddToActiveFlowButton = "exerciseDetailAddToActiveFlowButton"
    static let exerciseDetailHistoryButton = "exerciseDetailHistoryButton"
    static let exerciseDetailSuggestionSettingsButton = "exerciseDetailSuggestionSettingsButton"
    static let exerciseProgressionStepValueField = "exerciseProgressionStepValueField"
    static let exerciseSuggestionSettingsSaveButton = "exerciseSuggestionSettingsSaveButton"

    // MARK: - ExerciseInfoView
    static let exerciseInfoFavoriteButton = "exerciseInfoFavoriteButton"
    static let exerciseInfoSuggestionSettingsButton = "exerciseInfoSuggestionSettingsButton"

    // MARK: - ExerciseHistoryView
    static let exerciseHistoryEmptyState = "exerciseHistoryEmptyState"
    static let exerciseHistoryList = "exerciseHistoryList"
    static let exerciseHistoryCopyCancelButton = "exerciseHistoryCopyCancelButton"

    static func exerciseHistoryPerformanceCard(_ performance: ExercisePerformance) -> String { "exerciseHistoryPerformanceCard-\(performance.id.uuidString)" }

    static func exerciseHistoryCopyMenu(_ performance: ExercisePerformance) -> String { "exerciseHistoryCopyMenu-\(performance.id.uuidString)" }

    static func exerciseHistoryCopyModeButton(_ mode: ExerciseHistoryCopyMode) -> String { "exerciseHistoryCopyModeButton-\(mode.rawValue)" }

    static func exerciseHistoryCopyStrategyButton(_ strategy: ExerciseHistoryCopyStrategy) -> String {
        switch strategy {
        case .replaceAll: "exerciseHistoryCopyStrategyButton-replaceAll"
        case .replaceRemaining: "exerciseHistoryCopyStrategyButton-replaceRemaining"
        }
    }

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

    static func workoutSplitInactiveRowOpenButton(_ split: WorkoutSplit) -> String { "workoutSplitInactiveRowOpenButton-\(split.title)" }

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

    // MARK: - PlanBuilderSheet
    static let planBuilderSheet = "planBuilderSheet"
    static let planBuilderScratchButton = "planBuilderScratchButton"
    static let planBuilderAIButton = "planBuilderAIButton"
    static let planBuilderImportButton = "planBuilderImportButton"
    static let aiPlanPromptField = "aiPlanPromptField"
    static let aiPlanGenerateButton = "aiPlanGenerateButton"
    static let aiPlanGeneratingOverlay = "aiPlanGeneratingOverlay"
    static let planImportTextField = "planImportTextField"
    static let planImportButton = "planImportButton"
    static let planImportOverlay = "planImportOverlay"

    static func planBuilderTemplate(_ id: String) -> String { "planBuilderTemplate-\(id)" }
    static func planTemplateDay(_ templateID: String, _ dayID: String) -> String { "planTemplateDay-\(templateID)-\(dayID)" }
    static func planTemplateBuildProgram(_ templateID: String) -> String { "planTemplateBuildProgram-\(templateID)" }
    static func aiPlanQuickPick(_ value: String) -> String { "aiPlanQuickPick-\(value.replacingOccurrences(of: " ", with: "_"))" }
    static func splitBuilderProgram(_ id: String) -> String { "splitBuilderProgram-\(id)" }
    static func aiReplacementSuggestion(_ catalogID: String) -> String { "aiReplacementSuggestion-\(catalogID)" }

    static let aiReplacementLoading = "aiReplacementLoading"

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

    static let workoutSummaryOutcomeSection = "workoutSummaryOutcomeSection"
    static let workoutSummaryExerciseRecapSection = "workoutSummaryExerciseRecapSection"
    static func workoutSummaryOutcomeOption(_ outcome: SessionOutcome) -> String { "workoutSummaryOutcomeOption-\(slug(outcome.rawValue))" }
    static func workoutSummaryExerciseRecapCard(_ catalogID: String) -> String { "workoutSummaryExerciseRecapCard-\(slug(catalogID))" }

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
    static let askVillainArcOpenButton = "askVillainArcOpenButton"
    static let askVillainArcQuestionField = "askVillainArcQuestionField"
    static let askVillainArcAskButton = "askVillainArcAskButton"
    static let askVillainArcAnswer = "askVillainArcAnswer"
    static let cardioLiveActivityMetricsRow = "cardioLiveActivityMetricsRow"
    static func cardioLiveActivityMetricRow(_ rawValue: String) -> String { "cardioLiveActivityMetricRow-\(rawValue)" }
    static let workoutDetailNotesText = "workoutDetailNotesText"
    static let workoutDetailNotesSyncButton = "workoutDetailNotesSyncButton"
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
    static let workoutSettingsAssumeTargetRPEToggle = "workoutSettingsAssumeTargetRPEToggle"
    static let workoutSettingsAutoFillPlanTargetsToggle = "workoutSettingsAutoFillPlanTargetsToggle"
    static let workoutSettingsPrefersTargetReferenceToggle = "workoutSettingsPrefersTargetReferenceToggle"
    static let workoutSettingsPreviousReferenceSourcePicker = "workoutSettingsPreviousReferenceSourcePicker"
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

    // MARK: - OnboardingView
    static let onboardingConnectHealthButton = "onboardingConnectHealthButton"
    static let onboardingSkipHealthButton = "onboardingSkipHealthButton"
    static let onboardingRetryButton = "onboardingRetryButton"
    static let onboardingHealthStepContinueButton = "onboardingHealthStepContinueButton"
    static let onboardingHealthStepConnectButton = "onboardingHealthStepConnectButton"
    static let onboardingHealthStepSkipButton = "onboardingHealthStepSkipButton"
    static let onboardingLocationContinueButton = "onboardingLocationContinueButton"
    static let onboardingGenderContinueButton = "onboardingGenderContinueButton"
    static let onboardingHeightFeetPicker = "onboardingHeightFeetPicker"
    static let onboardingHeightInchesPicker = "onboardingHeightInchesPicker"
    static let onboardingHeightCentimetersPicker = "onboardingHeightCentimetersPicker"
    static let onboardingHeightContinueButton = "onboardingHeightContinueButton"
    static let onboardingFitnessLevelContinueButton = "onboardingFitnessLevelContinueButton"
    static let onboardingTrainingGoalContinueButton = "onboardingTrainingGoalContinueButton"
    static let debugSkipOnboardingButton = "debugSkipOnboardingButton"

    static func onboardingGenderOption(_ gender: UserGender) -> String { "onboardingGenderOption-\(gender.rawValue)" }

    static func onboardingFitnessLevelOption(_ level: FitnessLevel) -> String { "onboardingFitnessLevelOption-\(level.rawValue)" }

    static func onboardingTrainingGoalOption(_ kind: TrainingGoalKind) -> String { "onboardingTrainingGoalOption-\(kind.rawValue)" }

    // MARK: - Paywall / Suggestions / Assistant / Exercise info
    static let paywallRetryButton = "paywallRetryButton"
    static let paywallAnnualCommitmentOption = "paywallAnnualCommitmentOption"
    static let paywallTermsButton = "paywallTermsButton"
    static let paywallPrivacyButton = "paywallPrivacyButton"
    static let paywallEULAButton = "paywallEULAButton"
    static let premiumLockedUpgradeButton = "premiumLockedUpgradeButton"
    static let exerciseDetailMetricPicker = "exerciseDetailMetricPicker"
    static let exerciseDetailAddedConfirmationDismissButton = "exerciseDetailAddedConfirmationDismissButton"
    static let exerciseDetailAllHistoryButton = "exerciseDetailAllHistoryButton"
    static let exerciseInfoSelectButton = "exerciseInfoSelectButton"
    static let exerciseInfoMetricPicker = "exerciseInfoMetricPicker"
    static let exerciseInfoAllHistoryLink = "exerciseInfoAllHistoryLink"
    static let exerciseSuggestionSettingsEnabledToggle = "exerciseSuggestionSettingsEnabledToggle"
    static let exerciseSuggestionSettingsCancelButton = "exerciseSuggestionSettingsCancelButton"
    static let deferredSuggestionsCloseButton = "deferredSuggestionsCloseButton"
    static let deferredSuggestionsCancelWorkoutConfirmButton = "deferredSuggestionsCancelWorkoutConfirmButton"
    static let deferredSuggestionsSkipButton = "deferredSuggestionsSkipButton"
    static let deferredSuggestionsAcceptAllButton = "deferredSuggestionsAcceptAllButton"
    static let suggestionRejectButton = "suggestionRejectButton"
    static let suggestionAcceptButton = "suggestionAcceptButton"
    static let suggestionDeferButton = "suggestionDeferButton"
    static let workoutPlanSuggestionsTabPicker = "workoutPlanSuggestionsTabPicker"
    static let askVillainArcCloseButton = "askVillainArcCloseButton"
    static let cardioFavoriteClearButton = "cardioFavoriteClearButton"
    static let activeCardioResumeBarButton = "activeCardioResumeBarButton"
    static let splitBuilderCloseButton = "splitBuilderCloseButton"

    static func exerciseProgressionStepPresetButton(_ value: Double) -> String { "exerciseProgressionStepPresetButton-\(slug(value.formatted(.number.precision(.fractionLength(0...2)))))" }

    static func askVillainArcQuickPick(_ suggestion: String) -> String { "askVillainArcQuickPick-\(slug(suggestion))" }

    static func cardioFavoriteTypeOption(_ typeRawValue: String) -> String { "cardioFavoriteTypeOption-\(slug(typeRawValue))" }

    // MARK: - Health surfaces
    static let healthHydrationSectionCard = "healthHydrationSectionCard"
    static let healthRespiratoryRateSectionCard = "healthRespiratoryRateSectionCard"
    static let healthWristTemperatureSectionCard = "healthWristTemperatureSectionCard"
    static let healthEnergyHistoryRangePicker = "healthEnergyHistoryRangePicker"
    static let healthVitalsLineHistoryRangePicker = "healthVitalsLineHistoryRangePicker"
    static let healthVitalsRangeHistoryRangePicker = "healthVitalsRangeHistoryRangePicker"
    static let healthHydrationHistoryRangePicker = "healthHydrationHistoryRangePicker"
    static let healthSleepHistoryRangePicker = "healthSleepHistoryRangePicker"
    static let healthSleepMetricPicker = "healthSleepMetricPicker"
    static let healthStepsHistoryRangePicker = "healthStepsHistoryRangePicker"
    static let healthWeightHistoryRangePicker = "healthWeightHistoryRangePicker"
    static let healthWeightHistoryLogWeightButton = "healthWeightHistoryLogWeightButton"
    static let healthTrendsRangePicker = "healthTrendsRangePicker"
    static let healthTrendDetailRangePicker = "healthTrendDetailRangePicker"
    static let healthTrendDetailDoneButton = "healthTrendDetailDoneButton"
    static let healthHydrationGoalButton = "healthHydrationGoalButton"
    static let healthHydrationGoalSummaryButton = "healthHydrationGoalSummaryButton"
    static let healthHydrationGoalHistoryAddButton = "healthHydrationGoalHistoryAddButton"
    static let healthNewHydrationGoalTargetField = "healthNewHydrationGoalTargetField"
    static let healthNewHydrationGoalSaveButton = "healthNewHydrationGoalSaveButton"
    static let healthAddHydrationEntryDatePicker = "healthAddHydrationEntryDatePicker"
    static let healthAddHydrationEntryTimePicker = "healthAddHydrationEntryTimePicker"
    static let healthAddHydrationEntryVolumeField = "healthAddHydrationEntryVolumeField"
    static let healthAddHydrationEntryConfirmButton = "healthAddHydrationEntryConfirmButton"
    static let healthSleepGoalButton = "healthSleepGoalButton"
    static let healthNewSleepGoalHoursPicker = "healthNewSleepGoalHoursPicker"
    static let healthNewSleepGoalMinutesPicker = "healthNewSleepGoalMinutesPicker"
    static let healthNewSleepGoalSaveButton = "healthNewSleepGoalSaveButton"
    static let healthStepsGoalSummaryButton = "healthStepsGoalSummaryButton"
    static let healthNewStepsGoalTargetField = "healthNewStepsGoalTargetField"
    static let healthNewStepsGoalSaveButton = "healthNewStepsGoalSaveButton"
    static let healthNewWeightGoalEstimatedRateButton = "healthNewWeightGoalEstimatedRateButton"
    static let healthWeightGoalCompletionKeepActiveButton = "healthWeightGoalCompletionKeepActiveButton"
    static let healthWeightGoalCompletionPrimaryButton = "healthWeightGoalCompletionPrimaryButton"
    static let healthTrainingConditionViewHistoryButton = "healthTrainingConditionViewHistoryButton"
    static let healthTrainingConditionClearEndDateButton = "healthTrainingConditionClearEndDateButton"
    static let healthTrainingConditionEditButton = "healthTrainingConditionEditButton"
    static let healthTrainingConditionEndButton = "healthTrainingConditionEndButton"

    static func healthHeartSectionCard(_ title: String) -> String { "healthHeartSectionCard-\(slug(title))" }

    static func healthWeightGoalCompleteSwipeButton(_ goal: WeightGoal) -> String { "healthWeightGoalCompleteSwipeButton-\(goal.id.uuidString)" }

    static func healthWeightGoalDeleteButton(_ goal: WeightGoal) -> String { "healthWeightGoalDeleteButton-\(goal.id.uuidString)" }

    static func healthStepsGoalDeleteButton(_ goal: StepsGoal) -> String { "healthStepsGoalDeleteButton-\(goal.id.uuidString)" }

    static func healthSleepGoalDeleteButton(_ goal: SleepGoal) -> String { "healthSleepGoalDeleteButton-\(goal.id.uuidString)" }

    static func healthHydrationGoalDeleteButton(_ goal: HydrationGoal) -> String { "healthHydrationGoalDeleteButton-\(goal.id.uuidString)" }

    static func healthTrainingConditionDeleteButton(_ period: TrainingConditionPeriod) -> String { "healthTrainingConditionDeleteButton-\(period.persistentModelID)" }

    static func healthTrainingConditionKindOption(_ choiceID: String) -> String { "healthTrainingConditionKindOption-\(slug(choiceID))" }

    static func healthTrainingConditionImpactOption(_ impact: TrainingImpact) -> String { "healthTrainingConditionImpactOption-\(impact.rawValue)" }

    // MARK: - WorkoutView / ExerciseView / WorkoutDetailView
    static let workoutChangeTitleButton = "workoutChangeTitleButton"
    static let workoutNotesButton = "workoutNotesButton"
    static let workoutNotesSyncButton = "workoutNotesSyncButton"
    static let workoutExerciseEditDoneButton = "workoutExerciseEditDoneButton"
    static let workoutDismissKeyboardButton = "workoutDismissKeyboardButton"
    static let workoutDetailCloseButton = "workoutDetailCloseButton"
    static let workoutDetailShareButton = "workoutDetailShareButton"
    static let workoutFinishEffortClearButton = "workoutFinishEffortClearButton"
    static let exerciseRestTimerPromptConfirmButton = "exerciseRestTimerPromptConfirmButton"
    static let exerciseRestTimerPromptKeepCurrentButton = "exerciseRestTimerPromptKeepCurrentButton"
    static let replaceExerciseKeepSetsButton = "replaceExerciseKeepSetsButton"
    static let replaceExerciseClearSetsButton = "replaceExerciseClearSetsButton"
    static let replaceExerciseCancelButton = "replaceExerciseCancelButton"
    static let notesPlanSyncCurrentField = "notesPlanSyncCurrentField"
    static let notesPlanSyncUsePlanNotesButton = "notesPlanSyncUsePlanNotesButton"
    static let preWorkoutCloseButton = "preWorkoutCloseButton"
    static let healthWorkoutDetailCloseButton = "healthWorkoutDetailCloseButton"
    static let healthWorkoutRouteMapCloseButton = "healthWorkoutRouteMapCloseButton"
    static let healthWorkoutHeartRateCloseButton = "healthWorkoutHeartRateCloseButton"

    static func workoutExerciseRemoveButton(_ exercise: ExercisePerformance) -> String { "workoutExerciseRemoveButton-\(exercise.catalogID)-\(exercise.index)" }

    static func exerciseNotesSyncButton(_ exercise: ExercisePerformance) -> String { "exerciseNotesSyncButton-\(exercise.catalogID)-\(exercise.index)" }

    static func exerciseSuggestionSettingsButton(_ exercise: ExercisePerformance) -> String { "exerciseSuggestionSettingsButton-\(exercise.catalogID)-\(exercise.index)" }

    static func exerciseReferenceColumnToggle(_ exercise: ExercisePerformance) -> String { "exerciseReferenceColumnToggle-\(exercise.catalogID)-\(exercise.index)" }

    static func filteredExerciseInfoButton(_ exercise: Exercise) -> String { "filteredExerciseInfoButton-\(exercise.catalogID)" }

    static func filteredExerciseSelectionToggle(_ exercise: Exercise) -> String { "filteredExerciseSelectionToggle-\(exercise.catalogID)" }

    static func filteredExerciseSuggestionSettingsButton(_ exercise: Exercise) -> String { "filteredExerciseSuggestionSettingsButton-\(exercise.catalogID)" }

    static func healthWorkoutDetailExpandButton(_ cardRawValue: String) -> String { "healthWorkoutDetailExpandButton-\(cardRawValue)" }

    static func workoutsTypeFilterChip(_ filterID: String) -> String { "workoutsTypeFilterChip-\(slug(filterID))" }

    // MARK: - WorkoutPlanView / WorkoutPlanDetailView / WorkoutPlansListView
    static let workoutPlanChangeTitleButton = "workoutPlanChangeTitleButton"
    static let workoutPlanNotesButton = "workoutPlanNotesButton"
    static let workoutPlanDismissKeyboardButton = "workoutPlanDismissKeyboardButton"
    static let workoutPlanExerciseEditDoneButton = "workoutPlanExerciseEditDoneButton"
    static let workoutPlanDeletePlanConfirmButton = "workoutPlanDeletePlanConfirmButton"
    static let workoutPlanDeleteAssessmentConfirmButton = "workoutPlanDeleteAssessmentConfirmButton"
    static let workoutPlanDeleteAssessmentCancelButton = "workoutPlanDeleteAssessmentCancelButton"
    static let workoutPlanDetailCloseButton = "workoutPlanDetailCloseButton"
    static let workoutPlanDetailSplitAssignmentMenu = "workoutPlanDetailSplitAssignmentMenu"
    static let workoutPlanDetailChangePlanButton = "workoutPlanDetailChangePlanButton"
    static let workoutPlanDetailClearPlanButton = "workoutPlanDetailClearPlanButton"
    static let workoutPlanDetailShareButton = "workoutPlanDetailShareButton"
    static let workoutPlanDetailAllSessionsLink = "workoutPlanDetailAllSessionsLink"
    static let workoutPlansDeleteAllAssessmentConfirmButton = "workoutPlansDeleteAllAssessmentConfirmButton"
    static let workoutPlansDeleteAllAssessmentCancelButton = "workoutPlansDeleteAllAssessmentCancelButton"
    static let workoutPlansDeleteSelectionConfirmButton = "workoutPlansDeleteSelectionConfirmButton"
    static let workoutPlansDeleteSelectionCancelButton = "workoutPlansDeleteSelectionCancelButton"
    static let planBuilderCloseButton = "planBuilderCloseButton"
    static let planImportCloseButton = "planImportCloseButton"
    static let aiPlanCloseButton = "aiPlanCloseButton"

    static func workoutPlanExerciseRemoveButton(_ exercise: ExercisePrescription) -> String { "workoutPlanExerciseRemoveButton-\(exercise.catalogID)-\(exercise.index)" }

    static func workoutPlanExerciseSuggestionSettingsButton(_ exercise: ExercisePrescription) -> String { "workoutPlanExerciseSuggestionSettingsButton-\(exercise.catalogID)-\(exercise.index)" }

    static func workoutPlanDetailSessionRow(_ workout: WorkoutSession) -> String { "workoutPlanDetailSessionRow-\(workout.id.uuidString)" }

    static func workoutPlanAllSessionsRow(_ workout: WorkoutSession) -> String { "workoutPlanAllSessionsRow-\(workout.id.uuidString)" }

    static func workoutPlanPickerRow(_ plan: WorkoutPlan) -> String { "workoutPlanPickerRow-\(plan.id)" }

    static func workoutPlanRowFavoriteSwipeButton(_ plan: WorkoutPlan) -> String { "workoutPlanRowFavoriteSwipeButton-\(plan.id)" }

    // MARK: - ProfileEditorViews
    static let profileGenderEditorCloseButton = "profileGenderEditorCloseButton"
    static let profileGenderEditorConfirmButton = "profileGenderEditorConfirmButton"
    static let profileHeightEditorFeetPicker = "profileHeightEditorFeetPicker"
    static let profileHeightEditorInchesPicker = "profileHeightEditorInchesPicker"
    static let profileHeightEditorCentimetersPicker = "profileHeightEditorCentimetersPicker"
    static let profileHeightEditorCloseButton = "profileHeightEditorCloseButton"
    static let profileHeightEditorConfirmButton = "profileHeightEditorConfirmButton"
    static let profileTrainingGoalEditorCloseButton = "profileTrainingGoalEditorCloseButton"
    static let profileTrainingGoalEditorConfirmButton = "profileTrainingGoalEditorConfirmButton"
    static let profileFitnessLevelEditorCloseButton = "profileFitnessLevelEditorCloseButton"
    static let profileFitnessLevelEditorConfirmButton = "profileFitnessLevelEditorConfirmButton"

    // MARK: - AppSettingsView
    static let settingsCloseButton = "settingsCloseButton"
    static let settingsThemePicker = "settingsThemePicker"
    static let settingsSendDiagnosticButton = "settingsSendDiagnosticButton"
    static let settingsRequestFeatureButton = "settingsRequestFeatureButton"
    static let settingsSupportPageButton = "settingsSupportPageButton"
    static let settingsAppleHealthOpenSystemSettingsButton = "settingsAppleHealthOpenSystemSettingsButton"
    static let settingsAppleHealthInstructionsDismissButton = "settingsAppleHealthInstructionsDismissButton"
    static let settingsNotificationsActionButton = "settingsNotificationsActionButton"
    static let settingsStepsNotificationModePicker = "settingsStepsNotificationModePicker"
    static let settingsSleepNotificationModePicker = "settingsSleepNotificationModePicker"
    static let settingsHydrationNotificationModePicker = "settingsHydrationNotificationModePicker"
    static let settingsWeightUnitPicker = "settingsWeightUnitPicker"
    static let settingsHeightUnitPicker = "settingsHeightUnitPicker"
    static let settingsDistanceUnitPicker = "settingsDistanceUnitPicker"
    static let settingsEnergyUnitPicker = "settingsEnergyUnitPicker"
    static let settingsTemperatureUnitPicker = "settingsTemperatureUnitPicker"
    static let settingsSpeedUnitPicker = "settingsSpeedUnitPicker"
    static let settingsLegalWebCloseButton = "settingsLegalWebCloseButton"
    // The Screenshot Studio's identifiers live in `FCTScreenshotStudio.ScreenshotStudioIdentifiers`:
    // they are a fleet-wide contract one capture driver relies on, and the studio's own views
    // apply them, so this app never spells them.
    static let debugShowOnboardingCarouselButton = "debugShowOnboardingCarouselButton"
    static let debugShowWhatsNewButton = "debugShowWhatsNewButton"
    static let debugResetAppDataCancelButton = "debugResetAppDataCancelButton"
    static let debugSeedExerciseHistoryButton = "debugSeedExerciseHistoryButton"
    static let debugSeedExerciseDetailHistoryButton = "debugSeedExerciseDetailHistoryButton"

    static func debugSeedHealthSamplesButton(_ scenarioTitle: String) -> String { "debugSeedHealthSamplesButton-\(slug(scenarioTitle))" }

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
    static let profileLabel = localized("Profile")
    static let profileHint = localized("Shows your profile.")
    static let profileSheetSettingsHint = localized("Shows app settings.")
    static let profileSheetReviewHint = localized("Opens the App Store review page.")
    static let profileSheetPrivacyPolicyHint = localized("Shows the privacy policy.")
    static let profileSheetTermsOfServiceHint = localized("Shows the terms of service.")
    static let settingsAppleHealthHint = localized("Shows Apple Health settings.")
    static let onboardingFitnessLevelOptionHint = localized("Selects this fitness level.")
    static let onboardingFitnessLevelContinueHint = localized("Saves your selected fitness level and continues to the next profile step.")
    static let onboardingTrainingGoalOptionHint = localized("Selects this training goal.")
    static let onboardingTrainingGoalContinueHint = localized("Saves your selected training goal and continues into the app.")
    static let workoutSettingsAutoFillPlanTargetsHint = localized("Controls whether plan workouts prefill set logging fields with prescribed targets.")
    static let morphingExpandToolbarLabel = localized("Show quick actions")
    static let morphingCollapseToolbarLabel = localized("Hide quick actions")
    static let morphingToolbarHint = localized("Shows or hides the quick action toolbar.")
    static let morphingStartWorkoutHint = localized("Starts a new workout session.")
    static let morphingStartTodaysWorkoutHint = localized("Starts today's workout from your active split.")
    static let morphingCreatePlanHint = localized("Creates a new workout plan.")
    static let morphingAddWeightHint = localized("Creates a new weight entry.")
    static let activeWorkoutResumeHint = localized("Reopens your current workout.")
    static let activeWorkoutResumeCompleteSetHint = localized("Marks the next active set complete.")
    static let activeWorkoutResumeCompleteSetLabel = localized("Complete set")
    static let activeWorkoutResumeOpenButtonLabel = localized("Open workout")
    static let activeWorkoutResumeRestTimerLabel = localized("Rest timer")
    static let activeWorkoutResumeElapsedLabel = localized("Workout elapsed time")
    static let activePlanResumeHint = localized("Reopens your current plan.")
    static let activePlanResumeOpenButtonLabel = localized("Open workout plan")
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
    static let healthSleepGoalHistoryAddLabel = localized("Add sleep goal")
    static let healthSleepGoalHistoryAddHint = localized("Creates a new sleep goal.")
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

    static func activeWorkoutResumeLabel(title: String, detail: String) -> String {
        localized("Workout in progress. \(title). \(detail)")
    }

    static func activePlanResumeLabel(title: String, detail: String) -> String {
        localized("Plan in progress. \(title). \(detail)")
    }

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
    static let workoutSummaryOutcomeSectionLabel = localized("Post-workout suggestion feedback")
    static let workoutSummaryOutcomeOptionHint = localized("Records this rating against each accepted suggestion you used in this workout.")
    static let workoutSummaryExerciseRecapSectionLabel = localized("Exercise recap")

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
    static let onboardingGenderOptionHint = localized("Selects this gender option.")
    static let onboardingGenderContinueHint = localized("Saves your selected gender and continues to the next profile step.")

    static func onboardingGenderOptionValue(isSelected: Bool) -> String { isSelected ? localized("Selected") : localized("Not selected") }
    static func onboardingFitnessLevelOptionValue(isSelected: Bool) -> String { isSelected ? localized("Selected") : localized("Not selected") }
    static func onboardingTrainingGoalOptionValue(isSelected: Bool) -> String { isSelected ? localized("Selected") : localized("Not selected") }
    static func settingsAppleHealthActionHint(action: HealthAuthorizationAction) -> String {
        switch action {
        case .requestAccess:
            return localized("Requests Apple Health read and write access.")
        case .openSettings:
            return localized("Opens Settings so you can change Apple Health permissions.")
        case .manageInSettings:
            return localized("Opens Settings so you can review Apple Health access.")
        case .unavailable:
            return localized("Apple Health access is unavailable.")
        }
    }

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
    static let workoutSettingsAssumeTargetRPEHint = localized("Fills in the target RPE when you mark a set complete without rating it.")
    static let workoutSettingsPrefersTargetReferenceHint = localized("When you have a plan, show your last performance in the reference column by default instead of the plan target. Tap the column header during a workout to switch.")
    static let workoutSettingsPreviousReferenceSourceHint = localized("Chooses whether previous values come from any workout or from the last completed session for the same plan.")
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
