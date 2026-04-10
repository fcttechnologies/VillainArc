import Foundation
#if canImport(FoundationModels)
import FoundationModels

@Generable struct AIExercisePerformanceSnapshot {
    @Guide(description: "Exercise.")
    let exercise: AIExerciseIdentitySnapshot
    @Guide(description: "Workout date.")
    let date: String
    @Guide(description: "Rep range.")
    let repRange: AIRepRangeSnapshot?
    @Guide(description: "Completed sets.")
    let sets: [AISetPerformanceSnapshot]

    init(performance: ExercisePerformance) {
        exercise = AIExerciseIdentitySnapshot(performance: performance)
        date = Self.iso8601String(from: performance.date)
        repRange = AIRepRangeSnapshot(policy: performance.repRange)
        sets = performance.sortedSets.map { AISetPerformanceSnapshot(set: $0, targetSnapshot: performance.originalTargetSnapshot) }
    }

    init(exercise: AIExerciseIdentitySnapshot, date: Date, snapshot: ExercisePerformanceSnapshot, targetSnapshot: ExerciseTargetSnapshot? = nil) {
        self.exercise = exercise
        self.date = Self.iso8601String(from: date)
        repRange = AIRepRangeSnapshot(snapshot: snapshot.repRange)
        sets = snapshot.sets.map { AISetPerformanceSnapshot(snapshot: $0, targetSnapshot: targetSnapshot) }
    }

    private static func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}

@Generable struct AISetPerformanceSnapshot {
    @Guide(description: "Set index.")
    let index: Int
    @Guide(description: "Original target slot.")
    let originalTargetSetIndex: Int?
    @Guide(description: "Set type.")
    let setType: AIExerciseSetType
    @Guide(description: "Weight kg.")
    let weight: Double
    @Guide(description: "Reps.")
    let reps: Int
    @Guide(description: "Rest sec.")
    let restSeconds: Int
    @Guide(description: "Actual RPE 1 to 10, or 0 when not recorded.")
    let rpe: Int

    init(set: SetPerformance, targetSnapshot: ExerciseTargetSnapshot?) {
        index = set.index
        originalTargetSetIndex = Self.resolveOriginalTargetSetIndex(targetSetID: set.originalTargetSetID ?? set.prescription?.id, targetSnapshot: targetSnapshot)
        setType = AIExerciseSetType(from: set.type)
        weight = set.weight
        reps = set.reps
        restSeconds = set.restSeconds
        rpe = set.rpe
    }

    init(snapshot: SetPerformanceSnapshot, targetSnapshot: ExerciseTargetSnapshot?) {
        index = snapshot.index
        originalTargetSetIndex = Self.resolveOriginalTargetSetIndex(targetSetID: snapshot.originalTargetSetID, targetSnapshot: targetSnapshot)
        setType = AIExerciseSetType(from: snapshot.type)
        weight = snapshot.weight
        reps = snapshot.reps
        restSeconds = snapshot.restSeconds
        rpe = snapshot.rpe
    }

    private static func resolveOriginalTargetSetIndex(targetSetID: UUID?, targetSnapshot: ExerciseTargetSnapshot?) -> Int? {
        guard let targetSetID, let targetSnapshot else { return nil }
        return targetSnapshot.sets.first(where: { $0.targetSetID == targetSetID })?.index
    }
}
#endif
