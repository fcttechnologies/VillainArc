import AppIntents

// These intents mutate app-owned state and depend on the main app's SwiftData container,
// routers, or live-session coordinators. Keep them out of read-only extension processes.
extension StartCardioSessionIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

extension FinishCardioSessionIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

extension CancelCardioSessionIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

extension AddExerciseIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

extension AddExercisesIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

extension ReplaceExerciseIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

extension ToggleExerciseFavoriteIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

extension AddHydrationEntryIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

extension AddWeightEntryIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

extension CreateHydrationGoalIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

extension CreateSleepGoalIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

extension CreateStepsGoalIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

extension CreateWeightGoalIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

extension EndTrainingConditionIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

extension StartRestTimerIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

extension PauseRestTimerIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

extension ResumeRestTimerIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

extension StopRestTimerIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

extension RestTimerControlIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

extension StartWorkoutIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

extension CompleteActiveSetIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

extension FinishWorkoutIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

extension CancelWorkoutIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

extension DeleteWorkoutIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

extension DeleteAllWorkoutsIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

extension SaveWorkoutAsPlanIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

extension CreateWorkoutPlanIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

extension StartWorkoutWithPlanIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

extension ToggleWorkoutPlanFavoriteIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

extension DeleteWorkoutPlanIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

extension DeleteAllWorkoutPlansIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

extension StartTodaysWorkoutIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}
