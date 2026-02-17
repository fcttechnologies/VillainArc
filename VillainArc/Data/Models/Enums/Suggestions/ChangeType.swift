import Foundation
import FoundationModels

enum ChangePolicy: String, Codable {
    case repRange
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
    case removeSet = "Remove Set"

    // Exercise-level rep range (target exercise, not set)
    case increaseRepRangeLower = "Increase Rep Range Lower"
    case decreaseRepRangeLower = "Decrease Rep Range Lower"
    case increaseRepRangeUpper = "Increase Rep Range Upper"
    case decreaseRepRangeUpper = "Decrease Rep Range Upper"
    case increaseRepRangeTarget = "Increase Rep Range Target"
    case decreaseRepRangeTarget = "Decrease Rep Range Target"
    case changeRepRangeMode = "Change Rep Range Mode"

    var policy: ChangePolicy? {
        switch self {
        case .increaseRepRangeLower, .decreaseRepRangeLower,
             .increaseRepRangeUpper, .decreaseRepRangeUpper,
             .increaseRepRangeTarget, .decreaseRepRangeTarget,
             .changeRepRangeMode:
            return .repRange
        case .removeSet:
            return .structure
        default:
            return nil
        }
    }
}
