import Foundation

enum WatchWorkoutCommand: Codable, Sendable {
    case startPlannedWorkout(planID: UUID)
    case activateMirroring(sessionID: UUID, commandID: UUID)
    case toggleSet(sessionID: UUID, setID: UUID, desiredComplete: Bool, commandID: UUID)
    case finish(sessionID: UUID, commandID: UUID)
    case cancel(sessionID: UUID, commandID: UUID)

    var commandID: UUID? {
        switch self {
        case .startPlannedWorkout:
            nil
        case .activateMirroring(_, let commandID),
                .toggleSet(_, _, _, let commandID),
                .finish(_, let commandID),
                .cancel(_, let commandID):
            commandID
        }
    }
}

enum WatchWorkoutCommandResult: Codable, Sendable {
    case started(ActiveWorkoutSnapshot)
    case updated(ActiveWorkoutSnapshot)
    case finishOnPhone(reason: String)
    case blocked(reason: String)
    case cancelled
    case failed(reason: String)
}
