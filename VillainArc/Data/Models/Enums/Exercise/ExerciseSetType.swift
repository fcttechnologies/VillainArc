import SwiftUI

enum ExerciseSetType: Int, Codable, CaseIterable {
    case warmup = 0
    case working = 1
    case dropSet = 3
    
    var shortLabel: String {
        switch self {
        case .working:
            return "" // For regular sets, we show the numeric index from outside
        case .warmup:
            return "W"
        case .dropSet:
            return "D"
        }
    }
    
    nonisolated var displayName : String {
        switch self {
        case .working:
            return "Working Set"
        case .warmup:
            return "Warm Up"
        case .dropSet:
            return "Drop Set"
        }
    }

    var tintColor: Color {
        switch self {
        case .working:
            return .primary
        case .warmup:
            return .orange
        case .dropSet:
            return .indigo
        }
    }
}
