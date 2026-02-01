import AppIntents
import SwiftUI

struct StopRestTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop Rest Timer"
    static let description = IntentDescription("Stops the current rest timer.")
    static let supportedModes: IntentModes = .background

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let restTimer = RestTimerState.shared

        guard restTimer.isActive else {
            throw RestTimerIntentError.noActiveTimer
        }

        restTimer.stop()
        return .result(dialog: "Rest timer stopped.")
    }
}
