import AppIntents

// These intents mutate app-owned state and depend on the main app's SwiftData container,
// routers, or live-session coordinators. Keep them out of read-only extension processes.
@available(iOS 27.0, *)
extension StartCardioSessionIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

@available(iOS 27.0, *)
extension FinishCardioSessionIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

@available(iOS 27.0, *)
extension CancelCardioSessionIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

@available(iOS 27.0, *)
extension AddExerciseIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

@available(iOS 27.0, *)
extension AddExercisesIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

@available(iOS 27.0, *)
extension ReplaceExerciseIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

@available(iOS 27.0, *)
extension ToggleExerciseFavoriteIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

@available(iOS 27.0, *)
extension AddHydrationEntryIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

@available(iOS 27.0, *)
extension AddWeightEntryIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

@available(iOS 27.0, *)
extension CreateHydrationGoalIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

@available(iOS 27.0, *)
extension CreateSleepGoalIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

@available(iOS 27.0, *)
extension CreateStepsGoalIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

@available(iOS 27.0, *)
extension CreateWeightGoalIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

@available(iOS 27.0, *)
extension EndTrainingConditionIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

@available(iOS 27.0, *)
extension StartRestTimerIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

@available(iOS 27.0, *)
extension PauseRestTimerIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

@available(iOS 27.0, *)
extension ResumeRestTimerIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

@available(iOS 27.0, *)
extension StopRestTimerIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

@available(iOS 27.0, *)
extension RestTimerControlIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

@available(iOS 27.0, *)
extension StartWorkoutIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

@available(iOS 27.0, *)
extension CompleteActiveSetIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

@available(iOS 27.0, *)
extension FinishWorkoutIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

@available(iOS 27.0, *)
extension CancelWorkoutIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

@available(iOS 27.0, *)
extension DeleteWorkoutIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

@available(iOS 27.0, *)
extension DeleteAllWorkoutsIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

@available(iOS 27.0, *)
extension SaveWorkoutAsPlanIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

@available(iOS 27.0, *)
extension CreateWorkoutPlanIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

@available(iOS 27.0, *)
extension StartWorkoutWithPlanIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

@available(iOS 27.0, *)
extension ToggleWorkoutPlanFavoriteIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

@available(iOS 27.0, *)
extension DeleteWorkoutPlanIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

@available(iOS 27.0, *)
extension DeleteAllWorkoutPlansIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}

@available(iOS 27.0, *)
extension StartTodaysWorkoutIntent {
    static var allowedExecutionTargets: IntentExecutionTargets { .main }
}
