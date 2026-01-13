import SwiftUI

enum ExerciseSetType: String, Codable, CaseIterable {
    case warmup = "Warm Up Set"
    case regular = "Regular Set"
    case superSet = "Super Set"
    case dropSet = "Drop Set"
    case failure = "Until Failure"
    
    var shortLabel: String {
        switch self {
        case .regular:
            return "" // For regular sets, we show the numeric index from outside
        case .warmup:
            return "W"
        case .superSet:
            return "S"
        case .dropSet:
            return "D"
        case .failure:
            return "F"
        }
    }

    var tintColor: Color {
        switch self {
        case .regular:
            return .primary
        case .warmup:
            return .orange
        case .superSet:
            return .purple
        case .dropSet:
            return .indigo
        case .failure:
            return .red
        }
    }
}
