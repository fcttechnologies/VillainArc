import Foundation
import SwiftData

@Model
class SetPerformance {
    var id: UUID = UUID()
    var index: Int = 0
    var type: ExerciseSetType = ExerciseSetType.working
    var weight: Double = 0
    var reps: Int = 0
    var restSeconds: Int = 0
    var complete: Bool = false
    var completedAt: Date?
    var exercise: ExercisePerformance?
    @Relationship(deleteRule: .nullify)
    var prescription: SetPrescription?

    var effectiveRestSeconds: Int {
        exercise?.effectiveRestSeconds(after: self) ?? restSeconds
    }

    var estimated1RM: Double? {
        guard weight > 0, reps > 0 else { return nil }
        return weight * (1 + (Double(reps) / 30))
    }

    var volume: Double {
        max(0, weight) * Double(max(0, reps))
    }

    // Adding set in session
    init(exercise: ExercisePerformance, weight: Double = 0, reps: Int = 0, restSeconds: Int = 0) {
        index = exercise.sets.count
        self.exercise = exercise
        self.weight = weight
        self.reps = reps
        self.restSeconds = restSeconds
    }
    
    // Adding set from plan
    init(exercise: ExercisePerformance, setPrescription: SetPrescription) {
        index = setPrescription.index
        type = setPrescription.type
        restSeconds = setPrescription.targetRest
        self.exercise = exercise
        prescription = setPrescription
    }
}

extension SetPerformance: RestTimeEditableSet {}
