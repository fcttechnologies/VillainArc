import AppIntents
import Testing

@testable import VillainArc

struct AppIntentExecutionPolicyTests {
    @Test
    func stateWritingIntentsRunOnlyInTheMainApp() {
        let targets: [IntentExecutionTargets] = [
            StartCardioSessionIntent.allowedExecutionTargets,
            FinishCardioSessionIntent.allowedExecutionTargets,
            CancelCardioSessionIntent.allowedExecutionTargets,
            AddExerciseIntent.allowedExecutionTargets,
            AddExercisesIntent.allowedExecutionTargets,
            ReplaceExerciseIntent.allowedExecutionTargets,
            ToggleExerciseFavoriteIntent.allowedExecutionTargets,
            AddHydrationEntryIntent.allowedExecutionTargets,
            AddWeightEntryIntent.allowedExecutionTargets,
            CreateHydrationGoalIntent.allowedExecutionTargets,
            CreateSleepGoalIntent.allowedExecutionTargets,
            CreateStepsGoalIntent.allowedExecutionTargets,
            CreateWeightGoalIntent.allowedExecutionTargets,
            EndTrainingConditionIntent.allowedExecutionTargets,
            StartRestTimerIntent.allowedExecutionTargets,
            PauseRestTimerIntent.allowedExecutionTargets,
            ResumeRestTimerIntent.allowedExecutionTargets,
            StopRestTimerIntent.allowedExecutionTargets,
            RestTimerControlIntent.allowedExecutionTargets,
            StartWorkoutIntent.allowedExecutionTargets,
            CompleteActiveSetIntent.allowedExecutionTargets,
            FinishWorkoutIntent.allowedExecutionTargets,
            CancelWorkoutIntent.allowedExecutionTargets,
            DeleteWorkoutIntent.allowedExecutionTargets,
            DeleteAllWorkoutsIntent.allowedExecutionTargets,
            SaveWorkoutAsPlanIntent.allowedExecutionTargets,
            CreateWorkoutPlanIntent.allowedExecutionTargets,
            StartWorkoutWithPlanIntent.allowedExecutionTargets,
            ToggleWorkoutPlanFavoriteIntent.allowedExecutionTargets,
            DeleteWorkoutPlanIntent.allowedExecutionTargets,
            DeleteAllWorkoutPlansIntent.allowedExecutionTargets,
            StartTodaysWorkoutIntent.allowedExecutionTargets,
        ]

        #expect(targets.allSatisfy { $0 == .main })
    }
}
