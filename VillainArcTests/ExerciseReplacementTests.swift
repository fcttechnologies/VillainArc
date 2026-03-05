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
        prescription.sets = [
            SetPrescription(exercisePrescription: prescription, setType: .warmup, targetWeight: 95, targetReps: 10, targetRest: 60, index: 0),
            SetPrescription(exercisePrescription: prescription, setType: .working, targetWeight: 135, targetReps: 8, targetRest: 90, index: 1)
        ]
        plan.exercises = [prescription]

        let session = WorkoutSession(from: plan)
        context.insert(session)

        guard let performance = session.sortedExercises.first else {
            Issue.record("Expected one exercise in the session")
            return
        }
        let sets = performance.sortedSets
        #expect(sets.count == 2)
        #expect(sets[0].weight == 95)
        #expect(sets[0].reps == 10)
        #expect(sets[1].weight == 135)
        #expect(sets[1].reps == 8)
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
        #expect(performance.sortedSets.isEmpty == false)
        #expect(performance.sortedSets.allSatisfy { $0.prescription != nil })

        performance.replaceWith(replacement, keepSets: true)

        #expect(performance.catalogID == replacement.catalogID)
        #expect(performance.prescription == nil)
        #expect(performance.sortedSets.allSatisfy { $0.prescription == nil })
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
}
