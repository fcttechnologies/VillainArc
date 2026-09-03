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
    /// running. `ReportingAppIntent` crumbs `intent.started` / `.returned` / `.threw` around it.
    case intentStartWorkout = "intent.start_workout"
    case intentStartTodaysWorkout = "intent.start_todays_workout"
    case intentEndWorkout = "intent.end_workout"
    case intentCancelWorkout = "intent.cancel_workout"
    case intentLogSet = "intent.log_set"
    case intentOpenWorkout = "intent.open_workout"
    case intentWorkoutSummary = "intent.workout_summary"
    case intentStartCardio = "intent.start_cardio"
    case intentEndCardio = "intent.end_cardio"
    case intentOpenCardio = "intent.open_cardio"
    case intentCreatePlan = "intent.create_plan"
    case intentOpenPlan = "intent.open_plan"
    case intentStartWorkoutWithPlan = "intent.start_workout_with_plan"
    case intentCreateSplit = "intent.create_split"
    case intentOpenSplit = "intent.open_split"
    case intentOpenExercise = "intent.open_exercise"
    case intentExerciseHistory = "intent.exercise_history"
    case intentLogWeight = "intent.log_weight"
    case intentLogHydration = "intent.log_hydration"
    case intentCreateGoal = "intent.create_goal"
    case intentHealthMetric = "intent.health_metric"
    case intentTrainingCondition = "intent.training_condition"
    case intentRestTimer = "intent.rest_timer"
    case intentAskAssistant = "intent.ask_assistant"
    case intentOpenApp = "intent.open_app"
    case intentOpenSettings = "intent.open_settings"
    case intentOpenProfile = "intent.open_profile"
    case intentLiveActivity = "intent.live_activity"
    case intentApplySuggestion = "intent.apply_suggestion"
    case intentReviewSuggestions = "intent.review_suggestions"
    case intentProgressionAnalysis = "intent.progression_analysis"
    case intentMuscleDistribution = "intent.muscle_distribution"
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
