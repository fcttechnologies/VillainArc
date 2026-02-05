import Foundation
import FoundationModels

@Generable
struct AIExerciseSuggestionInput: Equatable, Sendable {
    // Base context for the model (always provided).
    @Guide(description: "Exercise catalog identifier, unique to each exercise.")
    let catalogID: String
    let exerciseName: String
    @Guide(description: "Primary muscle targeted by this exercise (e.g., Chest, Quads, Back).")
    let primaryMuscle: String
    @Guide(description: "Current exercise prescription.")
    let prescription: AIExercisePrescriptionSnapshot
    @Guide(description: "What the user performed for this exercise.")
    let performance: AIExercisePerformanceSnapshot
}

@Generable
enum AIRepRangeMode: String, Equatable, Sendable {
    case notSet = "Not Set"
    case target = "Target"
    case range = "Range"
    case untilFailure = "Until Failure"
    
    init(from mode: RepRangeMode) {
        switch mode {
        case .notSet:
            self = .notSet
        case .target:
            self = .target
        case .range:
            self = .range
        case .untilFailure:
            self = .untilFailure
        }
    }
}

@Generable
enum AIRestTimeMode: String, Equatable, Sendable {
    case allSame = "All Same"
    case individual = "Individual"
    
    init(from mode: RestTimeMode) {
        switch mode {
        case .allSame:
            self = .allSame
        case .individual:
            self = .individual
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
struct AIExercisePrescriptionSnapshot: Equatable, Sendable {
    @Guide(description: "Rep range mode: notSet, target, range, or untilFailure.")
    let repRangeMode: AIRepRangeMode
    @Guide(description: "Lower bound of rep range (when mode is range).")
    let repRangeLower: Int
    @Guide(description: "Upper bound of rep range (when mode is range).")
    let repRangeUpper: Int
    @Guide(description: "Target reps (when mode is target).")
    let repRangeTarget: Int
    @Guide(description: "Rest time policy mode")
    let restTimeMode: AIRestTimeMode
    @Guide(description: "All-same rest seconds (when rest mode is allSame).")
    let restTimeAllSameSeconds: Int
    @Guide(description: "Set-level prescription snapshots for this exercise.")
    let sets: [AISetPrescriptionSnapshot]
    
    init(prescription: ExercisePrescription) {
        self.repRangeMode = AIRepRangeMode(from: prescription.repRange.activeMode)
        self.repRangeLower = prescription.repRange.lowerRange
        self.repRangeUpper = prescription.repRange.upperRange
        self.repRangeTarget = prescription.repRange.targetReps
        self.restTimeMode = AIRestTimeMode(from: prescription.restTimePolicy.activeMode)
        self.restTimeAllSameSeconds = prescription.restTimePolicy.allSameSeconds
        self.sets = prescription.sortedSets.map { AISetPrescriptionSnapshot(set: $0) }
    }
}

@Generable
struct AISetPrescriptionSnapshot: Equatable, Sendable {
    @Guide(description: "0-based set index within the exercise.")
    let index: Int
    @Guide(description: "Type of set: warmup, regular, superSet, dropSet, or failure.")
    let setType: AIExerciseSetType
    @Guide(description: "Target weight for the set.")
    let targetWeight: Double
    @Guide(description: "Target reps for the set.")
    let targetReps: Int
    @Guide(description: "Target rest seconds after the set.")
    let targetRestSeconds: Int
    
    init(set: SetPrescription) {
        self.index = set.index
        self.setType = AIExerciseSetType(from: set.type)
        self.targetWeight = set.targetWeight
        self.targetReps = set.targetReps
        self.targetRestSeconds = set.targetRest
    }
}

@Generable
struct AIExercisePerformanceSnapshot: Equatable, Sendable {
    @Guide(description: "ISO 8601 date string when this exercise performance occurred.")
    let date: String
    @Guide(description: "Rep range mode that was active during this performance: notSet, target, range, or untilFailure.")
    let repRangeMode: AIRepRangeMode
    @Guide(description: "Lower bound of rep range (when mode is range).")
    let repRangeLower: Int
    @Guide(description: "Upper bound of rep range (when mode is range).")
    let repRangeUpper: Int
    @Guide(description: "Target reps (when mode is target).")
    let repRangeTarget: Int
    @Guide(description: "Rest time mode that was active: allSame or individual.")
    let restTimeMode: AIRestTimeMode
    @Guide(description: "All-same rest seconds (when rest mode is allSame).")
    let restTimeAllSameSeconds: Int
    @Guide(description: "Set-level performance snapshots for this exercise.")
    let sets: [AISetPerformanceSnapshot]
    
    init(performance: ExercisePerformance) {
        self.date = Self.iso8601String(from: performance.date)
        self.repRangeMode = AIRepRangeMode(from: performance.repRange.activeMode)
        self.repRangeLower = performance.repRange.lowerRange
        self.repRangeUpper = performance.repRange.upperRange
        self.repRangeTarget = performance.repRange.targetReps
        self.restTimeMode = AIRestTimeMode(from: performance.restTimePolicy.activeMode)
        self.restTimeAllSameSeconds = performance.restTimePolicy.allSameSeconds
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

@Generable
struct AIExerciseHistoryContext: Equatable, Sendable {
    // Compact cached history for optional tool use.
    @Guide(description: "True if cached history exists for this exercise.")
    let hasHistory: Bool
    @Guide(description: "Total completed sessions for this exercise.")
    let totalSessions: Int
    @Guide(description: "Completed sessions in the last 30 days.")
    let last30DaySessions: Int
    @Guide(description: "Trend string: improving, stable, declining, insufficient.")
    let progressionTrend: String
    @Guide(description: "Best estimated 1RM across history.")
    let bestEstimated1RM: Double
    @Guide(description: "Best weight used across history.")
    let bestWeight: Double
    @Guide(description: "Best total volume across history.")
    let bestVolume: Double
    @Guide(description: "Average weight across last 3 sessions.")
    let last3AvgWeight: Double
    @Guide(description: "Average volume across last 3 sessions.")
    let last3AvgVolume: Double
    @Guide(description: "Average set count across last 3 sessions.")
    let last3AvgSetCount: Int
    @Guide(description: "Average rest seconds across last 3 sessions.")
    let last3AvgRestSeconds: Int
    @Guide(description: "Typical set count across all history.")
    let typicalSetCount: Int
    @Guide(description: "Typical lower rep range across history.")
    let typicalRepRangeLower: Int
    @Guide(description: "Typical upper rep range across history.")
    let typicalRepRangeUpper: Int
    @Guide(description: "Typical rest seconds across history.")
    let typicalRestSeconds: Int
}



@Generable
struct AISuggestionOutput: Equatable, Sendable {
    @Guide(description: "Zero or more AI suggestions for this exercise.")
    let suggestions: [AISuggestion]
}

@Generable
struct AISuggestion: Equatable, Sendable {
    // -1 means exercise-level change (rep range or rest-time policy).
    @Guide(description: "0-based set index for set-level changes. Use -1 for exercise-level changes.")
    let targetSetIndex: Int
    @Guide(description: "Change type to apply.")
    let changeType: AIChangeType
    @Guide(description: "New target value for the change.")
    let newValue: Double
    @Guide(description: "Short, user-facing reason for the suggestion.")
    let reasoning: String
}

@Generable
enum AIChangeType: String, Equatable, Sendable {
    case increaseWeight = "Increase Weight"
    case decreaseWeight = "Decrease Weight"
    case increaseReps = "Increase Reps"
    case decreaseReps = "Decrease Reps"
    case increaseRest = "Increase Rest for individual set (when rest time policy is Individual)"
    case decreaseRest = "Decrease Rest for individual set"
    case changeRepRangeMode = "Change Rep Range Mode (only when rep range is Not Set and history supports it)"
    case increaseRestTimeSeconds = "Increase Rest Time (when rest time policy is All Same)"
    case decreaseRestTimeSeconds = "Decrease Rest Time (when rest time policy is All Same)"
}

extension AIExerciseHistoryContext {
    static func from(history: ExerciseHistory?) -> AIExerciseHistoryContext {
        guard let history else {
            return AIExerciseHistoryContext(
                hasHistory: false,
                totalSessions: 0,
                last30DaySessions: 0,
                progressionTrend: ProgressionTrend.insufficient.rawValue,
                bestEstimated1RM: 0,
                bestWeight: 0,
                bestVolume: 0,
                last3AvgWeight: 0,
                last3AvgVolume: 0,
                last3AvgSetCount: 0,
                last3AvgRestSeconds: 0,
                typicalSetCount: 0,
                typicalRepRangeLower: 0,
                typicalRepRangeUpper: 0,
                typicalRestSeconds: 0
            )
        }

        return AIExerciseHistoryContext(
            hasHistory: true,
            totalSessions: history.totalSessions,
            last30DaySessions: history.last30DaySessions,
            progressionTrend: history.progressionTrend.rawValue,
            bestEstimated1RM: history.bestEstimated1RM,
            bestWeight: history.bestWeight,
            bestVolume: history.bestVolume,
            last3AvgWeight: history.last3AvgWeight,
            last3AvgVolume: history.last3AvgVolume,
            last3AvgSetCount: history.last3AvgSetCount,
            last3AvgRestSeconds: history.last3AvgRestSeconds,
            typicalSetCount: history.typicalSetCount,
            typicalRepRangeLower: history.typicalRepRangeLower,
            typicalRepRangeUpper: history.typicalRepRangeUpper,
            typicalRestSeconds: history.typicalRestSeconds
        )
    }
}

extension AIChangeType {
    var changeType: ChangeType {
        switch self {
        case .increaseWeight:
            return .increaseWeight
        case .decreaseWeight:
            return .decreaseWeight
        case .increaseReps:
            return .increaseReps
        case .decreaseReps:
            return .decreaseReps
        case .increaseRest:
            return .increaseRest
        case .decreaseRest:
            return .decreaseRest
        case .changeRepRangeMode:
            return .changeRepRangeMode
        case .increaseRestTimeSeconds:
            return .increaseRestTimeSeconds
        case .decreaseRestTimeSeconds:
            return .decreaseRestTimeSeconds
        }
    }

    var isExerciseLevel: Bool {
        switch self {
        case .changeRepRangeMode,
             .increaseRestTimeSeconds,
             .decreaseRestTimeSeconds:
            return true
        default:
            return false
        }
    }
}
