import FCTMetrics
import Foundation
import SwiftData
import Testing

@testable import VillainArc

/// The engine's verdict distribution: what Villain Arc concludes about its own suggestion once a
/// later workout grades it, sliced by what the suggestion proposed and by how much evidence it had.
///
/// The names are pinned verbatim because they are a wire vocabulary: `diag.counters.name` is free
/// text server-side, so nothing but this suite stops a rename from silently splitting one counter
/// into two series that no report will ever join back together.
@Suite(.serialized) struct SuggestionVerdictCounterTests {

    /// Captures what the resolver counted, in place of `Diag` (whose recorder sits in a
    /// process-wide slot with nothing to read it back).
    final class SpyVerdicts: SuggestionVerdictReporting, @unchecked Sendable {
        private let lock = NSLock()
        private var captured: [String] = []

        func count(_ counter: SuggestionVerdictCounter) {
            lock.lock()
            defer { lock.unlock() }
            captured.append(counter.diagName)
        }

        var names: [String] {
            lock.lock()
            defer { lock.unlock() }
            return captured
        }
    }

    // MARK: - The names themselves

    @Test func aKindSliceIsNamedForItsVerdictAndCategory() {
        #expect(SuggestionVerdictCounter(verdict: .good, category: .performance).diagName
            == "suggestion.verdict.good.kind.performance")
        #expect(SuggestionVerdictCounter(verdict: .tooAggressive, category: .recovery).diagName
            == "suggestion.verdict.too_aggressive.kind.recovery")
        #expect(SuggestionVerdictCounter(verdict: .insufficient, category: .repRangeConfiguration).diagName
            == "suggestion.verdict.insufficient.kind.repRangeConfiguration")
    }

    @Test func aRungSliceIsNamedForItsVerdictAndTier() {
        #expect(SuggestionVerdictCounter(verdict: .tooEasy, tier: .exploratory).diagName
            == "suggestion.verdict.too_easy.rung.exploratory")
        #expect(SuggestionVerdictCounter(verdict: .good, tier: .strong).diagName
            == "suggestion.verdict.good.rung.strong")
        #expect(SuggestionVerdictCounter(verdict: .ignored, tier: .moderate).diagName
            == "suggestion.verdict.ignored.rung.moderate")
    }

    /// Every name the type can produce, and nothing outside the two closed vocabularies can reach
    /// it: there is no initializer that takes text.
    @Test func theWholeVocabularyIsTwoClosedProducts() {
        let categories: [SuggestionCategory] = [.performance, .recovery, .structure, .repRangeConfiguration, .warmupCalibration, .volume]
        let tiers: [SuggestionConfidenceTier] = [.exploratory, .moderate, .strong]
        var names = Set<String>()
        for verdict in SuggestionVerdictCounter.Verdict.allCases {
            for category in categories { names.insert(SuggestionVerdictCounter(verdict: verdict, category: category).diagName) }
            for tier in tiers { names.insert(SuggestionVerdictCounter(verdict: verdict, tier: tier).diagName) }
        }
        // 5 verdicts x (6 kinds + 3 rungs), every one distinct.
        #expect(names.count == 45)
        #expect(names.allSatisfy { $0.hasPrefix("suggestion.verdict.") })
    }

    @Test func aPendingSuggestionHasNoVerdictToCount() {
        #expect(SuggestionVerdictCounter.Verdict(.pending) == nil)
        #expect(SuggestionVerdictCounter.Verdict(.insufficient) == .insufficient)
    }

    // MARK: - The resolver driving it for real

    @Test @MainActor func resolvingASuggestionCountsBothSlices() async throws {
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
            trainingStyle: .straightSets, createdAt: Date().addingTimeInterval(-172_800), changes: [change],
            suggestionConfidence: SuggestionConfidenceTier.strong.defaultScore
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
        let spy = SpyVerdicts()

        await OutcomeResolver.resolveOutcomes(for: session, context: context, verdicts: spy)

        #expect(event.outcome == .good)
        #expect(spy.names.sorted() == [
            "suggestion.verdict.good.kind.performance",
            "suggestion.verdict.good.rung.strong",
        ])
    }

    /// The half the outcome wire cannot carry. `.insufficient` reports no `AlgorithmOutcome` — the
    /// fleet vocabulary has no value for it — so if it were dropped here too, an engine whose
    /// evidence keeps failing to decide would read as an engine with nothing wrong.
    @Test @MainActor func anUndecidableVerdictStillCounts() async throws {
        let spy = SpyVerdicts()
        spy.record(verdict: .insufficient, category: .recovery, confidence: SuggestionConfidenceTier.exploratory.defaultScore)

        #expect(spy.names.sorted() == [
            "suggestion.verdict.insufficient.kind.recovery",
            "suggestion.verdict.insufficient.rung.exploratory",
        ])
    }

    @Test @MainActor func apendingVerdictCountsNothing() {
        let spy = SpyVerdicts()
        spy.record(verdict: .pending, category: .performance, confidence: 0.9)
        #expect(spy.names.isEmpty)
    }
}
