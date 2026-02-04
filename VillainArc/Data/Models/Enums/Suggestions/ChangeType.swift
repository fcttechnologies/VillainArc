import Foundation

enum ChangePolicy: String, Codable {
    case repRange
    case restTime
}

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
    case increaseRepRangeTarget  // e.g., target 8 → 10 (when mode is .target)
    case decreaseRepRangeTarget  // e.g., target 10 → 8
    case changeRepRangeMode      // e.g., .range → .target (use newValue for mode raw value)
    case changeRestTimeMode
    case increaseRestTimeSeconds // allSameSeconds increase
    case decreaseRestTimeSeconds // allSameSeconds decrease
    
    // Exercise-level (if needed)
    case reorderExercise
    case removeExercise
    case addExercise
    
    /// Returns the policy category for grouping exercise-level changes
    var policy: ChangePolicy? {
        switch self {
        case .increaseRepRangeLower, .decreaseRepRangeLower,
             .increaseRepRangeUpper, .decreaseRepRangeUpper,
             .increaseRepRangeTarget, .decreaseRepRangeTarget,
             .changeRepRangeMode:
            return .repRange
        case .changeRestTimeMode, .increaseRestTimeSeconds, .decreaseRestTimeSeconds:
            return .restTime
        default:
            return nil  // Set-level changes
        }
    }
}
