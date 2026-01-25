import AppIntents

struct VillainArcShortcuts: AppShortcutsProvider {

    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartWorkoutIntent(),
            phrases: [
                "Start a new workout in \(.applicationName)",
                "Start an empty workout in \(.applicationName)",
                "Begin a new workout with \(.applicationName)",
                "New workout in \(.applicationName)"
            ],
            shortTitle: "New Workout",
            systemImageName: "figure.strengthtraining.traditional"
        )

        AppShortcut(
            intent: StartWorkoutWithTemplateIntent(),
            phrases: [
                "Start \(\.$template) in \(.applicationName)",
                "Start \(\.$template) workout in \(.applicationName)",
                "Begin \(\.$template) with \(.applicationName)",
                "Start template \(\.$template) in \(.applicationName)"
            ],
            shortTitle: "Start Template",
            systemImageName: "list.clipboard"
        )

        AppShortcut(
            intent: StartLastWorkoutAgainIntent(),
            phrases: [
                "Repeat last workout in \(.applicationName)",
                "Start last workout again in \(.applicationName)",
                "Do last workout in \(.applicationName)"
            ],
            shortTitle: "Repeat Last Workout",
            systemImageName: "arrow.triangle.2.circlepath"
        )

        AppShortcut(
            intent: ResumeActiveSessionIntent(),
            phrases: [
                "Resume workout in \(.applicationName)",
                "Continue workout in \(.applicationName)",
                "Resume session in \(.applicationName)",
                "Continue session in \(.applicationName)"
            ],
            shortTitle: "Resume Session",
            systemImageName: "play.circle"
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
            intent: ShowTemplatesListIntent(),
            phrases: [
                "Show templates in \(.applicationName)",
                "Open templates in \(.applicationName)",
                "View templates in \(.applicationName)"
            ],
            shortTitle: "Templates",
            systemImageName: "list.clipboard"
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
