import Foundation

// The phone ↔ watch WatchConnectivity contract. This file compiles into BOTH the
// iOS app (synchronized group) and the Watch app (allowlisted in the Watch target's
// exception set in project.pbxproj), so everything here must stay pure Foundation,
// Codable, and nonisolated. The phone is the source of truth: it pushes
// `WatchSyncPayload` snapshots via `updateApplicationContext`, and the watch sends
// `WatchSyncCommand`s back via `sendMessage`, receiving a fresh payload in the reply.

nonisolated enum WatchSync {
    /// Application-context / reply dictionary key holding the JSON-encoded payload.
    static let payloadKey = "payload"
    /// Message dictionary key holding the JSON-encoded command.
    static let commandKey = "command"
    static let schemaVersion = 1

    static func encodePayload(_ payload: WatchSyncPayload) -> [String: Any]? {
        guard let data = try? JSONEncoder().encode(payload) else { return nil }
        return [payloadKey: data]
    }

    static func decodePayload(from dictionary: [String: Any]) -> WatchSyncPayload? {
        guard let data = dictionary[payloadKey] as? Data else { return nil }
        return try? JSONDecoder().decode(WatchSyncPayload.self, from: data)
    }

    static func encodeCommand(_ command: WatchSyncCommand) -> [String: Any]? {
        guard let data = try? JSONEncoder().encode(command) else { return nil }
        return [commandKey: data]
    }

    static func decodeCommand(from dictionary: [String: Any]) -> WatchSyncCommand? {
        guard let data = dictionary[commandKey] as? Data else { return nil }
        return try? JSONDecoder().decode(WatchSyncCommand.self, from: data)
    }
}

// MARK: - Payload (phone → watch)

nonisolated struct WatchSyncPayload: Codable, Equatable {
    var schemaVersion: Int = WatchSync.schemaVersion
    var restTimer: WatchRestTimerSnapshot?
    var liveSession: WatchLiveSessionSnapshot?
    var quickStats: WatchQuickStatsSnapshot?
    var heartRateZones: WatchHeartRateZoneConfig?
}

nonisolated struct WatchRestTimerSnapshot: Codable, Equatable {
    /// Non-nil while the timer is counting down.
    var endDate: Date?
    var pausedRemainingSeconds: Int
    var isPaused: Bool
    /// The duration the timer was started with, for progress rendering.
    var startedSeconds: Int

    var isRunning: Bool { endDate != nil && !isPaused }
    var isActive: Bool { isRunning || (isPaused && pausedRemainingSeconds > 0) }
}

nonisolated enum WatchLiveSessionKind: String, Codable {
    case strength
    case cardio
}

nonisolated struct WatchLiveSessionSnapshot: Codable, Equatable {
    var kind: WatchLiveSessionKind
    var title: String
    var startedAt: Date
    var heartRateBPM: Double?
    /// Preformatted on the phone (locale- and unit-aware), e.g. "231 cal".
    var activeEnergyText: String?

    // Strength
    var exerciseName: String?
    /// 1-based position of the current exercise.
    var exercisePosition: Int?
    var exerciseCount: Int?
    /// 1-based position of the current set within the exercise.
    var setPosition: Int?
    var setCount: Int?
    /// Preformatted target for the current set, e.g. "8 reps · 135 lbs".
    var targetText: String?
    var completedSets: Int?
    var totalSets: Int?

    // Cardio
    /// Preformatted on the phone, e.g. "1.24 mi".
    var distanceText: String?
    /// Preformatted on the phone, e.g. "9:41 /mi".
    var paceText: String?
}

nonisolated struct WatchQuickStatsSnapshot: Codable, Equatable {
    var lastWorkoutTitle: String?
    var lastWorkoutDate: Date?
    var lastWorkoutDurationSeconds: TimeInterval?
    var lastWorkoutSets: Int?
    /// Preformatted total volume, e.g. "12,450 lbs".
    var lastWorkoutVolumeText: String?
    var restingHeartRateBPM: Double?
}

// MARK: - Heart-rate zones
//
// The estimated 5-zone model (percent of estimated max heart rate). The thresholds
// mirror the estimated-zone math in HealthWorkoutDetailLoader so the watch glance
// agrees with the workout detail's zone cards.

nonisolated struct WatchHeartRateZoneConfig: Codable, Equatable {
    var estimatedMaxHeartRate: Double

    func zone(for bpm: Double) -> Int {
        let percentage = bpm / estimatedMaxHeartRate
        switch percentage {
        case ..<0.6: return 1
        case ..<0.7: return 2
        case ..<0.8: return 3
        case ..<0.9: return 4
        default: return 5
        }
    }

    func bounds(for zone: Int) -> (lower: Double?, upper: Double?) {
        switch zone {
        case 1: return (nil, estimatedMaxHeartRate * 0.6)
        case 2: return (estimatedMaxHeartRate * 0.6, estimatedMaxHeartRate * 0.7)
        case 3: return (estimatedMaxHeartRate * 0.7, estimatedMaxHeartRate * 0.8)
        case 4: return (estimatedMaxHeartRate * 0.8, estimatedMaxHeartRate * 0.9)
        case 5: return (estimatedMaxHeartRate * 0.9, nil)
        default: return (nil, nil)
        }
    }
}

// MARK: - Commands (watch → phone)

nonisolated enum WatchSyncCommand: Codable, Equatable {
    case requestSync
    case startRestTimer(seconds: Int)
    case pauseRestTimer
    case resumeRestTimer
    case stopRestTimer
    case adjustRestTimer(deltaSeconds: Int)
    case completeActiveSet
}
