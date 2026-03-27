import Foundation

enum WeightGoalEndReason: String, Codable {
    case achieved
    case manualOverride
    case replaced
}
