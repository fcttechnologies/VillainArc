import Observation
import SwiftData

@MainActor
@Observable
final class WorkoutRouter {
    var activeWorkout: Workout?

    func start(from template: Workout? = nil, context: ModelContext) {
        let newWorkout = template.map { Workout(previous: $0) } ?? Workout()
        context.insert(newWorkout)
        saveContext(context: context)
        activeWorkout = newWorkout
    }

    func resume(_ workout: Workout) {
        activeWorkout = workout
    }

    func clear() {
        activeWorkout = nil
    }
}
