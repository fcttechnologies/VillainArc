import FCTMetrics
import Foundation

// MARK: - The Diag vocabulary

/// Villain Arc's breadcrumbs: the shape of what happened, never a destination, a value, or a name.
/// Every name is a compile-time constant — free text is structurally unable to leave the device.
///
/// Two families, and the split is what makes a trail readable. **Screens** ride `.diagScreen(_:)`
/// on the screen's own view, so the last screen crumb before a crash is the screen the user was
/// looking at. **Actions** are one `Diag.breadcrumb(_:)` at the top of the handler that runs them,
/// because a button's own action closure is the only place that fires exactly when the action does.
///
/// This file compiles into the widget extension as well as the app, so it depends on `FCTMetrics`
/// and `Foundation` and nothing else.
nonisolated enum VACrumb: String, DiagBreadcrumb, CaseIterable {

    // MARK: Screens — tab roots

    case homeTab = "home.tab"
    case cardioTab = "cardio.tab"
    case healthTab = "health.tab"
    case profileTab = "profile.tab"

    // MARK: Screens — workouts

    case workoutList = "workout.list"
    case workoutDetail = "workout.detail"
    case workoutSession = "workout.session"
    case workoutSummary = "workout.summary"
    case workoutLiveStats = "workout.live_stats"
    case workoutSettings = "workout.settings"
    case workoutEffortPrompt = "workout.effort_prompt"
    case workoutPreContext = "workout.pre_context"
    case workoutRestTimer = "workout.rest_timer"
    case workoutNotesEditor = "workout.notes_editor"
    case workoutRepRangeEditor = "workout.rep_range_editor"
    case workoutRestTimeEditor = "workout.rest_time_editor"
    case healthWorkoutDetail = "workout.health_detail"

    // MARK: Screens — plans and splits

    case planList = "plan.list"
    case planDetail = "plan.detail"
    case planEditor = "plan.editor"
    case planBuilder = "plan.builder"
    case planTemplateDetail = "plan.template_detail"
    case planPicker = "plan.picker"
    case planAIPrompt = "plan.ai_prompt"
    case planImport = "plan.import"
    case splitList = "split.list"
    case splitDetail = "split.detail"
    case splitBuilder = "split.builder"
    case splitDay = "split.day"
    case splitSelectMode = "split.select_mode"
    case splitSelectDays = "split.select_days"
    case splitSelectRestDays = "split.select_rest_days"

    // MARK: Screens — exercises

    case exerciseList = "exercise.list"
    case exerciseDetail = "exercise.detail"
    case exerciseHistory = "exercise.history"
    case exerciseInfo = "exercise.info"
    case exerciseAdd = "exercise.add"
    case exerciseReplace = "exercise.replace"
    case exerciseMuscleFilter = "exercise.muscle_filter"
    case exerciseSuggestionSettings = "exercise.suggestion_settings"

    // MARK: Screens — cardio

    case cardioSession = "cardio.session"
    case cardioDetail = "cardio.detail"
    case cardioStart = "cardio.start"
    case cardioMetrics = "cardio.metrics"
    case cardioRoutes = "cardio.routes"

    // MARK: Screens — health

    case healthWeightHistory = "health.weight_history"
    case healthAllWeightEntries = "health.all_weight_entries"
    case healthWeightGoalHistory = "health.weight_goal_history"
    case healthWeightGoalCompletion = "health.weight_goal_completion"
    case healthAddWeight = "health.add_weight"
    case healthNewWeightGoal = "health.new_weight_goal"
    case healthSleepHistory = "health.sleep_history"
    case healthSleepGoalHistory = "health.sleep_goal_history"
    case healthNewSleepGoal = "health.new_sleep_goal"
    case healthStepsHistory = "health.steps_history"
    case healthStepsGoalHistory = "health.steps_goal_history"
    case healthNewStepsGoal = "health.new_steps_goal"
    case healthEnergyHistory = "health.energy_history"
    case healthHydrationHistory = "health.hydration_history"
    case healthHydrationGoalHistory = "health.hydration_goal_history"
    case healthAddHydration = "health.add_hydration"
    case healthNewHydrationGoal = "health.new_hydration_goal"
    case healthHeartRateHistory = "health.heart_rate_history"
    case healthRestingHeartRateHistory = "health.resting_heart_rate_history"
    case healthWalkingHeartRateHistory = "health.walking_heart_rate_history"
    case healthHeartRateVariabilityHistory = "health.hrv_history"
    case healthRespiratoryRateHistory = "health.respiratory_rate_history"
    case healthWristTemperatureHistory = "health.wrist_temperature_history"
    case healthTrainingConditionHistory = "health.training_condition_history"
    case healthTrainingConditionEditor = "health.training_condition_editor"
    case healthTrends = "health.trends"
    case healthTrendDetail = "health.trend_detail"
    case healthSleepTimingInsights = "health.sleep_timing_insights"
    case healthCorrelationInsights = "health.correlation_insights"

    // MARK: Screens — suggestions

    case suggestionReview = "suggestion.review"
    case suggestionDeferred = "suggestion.deferred"
    case suggestionPlan = "suggestion.plan"
    case suggestionProgression = "suggestion.progression"

    // MARK: Screens — app shell

    case onboardingSetup = "onboarding.setup"
    case settings = "settings"
    case settingsWorkoutPreferences = "settings.workout_preferences"
    case settingsAppleHealth = "settings.apple_health"
    case settingsCardioMetricPicker = "settings.cardio_metric_picker"
    case settingsLegal = "settings.legal"
    case profileEditor = "profile.editor"
    case assistant = "assistant"
    case paywall = "paywall"
    case premiumLocked = "premium.locked"
    case whatsNew = "whats_new"
    case textEditor = "text_editor"

    // MARK: Actions — workouts

    case workoutStarted = "workout_started"
    case workoutFinished = "workout_finished"
    case workoutDiscarded = "workout_discarded"
    case workoutPaused = "workout_paused"
    case workoutResumed = "workout_resumed"
    case setLogged = "set_logged"
    case setAdded = "set_added"
    case setDeleted = "set_deleted"
    case exerciseAdded = "exercise_added"
    case exerciseRemoved = "exercise_removed"
    case exerciseReplaced = "exercise_replaced"
    case exerciseReordered = "exercise_reordered"
    case restTimerStarted = "rest_timer_started"
    case restTimerSkipped = "rest_timer_skipped"
    case effortRecorded = "effort_recorded"

    // MARK: Actions — cardio

    case cardioStarted = "cardio_started"
    case cardioFinished = "cardio_finished"
    case cardioDiscarded = "cardio_discarded"
    case cardioIntervalAdded = "cardio_interval_added"

    // MARK: Actions — plans and splits

    case planCreated = "plan_created"
    case planEdited = "plan_edited"
    case planDeleted = "plan_deleted"
    case planUsed = "plan_used"
    case planTemplateApplied = "plan_template_applied"
    case splitCreated = "split_created"
    case splitActivated = "split_activated"
    case splitDeleted = "split_deleted"

    // MARK: Actions — suggestions and AI

    case suggestionDecided = "suggestion_decided"
    case suggestionApplied = "suggestion_applied"
    case suggestionDismissed = "suggestion_dismissed"
    case suggestionDeferredAction = "suggestion_deferred"
    case assistantAsked = "assistant_asked"
    case aiPlanRequested = "ai_plan_requested"
    case aiPlanImported = "ai_plan_imported"
    case aiReplacementRequested = "ai_replacement_requested"
    case aiProgressionRequested = "ai_progression_requested"

    // MARK: Actions — health

    case healthSyncRan = "health_sync_ran"
    case weightLogged = "weight_logged"
    case hydrationLogged = "hydration_logged"
    case goalCreated = "goal_created"
    case goalCompleted = "goal_completed"
    case trainingConditionLogged = "training_condition_logged"

    // MARK: Actions — app shell

    case paywallShown = "paywall_shown"
    case settingChanged = "setting_changed"
    case storeSaved = "store_saved"
    case dataExported = "data_exported"

    // MARK: Actions — App Intents

    /// One case per intent, so a crash inside a headless invocation names which intent was
    /// running. `ReportingAppIntent` crumbs `intent.started` / `.returned` / `.threw` around it,
    /// and `IntentCrumbCoverageTests` pins that every intent in the app has a case here.

    case intentCancelCardioSession = "intent.cancel_cardio_session"
    case intentFinishCardioSession = "intent.finish_cardio_session"
    case intentOpenActiveCardioSession = "intent.open_active_cardio_session"
    case intentOpenCardioSession = "intent.open_cardio_session"
    case intentShowCardioHistory = "intent.show_cardio_history"
    case intentStartCardioSession = "intent.start_cardio_session"
    case intentAddExercise = "intent.add_exercise"
    case intentAddExercises = "intent.add_exercises"
    case intentOpenExercise = "intent.open_exercise"
    case intentOpenExercises = "intent.open_exercises"
    case intentReplaceExercise = "intent.replace_exercise"
    case intentShowExerciseHistory = "intent.show_exercise_history"
    case intentToggleExerciseFavorite = "intent.toggle_exercise_favorite"
    case intentViewLastUsedExercise = "intent.view_last_used_exercise"
    case intentAddHydrationEntry = "intent.add_hydration_entry"
    case intentAddWeightEntry = "intent.add_weight_entry"
    case intentCreateHydrationGoal = "intent.create_hydration_goal"
    case intentCreateSleepGoal = "intent.create_sleep_goal"
    case intentCreateStepsGoal = "intent.create_steps_goal"
    case intentCreateWeightGoal = "intent.create_weight_goal"
    case intentEndTrainingCondition = "intent.end_training_condition"
    case intentGetActiveCalories = "intent.get_active_calories"
    case intentGetHeartRateForDay = "intent.get_heart_rate_for_day"
    case intentGetRespiratoryRateForDay = "intent.get_respiratory_rate_for_day"
    case intentGetWristTemperatureForDay = "intent.get_wrist_temperature_for_day"
    case intentGetHydrationForDay = "intent.get_hydration_for_day"
    case intentGetCaloriesBurned = "intent.get_calories_burned"
    case intentGetDistance = "intent.get_distance"
    case intentGetHealthDaySummaryForDay = "intent.get_health_day_summary_for_day"
    case intentGetHealthDaySummary = "intent.get_health_day_summary"
    case intentGetHealthMetricForDay = "intent.get_health_metric_for_day"
    case intentGetHealthMetric = "intent.get_health_metric"
    case intentGetHeartRate = "intent.get_heart_rate"
    case intentGetHydrationGoalStatus = "intent.get_hydration_goal_status"
    case intentGetHydration = "intent.get_hydration"
    case intentGetLatestWeight = "intent.get_latest_weight"
    case intentGetRespiratoryRate = "intent.get_respiratory_rate"
    case intentGetRestingCalories = "intent.get_resting_calories"
    case intentGetSleepGoalStatus = "intent.get_sleep_goal_status"
    case intentGetSleep = "intent.get_sleep"
    case intentGetStepsGoalStatus = "intent.get_steps_goal_status"
    case intentGetSteps = "intent.get_steps"
    case intentGetTrainingCondition = "intent.get_training_condition"
    case intentGetWeightGoalStatus = "intent.get_weight_goal_status"
    case intentGetWeight = "intent.get_weight"
    case intentGetWristTemperature = "intent.get_wrist_temperature"
    case intentOpenTrainingConditionHistory = "intent.open_training_condition_history"
    case intentShowHydrationHistory = "intent.show_hydration_history"
    case intentShowHydrationGoalHistory = "intent.show_hydration_goal_history"
    case intentShowHeartRateHistory = "intent.show_heart_rate_history"
    case intentShowRestingHeartRateHistory = "intent.show_resting_heart_rate_history"
    case intentShowWalkingHeartRateHistory = "intent.show_walking_heart_rate_history"
    case intentShowHeartRateVariabilityHistory = "intent.show_heart_rate_variability_history"
    case intentShowRespiratoryRateHistory = "intent.show_respiratory_rate_history"
    case intentShowWristTemperatureHistory = "intent.show_wrist_temperature_history"
    case intentShowAllWeightEntries = "intent.show_all_weight_entries"
    case intentShowCaloriesBurnedHistory = "intent.show_calories_burned_history"
    case intentShowCorrelationInsights = "intent.show_correlation_insights"
    case intentShowHealthTrends = "intent.show_health_trends"
    case intentShowSleepGoalHistory = "intent.show_sleep_goal_history"
    case intentShowSleepHistory = "intent.show_sleep_history"
    case intentShowSleepInsights = "intent.show_sleep_insights"
    case intentShowStepsGoalHistory = "intent.show_steps_goal_history"
    case intentShowStepsHistory = "intent.show_steps_history"
    case intentShowWeightGoalHistory = "intent.show_weight_goal_history"
    case intentShowWeightHistory = "intent.show_weight_history"
    case intentUpdateTrainingCondition = "intent.update_training_condition"
    case intentLiveActivityAddExercise = "intent.live_activity_add_exercise"
    case intentLiveActivityCompleteSet = "intent.live_activity_complete_set"
    case intentLiveActivityPauseRestTimer = "intent.live_activity_pause_rest_timer"
    case intentLiveActivityResumeRestTimer = "intent.live_activity_resume_rest_timer"
    case intentOpenApp = "intent.open_app"
    case intentOpenWorkoutPreferences = "intent.open_workout_preferences"
    case intentOpenAppleHealthSettings = "intent.open_apple_health_settings"
    case intentOpenNotificationSettings = "intent.open_notification_settings"
    case intentOpenUnitSettings = "intent.open_unit_settings"
    case intentOpenProfile = "intent.open_profile"
    case intentOpenSettings = "intent.open_settings"
    case intentPauseRestTimer = "intent.pause_rest_timer"
    case intentRestTimerControl = "intent.rest_timer_control"
    case intentRestTimerSnippet = "intent.rest_timer_snippet"
    case intentResumeRestTimer = "intent.resume_rest_timer"
    case intentStartRestTimer = "intent.start_rest_timer"
    case intentStopRestTimer = "intent.stop_rest_timer"
    case intentCancelWorkout = "intent.cancel_workout"
    case intentCompleteActiveSet = "intent.complete_active_set"
    case intentDeleteAllWorkouts = "intent.delete_all_workouts"
    case intentDeleteWorkout = "intent.delete_workout"
    case intentFinishWorkout = "intent.finish_workout"
    case intentLastWorkoutSummary = "intent.last_workout_summary"
    case intentOpenActiveWorkout = "intent.open_active_workout"
    case intentOpenPreWorkoutContext = "intent.open_pre_workout_context"
    case intentOpenRestTimer = "intent.open_rest_timer"
    case intentOpenWorkout = "intent.open_workout"
    case intentOpenWorkoutSettings = "intent.open_workout_settings"
    case intentSaveWorkoutAsPlan = "intent.save_workout_as_plan"
    case intentShowWorkoutHistory = "intent.show_workout_history"
    case intentStartWorkout = "intent.start_workout"
    case intentViewLastWorkout = "intent.view_last_workout"
    case intentCreateWorkoutPlan = "intent.create_workout_plan"
    case intentDeleteAllWorkoutPlans = "intent.delete_all_workout_plans"
    case intentDeleteWorkoutPlan = "intent.delete_workout_plan"
    case intentEditWorkoutPlan = "intent.edit_workout_plan"
    case intentOpenActiveWorkoutPlan = "intent.open_active_workout_plan"
    case intentOpenWorkoutPlan = "intent.open_workout_plan"
    case intentShowWorkoutPlans = "intent.show_workout_plans"
    case intentStartWorkoutWithPlan = "intent.start_workout_with_plan"
    case intentToggleWorkoutPlanFavorite = "intent.toggle_workout_plan_favorite"
    case intentViewLastWorkoutPlan = "intent.view_last_workout_plan"
    case intentCreateWorkoutSplit = "intent.create_workout_split"
    case intentManageWorkoutSplits = "intent.manage_workout_splits"
    case intentOpenTodaysPlan = "intent.open_todays_plan"
    case intentOpenWorkoutSplit = "intent.open_workout_split"
    case intentStartTodaysWorkout = "intent.start_todays_workout"
    case intentTrainingSummary = "intent.training_summary"
}

/// The funnels whose abandonment is itself the signal.
nonisolated enum VAFunnel: String, DiagFunnel, CaseIterable {
    /// Villain Arc's own setup questions, after the account's. Reached once per install.
    case onboarding = "onboarding"
    case workoutSession = "workout_session"
    case cardioSession = "cardio_session"
    case planAuthoring = "plan_authoring"
    case suggestionReview = "suggestion_review"

    /// The app's own setup is a milestone; a workout, a cardio session, a plan being authored and
    /// a review pass all genuinely recur, and each run is its own measurement.
    var completesOncePerInstall: Bool { self == .onboarding }
}

/// Dated deltas, coalesced by day on-device before they ride. One per feature: what a counter
/// answers is how many installs reach a feature at all, which no crash trail can say.
nonisolated enum VACounter: String, DiagCounter, CaseIterable {
    case workoutsCompleted = "workouts_completed"
    case cardioCompleted = "cardio_completed"
    case setsLogged = "sets_logged"
    case plansCreated = "plans_created"
    case splitsCreated = "splits_created"
    case exercisesReplaced = "exercises_replaced"
    case aiPlansGenerated = "ai_plans_generated"
    case aiPlansImported = "ai_plans_imported"
    case aiReplacementsSuggested = "ai_replacements_suggested"
    case aiProgressionAnalyses = "ai_progression_analyses"
    case assistantQuestions = "assistant_questions"
    case suggestionsShown = "suggestions_shown"
    case suggestionsApplied = "suggestions_applied"
    case weightEntriesLogged = "weight_entries_logged"
    case hydrationEntriesLogged = "hydration_entries_logged"
    case goalsCreated = "goals_created"
    case healthTrendsViewed = "health_trends_viewed"
    case muscleDistributionRangeChanged = "muscle_distribution_range_changed"
    /// The escalation this app pays for: a model turn the on-device window could not hold, run on
    /// Private Cloud Compute instead. Fleet-wide it is what says whether the entitlement earns its
    /// keep; per install it is nothing but a count.
    case aiCloudEscalations = "ai_cloud_escalations"
    case aiCloudUnavailable = "ai_cloud_unavailable"
}
