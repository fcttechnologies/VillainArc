import AppIntents
import SwiftData

struct FinishWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Finish Workout"
    static let description = IntentDescription("Finishes the current workout session.")
    static let supportedModes: IntentModes = .foreground(.dynamic)

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        let context = SharedModelContainer.container.mainContext
        
        guard let workoutSession = try? context.fetch(WorkoutSession.incomplete).first else {
            throw FinishWorkoutError.noWorkoutSession
        }
        
        guard !workoutSession.exercises.isEmpty else {
            throw FinishWorkoutError.noExercises
        }

        let hasIncompleteSets = workoutSession.exercises.contains { exercise in
            exercise.sets.contains { !$0.complete }
        }

        let finishAction: IntentChoiceOption.Style
        if hasIncompleteSets {
            let markAllOption = IntentChoiceOption(title: "Mark all sets complete", style: .default)
            let deleteOption = IntentChoiceOption(title: "Delete incomplete sets", style: .destructive)
            let choice = try await requestChoice(
                between: [markAllOption, deleteOption, .cancel],
                dialog: IntentDialog("Before finishing, choose how to handle incomplete sets.")
            )
            finishAction = choice.style
        } else {
            finishAction = .default
        }

        switch finishAction {
        case .destructive:
            for exercise in workoutSession.exercises {
                let incompleteSets = exercise.sets.filter { !$0.complete }
                for set in incompleteSets {
                    exercise.deleteSet(set)
                    context.delete(set)
                }
            }
            let emptyExercises = workoutSession.exercises.filter { $0.sets.isEmpty }
            for exercise in emptyExercises {
                workoutSession.deleteExercise(exercise)
                context.delete(exercise)
            }
            if workoutSession.exercises.isEmpty {
                RestTimerState.shared.stop()
                workoutSession.activeExercise = nil
                context.delete(workoutSession)
                saveContext(context: context)
                AppRouter.shared.activeWorkoutSession = nil
                WorkoutActivityManager.end()
                throw FinishWorkoutError.workoutDeleted
            }
        case .cancel:
            throw FinishWorkoutError.cancelled
        default:
            for exercise in workoutSession.exercises {
                for set in exercise.sets where !set.complete {
                    set.complete = true
                    set.completedAt = Date()
                }
            }
        }

        workoutSession.status = SessionStatus.done.rawValue
        workoutSession.endedAt = Date()
        workoutSession.activeExercise = nil
        RestTimerState.shared.stop()
        saveContext(context: context)
        SpotlightIndexer.index(workoutSession: workoutSession)
        AppRouter.shared.activeWorkoutSession = nil
        WorkoutActivityManager.end()
        
        return .result(opensIntent: OpenAppIntent())
    }
}

enum FinishWorkoutError: Error, CustomLocalizedStringResourceConvertible {
    case noWorkoutSession
    case noExercises
    case workoutDeleted
    case cancelled

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noWorkoutSession:
            return "No workout session found."
        case .noExercises:
            return "Cannot finish a workout with no exercises."
        case .workoutDeleted:
            return "Workout deleted because no completed sets remained."
        case .cancelled:
            return "Workout finish canceled."
        }
    }
}
