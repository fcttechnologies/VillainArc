import AppIntents
import SwiftData

struct CompleteActiveSetIntent: AppIntent {
    static let title: LocalizedStringResource = "Complete Active Set"
    static let description = IntentDescription("Completes the next incomplete set in your active workout.")
    static let supportedModes: IntentModes = .background

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = SharedModelContainer.container.mainContext
        guard let workout = try? context.fetch(Workout.incomplete).first else {
            return .result(dialog: "No active workout to update.")
        }

        guard let set = workout.activeSet(),
              let exercise = workout.exercise(containing: set)
        else {
            return .result(dialog: "No incomplete sets found.")
        }

        set.complete = true
        startRestTimerIfNeeded(for: set, context: context)
        saveContext(context: context)
        let setNumber = set.index + 1
        return .result(dialog: "Completed set \(setNumber) of \(exercise.name).")
    }
    
    @MainActor
    private func startRestTimerIfNeeded(for set: ExerciseSet, context: ModelContext) {
        guard autoStartRestTimerEnabled else { return }
        let restSeconds = set.effectiveRestSeconds
        guard restSeconds > 0 else { return }

        RestTimerState.shared.start(seconds: restSeconds, startedFromSetID: set.persistentModelID)
        RestTimeHistory.record(seconds: restSeconds, context: context)
        Task { await IntentDonations.donateStartRestTimer(seconds: restSeconds) }
    }

    private var autoStartRestTimerEnabled: Bool {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "autoStartRestTimer") == nil {
            return true
        }
        return defaults.bool(forKey: "autoStartRestTimer")
    }
}
