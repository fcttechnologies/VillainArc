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
    
    static func donateLastWorkoutSummary() async {
        _ = try? await LastWorkoutSummaryIntent().donate()
    }
    
    static func donateCreateTemplate() async {
        _ = try? await CreateTemplateIntent().donate()
    }
}
