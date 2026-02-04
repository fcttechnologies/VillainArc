import Foundation
import SwiftData

@Model
class PrescriptionChange {
    var id: UUID = UUID()
    var source: SuggestionSource = SuggestionSource.rules
    var catalogID: String = ""
    
    // When/where triggered
    @Relationship(deleteRule: .nullify)
    var sessionFrom: WorkoutSession?
    var createdAt: Date = Date()              // When suggestion was created
    
    // Evidence
    @Relationship(deleteRule: .nullify)
    var sourceExercisePerformance: ExercisePerformance?
    @Relationship(deleteRule: .nullify)
    var sourceSetPerformance: SetPerformance?
    
    // Target
    @Relationship(deleteRule: .nullify)
    var targetExercisePrescription: ExercisePrescription?
    @Relationship(deleteRule: .nullify)
    var targetSetPrescription: SetPrescription?
    
    // The Change
    var changeType: ChangeType = ChangeType.increaseWeight
    var previousValue: Double?
    var newValue: Double?
    var changeReasoning: String?
    
    // Decision
    var decision: Decision = Decision.pending         // Default to pending
    
    // Outcome
    var outcome: Outcome = Outcome.pending           // Default to pending
    @Relationship(deleteRule: .nullify)
    var evaluatedInSession: WorkoutSession?   // Which session evaluated
    var evaluatedAt: Date?                    // When outcome was determined
    
    init() {}
}
