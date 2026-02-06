import Foundation
import FoundationModels

// MARK: - AI-Readable Enums

@Generable
enum AIRepRangeMode: String, Equatable, Sendable {
    case target = "Target"
    case range = "Range"
    
    var repRangeMode: RepRangeMode {
        switch self {
        case .target:
            return .target
        case .range:
            return .range
        }
    }
}

@Generable
enum AIExerciseSetType: String, Equatable, Sendable {
    case warmup = "Warm Up Set"
    case regular = "Regular Set"
    case superSet = "Super Set"
    case dropSet = "Drop Set"
    case failure = "Failure Set"
    
    init(from type: ExerciseSetType) {
        switch type {
        case .warmup:
            self = .warmup
        case .regular:
            self = .regular
        case .superSet:
            self = .superSet
        case .dropSet:
            self = .dropSet
        case .failure:
            self = .failure
        }
    }
}

@Generable
enum AITrainingStyleClassification: String, Equatable, Sendable {
    case straightSets = "Straight Sets"
    case ascendingPyramid = "Ascending Pyramid"
    case descendingPyramid = "Descending Pyramid"
    case ascending = "Ascending"
    case topSetBackoffs = "Top Set Then Backoffs"
    case unknown = "Unknown"
    
    var trainingStyle: TrainingStyle {
        switch self {
        case .straightSets:
            return .straightSets
        case .ascendingPyramid:
            return .ascendingPyramid
        case .descendingPyramid:
            return .descendingPyramid
        case .ascending:
            return .ascending
        case .topSetBackoffs:
            return .topSetBackoffs
        case .unknown:
            return .unknown
        }
    }
}

// MARK: - AI Input

@Generable
struct AIInferenceInput: Equatable, Sendable {
    @Guide(description: "Exercise catalog identifier, unique to each exercise.")
    let catalogID: String
    let exerciseName: String
    @Guide(description: "Primary muscle targeted by this exercise (e.g., Chest, Quads, Back).")
    let primaryMuscle: String
    @Guide(description: "What the user performed for this exercise in the current session.")
    let performance: AIExercisePerformanceSnapshot
}

// MARK: - AI Output

@Generable
struct AIInferenceOutput: Equatable, Sendable {
    @Guide(description: "Classified rep range mode and values. Nil if unable to determine.")
    let repRangeClassification: AIRepRangeClassification?
    @Guide(description: "Classified training style. Nil if unable to determine.")
    let trainingStyleClassification: AITrainingStyleClassification?
}

@Generable
struct AIRepRangeClassification: Equatable, Sendable {
    @Guide(description: "Classified rep range mode: Target or Range only.")
    let mode: AIRepRangeMode
    @Guide(description: "Lower bound of rep range (when mode is Range). 0 if not applicable.")
    let lowerRange: Int
    @Guide(description: "Upper bound of rep range (when mode is Range). 0 if not applicable.")
    let upperRange: Int
    @Guide(description: "Target reps (when mode is Target). 0 if not applicable.")
    let targetReps: Int
}

// MARK: - Performance Snapshots (used as input and tool return type)

@Generable
struct AIExercisePerformanceSnapshot: Equatable, Sendable {
    @Guide(description: "ISO 8601 date string when this exercise performance occurred.")
    let date: String
    @Guide(description: "Rep range mode that was active during this performance (Target or Range), or nil if not set.")
    let repRangeMode: AIRepRangeMode?
    @Guide(description: "Lower bound of rep range (when mode is Range). Nil if not applicable.")
    let repRangeLower: Int?
    @Guide(description: "Upper bound of rep range (when mode is Range). Nil if not applicable.")
    let repRangeUpper: Int?
    @Guide(description: "Target reps (when mode is Target). Nil if not applicable.")
    let repRangeTarget: Int?
    @Guide(description: "Set-level performance snapshots for this exercise.")
    let sets: [AISetPerformanceSnapshot]
    
    init(performance: ExercisePerformance) {
        self.date = Self.iso8601String(from: performance.date)
        let policy = performance.repRange
        switch policy.activeMode {
        case .range:
            self.repRangeMode = .range
            self.repRangeLower = policy.lowerRange
            self.repRangeUpper = policy.upperRange
            self.repRangeTarget = nil
        case .target:
            self.repRangeMode = .target
            self.repRangeLower = nil
            self.repRangeUpper = nil
            self.repRangeTarget = policy.targetReps
        case .notSet, .untilFailure:
            self.repRangeMode = nil
            self.repRangeLower = nil
            self.repRangeUpper = nil
            self.repRangeTarget = nil
        }
        self.sets = performance.sortedSets.map { AISetPerformanceSnapshot(set: $0) }
    }

    private static func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}

@Generable
struct AISetPerformanceSnapshot: Equatable, Sendable {
    @Guide(description: "0-based set index within the exercise.")
    let index: Int
    @Guide(description: "Type of set: warmup, regular, superSet, dropSet, or failure.")
    let setType: AIExerciseSetType
    @Guide(description: "Actual weight used for the set.")
    let weight: Double
    @Guide(description: "Actual reps completed for the set.")
    let reps: Int
    @Guide(description: "Actual rest seconds recorded for the set.")
    let restSeconds: Int
    
    init(set: SetPerformance) {
        self.index = set.index
        self.setType = AIExerciseSetType(from: set.type)
        self.weight = set.weight
        self.reps = set.reps
        self.restSeconds = set.restSeconds
    }
}
