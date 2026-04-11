import AppIntents
import SwiftData

struct FinishWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Finish Workout"
    static let description = IntentDescription("Finishes the current workout session.")
    static let supportedModes: IntentModes = .foreground(.dynamic)

    @MainActor func perform() async throws -> some IntentResult & OpensIntent {
        let context = SharedModelContainer.container.mainContext
        guard let workoutSession = try? context.fetch(WorkoutSession.incomplete).first else { throw FinishWorkoutError.noWorkoutSession }

        guard workoutSession.statusValue == .active else { throw FinishWorkoutError.noActiveWorkout }
        guard !(workoutSession.exercises?.isEmpty ?? false) else { throw FinishWorkoutError.noExercises }

        let shouldPromptForPostWorkoutEffort = (try? context.fetch(AppSettings.single).first)?.promptForPostWorkoutEffort ?? true

        if shouldPromptForPostWorkoutEffort {
            AppRouter.shared.presentFinishWorkoutFlow(for: workoutSession)
            return .result(opensIntent: OpenAppIntent())
        }

        let summary = workoutSession.unfinishedSetSummary
        let finishAction: WorkoutFinishAction
        switch summary.caseType {
        case .none: finishAction = .finish
        case .emptyAndLogged:
            let markOption = IntentChoiceOption(title: "Mark logged sets as complete", style: .default)
            let deleteOption = IntentChoiceOption(title: "Delete all unfinished sets", style: .destructive)
            let choice = try await requestChoice(between: [markOption, deleteOption, .cancel], dialog: IntentDialog(emptyAndLoggedDialog(loggedCount: summary.loggedCount, emptyCount: summary.emptyCount)))
            switch choice.style {
            case .default: finishAction = .markLoggedComplete
            case .destructive: finishAction = .deleteUnfinished
            default: throw FinishWorkoutError.cancelled
            }
        case .loggedOnly:
            let markOption = IntentChoiceOption(title: "Mark as complete", style: .default)
            let deleteOption = IntentChoiceOption(title: "Delete these sets", style: .destructive)
            let choice = try await requestChoice(between: [markOption, deleteOption, .cancel], dialog: IntentDialog(loggedOnlyDialog(loggedCount: summary.loggedCount)))
            switch choice.style {
            case .default: finishAction = .markLoggedComplete
            case .destructive: finishAction = .deleteUnfinished
            default: throw FinishWorkoutError.cancelled
            }
        case .emptyOnly:
            let deleteOption = IntentChoiceOption(title: "Delete empty sets", style: .destructive)
            let choice = try await requestChoice(between: [deleteOption, .cancel], dialog: IntentDialog(emptyOnlyDialog(emptyCount: summary.emptyCount)))
            switch choice.style {
            case .destructive: finishAction = .deleteEmpty
            default: throw FinishWorkoutError.cancelled
            }
        }

        let shouldPrewarmSuggestions = workoutSession.workoutPlan != nil
        let result = workoutSession.finish(action: finishAction, context: context)
        switch result {
        case .finished:
            let weightUnit = AppSettingsSnapshot(settings: (try? context.fetch(AppSettings.single))?.first).weightUnit
            workoutSession.convertSetWeightsToKg(from: weightUnit)
            RestTimerState.shared.stop()
            saveContext(context: context)
            await HealthLiveWorkoutSessionCoordinator.shared.finishIfRunning(for: workoutSession, context: context)
            WorkoutActivityManager.end()
            if shouldPrewarmSuggestions { FoundationModelPrewarmer.warmup() }
        case .workoutDeleted:
            RestTimerState.shared.stop()
            HealthLiveWorkoutSessionCoordinator.shared.discardIfRunning(for: workoutSession)
            saveContext(context: context)
            AppRouter.shared.activeWorkoutSession = nil
            WorkoutActivityManager.end()
            throw FinishWorkoutError.workoutDeleted
        }
        return .result(opensIntent: OpenAppIntent())
    }
}

private func emptyAndLoggedDialog(loggedCount: Int, emptyCount: Int) -> LocalizedStringResource {
    let loggedLabel = loggedCount == 1 ? String(localized: "1 logged set") : String(localized: "\(loggedCount) logged sets")
    let emptyLabel = emptyCount == 1 ? String(localized: "1 empty set") : String(localized: "\(emptyCount) empty sets")
    return LocalizedStringResource("You have \(loggedLabel) and \(emptyLabel) with no data.")
}

private func loggedOnlyDialog(loggedCount: Int) -> LocalizedStringResource {
    if loggedCount == 1 { return "You have 1 set with data, but it is not marked complete." }
    return "You have \(loggedCount) sets with data, but they are not marked complete."
}

private func emptyOnlyDialog(emptyCount: Int) -> LocalizedStringResource {
    if emptyCount == 1 { return "You have 1 empty set.\nLog it or remove it before finishing." }
    return "You have \(emptyCount) empty sets.\nLog them or remove them before finishing."
}

enum FinishWorkoutError: Error, CustomLocalizedStringResourceConvertible {
    case noWorkoutSession
    case noExercises
    case noActiveWorkout
    case workoutDeleted
    case cancelled

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noWorkoutSession: return "No workout session found."
        case .noActiveWorkout: return "No active workout found."
        case .noExercises: return "Cannot finish a workout with no exercises."
        case .workoutDeleted: return "Workout deleted because no completed sets remained."
        case .cancelled: return "Workout finish canceled."
        }
    }
}
