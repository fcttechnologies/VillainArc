import Foundation

enum Outcome: String, Codable {
    case pending
    case good
    case tooAggressive
    case tooEasy
    case ignored        // User didn't follow during workout
    case userModified   // User changed the prescription after accepting
}
