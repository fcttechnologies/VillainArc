import SwiftData
import Foundation
import Testing
@testable import VillainArc

struct WorkoutFinishTests {

    // MARK: - Helpers

    @MainActor
    private func makeSession(context: ModelContext, exerciseConfigs: [(weight: Double, reps: Int, complete: Bool)]) -> WorkoutSession {
        let session = WorkoutSession()
        context.insert(session)

        let exercise = ExercisePerformance(exercise: Exercise(from: ExerciseCatalog.byID["barbell_bench_press"]!), workoutSession: session)
        context.insert(exercise)
        session.exercises.append(exercise)
        // Remove the auto-added set from init
        for set in exercise.sets {
            context.delete(set)
        }
        exercise.sets.removeAll()

        for (i, config) in exerciseConfigs.enumerated() {
            let set = SetPerformance(exercise: exercise, weight: config.weight, reps: config.reps)
            set.index = i
            set.complete = config.complete
            if config.complete {
                set.completedAt = Date()
            }
            context.insert(set)
            exercise.sets.append(set)
        }

        return session
    }

    @MainActor
    private func makeMultiExerciseSession(context: ModelContext) -> WorkoutSession {
        let session = WorkoutSession()
        context.insert(session)

        // Exercise 1: all sets complete
        let exercise1 = ExercisePerformance(exercise: Exercise(from: ExerciseCatalog.byID["barbell_bench_press"]!), workoutSession: session)
        context.insert(exercise1)
        session.exercises.append(exercise1)
        for set in exercise1.sets { context.delete(set) }
        exercise1.sets.removeAll()
        let set1 = SetPerformance(exercise: exercise1, weight: 135, reps: 10)
        set1.complete = true
        set1.completedAt = Date()
        context.insert(set1)
        exercise1.sets.append(set1)

        // Exercise 2: only empty (incomplete) sets
        let exercise2 = ExercisePerformance(exercise: Exercise(from: ExerciseCatalog.byID["barbell_squat"]!), workoutSession: session)
        exercise2.index = 1
        context.insert(exercise2)
        session.exercises.append(exercise2)
        for set in exercise2.sets { context.delete(set) }
        exercise2.sets.removeAll()
        let set2 = SetPerformance(exercise: exercise2, weight: 0, reps: 0)
        set2.complete = false
        context.insert(set2)
        exercise2.sets.append(set2)

        return session
    }

    // MARK: - .finish action (all sets already complete)

    @Test @MainActor
    func finishWithAllSetsComplete_setsStatusToSummary() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)

        let session = makeSession(context: context, exerciseConfigs: [
            (weight: 135, reps: 10, complete: true),
            (weight: 145, reps: 8, complete: true),
        ])

        let result = session.finish(action: .finish, context: context)

        #expect(result == .finished)
        #expect(session.statusValue == .summary)
        #expect(session.endedAt != nil)
        #expect(session.activeExercise == nil)
    }

    // MARK: - .markLoggedComplete action

    @Test @MainActor
    func markLoggedComplete_marksLoggedSetsAndDeletesEmpty() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)

        // 1 complete, 1 logged (has data but not complete), 1 empty
        let session = makeSession(context: context, exerciseConfigs: [
            (weight: 135, reps: 10, complete: true),
            (weight: 145, reps: 8, complete: false),  // logged
            (weight: 0, reps: 0, complete: false),     // empty
        ])

        let exercise = session.exercises.first!
        let loggedSet = exercise.sortedSets[1]
        let emptySet = exercise.sortedSets[2]

        #expect(!loggedSet.complete)
        #expect(!emptySet.complete)

        let result = session.finish(action: .markLoggedComplete, context: context)

        #expect(result == .finished)
        #expect(loggedSet.complete)
        #expect(loggedSet.completedAt != nil)
        #expect(!exercise.sets.contains(emptySet))
        #expect(session.statusValue == .summary)
        #expect(session.endedAt != nil)
    }

    @Test @MainActor
    func markLoggedComplete_withOnlyLoggedSets_marksThemComplete() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)

        let session = makeSession(context: context, exerciseConfigs: [
            (weight: 135, reps: 10, complete: true),
            (weight: 145, reps: 8, complete: false),  // logged
        ])

        let exercise = session.exercises.first!
        let loggedSet = exercise.sortedSets[1]

        let result = session.finish(action: .markLoggedComplete, context: context)

        #expect(result == .finished)
        #expect(loggedSet.complete)
        #expect(loggedSet.completedAt != nil)
        #expect(exercise.sets.count == 2)
        #expect(session.statusValue == .summary)
    }

    // MARK: - .deleteUnfinished action

    @Test @MainActor
    func deleteUnfinished_deletesAllIncompleteSets() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)

        let session = makeSession(context: context, exerciseConfigs: [
            (weight: 135, reps: 10, complete: true),
            (weight: 145, reps: 8, complete: false),  // logged
            (weight: 0, reps: 0, complete: false),     // empty
        ])

        let exercise = session.exercises.first!

        let result = session.finish(action: .deleteUnfinished, context: context)

        #expect(result == .finished)
        #expect(exercise.sets.count == 1)
        #expect(exercise.sets.first?.complete == true)
        #expect(session.statusValue == .summary)
    }

    @Test @MainActor
    func deleteUnfinished_whenAllSetsDeleted_deletesWorkout() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)

        // All sets are incomplete
        let session = makeSession(context: context, exerciseConfigs: [
            (weight: 145, reps: 8, complete: false),
            (weight: 0, reps: 0, complete: false),
        ])

        let result = session.finish(action: .deleteUnfinished, context: context)

        #expect(result == .workoutDeleted)
    }

    // MARK: - .deleteEmpty action

    @Test @MainActor
    func deleteEmpty_deletesOnlyEmptySets() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)

        let session = makeSession(context: context, exerciseConfigs: [
            (weight: 135, reps: 10, complete: true),
            (weight: 145, reps: 8, complete: false),  // logged — should remain
            (weight: 0, reps: 0, complete: false),     // empty — should be deleted
        ])

        let exercise = session.exercises.first!
        let loggedSet = exercise.sortedSets[1]

        let result = session.finish(action: .deleteEmpty, context: context)

        #expect(result == .finished)
        #expect(exercise.sets.count == 2)
        #expect(exercise.sets.contains(loggedSet))
        #expect(session.statusValue == .summary)
    }

    @Test @MainActor
    func deleteEmpty_whenAllSetsEmpty_deletesWorkout() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)

        // All sets are empty
        let session = makeSession(context: context, exerciseConfigs: [
            (weight: 0, reps: 0, complete: false),
            (weight: 0, reps: 0, complete: false),
        ])

        let result = session.finish(action: .deleteEmpty, context: context)

        #expect(result == .workoutDeleted)
    }

    // MARK: - Prune empty exercises

    @Test @MainActor
    func finish_prunesExercisesWithNoSetsRemaining() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)

        let session = makeMultiExerciseSession(context: context)
        #expect(session.exercises.count == 2)

        // deleteEmpty will remove the empty set from exercise2, leaving it with 0 sets
        let result = session.finish(action: .deleteEmpty, context: context)

        #expect(result == .finished)
        #expect(session.exercises.count == 1)
        #expect(session.exercises.first?.catalogID == "barbell_bench_press")
        #expect(session.statusValue == .summary)
    }

    @Test @MainActor
    func finish_deletesWorkoutWhenAllExercisesPruned() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)

        // Single exercise with only empty sets
        let session = makeSession(context: context, exerciseConfigs: [
            (weight: 0, reps: 0, complete: false),
        ])

        let result = session.finish(action: .deleteEmpty, context: context)

        #expect(result == .workoutDeleted)
    }

    // MARK: - State after finish

    @Test @MainActor
    func finish_clearsActiveExercise() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)

        let session = makeSession(context: context, exerciseConfigs: [
            (weight: 135, reps: 10, complete: true),
        ])
        session.activeExercise = session.exercises.first

        let result = session.finish(action: .finish, context: context)

        #expect(result == .finished)
        #expect(session.activeExercise == nil)
    }

    @Test @MainActor
    func finish_setsEndedAt() throws {
        let container = try TestModelContainer.make()
        let context = ModelContext(container)

        let session = makeSession(context: context, exerciseConfigs: [
            (weight: 135, reps: 10, complete: true),
        ])
        #expect(session.endedAt == nil)

        let before = Date()
        let result = session.finish(action: .finish, context: context)
        let after = Date()

        #expect(result == .finished)
        #expect(session.endedAt != nil)
        #expect(session.endedAt! >= before)
        #expect(session.endedAt! <= after)
    }
}
