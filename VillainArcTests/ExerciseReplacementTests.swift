import Foundation
import SwiftData
import Testing
@testable import VillainArc

struct ExerciseReplacementTests {
    @Test @MainActor
    // Starting a workout from a plan should prefill set values from each target set.
    func startFromPlanCopiesTargetValuesIntoSetPerformance() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)
        
        let plan = WorkoutPlan(title: "Pull Day")
        context.insert(plan)
        
        let row = Exercise(from: ExerciseCatalog.byID["barbell_bent_over_row"]!)
        let prescription = ExercisePrescription(exercise: row, workoutPlan: plan)
        prescription.repRange?.activeMode = .range
        prescription.repRange?.lowerRange = 6
        prescription.repRange?.upperRange = 10
        prescription.sets = [
            SetPrescription(exercisePrescription: prescription, setType: .warmup, targetWeight: 95, targetReps: 10, targetRest: 60, targetRPE: 0, index: 0),
            SetPrescription(exercisePrescription: prescription, setType: .working, targetWeight: 135, targetReps: 8, targetRest: 90, targetRPE: 8, index: 1)
        ]
        plan.exercises = [prescription]
        
        let session = WorkoutSession(from: plan)
        context.insert(session)
        
        guard let performance = session.sortedExercises.first else {
            Issue.record("Expected one exercise in the session")
            return
        }
        let sets = performance.sortedSets
        let snapshot = performance.originalTargetSnapshot
        #expect(prescription.activePerformance?.id == performance.id)
        #expect(prescription.sortedSets[0].activePerformance?.id == sets[0].id)
        #expect(prescription.sortedSets[1].activePerformance?.id == sets[1].id)
        #expect(sets.count == 2)
        #expect(sets[0].weight == 95)
        #expect(sets[0].reps == 10)
        #expect(sets[1].weight == 135)
        #expect(sets[1].reps == 8)
        #expect(snapshot?.repRange.mode == .range)
        #expect(snapshot?.repRange.lower == 6)
        #expect(snapshot?.repRange.upper == 10)
        #expect(snapshot?.sets.count == 2)
        #expect(snapshot?.sets[0].targetWeight == 95)
        #expect(snapshot?.sets[0].targetReps == 10)
        #expect(snapshot?.sets[0].targetRest == 60)
        #expect(snapshot?.sets[0].targetRPE == 0)
        #expect(snapshot?.sets[1].targetWeight == 135)
        #expect(snapshot?.sets[1].targetReps == 8)
        #expect(snapshot?.sets[1].targetRest == 90)
        #expect(snapshot?.sets[1].targetRPE == 8)
    }
    
    @Test @MainActor
    // Freeform exercises should not invent an original target snapshot.
    func freeformExerciseStartsWithoutOriginalTargetSnapshot() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)
        
        let session = WorkoutSession()
        context.insert(session)
        
        let bench = Exercise(from: ExerciseCatalog.byID["barbell_bench_press"]!)
        let performance = ExercisePerformance(exercise: bench, workoutSession: session)
        context.insert(performance)
        
        #expect(performance.originalTargetSnapshot == nil)
    }
    
    @Test @MainActor
    // Replacing an exercise should detach all plan targets from the current performance.
    func replaceExerciseClearsExerciseAndSetPrescriptions() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)
        
        let plan = WorkoutPlan(title: "Push Day")
        context.insert(plan)
        
        let bench = Exercise(from: ExerciseCatalog.byID["barbell_bench_press"]!)
        let replacement = Exercise(from: ExerciseCatalog.byID["barbell_incline_bench_press"]!)
        
        let prescription = ExercisePrescription(exercise: bench, workoutPlan: plan)
        let setPrescription = SetPrescription(
            exercisePrescription: prescription,
            setType: .working,
            targetWeight: 185,
            targetReps: 8,
            targetRest: 120,
            index: 0
        )
        prescription.sets = [setPrescription]
        plan.exercises = [prescription]
        
        let session = WorkoutSession(from: plan)
        context.insert(session)
        
        guard let performance = session.sortedExercises.first else {
            Issue.record("Expected one exercise in the session")
            return
        }
        
        #expect(performance.prescription != nil)
        #expect(performance.originalTargetSnapshot != nil)
        #expect(performance.sortedSets.isEmpty == false)
        #expect(performance.sortedSets.allSatisfy { $0.prescription != nil })
        
        performance.replaceWith(replacement, keepSets: true)
        
        #expect(performance.catalogID == replacement.catalogID)
        #expect(performance.prescription == nil)
        #expect(performance.originalTargetSnapshot == nil)
        #expect(performance.sortedSets.allSatisfy { $0.prescription == nil })
        #expect(replacement.lastAddedAt != nil)
    }
    
    @Test @MainActor
    // After replace, historical lookup should follow the NEW exercise catalog id.
    func lastCompletedLookupUsesNewExerciseAfterReplace() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)
        
        let bench = Exercise(from: ExerciseCatalog.byID["barbell_bench_press"]!)
        let incline = Exercise(from: ExerciseCatalog.byID["barbell_incline_bench_press"]!)
        
        let oldSession = WorkoutSession(status: .done, startedAt: Calendar.current.date(byAdding: .day, value: -2, to: Date())!)
        context.insert(oldSession)
        oldSession.addExercise(bench)
        guard let oldPerf = oldSession.sortedExercises.first,
              let oldSet = oldPerf.sortedSets.first else {
            Issue.record("Expected old completed bench performance")
            return
        }
        oldPerf.date = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        oldSet.reps = 6
        oldSet.weight = 185
        
        let newSession = WorkoutSession(status: .done, startedAt: Calendar.current.date(byAdding: .day, value: -1, to: Date())!)
        context.insert(newSession)
        newSession.addExercise(incline)
        guard let newPerf = newSession.sortedExercises.first,
              let newSet = newPerf.sortedSets.first else {
            Issue.record("Expected new completed incline performance")
            return
        }
        newPerf.date = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        newSet.reps = 10
        newSet.weight = 165
        
        let plan = WorkoutPlan(title: "Bench Focus")
        context.insert(plan)
        let prescription = ExercisePrescription(exercise: bench, workoutPlan: plan)
        prescription.sets = [SetPrescription(exercisePrescription: prescription, setType: .working, targetWeight: 180, targetReps: 8, targetRest: 90, index: 0)]
        plan.exercises = [prescription]
        
        let liveSession = WorkoutSession(from: plan)
        context.insert(liveSession)
        guard let livePerf = liveSession.sortedExercises.first else {
            Issue.record("Expected active exercise in live session")
            return
        }
        
        let beforeReplace = try context.fetch(ExercisePerformance.lastCompleted(for: livePerf)).first
        #expect(beforeReplace?.catalogID == bench.catalogID)
        
        livePerf.replaceWith(incline, keepSets: true)
        
        let afterReplace = try context.fetch(ExercisePerformance.lastCompleted(for: livePerf)).first
        #expect(afterReplace?.catalogID == incline.catalogID)
        #expect(afterReplace?.sortedSets.first?.reps == 10)
        #expect(afterReplace?.sortedSets.first?.weight == 165)
    }
    
    @Test @MainActor
    // Replacing a session-derived plan exercise should unlink completed workout evidence from the repurposed prescription.
    func replacingSessionDerivedPrescriptionClearsLinkedPerformanceReferences() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)
        
        let bench = Exercise(from: ExerciseCatalog.byID["barbell_bench_press"]!)
        let incline = Exercise(from: ExerciseCatalog.byID["barbell_incline_bench_press"]!)
        
        let session = WorkoutSession(status: .done)
        context.insert(session)
        session.addExercise(bench)
        
        guard let performance = session.sortedExercises.first,
              let set = performance.sortedSets.first else {
            Issue.record("Expected completed performance linked to the saved workout plan.")
            return
        }
        
        let plan = WorkoutPlan(from: session)
        context.insert(plan)
        
        guard let prescription = plan.sortedExercises.first else {
            Issue.record("Expected plan exercise copied from workout performance.")
            return
        }
        
        #expect(performance.prescription?.id == prescription.id)
        #expect(set.prescription?.exercise?.id == prescription.id)
        
        prescription.replaceWith(incline, keepSets: true)
        
        #expect(performance.prescription == nil)
        #expect(set.prescription == nil)
        #expect(prescription.catalogID == incline.catalogID)
    }
    
    @Test @MainActor
    // Saving an edit copy with a replaced exercise should clear historical performance links from the reused original prescription.
    func applyingEditingCopyAfterReplaceClearsOriginalLinkedPerformanceReferences() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)
        
        let bench = Exercise(from: ExerciseCatalog.byID["barbell_bench_press"]!)
        let incline = Exercise(from: ExerciseCatalog.byID["barbell_incline_bench_press"]!)
        
        let session = WorkoutSession(status: .done)
        context.insert(session)
        session.addExercise(bench)
        
        guard let performance = session.sortedExercises.first,
              let set = performance.sortedSets.first else {
            Issue.record("Expected completed performance linked to the original prescription.")
            return
        }
        
        let plan = WorkoutPlan(from: session, completed: true)
        context.insert(plan)
        let editCopy = plan.createEditingCopy(context: context)
        
        guard let copyExercise = editCopy.sortedExercises.first,
              let originalExercise = plan.sortedExercises.first else {
            Issue.record("Expected original and copy exercises for replacement test.")
            return
        }
        
        #expect(performance.prescription?.id == originalExercise.id)
        #expect(set.prescription?.exercise?.id == originalExercise.id)
        
        copyExercise.replaceWith(incline, keepSets: true)
        plan.applyEditingCopy(editCopy, context: context)
        
        #expect(originalExercise.catalogID == incline.catalogID)
        #expect(performance.prescription == nil)
        #expect(set.prescription == nil)
    }
    
    @Test @MainActor
    // Completed workouts should drop live prescription links once the history pipeline is done.
    func clearingHistoricalUseLinksDetachesCompletedSessionFromPlanTargets() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)
        
        let plan = WorkoutPlan(title: "Push Day")
        context.insert(plan)
        
        let bench = Exercise(from: ExerciseCatalog.byID["barbell_bench_press"]!)
        let prescription = ExercisePrescription(exercise: bench, workoutPlan: plan)
        let setPrescription = SetPrescription(exercisePrescription: prescription, setType: .working, targetWeight: 185, targetReps: 8, targetRest: 120, index: 0)
        prescription.sets = [setPrescription]
        plan.exercises = [prescription]
        
        let session = WorkoutSession(from: plan)
        context.insert(session)
        
        guard let performance = session.sortedExercises.first,
              let set = performance.sortedSets.first else {
            Issue.record("Expected completed workout performance linked to a plan target.")
            return
        }
        
        #expect(performance.prescription?.id == prescription.id)
        #expect(prescription.activePerformance?.id == performance.id)
        #expect(set.prescription?.id == setPrescription.id)
        #expect(setPrescription.activePerformance?.id == set.id)
        
        session.clearPrescriptionLinksForHistoricalUse()
        
        #expect(performance.prescription == nil)
        #expect(prescription.activePerformance == nil)
        #expect(set.prescription == nil)
        #expect(setPrescription.activePerformance == nil)
    }
    
    @Test @MainActor
    // Finalizing a session-derived plan should clear links from its completed source workout.
    func clearingCompletedSessionPerformanceReferencesDetachesSavedSourceWorkout() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)
        
        let session = WorkoutSession(status: .done)
        context.insert(session)
        let bench = Exercise(from: ExerciseCatalog.byID["barbell_bench_press"]!)
        session.addExercise(bench)
        
        guard let performance = session.sortedExercises.first,
              let set = performance.sortedSets.first else {
            Issue.record("Expected source workout performance.")
            return
        }
        
        let plan = WorkoutPlan(from: session, completed: true)
        context.insert(plan)
        session.workoutPlan = plan
        
        guard let prescription = plan.sortedExercises.first,
              let setPrescription = prescription.sortedSets.first else {
            Issue.record("Expected session-derived prescription.")
            return
        }
        
        #expect(performance.prescription?.id == prescription.id)
        #expect(set.prescription?.id == setPrescription.id)
        
        plan.clearCompletedSessionPerformanceReferences()
        
        #expect(performance.prescription == nil)
        #expect(prescription.activePerformance == nil)
        #expect(set.prescription == nil)
        #expect(setPrescription.activePerformance == nil)
    }
}
