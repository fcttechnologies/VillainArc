import Foundation
import FoundationModels

enum ChangePolicy: String, Codable {
    case repRange
    case restTime
    case structure
}

@Generable
enum ChangeType: String, Codable {
    // Set-level (target a specific set)
    case increaseWeight = "Increase Weight"
    case decreaseWeight = "Decrease Weight"
    case increaseReps = "Increase Reps"
    case decreaseReps = "Decrease Reps"
    case increaseRest = "Increase Rest"
    case decreaseRest = "Decrease Rest"
    case changeSetType = "Change Set Type"
    
    // Exercise-level structure
    case removeSet = "Remove Set"                             // drop the last set (volume regression)
    
    // Exercise-level rep range (target exercise, not set)
    case increaseRepRangeLower = "Increase Rep Range Lower"   // e.g., 8 → 10
    case decreaseRepRangeLower = "Decrease Rep Range Lower"   // e.g., 8 → 6
    case increaseRepRangeUpper = "Increase Rep Range Upper"   // e.g., 12 → 15
    case decreaseRepRangeUpper = "Decrease Rep Range Upper"   // e.g., 12 → 10
    case increaseRepRangeTarget = "Increase Rep Range Target" // e.g., target 8 → 10 (when mode is .target)
    case decreaseRepRangeTarget = "Decrease Rep Range Target" // e.g., target 10 → 8
    case changeRepRangeMode = "Change Rep Range Mode"         // e.g., .range → .target (use newValue for mode raw value)
    case changeRestTimeMode = "Change Rest Time Mode"
    case increaseRestTimeSeconds = "Increase Rest Time Seconds" // allSameSeconds increase
    case decreaseRestTimeSeconds = "Decrease Rest Time Seconds" // allSameSeconds decrease
    
    // Returns the policy category for grouping exercise-level changes
    var policy: ChangePolicy? {
        switch self {
        case .increaseRepRangeLower, .decreaseRepRangeLower,
             .increaseRepRangeUpper, .decreaseRepRangeUpper,
             .increaseRepRangeTarget, .decreaseRepRangeTarget,
             .changeRepRangeMode:
            return .repRange
        case .changeRestTimeMode, .increaseRestTimeSeconds, .decreaseRestTimeSeconds:
            return .restTime
        case .removeSet:
            return .structure
        default:
            return nil  // Set-level changes
        }
    }
}
