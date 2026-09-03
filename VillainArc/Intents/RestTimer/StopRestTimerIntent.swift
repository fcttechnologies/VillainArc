import AppIntents
import FCTMetrics
import SwiftData
import SwiftUI

struct StopRestTimerIntent: AppIntent {
    /// What this intent's run travels under, so a crash with nobody watching names the intent.
    static let diagCrumb: any DiagBreadcrumb = VACrumb.intentStopRestTimer

    static let title: LocalizedStringResource = "Stop Rest Timer"
    static let description = IntentDescription("Stops the current rest timer.")
    static let supportedModes: IntentModes = .background

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        Diag.breadcrumb(Self.diagCrumb)
        let restTimer = RestTimerState.shared

        guard restTimer.isActive else { throw RestTimerIntentError.noActiveTimer }

        restTimer.stop()
        return .result(dialog: "Rest timer stopped.")
    }
}
