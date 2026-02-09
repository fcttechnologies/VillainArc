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

        let summary = workoutSession.unfinishedSetSummary
        let loggedSetLabel = setCountString(summary.loggedCount)
        let emptySetLabel = setCountString(summary.emptyCount, adjective: "empty")
        let loggedVerb = summary.loggedCount == 1 ? "isnt" : "arent"
        let finishAction: FinishWorkoutAction
        switch summary.caseType {
        case .none:
            finishAction = .finish
        case .emptyAndLogged:
            let markOption = IntentChoiceOption(title: "Mark logged sets as complete", style: .default)
            let deleteOption = IntentChoiceOption(title: "Delete all unfinished sets", style: .destructive)
            let choice = try await requestChoice(
                between: [markOption, deleteOption, .cancel],
                dialog: IntentDialog("You have \(loggedSetLabel) logged and \(emptySetLabel) with no data.")
            )
            switch choice.style {
            case .default:
                finishAction = .markLoggedComplete
            case .destructive:
                finishAction = .deleteUnfinished
            default:
                throw FinishWorkoutError.cancelled
            }
        case .loggedOnly:
            let markOption = IntentChoiceOption(title: "Mark as complete", style: .default)
            let deleteOption = IntentChoiceOption(title: "Delete these sets", style: .destructive)
            let choice = try await requestChoice(
                between: [markOption, deleteOption, .cancel],
                dialog: IntentDialog("You have \(loggedSetLabel) with data but \(loggedVerb) marked complete.")
            )
            switch choice.style {
            case .default:
                finishAction = .markLoggedComplete
            case .destructive:
                finishAction = .deleteUnfinished
            default:
                throw FinishWorkoutError.cancelled
            }
        case .emptyOnly:
            let deleteOption = IntentChoiceOption(title: "Delete empty sets", style: .destructive)
            let choice = try await requestChoice(
                between: [deleteOption, .cancel],
                dialog: IntentDialog("You have \(emptySetLabel).\nTo finish, either log them or remove them.")
            )
            switch choice.style {
            case .destructive:
                finishAction = .deleteEmpty
            default:
                throw FinishWorkoutError.cancelled
            }
        }

        switch finishAction {
        case .markLoggedComplete:
            for set in summary.loggedSets {
                set.complete = true
                set.completedAt = Date()
            }
            if summary.hasEmpty {
                for set in summary.emptySets {
                    set.exercise?.deleteSet(set)
                    context.delete(set)
                }
                if removeEmptyExercisesIfNeeded(for: workoutSession, context: context) {
                    throw FinishWorkoutError.workoutDeleted
                }
            }
        case .deleteUnfinished:
            let setsToDelete = summary.loggedSets + summary.emptySets
            for set in setsToDelete {
                set.exercise?.deleteSet(set)
                context.delete(set)
            }
            if removeEmptyExercisesIfNeeded(for: workoutSession, context: context) {
                throw FinishWorkoutError.workoutDeleted
            }
        case .deleteEmpty:
            for set in summary.emptySets {
                set.exercise?.deleteSet(set)
                context.delete(set)
            }
            if removeEmptyExercisesIfNeeded(for: workoutSession, context: context) {
                throw FinishWorkoutError.workoutDeleted
            }
        case .finish:
            break
        }

        workoutSession.status = SessionStatus.summary.rawValue
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

private enum FinishWorkoutAction {
    case finish
    case markLoggedComplete
    case deleteUnfinished
    case deleteEmpty
}

private func setCountString(_ count: Int, adjective: String? = nil) -> String {
    let value = count == 1 ? "1" : "\(count)"
    let suffix = count == 1 ? "set" : "sets"
    if let adjective {
        return "\(value) \(adjective) \(suffix)"
    }
    return "\(value) \(suffix)"
}

private func removeEmptyExercisesIfNeeded(for workoutSession: WorkoutSession, context: ModelContext) -> Bool {
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
        return true
    }
    return false
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
