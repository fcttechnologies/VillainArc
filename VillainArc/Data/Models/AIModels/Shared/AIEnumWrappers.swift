import Foundation
import FoundationModels

@Generable enum AIRepRangeMode: String {
    case target = "Target"
    case range = "Range"

    init?(from mode: RepRangeMode) {
        switch mode {
        case .target: self = .target
        case .range: self = .range
        case .notSet: return nil
        }
    }

    var repRangeMode: RepRangeMode {
        switch self {
        case .target: return .target
        case .range: return .range
        }
    }
}

@Generable enum AIExerciseSetType: String {
    case warmup = "Warm Up Set"
    case working = "Working Set"
    case dropSet = "Drop Set"

    init(from type: ExerciseSetType) {
        switch type {
        case .warmup: self = .warmup
        case .working: self = .working
        case .dropSet: self = .dropSet
        }
    }
}

@Generable enum AIMoodLevel: String {
    case sick = "Sick"
    case tired = "Tired"
    case okay = "Okay"
    case good = "Good"
    case great = "Great"

    init?(from mood: MoodLevel) {
        switch mood {
        case .sick: self = .sick
        case .tired: self = .tired
        case .okay: self = .okay
        case .good: self = .good
        case .great: self = .great
        case .notSet: return nil
        }
    }
}
