import Foundation
import SwiftData

@Model final class RepRangePolicy {
    var activeMode: RepRangeMode = RepRangeMode.notSet
    var lowerRange: Int = 8
    var upperRange: Int = 12
    var targetReps: Int = 8
    var exercisePerformance: ExercisePerformance?
    var exercisePrescription: ExercisePrescription?

    var displayText: String {
        switch activeMode {
        case .notSet: return "Rep Range: Not Set"
        case .range: return "Rep Range: \(lowerRange)-\(upperRange)"
        case .target: return "Target: \(targetReps) reps"
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

extension RepRangePolicy {
    func resetToDefault() {
        activeMode = .notSet
        lowerRange = 8
        upperRange = 12
        targetReps = 8
    }

    func apply(snapshot: RepRangeSnapshot) {
        activeMode = snapshot.mode
        lowerRange = snapshot.lower
        upperRange = snapshot.upper
        targetReps = snapshot.target
    }
}
