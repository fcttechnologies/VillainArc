import Foundation

struct WatchRuntimeApplicationContext: Codable, Sendable {
    let activeSnapshot: ActiveWorkoutSnapshot?
}

enum PhoneToWatchRuntimeEvent: Codable, Sendable {
    case snapshot(ActiveWorkoutSnapshot)
    case clearActiveWorkout
    case finishMirroredSession(sessionID: UUID, endedAt: Date)
    case discardMirroredSession(sessionID: UUID)
}

enum MirroredWorkoutRemoteMessage: Codable, Sendable {
    case snapshot(ActiveWorkoutSnapshot)
    case command(WatchWorkoutCommand)
    case commandResult(commandID: UUID, result: WatchWorkoutCommandResult)
    case finishMirroredSession(sessionID: UUID, endedAt: Date)
    case discardMirroredSession(sessionID: UUID)
}

enum PhoneToWatchControlRequest: Codable, Sendable {
    case startMirroring(ActiveWorkoutSnapshot)
}
