import Foundation
import SwiftData

@Model
class RepRangePolicy {
    var activeMode: RepRangeMode = RepRangeMode.notSet
    var lowerRange: Int = 8
    var upperRange: Int = 12
    var targetReps: Int = 8
    
    var displayText: String {
        switch activeMode {
        case .notSet:
            return "Rep Range: Not Set"
        case .range:
            return "Rep Range: \(lowerRange)-\(upperRange)"
        case .target:
            return "Rep Target: \(targetReps)"
        case .untilFailure:
            return "Rep Goal: Until Failure"
        }
    }
    
    init(activeMode: RepRangeMode = .notSet, lowerRange: Int = 8, upperRange: Int = 12, targetReps: Int = 8) {
        self.activeMode = activeMode
        self.lowerRange = lowerRange
        self.upperRange = upperRange
        self.targetReps = targetReps
    }
}

enum RepRangeMode: String, CaseIterable, Codable {
    case notSet
    case target
    case range
    case untilFailure
    
    var displayName: String {
        switch self {
        case .notSet:
            return "Not Set"
        case .target:
            return "Target"
        case .range:
            return "Range"
        case .untilFailure:
            return "Until Failure"
        }
    }
}
