import Foundation
import FoundationModels

@Generable
enum AIProgressionTrend: String {
    case improving = "Improving"
    case stable = "Stable"
    case mixed = "Mixed"
    case stalling = "Stalling"
    case unclear = "Unclear"
}

@Generable
struct AIExerciseProgressionInsight {
    @Guide(description: "Short high-level summary of how the exercise is trending.")
    let summary: String
    @Guide(description: "Overall trend label for the recent exercise progression.")
    let trend: AIProgressionTrend
    @Guide(description: "Specific positive takeaways from recent sessions.")
    let positives: [String]
    @Guide(description: "Specific concerns or limitations in the recent data.")
    let concerns: [String]
    @Guide(description: "One practical next step for the user.")
    let nextStep: String
    @Guide(description: "Confidence from 0.0 to 1.0.")
    let confidence: Double
    @Guide(description: "Short suggested follow-up questions the user may want to ask next.")
    let followUpSuggestions: [String]
}
