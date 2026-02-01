import AppIntents

enum RestTimerIntentError: Error, CustomLocalizedStringResourceConvertible {
    case noWorkoutSession
    case invalidDuration
    case noRunningTimer
    case alreadyPaused
    case alreadyRunning
    case noPausedTimer
    case noActiveTimer

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noWorkoutSession:
            return "No workout session to start a rest timer in."
        case .invalidDuration:
            return "Rest timer duration must be greater than zero."
        case .noRunningTimer:
            return "No running rest timer to pause."
        case .alreadyPaused:
            return "Rest timer is already paused."
        case .alreadyRunning:
            return "Rest timer is already running."
        case .noPausedTimer:
            return "No paused rest timer to resume."
        case .noActiveTimer:
            return "No active rest timer to stop."
        }
    }
}
