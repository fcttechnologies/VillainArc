import FCTMetrics
import Foundation
import SwiftData
import Testing

@testable import VillainArc

/// What Villain Arc reports to `diag.algorithm_outcomes` about its next-set engine: one row for the
/// user's decision on a suggestion, and one for the verdict a later workout reaches on it.
///
/// The app's own `Outcome` stays what it reasons and learns with; these are the translations at the
/// edge, and each surface is driven for real rather than the translation being checked alone.
@Suite(.serialized) struct AlgorithmOutcomeTests {

    /// Captures what a surface reported, in place of `Diag` (which holds its recorder in a
    /// process-wide slot with nothing to read it back).
    final class SpyOutcomes: SuggestionOutcomeReporting, @unchecked Sendable {
        private let lock = NSLock()
        private var captured: [AlgorithmOutcome<VillainArcEngine>] = []

        func record(_ outcome: AlgorithmOutcome<VillainArcEngine>) {
            lock.lock()
            defer { lock.unlock() }
            captured.append(outcome)
        }

        var recorded: [AlgorithmOutcome<VillainArcEngine>] {
            lock.lock()
            defer { lock.unlock() }
            return captured
        }
    }

    @MainActor private func makeEvent(
        context: ModelContext,
        prescription: ExercisePrescription,
        source: SuggestionSource = .rules,
        createdAt: Date = Date()
    ) -> SuggestionEvent {
        let change = PrescriptionChange(changeType: .increaseWeight, previousValue: 100, newValue: 105)
        context.insert(change)
        let event = SuggestionEvent(
            source: source, category: .performance, catalogID: prescription.catalogID, sessionFrom: nil,
            targetExercisePrescription: prescription, targetSetPrescription: prescription.sortedSets.first,
            triggerTargetSetID: prescription.sortedSets.first?.id, trainingStyle: .straightSets,
            createdAt: createdAt, changes: [change]
        )
        change.event = event
        context.insert(event)
        return event
    }

    // MARK: - The review surfaces

    @Test @MainActor func acceptingAGroupReportsAccepted() throws {
        let context = try TestDataFactory.makeContext()
        let (_, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 1)
        let event = makeEvent(context: context, prescription: prescription, createdAt: Date().addingTimeInterval(-7_200))
        let spy = SpyOutcomes()

        acceptGroup(SuggestionGroup(event: event), rank: 3, context: context, outcomes: spy)

        #expect(event.decision == .accepted)
        let outcome = try #require(spy.recorded.first)
        #expect(spy.recorded.count == 1)
        #expect(outcome.engine == .nextSet)
        #expect(outcome.outcome == .accepted)
        #expect(outcome.suggestionSource == .progression)
        #expect(outcome.rankPosition == 3)
        #expect(outcome.delayBucket == .hour)
    }

    @Test @MainActor func rejectingAGroupReportsDismissed() throws {
        let context = try TestDataFactory.makeContext()
        let (_, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 1)
        let event = makeEvent(context: context, prescription: prescription, createdAt: Date().addingTimeInterval(-30))
        let spy = SpyOutcomes()

        rejectGroup(SuggestionGroup(event: event), rank: 1, context: context, outcomes: spy)

        #expect(event.decision == .rejected)
        let outcome = try #require(spy.recorded.first)
        #expect(spy.recorded.count == 1)
        #expect(outcome.engine == .nextSet)
        #expect(outcome.outcome == .dismissed)
        #expect(outcome.suggestionSource == .progression)
        #expect(outcome.rankPosition == 1)
        #expect(outcome.delayBucket == .immediate)
    }

    @Test @MainActor func skippingTheReviewReportsEveryOpenSuggestionDismissed() throws {
        let context = try TestDataFactory.makeContext()
        let (_, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 1)
        let first = makeEvent(context: context, prescription: prescription)
        let second = makeEvent(context: context, prescription: prescription)
        let alreadyDecided = makeEvent(context: context, prescription: prescription)
        alreadyDecided.decision = .accepted
        second.decision = .deferred
        let spy = SpyOutcomes()

        skipSuggestions([first, second, alreadyDecided], context: context, outcomes: spy)

        #expect(first.decision == .rejected)
        #expect(second.decision == .rejected)
        #expect(alreadyDecided.decision == .accepted)   // already answered, left alone
        #expect(spy.recorded.map(\.outcome) == [.dismissed, .dismissed])
        #expect(spy.recorded.map(\.rankPosition) == [1, 2])
        #expect(spy.recorded.allSatisfy { $0.suggestionSource == .progression })
        #expect(spy.recorded.allSatisfy { $0.delayBucket == .immediate })
    }

    @Test @MainActor func anAISuggestionIsReportedAsSimilarity() throws {
        let context = try TestDataFactory.makeContext()
        let (_, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 1)
        let event = makeEvent(context: context, prescription: prescription, source: .ai)
        let spy = SpyOutcomes()

        acceptGroup(SuggestionGroup(event: event), rank: 1, context: context, outcomes: spy)

        #expect(spy.recorded.first?.suggestionSource == .similarity)
    }

    @Test @MainActor func aUserAuthoredSuggestionReportsNothing() throws {
        let context = try TestDataFactory.makeContext()
        let (_, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 1)
        let event = makeEvent(context: context, prescription: prescription, source: .user)
        let spy = SpyOutcomes()

        acceptGroup(SuggestionGroup(event: event), rank: 1, context: context, outcomes: spy)

        #expect(event.decision == .accepted)   // the app still records the decision
        #expect(spy.recorded.isEmpty)          // but the engine never made this suggestion
    }

    // MARK: - The resolver's verdict

    @Test @MainActor func aFollowedSuggestionIsReportedAcceptedWhenItResolves() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(
            context: context, workingSets: 1, targetWeight: 100, targetReps: 8, repRangeMode: .range, lowerRange: 6, upperRange: 10
        )
        let triggerSession = TestDataFactory.makeSession(context: context, daysAgo: 3)
        triggerSession.statusValue = .done
        let triggerPerf = TestDataFactory.makePerformance(
            context: context, session: triggerSession, prescription: prescription,
            sets: [(weight: 100, reps: 8, rest: 90, type: .working)]
        )
        let change = PrescriptionChange(changeType: .increaseWeight, previousValue: 100, newValue: 102.5)
        context.insert(change)
        let event = SuggestionEvent(
            category: .performance, catalogID: prescription.catalogID, sessionFrom: nil,
            targetExercisePrescription: prescription, targetSetPrescription: prescription.sortedSets.first,
            triggerTargetSetID: prescription.sortedSets.first?.id, triggerPerformance: triggerPerf,
            trainingStyle: .straightSets, createdAt: Date().addingTimeInterval(-172_800), changes: [change]
        )
        change.event = event
        context.insert(event)
        event.decision = .accepted

        let session = TestDataFactory.makeSession(context: context)
        session.workoutPlan = plan
        _ = TestDataFactory.makePerformance(
            context: context, session: session, prescription: prescription,
            sets: [(weight: 102.5, reps: 8, rest: 90, type: .working)]
        )
        let spy = SpyOutcomes()

        await OutcomeResolver.resolveOutcomes(for: session, context: context, outcomes: spy)

        #expect(event.outcome == .good)
        let outcome = try #require(spy.recorded.first)
        #expect(spy.recorded.count == 1)
        #expect(outcome.engine == .nextSet)
        #expect(outcome.outcome == .accepted)
        #expect(outcome.suggestionSource == .progression)
        #expect(outcome.rankPosition == 1)
        #expect(outcome.delayBucket == .day)
    }

    @Test @MainActor func anIgnoredSuggestionIsReportedAbandoned() async throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(
            context: context, workingSets: 1, targetWeight: 100, targetReps: 8, repRangeMode: .range, lowerRange: 6, upperRange: 10
        )
        let triggerSession = TestDataFactory.makeSession(context: context, daysAgo: 3)
        triggerSession.statusValue = .done
        let triggerPerf = TestDataFactory.makePerformance(
            context: context, session: triggerSession, prescription: prescription,
            sets: [(weight: 100, reps: 8, rest: 90, type: .working)]
        )
        let change = PrescriptionChange(changeType: .increaseWeight, previousValue: 100, newValue: 110)
        context.insert(change)
        let event = SuggestionEvent(
            category: .performance, catalogID: prescription.catalogID, sessionFrom: nil,
            targetExercisePrescription: prescription, targetSetPrescription: prescription.sortedSets.first,
            triggerTargetSetID: prescription.sortedSets.first?.id, triggerPerformance: triggerPerf,
            trainingStyle: .straightSets, createdAt: Date().addingTimeInterval(-3_600), changes: [change]
        )
        change.event = event
        context.insert(event)
        event.decision = .accepted

        let session = TestDataFactory.makeSession(context: context)
        session.workoutPlan = plan
        // The athlete never went near the suggested load.
        _ = TestDataFactory.makePerformance(
            context: context, session: session, prescription: prescription,
            sets: [(weight: 100, reps: 8, rest: 90, type: .working)]
        )
        let spy = SpyOutcomes()

        await OutcomeResolver.resolveOutcomes(for: session, context: context, outcomes: spy)

        #expect(event.outcome == .ignored)
        #expect(spy.recorded.map(\.outcome) == [.abandoned])
    }

    // MARK: - The translation itself

    @Test func theVocabularyMapsEveryOutcome() {
        #expect(Outcome.good.diagOutcome == .accepted)
        #expect(Outcome.tooAggressive.diagOutcome == .tooAggressive)
        #expect(Outcome.tooEasy.diagOutcome == .tooEasy)
        #expect(Outcome.ignored.diagOutcome == .abandoned)
        // The fleet has no value for either: reporting one would invent a verdict.
        #expect(Outcome.insufficient.diagOutcome == nil)
        #expect(Outcome.pending.diagOutcome == nil)
    }
}
