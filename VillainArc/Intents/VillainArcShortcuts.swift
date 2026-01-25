import AppIntents

struct VillainArcShortcuts: AppShortcutsProvider {

    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartWorkoutIntent(),
            phrases: [
                "Start workout in \(.applicationName)",
                "Resume workout in \(.applicationName)",
                "Begin workout with \(.applicationName)",
                "Start my workout in \(.applicationName)"
            ],
            shortTitle: "Start Workout",
            systemImageName: "figure.strengthtraining.traditional"
        )
        
        AppShortcut(
            intent: ViewLastWorkoutIntent(),
            phrases: [
                "Show my last workout in \(.applicationName)",
                "View last workout in \(.applicationName)",
                "What was my last workout in \(.applicationName)"
            ],
            shortTitle: "View Last Workout",
            systemImageName: "clock.arrow.circlepath"
        )
        
        AppShortcut(
            intent: ShowWorkoutHistoryIntent(),
            phrases: [
                "Show my workout history in \(.applicationName)",
                "Show my workouts in \(.applicationName)",
                "Open workout history in \(.applicationName)"
            ],
            shortTitle: "Workout History",
            systemImageName: "list.bullet.clipboard"
        )
        
        AppShortcut(
            intent: LastWorkoutSummaryIntent(),
            phrases: [
                "What did I do in my last workout in \(.applicationName)",
                "Summarize my last workout in \(.applicationName)",
                "Tell me about my last workout in \(.applicationName)"
            ],
            shortTitle: "Last Workout Summary",
            systemImageName: "questionmark.bubble"
        )
        
        AppShortcut(
            intent: CreateTemplateIntent(),
            phrases: [
                "Create workout template in \(.applicationName)",
                "Create template in \(.applicationName)",
                "Begin creating a template with \(.applicationName)",
                "Begin creating a workout template in \(.applicationName)"
            ],
            shortTitle: "Create Template",
            systemImageName: "list.clipboard"
        )
    }
}
