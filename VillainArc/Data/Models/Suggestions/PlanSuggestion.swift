import Foundation
import SwiftData

@Model
class PlanSuggestion {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var source: SuggestionSource = SuggestionSource.rules
    var reasoning: String?
    @Relationship(deleteRule: .nullify)
    var workoutSessionFrom: WorkoutSession?
    @Relationship(deleteRule: .nullify)
    var planSnapshotFrom: PlanSnapshot?
    @Relationship(deleteRule: .cascade, inverse: \SuggestedChange.planSuggestion)
    var suggestedChanges: [SuggestedChange] = []
    
    init(workoutSessionFrom: WorkoutSession, planSnapshotFrom: PlanSnapshot) {
        self.workoutSessionFrom = workoutSessionFrom
        self.planSnapshotFrom = planSnapshotFrom
    }
}
