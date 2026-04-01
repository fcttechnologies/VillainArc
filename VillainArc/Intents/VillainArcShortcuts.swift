import AppIntents

struct VillainArcShortcuts: AppShortcutsProvider {

    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartTodaysWorkoutIntent(), phrases: [
                "Start today's workout in \(.applicationName)",
                "Start my workout for today in \(.applicationName)",
                "Begin today's workout in \(.applicationName)",
                "Start my split workout in \(.applicationName)",
                "Start today's split in \(.applicationName)",
                "Do today's workout in \(.applicationName)",
                "Do today's split in \(.applicationName)",
                "Let's do today's workout in \(.applicationName)",
                "Time to train in \(.applicationName)",
                "What's today's workout in \(.applicationName)"
            ], shortTitle: "Start Today's Workout", systemImageName: "figure.strengthtraining.traditional")

        AppShortcut(intent: TrainingSummaryIntent(), phrases: [
                "What am I training \(\.$day) in \(.applicationName)",
                "What am I training on \(\.$day) in \(.applicationName)",
                "What am I hitting \(\.$day) in \(.applicationName)",
                "What am I hitting on \(\.$day) in \(.applicationName)",
                "What's my workout \(\.$day) in \(.applicationName)",
                "What's my workout on \(\.$day) in \(.applicationName)",
                "What do I train \(\.$day) in \(.applicationName)",
                "What do I train on \(\.$day) in \(.applicationName)",
                "What am I working out \(\.$day) in \(.applicationName)",
                "What's my split \(\.$day) in \(.applicationName)"
            ], shortTitle: "Training Summary", systemImageName: "calendar")
        
        AppShortcut(intent: CompleteActiveSetIntent(), phrases: [
                "Complete my set in \(.applicationName)",
                "Complete the set in \(.applicationName)",
                "Complete current set in \(.applicationName)",
                "Done with my set in \(.applicationName)",
                "Finished my set in \(.applicationName)",
                "Mark my set complete in \(.applicationName)",
                "Mark set as done in \(.applicationName)",
                "Log my set in \(.applicationName)",
                "I finished my set in \(.applicationName)",
                "My set is done in \(.applicationName)"
            ], shortTitle: "Complete Set", systemImageName: "checkmark.circle")

        AppShortcut(intent: AddExerciseIntent(), phrases: [
                "Add \(\.$exercise) in \(.applicationName)",
                "Add \(\.$exercise) to my workout in \(.applicationName)",
                "Add \(\.$exercise) to workout in \(.applicationName)",
                "Add \(\.$exercise) to my plan in \(.applicationName)",
                "Add \(\.$exercise) to template in \(.applicationName)",
                "Add an exercise in \(.applicationName)",
                "Add exercise in \(.applicationName)",
                "Add exercise to my workout in \(.applicationName)",
                "Add an exercise to my plan in \(.applicationName)",
                "Include \(\.$exercise) in \(.applicationName)"
            ], shortTitle: "Add Exercise", systemImageName: "dumbbell.fill")

        AppShortcut(intent: StartRestTimerIntent(), phrases: [
                "Start rest timer in \(.applicationName)",
                "Start a rest timer in \(.applicationName)",
                "Start my rest in \(.applicationName)",
                "Start resting in \(.applicationName)",
                "Begin rest timer in \(.applicationName)",
                "Rest in \(.applicationName)",
                "Time to rest in \(.applicationName)",
                "Start my rest timer in \(.applicationName)",
                "Take a rest in \(.applicationName)",
                "Begin resting in \(.applicationName)"
            ], shortTitle: "Start Timer", systemImageName: "timer")

        AppShortcut(intent: GetHealthDaySummaryIntent(), phrases: [
                "Give me today's health summary in \(.applicationName)",
                "Show me today's health summary in \(.applicationName)",
                "How am I doing today in \(.applicationName)",
                "Summarize today in \(.applicationName)",
                "Give me today's health summary in \(.applicationName)"
            ], shortTitle: "Today's Summary", systemImageName: "heart.text.square")

        AppShortcut(intent: GetSleepIntent(), phrases: [
                "How much did I sleep last night in \(.applicationName)",
                "Show my last night's sleep in \(.applicationName)",
                "Tell me my last night's sleep in \(.applicationName)",
                "What was my sleep last night in \(.applicationName)",
                "Get last night's sleep in \(.applicationName)"
            ], shortTitle: "Last Night's Sleep", systemImageName: "bed.double.fill")

        AppShortcut(intent: GetStepsIntent(), phrases: [
                "How many steps did I take today in \(.applicationName)",
                "Show me today's steps in \(.applicationName)",
                "Tell me my steps today in \(.applicationName)",
                "What are my steps today in \(.applicationName)",
                "Get today's steps in \(.applicationName)"
            ], shortTitle: "Today's Steps", systemImageName: "figure.walk")

        AppShortcut(intent: GetCaloriesBurnedIntent(), phrases: [
                "How many calories did I burn today in \(.applicationName)",
                "Show me today's calories burned in \(.applicationName)",
                "Tell me my calories burned today in \(.applicationName)",
                "What are my calories burned today in \(.applicationName)",
                "Get today's calories burned in \(.applicationName)"
            ], shortTitle: "Today's Calories", systemImageName: "flame.fill")

        AppShortcut(intent: StopRestTimerIntent(), phrases: [
                "Stop rest timer in \(.applicationName)",
                "Stop my rest timer in \(.applicationName)",
                "Stop resting in \(.applicationName)",
                "End rest timer in \(.applicationName)",
                "End my rest in \(.applicationName)",
                "Skip rest in \(.applicationName)",
                "Skip my rest in \(.applicationName)",
                "Done resting in \(.applicationName)",
                "I'm ready in \(.applicationName)",
                "I'm done resting in \(.applicationName)"
            ], shortTitle: "Stop Timer", systemImageName: "stop.circle")

    }
}

//        AppShortcut(intent: StartWorkoutIntent(), phrases: [
//                "Start a workout in \(.applicationName)",
//                "Start a new workout in \(.applicationName)",
//                "Start an empty workout in \(.applicationName)",
//                "Begin a workout in \(.applicationName)",
//                "Begin a new workout in \(.applicationName)",
//                "Create a new workout in \(.applicationName)",
//                "Start working out in \(.applicationName)",
//                "Let's work out in \(.applicationName)",
//                "Time to work out in \(.applicationName)",
//                "New workout in \(.applicationName)"
//            ], shortTitle: "Start Workout", systemImageName: "figure.strengthtraining.traditional")
//
//        AppShortcut(intent: LastWorkoutSummaryIntent(), phrases: [
//                "What did I do last workout in \(.applicationName)",
//                "What did I do in my last workout in \(.applicationName)",
//                "What was my last workout in \(.applicationName)",
//                "Summarize my last workout in \(.applicationName)",
//                "Tell me about my last workout in \(.applicationName)",
//                "How was my last workout in \(.applicationName)",
//                "Recap my last workout in \(.applicationName)",
//                "Last workout summary in \(.applicationName)",
//                "Show my last workout in \(.applicationName)",
//                "What did I train last in \(.applicationName)"
//            ], shortTitle: "Last Workout Summary", systemImageName: "note.text")
//
//        AppShortcut(intent: StartWorkoutWithPlanIntent(), phrases: [
//                "Start \(\.$workoutPlan) in \(.applicationName)",
//                "Start \(\.$workoutPlan) with \(.applicationName)",
//                "Start the \(\.$workoutPlan) in \(.applicationName)",
//                "Start the \(\.$workoutPlan) plan in \(.applicationName)",
//                "Do \(\.$workoutPlan) in \(.applicationName)",
//                "Do the \(\.$workoutPlan) plan in \(.applicationName)",
//                "Begin \(\.$workoutPlan) in \(.applicationName)",
//                "Start a workout from \(\.$workoutPlan) in \(.applicationName)",
//                "Start a workout plan in \(.applicationName)",
//                "Start a workout from a plan in \(.applicationName)"
//            ], shortTitle: "Start Workout with Plan", systemImageName: "list.clipboard")
//
//        AppShortcut(intent: FinishWorkoutIntent(), phrases: [
//                "Finish workout in \(.applicationName)",
//                "Finish my workout in \(.applicationName)",
//                "Complete workout in \(.applicationName)",
//                "Complete my workout in \(.applicationName)",
//                "End workout in \(.applicationName)",
//                "End my workout in \(.applicationName)",
//                "Save my workout in \(.applicationName)",
//                "I'm done working out in \(.applicationName)",
//                "Done with my workout in \(.applicationName)",
//                "Wrap up my workout in \(.applicationName)"
//            ], shortTitle: "Finish Workout", systemImageName: "checkmark.circle")
//
//        AppShortcut(intent: ShowWeightHistoryIntent(), phrases: [
//                "Show my weight history in \(.applicationName)",
//                "Open weight history in \(.applicationName)",
//                "View my weight history in \(.applicationName)",
//                "Show my weight progress in \(.applicationName)",
//                "Open my weight in \(.applicationName)"
//            ], shortTitle: "Weight History", systemImageName: "scalemass.fill")
//
//        AppShortcut(intent: ShowAllWeightEntriesIntent(), phrases: [
//                "Show all weight entries in \(.applicationName)",
//                "Open all weight entries in \(.applicationName)",
//                "View all my weigh ins in \(.applicationName)",
//                "Show my weigh ins in \(.applicationName)",
//                "Open my weight log in \(.applicationName)"
//            ], shortTitle: "All Weight Entries", systemImageName: "list.bullet")
//
//        AppShortcut(intent: ShowWeightGoalHistoryIntent(), phrases: [
//                "Show my weight goal history in \(.applicationName)",
//                "Open weight goals in \(.applicationName)",
//                "View my weight goals in \(.applicationName)",
//                "Show my goal history in \(.applicationName)",
//                "Open my weight goal history in \(.applicationName)"
//            ], shortTitle: "Weight Goals", systemImageName: "target")
//
//        AppShortcut(intent: ShowStepsHistoryIntent(), phrases: [
//                "Show my steps history in \(.applicationName)",
//                "Open steps history in \(.applicationName)",
//                "View my walking history in \(.applicationName)",
//                "Show my steps and distance in \(.applicationName)",
//                "Open my steps in \(.applicationName)"
//            ], shortTitle: "Steps History", systemImageName: "figure.walk")
//
//        AppShortcut(intent: ShowStepsGoalHistoryIntent(), phrases: [
//                "Show my steps goal history in \(.applicationName)",
//                "Open steps goals in \(.applicationName)",
//                "View my steps goals in \(.applicationName)",
//                "Show my step goals in \(.applicationName)",
//                "Open my steps goal history in \(.applicationName)"
//            ], shortTitle: "Steps Goals", systemImageName: "target")
//
//        AppShortcut(intent: ShowSleepHistoryIntent(), phrases: [
//                "Show my sleep history in \(.applicationName)",
//                "Open sleep history in \(.applicationName)",
//                "View my sleep in \(.applicationName)",
//                "Show my sleep progress in \(.applicationName)",
//                "Open my sleep in \(.applicationName)"
//            ], shortTitle: "Sleep History", systemImageName: "bed.double.fill")
//
//        AppShortcut(intent: ShowCaloriesBurnedHistoryIntent(), phrases: [
//                "Show my calories burned history in \(.applicationName)",
//                "Open calories burned history in \(.applicationName)",
//                "View my energy history in \(.applicationName)",
//                "Show my calories burned in \(.applicationName)",
//                "Open my energy in \(.applicationName)"
//            ], shortTitle: "Calories Burned", systemImageName: "flame.fill")
//
//        AppShortcut(intent: GetHealthDaySummaryIntent(), phrases: [
//                "Give me my health summary in \(.applicationName)",
//                "Show my health summary in \(.applicationName)",
//                "How am I doing today in \(.applicationName)",
//                "Summarize my health in \(.applicationName)",
//                "Give me today's health summary in \(.applicationName)"
//            ], shortTitle: "Health Summary", systemImageName: "heart.text.square")
//
//        AppShortcut(intent: GetHealthMetricIntent(), phrases: [
//                "Get \(\.$metric) in \(.applicationName)",
//                "Show my \(\.$metric) in \(.applicationName)",
//                "What is my \(\.$metric) in \(.applicationName)",
//                "Tell me my \(\.$metric) in \(.applicationName)",
//                "How much \(\.$metric) do I have in \(.applicationName)"
//            ], shortTitle: "Today's Metric", systemImageName: "chart.bar")
//
//        AppShortcut(intent: GetHealthDaySummaryForDayIntent(), phrases: [
//                "Summarize my health for \(\.$date) in \(.applicationName)",
//                "Give me my health summary for \(\.$date) in \(.applicationName)",
//                "Show my health summary for \(\.$date) in \(.applicationName)",
//                "How was my health on \(\.$date) in \(.applicationName)",
//                "Tell me my health summary for \(\.$date) in \(.applicationName)"
//            ], shortTitle: "Health Summary For Day", systemImageName: "heart.text.square")
//
//        AppShortcut(intent: GetHealthMetricForDayIntent(), phrases: [
//                "Get \(\.$metric) for \(\.$date) in \(.applicationName)",
//                "How much \(\.$metric) did I have on \(\.$date) in \(.applicationName)",
//                "Show my \(\.$metric) for \(\.$date) in \(.applicationName)",
//                "What was my \(\.$metric) on \(\.$date) in \(.applicationName)",
//                "Tell me my \(\.$metric) for \(\.$date) in \(.applicationName)"
//            ], shortTitle: "Metric For Day", systemImageName: "chart.bar")
//
//        AppShortcut(intent: GetWeightIntent(), phrases: [
//                "What did I weigh today in \(.applicationName)",
//                "What is my weight in \(.applicationName)",
//                "Show my weight in \(.applicationName)",
//                "How much did I weigh in \(.applicationName)",
//                "Tell me my weight in \(.applicationName)"
//            ], shortTitle: "Get Weight", systemImageName: "scalemass.fill")
//
//        AppShortcut(intent: GetSleepIntent(), phrases: [
//                "How much did I sleep today in \(.applicationName)",
//                "How much did I sleep in \(.applicationName)",
//                "Show my sleep in \(.applicationName)",
//                "Tell me my sleep in \(.applicationName)",
//                "What was my sleep in \(.applicationName)"
//            ], shortTitle: "Get Sleep", systemImageName: "bed.double.fill")
//
//        AppShortcut(intent: GetStepsIntent(), phrases: [
//                "How many steps did I take today in \(.applicationName)",
//                "How many steps did I take in \(.applicationName)",
//                "Show my steps in \(.applicationName)",
//                "Tell me my steps in \(.applicationName)",
//                "What were my steps in \(.applicationName)"
//            ], shortTitle: "Get Steps", systemImageName: "figure.walk")
//
//        AppShortcut(intent: GetDistanceIntent(), phrases: [
//                "How far did I walk today in \(.applicationName)",
//                "How far did I walk in \(.applicationName)",
//                "Show my distance in \(.applicationName)",
//                "Tell me my distance in \(.applicationName)",
//                "What was my distance in \(.applicationName)"
//            ], shortTitle: "Get Distance", systemImageName: "figure.walk.motion")
//
//        AppShortcut(intent: GetCaloriesBurnedIntent(), phrases: [
//                "How many calories did I burn today in \(.applicationName)",
//                "How many calories did I burn in \(.applicationName)",
//                "Show my calories burned in \(.applicationName)",
//                "Tell me my calories burned in \(.applicationName)",
//                "What were my calories burned in \(.applicationName)"
//            ], shortTitle: "Get Calories", systemImageName: "flame.fill")
//
//        AppShortcut(intent: GetLatestWeightIntent(), phrases: [
//                "What is my latest weight in \(.applicationName)",
//                "What was my latest weight in \(.applicationName)",
//                "Show my latest weight in \(.applicationName)",
//                "Tell me my latest weight in \(.applicationName)",
//                "What did I weigh most recently in \(.applicationName)"
//            ], shortTitle: "Latest Weight", systemImageName: "scalemass.fill")
//
//        AppShortcut(intent: AddWeightEntryIntent(), phrases: [
//                "Log \(\.$weight) in \(.applicationName)",
//                "Add \(\.$weight) to my weight in \(.applicationName)",
//                "Record \(\.$weight) in \(.applicationName)",
//                "Log my weight in \(.applicationName)",
//                "Add a weight entry in \(.applicationName)"
//            ], shortTitle: "Add Weight", systemImageName: "plus.circle")
//
//        AppShortcut(intent: CreateStepsGoalIntent(), phrases: [
//                "Set my steps goal to \(\.$targetSteps) in \(.applicationName)",
//                "Make my steps goal \(\.$targetSteps) in \(.applicationName)",
//                "Create a steps goal in \(.applicationName)",
//                "Set a steps goal in \(.applicationName)",
//                "Update my steps goal in \(.applicationName)"
//            ], shortTitle: "Set Steps Goal", systemImageName: "target")
//
//        AppShortcut(intent: EndTrainingConditionIntent(), phrases: [
//                "End my training condition in \(.applicationName)",
//                "Clear my training condition in \(.applicationName)",
//                "I'm training normally again in \(.applicationName)",
//                "Return me to normal training in \(.applicationName)",
//                "End my injury status in \(.applicationName)"
//            ], shortTitle: "End Condition", systemImageName: "figure.run")
//
//        AppShortcut(intent: GetTrainingConditionIntent(), phrases: [
//                "What is my training condition in \(.applicationName)",
//                "How is my training status in \(.applicationName)",
//                "Am I injured in \(.applicationName)",
//                "Show my training condition in \(.applicationName)",
//                "Tell me my training condition in \(.applicationName)"
//            ], shortTitle: "Training Condition", systemImageName: "figure.run")
//
//        AppShortcut(intent: GetStepsGoalStatusIntent(), phrases: [
//                "How is my steps goal going in \(.applicationName)",
//                "What is my steps goal status in \(.applicationName)",
//                "How am I doing on my steps goal in \(.applicationName)",
//                "Show my steps goal status in \(.applicationName)",
//                "Tell me my steps goal status in \(.applicationName)"
//            ], shortTitle: "Steps Goal Status", systemImageName: "target")
//
//        AppShortcut(intent: GetWeightGoalStatusIntent(), phrases: [
//                "How is my weight goal going in \(.applicationName)",
//                "What is my weight goal status in \(.applicationName)",
//                "How am I doing on my weight goal in \(.applicationName)",
//                "Show my weight goal status in \(.applicationName)",
//                "Tell me my weight goal status in \(.applicationName)"
//            ], shortTitle: "Weight Goal Status", systemImageName: "target")
//
//        AppShortcut(intent: GetActiveCaloriesIntent(), phrases: [
//                "How many active calories have I burned in \(.applicationName)",
//                "Show my active calories in \(.applicationName)",
//                "Tell me my active calories in \(.applicationName)",
//                "What are my active calories in \(.applicationName)",
//                "How many active calories today in \(.applicationName)"
//            ], shortTitle: "Active Calories", systemImageName: "flame")
//
//        AppShortcut(intent: GetRestingCaloriesIntent(), phrases: [
//                "How many resting calories have I burned in \(.applicationName)",
//                "Show my resting calories in \(.applicationName)",
//                "Tell me my resting calories in \(.applicationName)",
//                "What are my resting calories in \(.applicationName)",
//                "How many resting calories today in \(.applicationName)"
//            ], shortTitle: "Resting Calories", systemImageName: "flame")
//
//        AppShortcut(intent: OpenTrainingConditionHistoryIntent(), phrases: [
//                "Open training condition history in \(.applicationName)",
//                "Show my training condition history in \(.applicationName)",
//                "View my training condition history in \(.applicationName)",
//                "Open condition history in \(.applicationName)",
//                "Show my condition history in \(.applicationName)"
//            ], shortTitle: "Condition History", systemImageName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
//
//        AppShortcut(intent: UpdateTrainingConditionIntent(), phrases: [
//                "Update my training condition in \(.applicationName)",
//                "Edit my training condition in \(.applicationName)",
//                "Change my training condition in \(.applicationName)",
//                "Open training condition editor in \(.applicationName)",
//                "Update my condition in \(.applicationName)"
//            ], shortTitle: "Update Condition", systemImageName: "square.and.pencil")

//AppShortcut(intent: OpenExerciseIntent(), phrases: [
//        "Open \(\.$exercise) in \(.applicationName)",
//        "Show \(\.$exercise) in \(.applicationName)",
//        "View \(\.$exercise) in \(.applicationName)",
//        "Show history for \(\.$exercise) in \(.applicationName)",
//        "Open history for \(\.$exercise) in \(.applicationName)",
//        "Show progress for \(\.$exercise) in \(.applicationName)",
//        "Open progress for \(\.$exercise) in \(.applicationName)",
//        "Show exercise details for \(\.$exercise) in \(.applicationName)",
//        "View exercise history in \(.applicationName)",
//        "Open an exercise in \(.applicationName)"
//    ], shortTitle: "Open Exercise", systemImageName: "chart.line.uptrend.xyaxis")
//        AppShortcut(
//            intent: CreateWorkoutPlanIntent(),
//            phrases: [
//                "Create workout plan in \(.applicationName)",
//                "Create plan in \(.applicationName)",
//                "Begin creating a workout plan with \(.applicationName)",
//                "Begin creating a plan in \(.applicationName)"
//            ],
//            shortTitle: "Create New Workout Plan",
//            systemImageName: "list.clipboard"
//        )
//        AppShortcut(
//            intent: AddExercisesIntent(),
//            phrases: [
//                "Add \(\.$exercises) in \(.applicationName)",
//                "Add exercises to workout in \(.applicationName)",
//                "Add exercises to template in \(.applicationName)"
//            ],
//            shortTitle: "Add Exercises",
//            systemImageName: "dumbbell.fill"
//        )

//        AppShortcut(
//            intent: CancelWorkoutIntent(),
//            phrases: [
//                "Cancel workout in \(.applicationName)",
//                "Discard workout in \(.applicationName)",
//                "Delete current workout in \(.applicationName)"
//            ],
//            shortTitle: "Cancel Workout",
//            systemImageName: "xmark.circle"
//        )
//        AppShortcut(
//            intent: PauseRestTimerIntent(),
//            phrases: [
//                "Pause rest timer in \(.applicationName)",
//                "Pause my rest timer in \(.applicationName)",
//                "Pause timer in \(.applicationName)",
//                "Pause my rest in \(.applicationName)"
//            ],
//            shortTitle: "Pause Timer",
//            systemImageName: "pause.circle"
//        )
//
//        AppShortcut(
//            intent: ResumeRestTimerIntent(),
//            phrases: [
//                "Resume rest timer in \(.applicationName)",
//                "Resume my rest timer in \(.applicationName)",
//                "Continue rest timer in \(.applicationName)",
//                "Continue my rest in \(.applicationName)"
//            ],
//            shortTitle: "Resume Timer",
//            systemImageName: "play.circle"
//        )

//        AppShortcut(
//            intent: OpenWorkoutPlanIntent(),
//            phrases: [
//                "Open \(\.$workoutPlan) in \(.applicationName)",
//                "View \(\.$workoutPlan) in \(.applicationName)",
//                "Show \(\.$workoutPlan) in \(.applicationName)"
//            ],
//            shortTitle: "Open Workout Plan",
//            systemImageName: "list.clipboard"
//        )
//        AppShortcut(
//            intent: ViewLastWorkoutIntent(),
//            phrases: [
//                "Show my last workout in \(.applicationName)",
//                "View last workout in \(.applicationName)",
//                "What was my last workout in \(.applicationName)"
//            ],
//            shortTitle: "View My Last Workout",
//            systemImageName: "clock.arrow.circlepath"
//        )

//        AppShortcut(
//            intent: OpenWorkoutIntent(),
//            phrases: [
//                "Open \(\.$workout) in \(.applicationName)",
//                "View \(\.$workout) in \(.applicationName)",
//                "Show \(\.$workout) in \(.applicationName)"
//            ],
//            shortTitle: "Open Workout",
//            systemImageName: "clock.arrow.circlepath"
//        )
        
//        AppShortcut(
//            intent: ShowWorkoutHistoryIntent(),
//            phrases: [
//                "Show my workout history in \(.applicationName)",
//                "Show my workouts in \(.applicationName)",
//                "Open workout history in \(.applicationName)"
//            ],
//            shortTitle: "Workout History",
//            systemImageName: "list.bullet.clipboard"
//        )

//        AppShortcut(
//            intent: ShowWorkoutPlansIntent(),
//            phrases: [
//                "Show workout plans in \(.applicationName)",
//                "Open workout plans in \(.applicationName)",
//                "View workout plans in \(.applicationName)"
//            ],
//            shortTitle: "Workout Plans",
//            systemImageName: "list.clipboard"
//        )
