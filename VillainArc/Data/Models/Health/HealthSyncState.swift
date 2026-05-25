import Foundation
import SwiftData

@Model final class HealthSyncState {
    var stepCountSyncedRangeStart: Date?
    var stepCountSyncedRangeEnd: Date?
    var walkingRunningDistanceSyncedRangeStart: Date?
    var walkingRunningDistanceSyncedRangeEnd: Date?
    var activeEnergyBurnedSyncedRangeStart: Date?
    var activeEnergyBurnedSyncedRangeEnd: Date?
    var restingEnergyBurnedSyncedRangeStart: Date?
    var restingEnergyBurnedSyncedRangeEnd: Date?
    var sleepWakeDaySyncedRangeStart: Date?
    var sleepWakeDaySyncedRangeEnd: Date?
    var doubleGoalLastTriggeredDay: Date?
    var tripleGoalLastTriggeredDay: Date?
    var bestDailyStepsKnown: Int?
    var newHighStepsLastTriggeredDay: Date?
    var sleepGoalLastNotifiedWakeDay: Date?
    var weeklyCoachingLastDeliveredWeekStart: Date?
    var heartRateSyncedRangeStart: Date?
    var heartRateSyncedRangeEnd: Date?
    var restingHeartRateSyncedRangeStart: Date?
    var restingHeartRateSyncedRangeEnd: Date?
    var walkingHeartRateSyncedRangeStart: Date?
    var walkingHeartRateSyncedRangeEnd: Date?
    var heartRateVariabilitySyncedRangeStart: Date?
    var heartRateVariabilitySyncedRangeEnd: Date?
    var respiratoryRateSyncedRangeStart: Date?
    var respiratoryRateSyncedRangeEnd: Date?
    var wristTemperatureSyncedRangeStart: Date?
    var wristTemperatureSyncedRangeEnd: Date?
    var dietaryWaterSyncedRangeStart: Date?
    var dietaryWaterSyncedRangeEnd: Date?

    init() {}

    var stepCountSyncedRange: ClosedRange<Date>? {
        get { Self.makeRange(start: stepCountSyncedRangeStart, end: stepCountSyncedRangeEnd) }
        set {
            stepCountSyncedRangeStart = newValue?.lowerBound
            stepCountSyncedRangeEnd = newValue?.upperBound
        }
    }

    var walkingRunningDistanceSyncedRange: ClosedRange<Date>? {
        get { Self.makeRange(start: walkingRunningDistanceSyncedRangeStart, end: walkingRunningDistanceSyncedRangeEnd) }
        set {
            walkingRunningDistanceSyncedRangeStart = newValue?.lowerBound
            walkingRunningDistanceSyncedRangeEnd = newValue?.upperBound
        }
    }

    var activeEnergyBurnedSyncedRange: ClosedRange<Date>? {
        get { Self.makeRange(start: activeEnergyBurnedSyncedRangeStart, end: activeEnergyBurnedSyncedRangeEnd) }
        set {
            activeEnergyBurnedSyncedRangeStart = newValue?.lowerBound
            activeEnergyBurnedSyncedRangeEnd = newValue?.upperBound
        }
    }

    var restingEnergyBurnedSyncedRange: ClosedRange<Date>? {
        get { Self.makeRange(start: restingEnergyBurnedSyncedRangeStart, end: restingEnergyBurnedSyncedRangeEnd) }
        set {
            restingEnergyBurnedSyncedRangeStart = newValue?.lowerBound
            restingEnergyBurnedSyncedRangeEnd = newValue?.upperBound
        }
    }

    var sleepWakeDaySyncedRange: ClosedRange<Date>? {
        get { Self.makeRange(start: sleepWakeDaySyncedRangeStart, end: sleepWakeDaySyncedRangeEnd) }
        set {
            sleepWakeDaySyncedRangeStart = newValue?.lowerBound
            sleepWakeDaySyncedRangeEnd = newValue?.upperBound
        }
    }

    var heartRateSyncedRange: ClosedRange<Date>? {
        get { Self.makeRange(start: heartRateSyncedRangeStart, end: heartRateSyncedRangeEnd) }
        set {
            heartRateSyncedRangeStart = newValue?.lowerBound
            heartRateSyncedRangeEnd = newValue?.upperBound
        }
    }

    var restingHeartRateSyncedRange: ClosedRange<Date>? {
        get { Self.makeRange(start: restingHeartRateSyncedRangeStart, end: restingHeartRateSyncedRangeEnd) }
        set {
            restingHeartRateSyncedRangeStart = newValue?.lowerBound
            restingHeartRateSyncedRangeEnd = newValue?.upperBound
        }
    }

    var walkingHeartRateSyncedRange: ClosedRange<Date>? {
        get { Self.makeRange(start: walkingHeartRateSyncedRangeStart, end: walkingHeartRateSyncedRangeEnd) }
        set {
            walkingHeartRateSyncedRangeStart = newValue?.lowerBound
            walkingHeartRateSyncedRangeEnd = newValue?.upperBound
        }
    }

    var heartRateVariabilitySyncedRange: ClosedRange<Date>? {
        get { Self.makeRange(start: heartRateVariabilitySyncedRangeStart, end: heartRateVariabilitySyncedRangeEnd) }
        set {
            heartRateVariabilitySyncedRangeStart = newValue?.lowerBound
            heartRateVariabilitySyncedRangeEnd = newValue?.upperBound
        }
    }

    var respiratoryRateSyncedRange: ClosedRange<Date>? {
        get { Self.makeRange(start: respiratoryRateSyncedRangeStart, end: respiratoryRateSyncedRangeEnd) }
        set {
            respiratoryRateSyncedRangeStart = newValue?.lowerBound
            respiratoryRateSyncedRangeEnd = newValue?.upperBound
        }
    }

    var wristTemperatureSyncedRange: ClosedRange<Date>? {
        get { Self.makeRange(start: wristTemperatureSyncedRangeStart, end: wristTemperatureSyncedRangeEnd) }
        set {
            wristTemperatureSyncedRangeStart = newValue?.lowerBound
            wristTemperatureSyncedRangeEnd = newValue?.upperBound
        }
    }

    var dietaryWaterSyncedRange: ClosedRange<Date>? {
        get { Self.makeRange(start: dietaryWaterSyncedRangeStart, end: dietaryWaterSyncedRangeEnd) }
        set {
            dietaryWaterSyncedRangeStart = newValue?.lowerBound
            dietaryWaterSyncedRangeEnd = newValue?.upperBound
        }
    }

    private static func makeRange(start: Date?, end: Date?) -> ClosedRange<Date>? {
        guard let start, let end else { return nil }
        return start...end
    }
}

extension HealthSyncState {
    static var single: FetchDescriptor<HealthSyncState> {
        var descriptor = FetchDescriptor<HealthSyncState>()
        descriptor.fetchLimit = 1
        return descriptor
    }
}
