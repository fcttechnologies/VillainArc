import Foundation
#if canImport(FoundationModels)
import FoundationModels

@Generable struct AIRepRangeSnapshot {
    @Guide(description: "Mode.")
    let mode: AIRepRangeMode
    @Guide(description: "Lower bound.")
    let lower: Int?
    @Guide(description: "Upper bound.")
    let upper: Int?
    @Guide(description: "Target reps.")
    let target: Int?

    init(mode: AIRepRangeMode, lower: Int? = nil, upper: Int? = nil, target: Int? = nil) {
        self.mode = mode
        self.lower = lower
        self.upper = upper
        self.target = target
    }

    init?(policy: RepRangePolicy?) {
        guard let policy else { return nil }

        switch policy.activeMode {
        case .range: self.init(mode: .range, lower: policy.lowerRange, upper: policy.upperRange)
        case .target: self.init(mode: .target, target: policy.targetReps)
        case .notSet: return nil
        }
    }

    init?(snapshot: RepRangeSnapshot) {
        switch snapshot.mode {
        case .range: self.init(mode: .range, lower: snapshot.lower, upper: snapshot.upper)
        case .target: self.init(mode: .target, target: snapshot.target)
        case .notSet: return nil
        }
    }
}
#endif
