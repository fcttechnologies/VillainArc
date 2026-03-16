import Foundation

enum Outcome: String, Codable {
    case pending
    case good
    case tooAggressive
    case tooEasy
    case insufficient
    case ignored
}
