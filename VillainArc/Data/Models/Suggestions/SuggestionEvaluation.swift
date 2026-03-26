import Foundation
import SwiftData

@Model final class SuggestionEvaluation {
    var id: UUID = UUID()

    @Relationship(deleteRule: .nullify) var event: SuggestionEvent?

    @Relationship(deleteRule: .nullify) var performance: ExercisePerformance?

    var sourceWorkoutSessionID: UUID = UUID()
    var partialOutcome: Outcome = Outcome.pending
    var confidence: Double = 0
    var reason: String = ""
    var evaluatedAt: Date = Date()

    init() {}

    convenience init(event: SuggestionEvent, performance: ExercisePerformance, sourceWorkoutSessionID: UUID, partialOutcome: Outcome, confidence: Double, reason: String) {
        self.init()
        self.event = event
        self.performance = performance
        self.sourceWorkoutSessionID = sourceWorkoutSessionID
        self.partialOutcome = partialOutcome
        self.confidence = confidence
        self.reason = reason
    }
}

extension SuggestionEvaluation {
    static func forSourceWorkoutSession(_ workoutSessionID: UUID) -> FetchDescriptor<SuggestionEvaluation> {
        let predicate = #Predicate<SuggestionEvaluation> { $0.sourceWorkoutSessionID == workoutSessionID }
        return FetchDescriptor(predicate: predicate)
    }
}
