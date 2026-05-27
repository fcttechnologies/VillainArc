import Foundation
import FoundationModels

@Generable
struct AIReplacementSuggestionList {
    @Guide(description: "Three to five replacement suggestions, ordered best-fit first.", .count(3...5))
    let suggestions: [AIReplacementSuggestion]
}

@Generable
struct AIReplacementSuggestion {
    @Guide(description: "Common gym name of the suggested replacement. Use familiar names like Dumbbell Bench Press, Cable Lat Pulldown.")
    let exerciseName: String

    @Guide(description: "Equipment used. Helps disambiguate exercises with the same name across barbell, dumbbell, cable, and machine variants.")
    let equipment: EquipmentType

    @Guide(description: "One sentence explaining why this swap works (matching muscles, similar movement pattern, or progression alternative).")
    let reasoning: String
}

/// Resolved suggestion after fuzzy-matching the AI's `exerciseName` to a real catalog item.
struct AIResolvedReplacementSuggestion: Identifiable {
    let id = UUID()
    let catalogID: String
    let exerciseName: String
    let equipment: EquipmentType
    let reasoning: String
}
