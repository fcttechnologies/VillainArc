import AppIntents

enum IntentDonations {
    static func donateStartWorkout() async {
        _ = try? await StartWorkoutIntent().donate()
    }
    
    static func donateViewLastWorkout() async {
        _ = try? await ViewLastWorkoutIntent().donate()
    }
    
    static func donateShowWorkoutHistory() async {
        _ = try? await ShowWorkoutHistoryIntent().donate()
    }

    static func donateShowTemplatesList() async {
        _ = try? await ShowTemplatesListIntent().donate()
    }
    
    static func donateLastWorkoutSummary() async {
        _ = try? await LastWorkoutSummaryIntent().donate()
    }
    
    static func donateCreateTemplate() async {
        _ = try? await CreateTemplateIntent().donate()
    }

    static func donateStartLastWorkoutAgain() async {
        _ = try? await StartLastWorkoutAgainIntent().donate()
    }

    static func donateStartWorkoutWithTemplate(template: WorkoutTemplate) async {
        let intent = StartWorkoutWithTemplateIntent()
        intent.template = WorkoutTemplateEntity(template: template)
        _ = try? await intent.donate()
    }
}
