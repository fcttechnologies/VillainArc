import Foundation
import SwiftData

@Model
class RepRangePolicy {
    var activeMode: RepRangeMode = RepRangeMode.notSet
    var lowerRange: Int = 8
    var upperRange: Int = 12
    var targetReps: Int = 8
    var exercisePerformance: ExercisePerformance?
    var exercisePrescription: ExercisePrescription?
    
    var displayText: String {
        switch activeMode {
        case .notSet:
            return "Rep Range: Not Set"
        case .range:
            return "Rep Range: \(lowerRange)-\(upperRange)"
        case .target:
            return "Rep Target: \(targetReps)"
        }
    }
    
    init() {}

    init(copying source: RepRangePolicy?) {
        activeMode = source?.activeMode ?? .notSet
        lowerRange = source?.lowerRange ?? 8
        upperRange = source?.upperRange ?? 12
        targetReps = source?.targetReps ?? 8
    }
}
