import Foundation
import SwiftData
import Testing

@testable import VillainArc

// Tests for the originalTargetSetID UUID tracking system.
//
// Core invariant: each SetPerformance created from a plan stores the SetPrescription.id
// as originalTargetSetID, and that UUID is immune to prescription reindexing caused
// by warmup add/remove operations. This makes all historical matching in RuleEngine
// correct even after the working-set indices shift.
//
struct UUIDTargetTrackingTests {
    @MainActor private func flattenedChanges(from drafts: [SuggestionEventDraft]) -> [(draft: SuggestionEventDraft, change: PrescriptionChangeDraft)] { drafts.flatMap { draft in draft.changes.map { (draft: draft, change: $0) } } }

    // MARK: - Invariant: UUID set at creation

    @Test @MainActor func originalTargetSetID_isSetFromPrescriptionIDAtSessionCreation() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 3, targetWeight: 100, targetReps: 8, targetRest: 90, repRangeMode: .target)
        prescription.repRange?.targetReps = 8

        let session = WorkoutSession(from: plan)
        context.insert(session)

        guard let performance = session.sortedExercises.first, performance.sortedSets.count == 3 else {
            Issue.record("Expected plan-backed performance with 3 sets.")
            return
        }

        let prescriptionSets = prescription.sortedSets
        let performanceSets = performance.sortedSets

        // Every set must carry the UUID of the prescription slot it was built from.
        #expect(performanceSets[0].originalTargetSetID == prescriptionSets[0].id)
        #expect(performanceSets[1].originalTargetSetID == prescriptionSets[1].id)
        #expect(performanceSets[2].originalTargetSetID == prescriptionSets[2].id)
    }

    // MARK: - Invariant: UUID survives clearPrescriptionLinksForHistoricalUse

    @Test @MainActor func originalTargetSetID_survivesAfterPrescriptionLinksAreCleared() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 2, targetWeight: 100, targetReps: 8, targetRest: 90, repRangeMode: .range, lowerRange: 8, upperRange: 10)

        let session = WorkoutSession(from: plan)
        context.insert(session)

        guard let performance = session.sortedExercises.first, performance.sortedSets.count == 2 else {
            Issue.record("Expected plan-backed performance with 2 sets.")
            return
        }

        let capturedIDs = prescription.sortedSets.map(\.id)

        // Confirm UUIDs are set before any clearing.
        #expect(performance.sortedSets[0].originalTargetSetID == capturedIDs[0])
        #expect(performance.sortedSets[1].originalTargetSetID == capturedIDs[1])

        session.clearPrescriptionLinksForHistoricalUse()

        // Live prescription links must be nil after clearing.
        #expect(performance.sortedSets[0].prescription == nil)
        #expect(performance.sortedSets[1].prescription == nil)

        // UUIDs must be unchanged — the stability guarantee.
        #expect(performance.sortedSets[0].originalTargetSetID == capturedIDs[0])
        #expect(performance.sortedSets[1].originalTargetSetID == capturedIDs[1])

        // The frozen exercise-level snapshot must carry matching UUIDs.
        let snapshotSets = performance.originalTargetSnapshot?.sets.sorted { $0.index < $1.index }
        #expect(snapshotSets?[0].targetSetID == capturedIDs[0])
        #expect(snapshotSets?[1].targetSetID == capturedIDs[1])
    }

    // MARK: - UUID matching survives warmup-add reindex

    @Test @MainActor func originalTargetSetID_matchesCorrectPrescriptionAfterWarmupAddShiftsWorkingSetIndices() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 2, targetWeight: 100, targetReps: 8, targetRest: 90, repRangeMode: .range, lowerRange: 8, upperRange: 10)

        // Capture working-set IDs before any mutation.
        let w1ID = prescription.sortedSets[0].id  // currently index 0
        let w2ID = prescription.sortedSets[1].id  // currently index 1

        // Historical session built with original 2-set layout.
        let histSession = WorkoutSession(from: plan)
        context.insert(histSession)
        guard let histPerf = histSession.sortedExercises.first, histPerf.sortedSets.count == 2 else {
            Issue.record("Expected historical performance with 2 sets.")
            return
        }

        // UUIDs are tracked at creation.
        #expect(histPerf.sortedSets[0].originalTargetSetID == w1ID)
        #expect(histPerf.sortedSets[1].originalTargetSetID == w2ID)

        histSession.clearPrescriptionLinksForHistoricalUse()

        // UUIDs survive the clear.
        #expect(histPerf.sortedSets[0].prescription == nil)
        #expect(histPerf.sortedSets[0].originalTargetSetID == w1ID)
        #expect(histPerf.sortedSets[1].originalTargetSetID == w2ID)

        // Simulate warmup add: give WU index -1 so sortedSets places it first,
        // then reindexSets() normalizes to WU=0, W1=1, W2=2.
        let warmup = SetPrescription(exercisePrescription: prescription, setType: .warmup, targetWeight: 40, targetReps: 10, targetRest: 60, index: -1)
        prescription.sets?.append(warmup)
        prescription.reindexSets()

        #expect(prescription.sortedSets.count == 3)
        #expect(prescription.sortedSets[0].type == .warmup)
        #expect(prescription.sortedSets[1].id == w1ID)  // W1 shifted to index 1
        #expect(prescription.sortedSets[2].id == w2ID)  // W2 shifted to index 2

        // Historical UUIDs remain correct — unaffected by the prescription mutation.
        #expect(histPerf.sortedSets[0].originalTargetSetID == w1ID)
        #expect(histPerf.sortedSets[1].originalTargetSetID == w2ID)
    }

    // MARK: - New warmup has no historical match

    @Test @MainActor func matchingSetPerformance_returnsNilForNewWarmupWithNoHistoricalEvidence() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 2, targetWeight: 100, targetReps: 8, targetRest: 90, repRangeMode: .range, lowerRange: 6, upperRange: 12)

        // Historical session existed BEFORE the warmup was added.
        let histSession = WorkoutSession(from: plan)
        context.insert(histSession)
        guard let histPerf = histSession.sortedExercises.first, histPerf.sortedSets.count == 2 else {
            Issue.record("Expected historical performance with 2 sets.")
            return
        }
        for set in histPerf.sortedSets {
            set.weight = 100
            set.reps = 9
            set.complete = true
        }
        histSession.clearPrescriptionLinksForHistoricalUse()

        // Add warmup AFTER the historical session was completed.
        let warmup = SetPrescription(exercisePrescription: prescription, setType: .warmup, targetWeight: 40, targetReps: 10, targetRest: 60, index: -1)
        prescription.sets?.append(warmup)
        prescription.reindexSets()
        let warmupPrescriptionID = warmup.id

        // Current session now has 3 sets.
        let currentSession = WorkoutSession(from: plan)
        context.insert(currentSession)
        guard let currentPerf = currentSession.sortedExercises.first, currentPerf.sortedSets.count == 3 else {
            Issue.record("Expected current performance with 3 sets (WU + 2 working).")
            return
        }
        for set in currentPerf.sortedSets {
            set.weight = set.type == .warmup ? 40 : 100
            set.reps = set.type == .warmup ? 10 : 9
            set.complete = true
        }

        let suggestionContext = ExerciseSuggestionContext(session: currentSession, performance: currentPerf, prescription: prescription, history: [histPerf], plan: plan, resolvedTrainingStyle: .straightSets, weightUnit: .kg)
        let suggestions = RuleEngine.evaluate(context: suggestionContext)

        // warmupActingLikeWorkingSet and calibrateWarmupWeights both need 2 sessions of warmup
        // data — the new warmup has zero historical evidence so neither should fire for it.
        let warmupSetChanges = flattenedChanges(from: suggestions).filter { $0.draft.targetSetPrescription?.id == warmupPrescriptionID }
        #expect(warmupSetChanges.isEmpty, "No rule should fire for a warmup set that has no historical performance.")
    }

    // MARK: - confirmedProgressionRange fires for the right sets after warmup-add reindex

    @Test @MainActor func confirmedProgressionRange_firesForCorrectSetsAfterWarmupAddShiftsWorkingSetIndices() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, catalogID: "machine_chest_press", workingSets: 2, targetWeight: 100, targetReps: 8, targetRest: 90, repRangeMode: .range, lowerRange: 8, upperRange: 10)

        let w1ID = prescription.sortedSets[0].id
        let w2ID = prescription.sortedSets[1].id

        // Historical session (2-set layout). Both working sets hit upper-1 (9 reps).
        let histSession = WorkoutSession(from: plan)
        context.insert(histSession)
        guard let histPerf = histSession.sortedExercises.first, histPerf.sortedSets.count == 2 else {
            Issue.record("Expected historical performance with 2 sets.")
            return
        }
        histPerf.sortedSets[0].weight = 100
        histPerf.sortedSets[0].reps = 9
        histPerf.sortedSets[0].complete = true
        histPerf.sortedSets[1].weight = 100
        histPerf.sortedSets[1].reps = 9
        histPerf.sortedSets[1].complete = true
        histSession.clearPrescriptionLinksForHistoricalUse()

        // Add warmup: W1 shifts to index 1, W2 shifts to index 2.
        let warmup = SetPrescription(exercisePrescription: prescription, setType: .warmup, targetWeight: 40, targetReps: 10, targetRest: 60, index: -1)
        prescription.sets?.append(warmup)
        prescription.reindexSets()

        // Current session (3-set layout: WU@idx0, W1@idx1, W2@idx2).
        let currentSession = WorkoutSession(from: plan)
        context.insert(currentSession)
        guard let currentPerf = currentSession.sortedExercises.first, currentPerf.sortedSets.count == 3 else {
            Issue.record("Expected current performance with 3 sets.")
            return
        }
        let cSets = currentPerf.sortedSets
        cSets[0].weight = 40
        cSets[0].reps = 10
        cSets[0].complete = true  // WU
        cSets[1].weight = 100
        cSets[1].reps = 9
        cSets[1].complete = true  // W1
        cSets[2].weight = 100
        cSets[2].reps = 9
        cSets[2].complete = true  // W2

        let suggestionContext = ExerciseSuggestionContext(session: currentSession, performance: currentPerf, prescription: prescription, history: [histPerf], plan: plan, resolvedTrainingStyle: .straightSets, weightUnit: .kg)
        let suggestions = RuleEngine.evaluate(context: suggestionContext)
        let weightChanges = flattenedChanges(from: suggestions).filter { $0.change.changeType == .increaseWeight }

        // Confirmed progression must fire for both working sets, correctly identified by UUID
        // even though their indices shifted from 0,1 to 1,2 after the warmup was inserted.
        let changeIDs = Set(weightChanges.compactMap { $0.draft.targetSetPrescription?.id })
        #expect(changeIDs.contains(w1ID), "Progression should fire for W1 via UUID-matched historical evidence.")
        #expect(changeIDs.contains(w2ID), "Progression should fire for W2 via UUID-matched historical evidence.")

        let changeIndices = Set(weightChanges.compactMap { $0.draft.targetSetPrescription?.index })
        #expect(changeIndices.contains(1), "W1 is now at prescription index 1 after reindex.")
        #expect(changeIndices.contains(2), "W2 is now at prescription index 2 after reindex.")
        #expect(!changeIndices.contains(0), "Warmup at index 0 must not receive a weight progression event.")
    }

    // MARK: - setTypeMismatch detects consistent mismatch after warmup-add reindex

    @Test @MainActor func setTypeMismatch_detectsConsistentMismatchAfterWarmupAddReindex() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 2, targetWeight: 100, targetReps: 8, targetRest: 90, repRangeMode: .target)
        prescription.repRange?.targetReps = 8

        // W1 is prescribed as .working. User consistently logs it as .warmup — a type mismatch.
        let w1ID = prescription.sortedSets[0].id
        let w2ID = prescription.sortedSets[1].id

        // Historical session: user logs W1 as .warmup.
        let histSession = WorkoutSession(from: plan)
        context.insert(histSession)
        guard let histPerf = histSession.sortedExercises.first, histPerf.sortedSets.count == 2 else {
            Issue.record("Expected historical performance with 2 sets.")
            return
        }
        histPerf.sortedSets[0].type = .warmup
        histPerf.sortedSets[0].weight = 60
        histPerf.sortedSets[0].reps = 8
        histPerf.sortedSets[0].complete = true
        histPerf.sortedSets[1].type = .working
        histPerf.sortedSets[1].weight = 100
        histPerf.sortedSets[1].reps = 8
        histPerf.sortedSets[1].complete = true
        histSession.clearPrescriptionLinksForHistoricalUse()

        // Add a warmup to prescription → W1 shifts from index 0 to 1, W2 from 1 to 2.
        let newWarmup = SetPrescription(exercisePrescription: prescription, setType: .warmup, targetWeight: 30, targetReps: 12, targetRest: 45, index: -1)
        prescription.sets?.append(newWarmup)
        prescription.reindexSets()

        // Current session from the updated 3-set prescription. User again logs W1 as .warmup.
        let currentSession = WorkoutSession(from: plan)
        context.insert(currentSession)
        guard let currentPerf = currentSession.sortedExercises.first, currentPerf.sortedSets.count == 3 else {
            Issue.record("Expected current performance with 3 sets.")
            return
        }
        let cSets = currentPerf.sortedSets
        cSets[0].type = .warmup
        cSets[0].weight = 30
        cSets[0].reps = 12
        cSets[0].complete = true  // new WU
        cSets[1].type = .warmup
        cSets[1].weight = 60
        cSets[1].reps = 8
        cSets[1].complete = true  // W1 (again as warmup)
        cSets[2].type = .working
        cSets[2].weight = 100
        cSets[2].reps = 8
        cSets[2].complete = true  // W2

        let suggestionContext = ExerciseSuggestionContext(session: currentSession, performance: currentPerf, prescription: prescription, history: [histPerf], plan: plan, resolvedTrainingStyle: .straightSets, weightUnit: .kg)
        let suggestions = RuleEngine.evaluate(context: suggestionContext)
        let typeChanges = flattenedChanges(from: suggestions).filter { $0.change.changeType == .changeSetType }

        // setTypeMismatch should detect W1 (prescribed as .working) was logged as .warmup
        // in both sessions. UUID-based historical matching bridges the reindex correctly.
        let mismatchForW1 = typeChanges.first(where: { $0.draft.targetSetPrescription?.id == w1ID })
        #expect(mismatchForW1 != nil, "setTypeMismatch should fire for W1 — UUID matching spans the index shift.")
        if let m = mismatchForW1 {
            #expect(m.change.previousValue == Double(ExerciseSetType.working.rawValue))
            #expect(m.change.newValue == Double(ExerciseSetType.warmup.rawValue))
        }

        // W2 was correctly logged as .working in both sessions — no mismatch.
        let mismatchForW2 = typeChanges.first(where: { $0.draft.targetSetPrescription?.id == w2ID })
        #expect(mismatchForW2 == nil, "W2 was logged correctly — no mismatch expected.")
    }

    @Test @MainActor func setTypeMismatch_requiresThreeSessionsForDropSetReclassification() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, workingSets: 1, targetWeight: 100, targetReps: 8, targetRest: 90, repRangeMode: .target)
        prescription.repRange?.targetReps = 8
        prescription.sortedSets[0].type = .dropSet

        let histSession = WorkoutSession(from: plan)
        context.insert(histSession)
        guard let histPerf = histSession.sortedExercises.first, histPerf.sortedSets.count == 1 else {
            Issue.record("Expected historical performance with 1 set.")
            return
        }
        histPerf.sortedSets[0].type = .working
        histPerf.sortedSets[0].weight = 100
        histPerf.sortedSets[0].reps = 8
        histPerf.sortedSets[0].complete = true
        histSession.clearPrescriptionLinksForHistoricalUse()

        let currentSession = WorkoutSession(from: plan)
        context.insert(currentSession)
        guard let currentPerf = currentSession.sortedExercises.first, currentPerf.sortedSets.count == 1 else {
            Issue.record("Expected current performance with 1 set.")
            return
        }
        currentPerf.sortedSets[0].type = .working
        currentPerf.sortedSets[0].weight = 100
        currentPerf.sortedSets[0].reps = 8
        currentPerf.sortedSets[0].complete = true

        let suggestionContext = ExerciseSuggestionContext(session: currentSession, performance: currentPerf, prescription: prescription, history: [histPerf], plan: plan, resolvedTrainingStyle: .straightSets, weightUnit: .kg)
        let suggestions = RuleEngine.evaluate(context: suggestionContext)
        let typeChanges = flattenedChanges(from: suggestions).filter { $0.change.changeType == .changeSetType }

        #expect(typeChanges.isEmpty, "Drop-set reclassification should need 3 sessions of consistent evidence, not 2")
    }

    // MARK: - belowRangeWeightDecrease resolves target weight from snapshot UUID after reindex

    @Test @MainActor func historicalTargetWeightLookup_usesSnapshotUUIDToConfirmAttemptedLoadAfterWarmupAddReindex() throws {
        let context = try TestDataFactory.makeContext()
        // Single working set. User repeatedly fails to hit the lower rep bound.
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, catalogID: "machine_chest_press", workingSets: 1, targetWeight: 100, targetReps: 8, targetRest: 90, repRangeMode: .range, lowerRange: 8, upperRange: 10)

        let w1ID = prescription.sortedSets[0].id

        // Session 1 (before warmup add): W1 attempted at prescribed 100 kg, only 5 reps (< lower=8).
        let session1 = WorkoutSession(from: plan)
        context.insert(session1)
        guard let perf1 = session1.sortedExercises.first, let set1 = perf1.sortedSets.first else {
            Issue.record("Expected perf1.")
            return
        }
        set1.weight = 100
        set1.reps = 5
        set1.complete = true
        session1.clearPrescriptionLinksForHistoricalUse()

        // Add warmup: W1 shifts from index 0 to index 1.
        let warmup = SetPrescription(exercisePrescription: prescription, setType: .warmup, targetWeight: 50, targetReps: 10, targetRest: 60, index: -1)
        prescription.sets?.append(warmup)
        prescription.reindexSets()

        // Session 2 (after warmup add): WU done, W1 again fails at 100 kg with 5 reps.
        let session2 = WorkoutSession(from: plan)
        context.insert(session2)
        guard let perf2 = session2.sortedExercises.first, perf2.sortedSets.count == 2 else {
            Issue.record("Expected perf2 with 2 sets.")
            return
        }
        perf2.sortedSets[0].weight = 50
        perf2.sortedSets[0].reps = 10
        perf2.sortedSets[0].complete = true  // WU
        perf2.sortedSets[1].weight = 100
        perf2.sortedSets[1].reps = 5
        perf2.sortedSets[1].complete = true  // W1
        session2.clearPrescriptionLinksForHistoricalUse()

        // Current session: user still cannot hit reps at the prescribed load.
        let currentSession = WorkoutSession(from: plan)
        context.insert(currentSession)
        guard let currentPerf = currentSession.sortedExercises.first, currentPerf.sortedSets.count == 2 else {
            Issue.record("Expected current performance with 2 sets.")
            return
        }
        currentPerf.sortedSets[0].weight = 50
        currentPerf.sortedSets[0].reps = 10
        currentPerf.sortedSets[0].complete = true
        currentPerf.sortedSets[1].weight = 100
        currentPerf.sortedSets[1].reps = 5
        currentPerf.sortedSets[1].complete = true

        let suggestionContext = ExerciseSuggestionContext(session: currentSession, performance: currentPerf, prescription: prescription, history: [perf2, perf1], plan: plan, resolvedTrainingStyle: .straightSets, weightUnit: .kg)
        let suggestions = RuleEngine.evaluate(context: suggestionContext)
        let weightDecrease = flattenedChanges(from: suggestions).first(where: { $0.change.changeType == .decreaseWeight })

        // belowRangeWeightDecrease fires only when it can confirm the user was attempting the
        // prescribed load (via historicalOrCurrentTargetSet). With W1's index shifted 0→1,
        // the rule must use UUID-based snapshot lookup to find targetWeight=100 in perf1
        // and perf2's snapshots. Both sessions confirm the user attempted 100 kg.
        #expect(weightDecrease != nil, "belowRangeWeightDecrease should fire — UUID snapshot lookup confirms prescribed load across the reindex.")
        #expect(weightDecrease?.draft.targetSetPrescription?.id == w1ID)
        #expect(weightDecrease?.change.previousValue == 100)
    }

    // MARK: - Double reindex (add warmup → remove warmup) leaves UUID matching intact

    @Test @MainActor func doubleReindex_UUIDMatchingUnbrokenAfterAddWarmupThenRemoveWarmup() throws {
        let context = try TestDataFactory.makeContext()
        let (plan, prescription) = TestDataFactory.makePrescription(context: context, catalogID: "machine_chest_press", workingSets: 2, targetWeight: 100, targetReps: 8, targetRest: 90, repRangeMode: .range, lowerRange: 8, upperRange: 10)

        let w1ID = prescription.sortedSets[0].id
        let w2ID = prescription.sortedSets[1].id

        // Phase 1: session with original 2-set layout (W1@idx0, W2@idx1).
        let session1 = WorkoutSession(from: plan)
        context.insert(session1)
        guard let perf1 = session1.sortedExercises.first, perf1.sortedSets.count == 2 else {
            Issue.record("Expected perf1 with 2 sets.")
            return
        }
        perf1.sortedSets[0].weight = 100
        perf1.sortedSets[0].reps = 9
        perf1.sortedSets[0].complete = true
        perf1.sortedSets[1].weight = 100
        perf1.sortedSets[1].reps = 9
        perf1.sortedSets[1].complete = true
        session1.clearPrescriptionLinksForHistoricalUse()

        // Phase 2: add warmup → W1@idx1, W2@idx2.
        let warmup = SetPrescription(exercisePrescription: prescription, setType: .warmup, targetWeight: 40, targetReps: 10, targetRest: 60, index: -1)
        prescription.sets?.append(warmup)
        prescription.reindexSets()

        let session2 = WorkoutSession(from: plan)
        context.insert(session2)
        guard let perf2 = session2.sortedExercises.first, perf2.sortedSets.count == 3 else {
            Issue.record("Expected perf2 with 3 sets.")
            return
        }
        perf2.sortedSets[0].weight = 40
        perf2.sortedSets[0].reps = 10
        perf2.sortedSets[0].complete = true  // WU
        perf2.sortedSets[1].weight = 100
        perf2.sortedSets[1].reps = 9
        perf2.sortedSets[1].complete = true  // W1
        perf2.sortedSets[2].weight = 100
        perf2.sortedSets[2].reps = 9
        perf2.sortedSets[2].complete = true  // W2
        session2.clearPrescriptionLinksForHistoricalUse()

        // Verify first reindex did not corrupt historical UUIDs.
        #expect(perf1.sortedSets[0].originalTargetSetID == w1ID)
        #expect(perf1.sortedSets[1].originalTargetSetID == w2ID)
        #expect(perf2.sortedSets[1].originalTargetSetID == w1ID)
        #expect(perf2.sortedSets[2].originalTargetSetID == w2ID)

        // Phase 3: remove warmup → W1@idx0, W2@idx1 (back to original layout).
        guard let warmupToDelete = prescription.sortedSets.first(where: { $0.type == .warmup }) else {
            Issue.record("Warmup set not found.")
            return
        }
        prescription.deleteSet(warmupToDelete)

        #expect(prescription.sortedSets.count == 2)
        #expect(prescription.sortedSets[0].id == w1ID)
        #expect(prescription.sortedSets[1].id == w2ID)

        // Phase 4: current session with restored 2-set layout. Both sets hit upper-1 again.
        let currentSession = WorkoutSession(from: plan)
        context.insert(currentSession)
        guard let currentPerf = currentSession.sortedExercises.first, currentPerf.sortedSets.count == 2 else {
            Issue.record("Expected current performance with 2 sets.")
            return
        }
        currentPerf.sortedSets[0].weight = 100
        currentPerf.sortedSets[0].reps = 9
        currentPerf.sortedSets[0].complete = true
        currentPerf.sortedSets[1].weight = 100
        currentPerf.sortedSets[1].reps = 9
        currentPerf.sortedSets[1].complete = true

        let suggestionContext = ExerciseSuggestionContext(session: currentSession, performance: currentPerf, prescription: prescription, history: [perf2, perf1], plan: plan, resolvedTrainingStyle: .straightSets, weightUnit: .kg)
        let suggestions = RuleEngine.evaluate(context: suggestionContext)
        let weightChanges = flattenedChanges(from: suggestions).filter { $0.change.changeType == .increaseWeight }

        // After both reindexes, confirmed progression must fire for exactly W1 and W2.
        let changeIDs = Set(weightChanges.compactMap { $0.draft.targetSetPrescription?.id })
        #expect(changeIDs.contains(w1ID), "UUID matching must find W1 evidence across the double reindex.")
        #expect(changeIDs.contains(w2ID), "UUID matching must find W2 evidence across the double reindex.")
        #expect(weightChanges.count == 2, "Exactly 2 progression events expected — one per working set.")
    }
}
