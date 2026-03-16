import Foundation

enum DecisionReason: String, Codable {
    case tooAggressive
    case tooConservative
    case wrongDirection
    case alreadyPlanned
    case notNow
    case other
}
