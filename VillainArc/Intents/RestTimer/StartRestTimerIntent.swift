import AppIntents
import Foundation
import SwiftData

struct StartRestTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Rest Timer"
    static let description = IntentDescription("Starts a rest timer.")
    static let supportedModes: IntentModes = .background
    static var parameterSummary: some ParameterSummary {
        Summary("Start rest timer for \(\.$duration)")
    }

    @Parameter(
        title: "Duration",
        defaultUnit: .seconds,
        supportsNegativeNumbers: false,
        requestValueDialog: IntentDialog("How long should the rest timer be?")
    )
    var duration: Measurement<UnitDuration>

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = SharedModelContainer.container.mainContext

        guard (try? context.fetch(WorkoutSession.incomplete).first) != nil else {
            return .result(dialog: "No workout session to start a rest timer in.")
        }

        let durationSeconds = Int(duration.converted(to: .seconds).value.rounded())
        guard durationSeconds > 0 else {
            return .result(dialog: "Rest timer duration must be greater than zero.")
        }

        RestTimerState.shared.start(seconds: durationSeconds)
        RestTimeHistory.record(seconds: durationSeconds, context: context)
        saveContext(context: context)

        return .result(dialog: "Rest timer started for \(secondsToTime(durationSeconds)).")
    }
}
