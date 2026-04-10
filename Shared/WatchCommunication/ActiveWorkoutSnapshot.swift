import Foundation

struct ActiveWorkoutSnapshot: Codable, Sendable {
    let sessionID: UUID
    let title: String
    let status: SessionStatus
    let startedAt: Date
    let activeExerciseID: UUID?
    let exercises: [WatchExerciseSnapshot]
    let restTimer: WatchRestTimerSnapshot?
    let healthCollectionMode: HealthCollectionMode
    let canFinishOnWatch: Bool
    let latestHeartRate: Double?
    let activeEnergyBurned: Double?
    let restingEnergyBurned: Double?
}

struct WatchExerciseSnapshot: Codable, Sendable {
    let exerciseID: UUID
    let name: String
    let sets: [WatchSetSnapshot]
}

struct WatchSetSnapshot: Codable, Sendable {
    let setID: UUID
    let index: Int
    let complete: Bool
    let reps: Int
    let weight: Double
    let targetRPE: Int?
    let hasTarget: Bool
}

struct WatchRestTimerSnapshot: Codable, Sendable {
    let endDate: Date?
    let pausedRemainingSeconds: Int
    let isPaused: Bool
    let startedSeconds: Int
}
