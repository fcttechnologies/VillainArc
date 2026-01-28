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
            intent: StartWorkoutWithTemplateIntent(),
            phrases: [
                "Start \(\.$template) in \(.applicationName)",
                "Start \(\.$template) with \(.applicationName)",
                "Start the \(\.$template) workout in \(.applicationName)",
                "Start the \(\.$template) template in \(.applicationName)",
                "Start a workout from the \(\.$template) template in \(.applicationName)",
                "Use the \(\.$template) template with \(.applicationName)",
                "Begin the \(\.$template) template workout in \(.applicationName)",
                "Start a template workout in \(.applicationName)",
                "Start a workout from a template in \(.applicationName)"
            ],
            shortTitle: "Start Workout with Template",
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
//            intent: StartLastWorkoutAgainIntent(),
//            phrases: [
//                "Repeat last workout in \(.applicationName)",
//                "Start last workout again in \(.applicationName)",
//                "Do last workout in \(.applicationName)"
//            ],
//            shortTitle: "Repeat Last Workout",
//            systemImageName: "arrow.triangle.2.circlepath"
//        )

        AppShortcut(
            intent: ResumeActiveSessionIntent(),
            phrases: [
                "Resume workout in \(.applicationName)",
                "Continue workout in \(.applicationName)",
                "Resume session in \(.applicationName)",
                "Continue session in \(.applicationName)",
                "Go back to my workout in \(.applicationName)",
                "Open my workout in \(.applicationName)"
            ],
            shortTitle: "Resume Session",
            systemImageName: "play.circle"
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
//            intent: ShowTemplatesListIntent(),
//            phrases: [
//                "Show templates in \(.applicationName)",
//                "Open templates in \(.applicationName)",
//                "View templates in \(.applicationName)"
//            ],
//            shortTitle: "Templates",
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
            systemImageName: "questionmark.bubble"
        )
        
//        AppShortcut(
//            intent: CreateTemplateIntent(),
//            phrases: [
//                "Create workout template in \(.applicationName)",
//                "Create template in \(.applicationName)",
//                "Begin creating a template with \(.applicationName)",
//                "Begin creating a workout template in \(.applicationName)"
//            ],
//            shortTitle: "Create New Template",
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
            systemImageName: "checkmark.circle.badge.questionmark"
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
            systemImageName: "plus.circle"
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
//
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
