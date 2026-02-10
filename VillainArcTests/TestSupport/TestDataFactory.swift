import Foundation
import SwiftData
@testable import VillainArc

@MainActor
enum TestDataFactory {
    static func makeContext() throws -> ModelContext {
        ModelContext(try TestModelContainer.make())
    }

    static func makePrescription(
        context: ModelContext,
        catalogID: String = "barbell_bench_press",
        workingSets: Int = 4,
        targetWeight: Double = 135,
        targetReps: Int = 8,
        targetRest: Int = 90,
        repRangeMode: RepRangeMode = .range,
        lowerRange: Int = 6,
        upperRange: Int = 12
    ) -> (WorkoutPlan, ExercisePrescription) {
        let plan = WorkoutPlan.makeForTests()
        context.insert(plan)

        let exercise = Exercise(from: ExerciseCatalog.byID[catalogID]!)
        let prescription = ExercisePrescription(exercise: exercise, workoutPlan: plan)
        prescription.sets = []
        prescription.repRange.activeMode = repRangeMode
        prescription.repRange.lowerRange = lowerRange
        prescription.repRange.upperRange = upperRange

        for i in 0..<workingSets {
            let set = SetPrescription(exercisePrescription: prescription, setType: .working, targetWeight: targetWeight, targetReps: targetReps, targetRest: targetRest, index: i)
            prescription.sets.append(set)
        }

        plan.exercises.append(prescription)
        return (plan, prescription)
    }

    static func makePerformance(
        context: ModelContext,
        session: WorkoutSession,
        prescription: ExercisePrescription,
        sets: [(weight: Double, reps: Int, rest: Int, type: ExerciseSetType)]
    ) -> ExercisePerformance {
        let perf = ExercisePerformance(workoutSession: session, exercisePrescription: prescription)
        for set in perf.sets {
            context.delete(set)
        }
        perf.sets.removeAll()

        for (index, config) in sets.enumerated() {
            let setPerf = SetPerformance(exercise: perf, setType: config.type, weight: config.weight, reps: config.reps, restSeconds: config.rest, index: index, complete: true)
            context.insert(setPerf)
            perf.sets.append(setPerf)
        }

        context.insert(perf)
        session.exercises.append(perf)
        return perf
    }

    static func makeSession(context: ModelContext, daysAgo: Int = 0) -> WorkoutSession {
        let session = WorkoutSession(startedAt: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!)
        context.insert(session)
        return session
    }

    static func makeSetPerformance(index: Int, weight: Double, reps: Int) -> SetPerformance {
        let set = SetPerformance()
        set.index = index
        set.weight = weight
        set.reps = reps
        set.type = .working
        set.complete = true
        return set
    }
}

@MainActor
private extension SetPerformance {
    convenience init() {
        self.init(rawIndex: 0)
    }

    convenience init(rawIndex: Int) {
        let dummy = ExercisePerformance()
        self.init(exercise: dummy)
        self.exercise = nil
    }
}

@MainActor
private extension ExercisePerformance {
    convenience init() {
        let dummySession = WorkoutSession()
        let exercise = Exercise(from: ExerciseCatalog.byID["barbell_bench_press"]!)
        self.init(exercise: exercise, workoutSession: dummySession)
        self.workoutSession = nil
    }
}
