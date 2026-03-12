import Foundation
import FoundationModels

@Generable
struct AIExercisePerformanceSnapshot {
    @Guide(description: "Exercise identity.")
    let exercise: AIExerciseIdentitySnapshot
    @Guide(description: "ISO 8601 workout date.")
    let date: String
    @Guide(description: "Rep range if configured.")
    let repRange: AIRepRangeSnapshot?
    @Guide(description: "Completed and logged sets.")
    let sets: [AISetPerformanceSnapshot]

    init(performance: ExercisePerformance) {
        exercise = AIExerciseIdentitySnapshot(performance: performance)
        date = Self.iso8601String(from: performance.date)
        repRange = AIRepRangeSnapshot(policy: performance.repRange)
        sets = performance.sortedSets.map { AISetPerformanceSnapshot(set: $0) }
    }

    init(exercise: AIExerciseIdentitySnapshot, date: Date, snapshot: ExercisePerformanceSnapshot) {
        self.exercise = exercise
        self.date = Self.iso8601String(from: date)
        repRange = AIRepRangeSnapshot(snapshot: snapshot.repRange)
        sets = snapshot.sets.map { AISetPerformanceSnapshot(snapshot: $0) }
    }

    private static func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}

@Generable
struct AISetPerformanceSnapshot {
    @Guide(description: "0-based set index.")
    let index: Int
    @Guide(description: "Set type.")
    let setType: AIExerciseSetType
    @Guide(description: "Weight used.")
    let weight: Double
    @Guide(description: "Reps completed.")
    let reps: Int
    @Guide(description: "Rest seconds recorded.")
    let restSeconds: Int

    init(set: SetPerformance) {
        index = set.index
        setType = AIExerciseSetType(from: set.type)
        weight = set.weight
        reps = set.reps
        restSeconds = set.restSeconds
    }

    init(snapshot: SetPerformanceSnapshot) {
        index = snapshot.index
        setType = AIExerciseSetType(from: snapshot.type)
        weight = snapshot.weight
        reps = snapshot.reps
        restSeconds = snapshot.restSeconds
    }
}
