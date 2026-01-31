import AppIntents

struct VillainArcShortcuts: AppShortcutsProvider {

    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartWorkoutIntent(),
            phrases: [
                "Start a new workout in \(.applicationName)",
                "Start an empty workout in \(.applicationName)",
                "Begin a workout from scratch in \(.applicationName)",
                "Create a new workout in \(.applicationName)",
                "Start a blank workout with \(.applicationName)",
                "Kick off a new workout with \(.applicationName)"
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
                "Start a workout from the \(\.$workoutPlan) plan in \(.applicationName)",
                "Use the \(\.$workoutPlan) plan with \(.applicationName)",
                "Begin the \(\.$workoutPlan) workout plan in \(.applicationName)",
                "Start a workout plan in \(.applicationName)",
                "Start a workout from a plan in \(.applicationName)"
            ],
            shortTitle: "Start Workout with Plan",
            systemImageName: "list.clipboard"
        )

        AppShortcut(
            intent: StartTodaysWorkoutIntent(),
            phrases: [
                "Start today's workout in \(.applicationName)",
                "Start my workout for today in \(.applicationName)",
                "Begin today's workout in \(.applicationName)",
                "Start my split workout in \(.applicationName)",
                "Start today's split in \(.applicationName)",
                "Do today's split in \(.applicationName)"
            ],
            shortTitle: "Start Today's Workout",
            systemImageName: "figure.strengthtraining.traditional"
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
//            intent: ShowWorkoutPsansListIntent(),
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
                "What did I do in my last workout in \(.applicationName)",
                "Summarize my last workout in \(.applicationName)",
                "Tell me about my last workout in \(.applicationName)",
                "How was my last workout in \(.applicationName)",
                "Recap my last workout in \(.applicationName)"
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
                "Complete workout in \(.applicationName)",
                "End workout in \(.applicationName)",
                "I'm done working out in \(.applicationName)",
                "Done with my workout in \(.applicationName)"
            ],
            shortTitle: "Finish Workout",
            systemImageName: "checkmark.circle"
        )

        AppShortcut(
            intent: CompleteActiveSetIntent(),
            phrases: [
                "Complete active set in \(.applicationName)",
                "Complete next set in \(.applicationName)",
                "Mark next set complete in \(.applicationName)",
                "Log my set in \(.applicationName)",
                "Done with my set in \(.applicationName)",
                "Set complete in \(.applicationName)",
                "Complete set in \(.applicationName)"
            ],
            shortTitle: "Complete Set",
            systemImageName: "checkmark.circle"
        )

        AppShortcut(
            intent: AddExerciseIntent(),
            phrases: [
                "Add \(\.$exercise) in \(.applicationName)",
                "Add \(\.$exercise) to workout in \(.applicationName)",
                "Add \(\.$exercise) to template in \(.applicationName)",
                "Add an exercise in \(.applicationName)",
                "Add exercise in \(.applicationName)"
            ],
            shortTitle: "Add Exercise",
            systemImageName: "dumbbell.fill"
        )

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
                "Begin rest timer in \(.applicationName)",
                "Start resting in \(.applicationName)",
                "Rest for in \(.applicationName)"
            ],
            shortTitle: "Start Timer",
            systemImageName: "timer"
        )

        AppShortcut(
            intent: PauseRestTimerIntent(),
            phrases: [
                "Pause rest timer in \(.applicationName)",
                "Pause my rest timer in \(.applicationName)",
                "Pause timer in \(.applicationName)",
                "Pause my rest in \(.applicationName)"
            ],
            shortTitle: "Pause Timer",
            systemImageName: "pause.circle"
        )

        AppShortcut(
            intent: ResumeRestTimerIntent(),
            phrases: [
                "Resume rest timer in \(.applicationName)",
                "Resume my rest timer in \(.applicationName)",
                "Continue rest timer in \(.applicationName)",
                "Continue my rest in \(.applicationName)"
            ],
            shortTitle: "Resume Timer",
            systemImageName: "play.circle"
        )

//        AppShortcut(
//            intent: StopRestTimerIntent(),
//            phrases: [
//                "Stop rest timer in \(.applicationName)",
//                "Stop my rest timer in \(.applicationName)",
//                "End rest timer in \(.applicationName)",
//                "Skip rest in \(.applicationName)",
//                "Skip my rest in \(.applicationName)",
//                "Skip rest timer in \(.applicationName)",
//                "I'm ready in \(.applicationName)"
//            ],
//            shortTitle: "Stop Timer",
//            systemImageName: "stop.circle"
//        )
    }
}
