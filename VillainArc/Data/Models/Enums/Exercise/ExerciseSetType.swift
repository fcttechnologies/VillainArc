import SwiftUI

enum ExerciseSetType: Int, Codable, CaseIterable {
    case warmup = 0
    case regular = 1
    case superSet = 2
    case dropSet = 3
    case failure = 4
    
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
    
    var displayName : String {
        switch self {
        case .regular:
            return "Regular Set"
        case .warmup:
            return "Warm Up Set"
        case .superSet:
            return "Super Set"
        case .dropSet:
            return "Drop Set"
        case .failure:
            return "Failure Set"
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
