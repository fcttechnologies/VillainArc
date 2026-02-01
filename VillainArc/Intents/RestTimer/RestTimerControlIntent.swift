import AppIntents

enum RestTimerControlAction: String, AppEnum {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Rest Timer Action")
    static let caseDisplayRepresentations: [RestTimerControlAction: DisplayRepresentation] = [
        .pause: DisplayRepresentation(title: "Pause"),
        .resume: DisplayRepresentation(title: "Resume"),
        .stop: DisplayRepresentation(title: "Stop")
    ]

    case pause
    case resume
    case stop
}

struct RestTimerControlIntent: AppIntent {
    static let title: LocalizedStringResource = "Rest Timer Control"
    static let isDiscoverable: Bool = false
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Action")
    var action: RestTimerControlAction

    init() {}

    init(action: RestTimerControlAction) {
        self.action = action
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let restTimer = RestTimerState.shared

        switch action {
        case .pause:
            guard restTimer.isRunning else {
                if restTimer.isPaused {
                    throw RestTimerIntentError.alreadyPaused
                }
                throw RestTimerIntentError.noRunningTimer
            }
            restTimer.pause()
        case .resume:
            guard restTimer.isPaused, restTimer.pausedRemainingSeconds > 0 else {
                if restTimer.isRunning {
                    throw RestTimerIntentError.alreadyRunning
                }
                throw RestTimerIntentError.noPausedTimer
            }
            restTimer.resume()
        case .stop:
            guard restTimer.isActive else {
                throw RestTimerIntentError.noActiveTimer
            }
            restTimer.stop()
        }

        RestTimerSnippetIntent.reload()
        return .result()
    }
}
