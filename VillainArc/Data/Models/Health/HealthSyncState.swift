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
