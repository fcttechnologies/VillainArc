import AppIntents

struct VillainArcShortcuts: AppShortcutsProvider {

    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartWorkoutIntent(),
            phrases: [
                "Start a workout in \(.applicationName)",
                "Start a new workout in \(.applicationName)",
                "Start an empty workout in \(.applicationName)",
                "Begin a workout in \(.applicationName)",
                "Begin a new workout in \(.applicationName)",
                "Create a new workout in \(.applicationName)",
                "Start working out in \(.applicationName)",
                "Let's work out in \(.applicationName)",
                "Time to work out in \(.applicationName)",
                "New workout in \(.applicationName)"
            ],
            shortTitle: "Start Workout",
            systemImageName: "figure.strengthtraining.traditional"
        )

        AppShortcut(
            intent: StartWorkoutWithPlanIntent(),
            phrases: [
                "Start \(\.$workoutPlan) in \(.applicationName)",
                "Start \(\.$workoutPlan) with \(.applicationName)",
                "Start the \(\.$workoutPlan) in \(.applicationName)",
                "Start the \(\.$workoutPlan) plan in \(.applicationName)",
                "Do \(\.$workoutPlan) in \(.applicationName)",
                "Do the \(\.$workoutPlan) plan in \(.applicationName)",
                "Begin \(\.$workoutPlan) in \(.applicationName)",
                "Start a workout from \(\.$workoutPlan) in \(.applicationName)",
                "Start a workout plan in \(.applicationName)",
                "Start a workout from a plan in \(.applicationName)"
            ],
            shortTitle: "Start Workout with Plan",
            systemImageName: "list.clipboard"
        )
        
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

        AppShortcut(
            intent: StartTodaysWorkoutIntent(),
            phrases: [
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
            ],
            shortTitle: "Start Today's Workout",
            systemImageName: "figure.strengthtraining.traditional"
        )

        AppShortcut(
            intent: TrainingSummaryIntent(),
            phrases: [
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
            ],
            shortTitle: "Training Summary",
            systemImageName: "calendar"
        )
        
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
        
        AppShortcut(
            intent: LastWorkoutSummaryIntent(),
            phrases: [
                "What did I do last workout in \(.applicationName)",
                "What did I do in my last workout in \(.applicationName)",
                "What was my last workout in \(.applicationName)",
                "Summarize my last workout in \(.applicationName)",
                "Tell me about my last workout in \(.applicationName)",
                "How was my last workout in \(.applicationName)",
                "Recap my last workout in \(.applicationName)",
                "Last workout summary in \(.applicationName)",
                "Show my last workout in \(.applicationName)",
                "What did I train last in \(.applicationName)"
            ],
            shortTitle: "Last Workout Summary",
            systemImageName: "note.text"
        )
        
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
        
        AppShortcut(
            intent: FinishWorkoutIntent(),
            phrases: [
                "Finish workout in \(.applicationName)",
                "Finish my workout in \(.applicationName)",
                "Complete workout in \(.applicationName)",
                "Complete my workout in \(.applicationName)",
                "End workout in \(.applicationName)",
                "End my workout in \(.applicationName)",
                "Save my workout in \(.applicationName)",
                "I'm done working out in \(.applicationName)",
                "Done with my workout in \(.applicationName)",
                "Wrap up my workout in \(.applicationName)"
            ],
            shortTitle: "Finish Workout",
            systemImageName: "checkmark.circle"
        )

        AppShortcut(
            intent: CompleteActiveSetIntent(),
            phrases: [
                "Complete set in \(.applicationName)",
                "Complete my set in \(.applicationName)",
                "Done with my set in \(.applicationName)",
                "Set done in \(.applicationName)",
                "Set complete in \(.applicationName)",
                "Finished my set in \(.applicationName)",
                "Log my set in \(.applicationName)",
                "Mark set complete in \(.applicationName)",
                "Next set in \(.applicationName)",
                "Complete next set in \(.applicationName)"
            ],
            shortTitle: "Complete Set",
            systemImageName: "checkmark.circle"
        )

        AppShortcut(
            intent: AddExerciseIntent(),
            phrases: [
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
            ],
            shortTitle: "Add Exercise",
            systemImageName: "dumbbell.fill"
        )

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

        AppShortcut(
            intent: StartRestTimerIntent(),
            phrases: [
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
            ],
            shortTitle: "Start Timer",
            systemImageName: "timer"
        )

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

        AppShortcut(
            intent: StopRestTimerIntent(),
            phrases: [
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
            ],
            shortTitle: "Stop Timer",
            systemImageName: "stop.circle"
        )

    }
}
