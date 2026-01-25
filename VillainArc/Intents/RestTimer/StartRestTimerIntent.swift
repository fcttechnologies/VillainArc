import AppIntents
import SwiftData

struct StartRestTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Rest Timer"
    static let description = IntentDescription("Starts a rest timer.")
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Seconds")
    var seconds: Int?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = SharedModelContainer.container.mainContext

        guard (try? context.fetch(Workout.incomplete).first) != nil else {
            return .result(dialog: "No active workout to start a rest timer.")
        }

        let selectedSeconds = seconds ?? recentSeconds(context: context) ?? RestTimePolicy.defaultRestSeconds
        let clampedSeconds = max(0, selectedSeconds)

        guard clampedSeconds > 0 else {
            return .result(dialog: "Rest timer duration must be greater than zero.")
        }

        RestTimerState.shared.start(seconds: clampedSeconds)
        RestTimeHistory.record(seconds: clampedSeconds, context: context)
        saveContext(context: context)

        return .result(dialog: "Rest timer started for \(secondsToTime(clampedSeconds)).")
    }

    private func recentSeconds(context: ModelContext) -> Int? {
        var descriptor = RestTimeHistory.recents
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor).first)?.seconds
    }
}
