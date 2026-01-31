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
    
    init() {}

    init(copying source: RepRangePolicy) {
        self.activeMode = source.activeMode
        self.lowerRange = source.lowerRange
        self.upperRange = source.upperRange
        self.targetReps = source.targetReps
    }
}
