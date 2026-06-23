import SwiftData
import Testing

@testable import VillainArc

/// Drift detection for completed workouts must work off `workoutPlan` + catalogID, because
/// `clearPrescriptionLinksForHistoricalUse()` nils the live `ExercisePerformance.prescription` link
/// at finish. Every test here clears that link first to exercise the real completed-state path.
@Suite(.serialized) struct CompletedWorkoutNotesSyncTests {

    @MainActor
    private func makeCompletedPlanLinkedSession(
        context: ModelContext,
        planNotes: String,
        exercisePrescriptionNotes: String,
        workoutNotes: String,
        exerciseNotes: String
    ) -> (WorkoutSession, ExercisePerformance) {
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 1)
        plan.notes = planNotes
        prescription.notes = exercisePrescriptionNotes

        let session = TestDataFactory.makeSession(context: context)
        session.workoutPlan = plan
        session.statusValue = .done
        session.notes = workoutNotes
        let perf = TestDataFactory.makePerformance(context: context, session: session, prescription: prescription, sets: [(weight: 100, reps: 8, rest: 90, type: .working)])
        perf.notes = exerciseNotes

        // Simulate finish: the live prescription link is gone on a completed workout.
        for set in perf.sortedSets { set.prescription = nil }
        perf.prescription = nil
        return (session, perf)
    }

    @Test @MainActor func driftedPlanNotes_returnsPlanNotes_whenWorkoutNotesDiffer() throws {
        let context = try TestDataFactory.makeContext()
        let (session, _) = makeCompletedPlanLinkedSession(context: context, planNotes: "Plan: tempo work.", exercisePrescriptionNotes: "", workoutNotes: "Felt strong.", exerciseNotes: "")

        #expect(CompletedWorkoutNotesSync.driftedPlanNotes(for: session) == "Plan: tempo work.")
    }

    @Test @MainActor func driftedPlanNotes_returnsNil_whenInSync() throws {
        let context = try TestDataFactory.makeContext()
        let (session, _) = makeCompletedPlanLinkedSession(context: context, planNotes: "Same notes.", exercisePrescriptionNotes: "", workoutNotes: "Same notes.", exerciseNotes: "")

        #expect(CompletedWorkoutNotesSync.driftedPlanNotes(for: session) == nil)
    }

    @Test @MainActor func driftedPlanNotes_ignoresWhitespaceOnlyDifference() throws {
        let context = try TestDataFactory.makeContext()
        let (session, _) = makeCompletedPlanLinkedSession(context: context, planNotes: "  Trimmed.  ", exercisePrescriptionNotes: "", workoutNotes: "Trimmed.", exerciseNotes: "")

        #expect(CompletedWorkoutNotesSync.driftedPlanNotes(for: session) == nil)
    }

    @Test @MainActor func driftedPlanNotes_returnsNil_whenNoPlanLink() throws {
        let context = try TestDataFactory.makeContext()
        let (_, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 1)
        let session = TestDataFactory.makeSession(context: context)
        session.statusValue = .done
        session.notes = "Free workout."
        _ = TestDataFactory.makePerformance(context: context, session: session, prescription: prescription, sets: [(weight: 100, reps: 8, rest: 90, type: .working)])

        #expect(CompletedWorkoutNotesSync.driftedPlanNotes(for: session) == nil)
    }

    @Test @MainActor func driftedPrescriptionNotes_matchesByCatalogID_afterLinkCleared() throws {
        let context = try TestDataFactory.makeContext()
        let (session, perf) = makeCompletedPlanLinkedSession(context: context, planNotes: "", exercisePrescriptionNotes: "Plan: pause at chest.", workoutNotes: "", exerciseNotes: "Forgot the pause.")

        #expect(perf.prescription == nil)  // confirms we're on the completed path
        #expect(CompletedWorkoutNotesSync.driftedPrescriptionNotes(for: perf, in: session) == "Plan: pause at chest.")
    }

    @Test @MainActor func driftedPrescriptionNotes_returnsNil_whenInSync() throws {
        let context = try TestDataFactory.makeContext()
        let (session, perf) = makeCompletedPlanLinkedSession(context: context, planNotes: "", exercisePrescriptionNotes: "Pause at chest.", workoutNotes: "", exerciseNotes: "Pause at chest.")

        #expect(CompletedWorkoutNotesSync.driftedPrescriptionNotes(for: perf, in: session) == nil)
    }

    @Test @MainActor func driftedPrescriptionNotes_returnsNil_whenNoMatchingCatalogID() throws {
        let context = try TestDataFactory.makeContext()
        // Plan prescription is bench; the performance is a different catalog id → no match.
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, catalogID: "barbell_bench_press", workingSets: 1)
        prescription.notes = "Bench cue."
        let session = TestDataFactory.makeSession(context: context)
        session.workoutPlan = plan
        session.statusValue = .done

        let (_, squatPrescription) = TestDataFactory.makePrescription(context: context, catalogID: "barbell_squat", workingSets: 1)
        let perf = TestDataFactory.makePerformance(context: context, session: session, prescription: squatPrescription, sets: [(weight: 100, reps: 8, rest: 90, type: .working)])
        perf.prescription = nil

        #expect(CompletedWorkoutNotesSync.driftedPrescriptionNotes(for: perf, in: session) == nil)
    }

    @Test @MainActor func hasAnyDrift_trueWhenEitherLevelDrifts() throws {
        let context = try TestDataFactory.makeContext()
        let (session, _) = makeCompletedPlanLinkedSession(context: context, planNotes: "", exercisePrescriptionNotes: "Plan cue.", workoutNotes: "", exerciseNotes: "Different.")

        #expect(CompletedWorkoutNotesSync.hasAnyDrift(in: session))
    }

    @Test @MainActor func hasAnyDrift_falseWhenFullyInSync() throws {
        let context = try TestDataFactory.makeContext()
        let (session, _) = makeCompletedPlanLinkedSession(context: context, planNotes: "P.", exercisePrescriptionNotes: "E.", workoutNotes: "P.", exerciseNotes: "E.")

        #expect(CompletedWorkoutNotesSync.hasAnyDrift(in: session) == false)
    }
}
