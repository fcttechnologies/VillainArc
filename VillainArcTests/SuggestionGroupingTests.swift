import SwiftData
import Testing

@testable import VillainArc

struct SuggestionGroupingTests {
    @Test @MainActor func pendingOutcomeSuggestionEvents_includeRejectedUnresolvedEvents() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, exercise) = TestDataFactory.makePrescription(context: context, workingSets: 1, targetWeight: 100)

        let change = PrescriptionChange(changeType: .decreaseWeight, previousValue: 100, newValue: 95)
        context.insert(change)

        let event = SuggestionEvent(catalogID: exercise.catalogID, sessionFrom: nil, targetExercisePrescription: exercise, targetSetPrescription: exercise.sortedSets.first, decision: .rejected, outcome: .pending, trainingStyle: .straightSets, changes: [change])
        context.insert(event)

        let events = pendingOutcomeSuggestionEvents(for: plan, in: context)

        #expect(events.count == 1)
        #expect(events.first?.id == event.id)
        #expect(events.first?.decision == .rejected)
    }
}
