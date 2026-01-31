import Foundation

enum ChangeType: String, Codable {
    case increaseWeight
    case decreaseWeight
    case increaseReps
    case decreaseReps
    case increaseRest
    case decreaseRest
    case addSet
    case removeSet
    case changeSetType
}
