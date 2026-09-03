import AppIntents
import FCTMetrics
import Foundation
import Testing

@testable import VillainArc

/// Every App Intent reports its own run, and every one of them under a distinct name.
///
/// An intent is the code most likely to crash with nobody watching — no UI, often no running app,
/// and a store opened through the extension's own container — so an intent that reports nothing
/// arrives with a trail ending at whatever the person last did by hand.
///
/// The crumb is dropped by hand at the top of each `perform()` rather than by conforming to
/// `FCTEntities.ReportingAppIntent`: that protocol supplies `perform()` from an extension and
/// declares `run() -> Self.PerformResult`, and Swift does not infer `PerformResult` from a `run()`
/// whose return type is opaque — which every intent here has. Adopting it fails the conformance
/// outright (`protocol requires nested type 'PerformResult'`), so the manual form is what reports.
@Suite struct IntentCrumbCoverageTests {

    /// The name each intent travels under, sampled across every intent family, so a rename that
    /// splits one intent's history into two series fails here rather than in the report.
    @Test func everyIntentFamilyNamesItself() {
        #expect(StartWorkoutIntent.diagCrumb.diagName == VACrumb.intentStartWorkout.diagName)
        #expect(StartCardioSessionIntent.diagCrumb.diagName == VACrumb.intentStartCardioSession.diagName)
        #expect(AddWeightEntryIntent.diagCrumb.diagName == VACrumb.intentAddWeightEntry.diagName)
        #expect(CreateWorkoutPlanIntent.diagCrumb.diagName == VACrumb.intentCreateWorkoutPlan.diagName)
        #expect(CreateWorkoutSplitIntent.diagCrumb.diagName == VACrumb.intentCreateWorkoutSplit.diagName)
        #expect(OpenExerciseIntent.diagCrumb.diagName == VACrumb.intentOpenExercise.diagName)
        #expect(StartRestTimerIntent.diagCrumb.diagName == VACrumb.intentStartRestTimer.diagName)
        #expect(LiveActivityCompleteSetIntent.diagCrumb.diagName == VACrumb.intentLiveActivityCompleteSet.diagName)
    }

    /// A name is what the fleet groups on, so two intents sharing one would report as one intent.
    @Test func everyCrumbNameIsDistinct() {
        let names = VACrumb.allCases.map(\.diagName)
        #expect(Set(names).count == names.count)
    }

    /// Every intent crumb is spelled `intent.*`, which is what separates a run of code with nobody
    /// watching from a screen the person was looking at when the trail is read.
    @Test func intentCrumbsAreNamespaced() {
        let intentCases = VACrumb.allCases.filter { $0.diagName.hasPrefix("intent.") }
        #expect(intentCases.count >= 115)
    }
}
