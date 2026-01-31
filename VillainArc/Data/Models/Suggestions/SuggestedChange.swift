import Foundation
import SwiftData

@Model
class SuggestedChange {
    var id: UUID = UUID()
    var sourceExercisePerformance: ExercisePerformance?
    var sourceSetPerformance: SetPerformance?
    
    var targetExercisePrescription: ExercisePrescription?
    var targetSetPrescription: SetPrescription?
    
    var changeType: ChangeType = ChangeType.increaseWeight
    var delta: Double?
    var value: Double?
    var changeReasoning: String?
    var planSuggestion: PlanSuggestion?
    var decision: Decision?
    var decisionReason: String?
    var decidedAt: Date?
    @Relationship(deleteRule: .nullify)
    var appliedInSnapshot: PlanSnapshot?
    var outcome: Outcome?
    var evaluatedAt: Date?
    @Relationship(deleteRule: .nullify)
    var evaluatedInSession: WorkoutSession?
    
    init(sourceExercisePerformance: ExercisePerformance, targetExercisePrescription: ExercisePrescription, delta: Double, value: Double, planSuggestion: PlanSuggestion) {
        self.sourceExercisePerformance = sourceExercisePerformance
        self.targetExercisePrescription = targetExercisePrescription
        self.delta = delta
        self.value = value
        self.planSuggestion = planSuggestion
    }
    
    init(sourceSetPerformance: SetPerformance, targetSetPrescription: SetPrescription, delta: Double, value: Double, planSuggestion: PlanSuggestion) {
        self.sourceSetPerformance = sourceSetPerformance
        self.targetSetPrescription = targetSetPrescription
        self.delta = delta
        self.value = value
        self.planSuggestion = planSuggestion
    }
}
