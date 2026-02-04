import Foundation

enum ChangeType: String, Codable {
    // Set-level (target a specific set)
    case increaseWeight
    case decreaseWeight
    case increaseReps
    case decreaseReps
    case increaseRest
    case decreaseRest
    case addSet
    case removeSet
    case changeSetType
    
    // Exercise-level rep range (target exercise, not set)
    case increaseRepRangeLower   // e.g., 8 → 10
    case decreaseRepRangeLower   // e.g., 8 → 6
    case increaseRepRangeUpper   // e.g., 12 → 15
    case decreaseRepRangeUpper   // e.g., 12 → 10
    case changeRepRangeMode      // e.g., .range → .target (use newValue for mode raw value)
    case changeRestTimeMode
    
    // Exercise-level (if needed)
    case reorderExercise
    case removeExercise
    case addExercise
}
