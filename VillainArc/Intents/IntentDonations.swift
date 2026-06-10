import AppIntents
import Foundation

enum IntentDonations {
    #if DEBUG
    private static let donationsEnabled = false
    #else
    private static let donationsEnabled = true
    #endif

    static func donateStartWorkout() async { guard donationsEnabled else { return }; _ = try? await StartWorkoutIntent().donate() }

    static func donateOpenWorkoutSplit() async { guard donationsEnabled else { return }; _ = try? await OpenWorkoutSplitIntent().donate() }

    static func donateCreateWorkoutSplit() async { guard donationsEnabled else { return }; _ = try? await CreateWorkoutSplitIntent().donate() }

    static func donateManageWorkoutSplits() async { guard donationsEnabled else { return }; _ = try? await ManageWorkoutSplitsIntent().donate() }

    static func donateOpenTodaysPlan() async { guard donationsEnabled else { return }; _ = try? await OpenTodaysPlanIntent().donate() }

    static func donateStartTodaysWorkout() async { guard donationsEnabled else { return }; _ = try? await StartTodaysWorkoutIntent().donate() }
    static func donateViewLastWorkout() async { guard donationsEnabled else { return }; _ = try? await ViewLastWorkoutIntent().donate() }

    static func donateOpenWorkout(workout: WorkoutSession) async {
        guard donationsEnabled else { return }
        let intent = OpenWorkoutIntent()
        intent.workout = WorkoutSessionEntity(workoutSession: workout)
        _ = try? await intent.donate()
    }

    static func donateOpenActiveWorkout() async { guard donationsEnabled else { return }; _ = try? await OpenActiveWorkoutIntent().donate() }
    static func donateOpenActiveWorkoutPlan() async { guard donationsEnabled else { return }; _ = try? await OpenActiveWorkoutPlanIntent().donate() }
    static func donateOpenProfile() async { guard donationsEnabled else { return }; _ = try? await OpenProfileIntent().donate() }
    static func donateOpenSettings() async { guard donationsEnabled else { return }; _ = try? await OpenSettingsIntent().donate() }
    static func donateOpenWorkoutPreferences() async { guard donationsEnabled else { return }; _ = try? await OpenWorkoutPreferencesIntent().donate() }
    static func donateOpenAppleHealthSettings() async { guard donationsEnabled else { return }; _ = try? await OpenAppleHealthSettingsIntent().donate() }
    static func donateOpenNotificationSettings() async { guard donationsEnabled else { return }; _ = try? await OpenNotificationSettingsIntent().donate() }
    static func donateOpenUnitSettings() async { guard donationsEnabled else { return }; _ = try? await OpenUnitSettingsIntent().donate() }

    static func donateSaveWorkoutAsPlan(workout: WorkoutSession) async {
        guard donationsEnabled else { return }
        let intent = SaveWorkoutAsPlanIntent()
        intent.workout = WorkoutSessionEntity(workoutSession: workout)
        _ = try? await intent.donate()
    }

    static func donateDeleteWorkout(workout: WorkoutSession) async {
        guard donationsEnabled else { return }
        let intent = DeleteWorkoutIntent()
        intent.workout = WorkoutSessionEntity(workoutSession: workout)
        _ = try? await intent.donate()
    }

    static func donateDeleteAllWorkouts() async { guard donationsEnabled else { return }; _ = try? await DeleteAllWorkoutsIntent().donate() }
    static func donateShowWorkoutHistory() async { guard donationsEnabled else { return }; _ = try? await ShowWorkoutHistoryIntent().donate() }
    static func donateShowWeightHistory() async { guard donationsEnabled else { return }; _ = try? await ShowWeightHistoryIntent().donate() }
    static func donateShowAllWeightEntries() async { guard donationsEnabled else { return }; _ = try? await ShowAllWeightEntriesIntent().donate() }
    static func donateShowWeightGoalHistory() async { guard donationsEnabled else { return }; _ = try? await ShowWeightGoalHistoryIntent().donate() }
    static func donateShowStepsHistory() async { guard donationsEnabled else { return }; _ = try? await ShowStepsHistoryIntent().donate() }
    static func donateShowStepsGoalHistory() async { guard donationsEnabled else { return }; _ = try? await ShowStepsGoalHistoryIntent().donate() }
    static func donateShowSleepHistory() async { guard donationsEnabled else { return }; _ = try? await ShowSleepHistoryIntent().donate() }
    static func donateShowSleepGoalHistory() async { guard donationsEnabled else { return }; _ = try? await ShowSleepGoalHistoryIntent().donate() }
    static func donateShowCaloriesBurnedHistory() async { guard donationsEnabled else { return }; _ = try? await ShowCaloriesBurnedHistoryIntent().donate() }
    static func donateCreateWeightGoal() async { guard donationsEnabled else { return }; _ = try? await CreateWeightGoalIntent().donate() }
    static func donateCreateSleepGoal() async { guard donationsEnabled else { return }; _ = try? await CreateSleepGoalIntent().donate() }

    static func donateShowWorkoutPlans() async { guard donationsEnabled else { return }; _ = try? await ShowWorkoutPlansIntent().donate() }

    static func donateOpenWorkoutPlan(workoutPlan: WorkoutPlan) async {
        guard donationsEnabled else { return }
        let intent = OpenWorkoutPlanIntent()
        intent.workoutPlan = WorkoutPlanEntity(workoutPlan: workoutPlan)
        _ = try? await intent.donate()
    }

    static func donateDeleteWorkoutPlan(workoutPlan: WorkoutPlan) async {
        await donateDeleteWorkoutPlan(workoutPlan: WorkoutPlanEntity(workoutPlan: workoutPlan))
    }

    static func donateDeleteWorkoutPlan(workoutPlan: WorkoutPlanEntity) async {
        guard donationsEnabled else { return }
        let intent = DeleteWorkoutPlanIntent()
        intent.workoutPlan = workoutPlan
        _ = try? await intent.donate()
    }

    static func donateDeleteAllWorkoutPlans() async { guard donationsEnabled else { return }; _ = try? await DeleteAllWorkoutPlansIntent().donate() }

    static func donateToggleWorkoutPlanFavorite(workoutPlan: WorkoutPlan) async {
        guard donationsEnabled else { return }
        let intent = ToggleWorkoutPlanFavoriteIntent()
        intent.workoutPlan = WorkoutPlanEntity(workoutPlan: workoutPlan)
        _ = try? await intent.donate()
    }

    static func donateLastWorkoutSummary() async { guard donationsEnabled else { return }; _ = try? await LastWorkoutSummaryIntent().donate() }

    static func donateTrainingSummary(day: TrainingDay = .today) async {
        guard donationsEnabled else { return }
        let intent = TrainingSummaryIntent()
        intent.day = day
        _ = try? await intent.donate()
    }

    static func donateCreateWorkoutPlan() async { guard donationsEnabled else { return }; _ = try? await CreateWorkoutPlanIntent().donate() }

    static func donateStartWorkoutWithPlan(workoutPlan: WorkoutPlan) async {
        guard donationsEnabled else { return }
        let intent = StartWorkoutWithPlanIntent()
        intent.workoutPlan = WorkoutPlanEntity(workoutPlan: workoutPlan)
        _ = try? await intent.donate()
    }

    static func donateAddExercise(exercise: Exercise) async {
        guard donationsEnabled else { return }
        let intent = AddExerciseIntent()
        intent.exercise = ExerciseEntity(exercise: exercise)
        _ = try? await intent.donate()
    }

    static func donateOpenExercise(exercise: Exercise) async {
        guard donationsEnabled else { return }
        let intent = OpenExerciseIntent()
        intent.exercise = ExerciseEntity(exercise: exercise)
        _ = try? await intent.donate()
    }

    static func donateOpenExercises() async { guard donationsEnabled else { return }; _ = try? await OpenExercisesIntent().donate() }

    static func donateOpenWorkoutSettings() async { guard donationsEnabled else { return }; _ = try? await OpenWorkoutSettingsIntent().donate() }

    static func donateOpenRestTimer() async { guard donationsEnabled else { return }; _ = try? await OpenRestTimerIntent().donate() }

    static func donateOpenPreWorkoutContext() async { guard donationsEnabled else { return }; _ = try? await OpenPreWorkoutContextIntent().donate() }

    static func donateStartRestTimer(seconds: Int) async {
        guard donationsEnabled else { return }
        guard seconds > 0 else { return }
        let intent = StartRestTimerIntent()
        intent.duration = Measurement(value: Double(seconds), unit: .seconds)
        _ = try? await intent.donate()
    }

    static func donatePauseRestTimer() async { guard donationsEnabled else { return }; _ = try? await PauseRestTimerIntent().donate() }

    static func donateResumeRestTimer() async { guard donationsEnabled else { return }; _ = try? await ResumeRestTimerIntent().donate() }

    static func donateStopRestTimer() async { guard donationsEnabled else { return }; _ = try? await StopRestTimerIntent().donate() }

    static func donateFinishWorkout() async { guard donationsEnabled else { return }; _ = try? await FinishWorkoutIntent().donate() }

    static func donateAddExercises(exercises: [Exercise]) async {
        guard donationsEnabled else { return }
        guard !exercises.isEmpty else { return }
        let intent = AddExercisesIntent()
        intent.exercises = exercises.map(ExerciseEntity.init)
        _ = try? await intent.donate()
    }

    static func donateCancelWorkout() async { guard donationsEnabled else { return }; _ = try? await CancelWorkoutIntent().donate() }

    static func donateCompleteActiveSet() async { guard donationsEnabled else { return }; _ = try? await CompleteActiveSetIntent().donate() }

    static func donateReplaceExercise(newExercise: Exercise) async {
        guard donationsEnabled else { return }
        let intent = ReplaceExerciseIntent()
        intent.newExercise = ExerciseEntity(exercise: newExercise)
        _ = try? await intent.donate()
    }

    static func donateToggleExerciseFavorite(exercise: Exercise) async {
        guard donationsEnabled else { return }
        let intent = ToggleExerciseFavoriteIntent()
        intent.exercise = ExerciseEntity(exercise: exercise)
        _ = try? await intent.donate()
    }

    static func donateStartCardioSession(type: CardioSessionType) async {
        guard donationsEnabled else { return }
        let intent = StartCardioSessionIntent()
        intent.kind = CardioKindAppEnum(type)
        _ = try? await intent.donate()
    }

    static func donateOpenActiveCardioSession() async {
        guard donationsEnabled else { return }
        _ = try? await OpenActiveCardioSessionIntent().donate()
    }

    static func donateShowCardioHistory() async {
        guard donationsEnabled else { return }
        _ = try? await ShowCardioHistoryIntent().donate()
    }

    static func donateShowHealthTrends() async { guard donationsEnabled else { return }; _ = try? await ShowHealthTrendsIntent().donate() }
    static func donateShowSleepInsights() async { guard donationsEnabled else { return }; _ = try? await ShowSleepInsightsIntent().donate() }
    static func donateShowCorrelationInsights() async { guard donationsEnabled else { return }; _ = try? await ShowCorrelationInsightsIntent().donate() }
}
