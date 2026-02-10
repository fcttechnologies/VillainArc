import AppIntents
import Foundation
import SwiftData
import SwiftUI

struct StartRestTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Rest Timer"
    static let description = IntentDescription("Starts a rest timer.")
    static let supportedModes: IntentModes = .background
    private static let maximumRestSeconds = 10 * 60
    static var parameterSummary: some ParameterSummary {
        Summary("Start rest timer for \(\.$duration)")
    }

    @Parameter(title: "Duration", defaultUnit: .seconds, supportsNegativeNumbers: false, requestValueDialog: IntentDialog("How long should the rest timer be?"))
    var duration: Measurement<UnitDuration>

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetIntent {
        let context = SharedModelContainer.container.mainContext

        guard (try? context.fetch(WorkoutSession.incomplete).first) != nil else {
            throw RestTimerIntentError.noWorkoutSession
        }

        let durationSeconds = Int(duration.converted(to: .seconds).value.rounded())
        guard durationSeconds > 0 else {
            throw RestTimerIntentError.invalidDuration
        }

        let clampedSeconds = min(durationSeconds, Self.maximumRestSeconds)
        RestTimerState.shared.start(seconds: clampedSeconds)
        RestTimeHistory.record(seconds: clampedSeconds, context: context)
        saveContext(context: context)

        return .result(dialog: "Rest timer started for \(secondsToTime(clampedSeconds)).", snippetIntent: RestTimerSnippetIntent())
    }
}
