import Foundation

enum WeightGoalType: String, Codable, CaseIterable {
    case cut
    case bulk
    case maintain
}

extension WeightGoalType {
    var title: String {
        switch self {
        case .cut:
            return "Cut"
        case .bulk:
            return "Bulk"
        case .maintain:
            return "Maintain"
        }
    }
}
