import Foundation
import SwiftData

@Model final class WeightGoal {
    #Index<WeightGoal>([\.startedAt], [\.endedAt])
    @Attribute(.preserveValueOnDeletion) var id: UUID = UUID()
    var type: WeightGoalType = WeightGoalType.maintain
    var startedAt: Date = Date()
    var endedAt: Date?
    /// Raw text, not a `WeightGoalEndReason?` attribute: an optional enum attribute on a synced
    /// model is dropped by the sync applier's save (`UserProfile.fitnessLevelRawValue` carries the
    /// full note). `SyncedOptionalEnumSweepTests` pins this one.
    var endReasonRawValue: String?
    var startWeight: Double = 0
    var targetWeight: Double = 0
    var targetDate: Date?
    var targetRatePerWeek: Double?

    init(type: WeightGoalType = WeightGoalType.maintain, startWeight: Double = 0, targetWeight: Double = 0, targetDate: Date? = nil, targetRatePerWeek: Double? = nil) {
        self.type = type
        self.startWeight = startWeight
        self.targetWeight = targetWeight
        self.targetDate = targetDate
        self.targetRatePerWeek = targetRatePerWeek
    }

    /// The typed face of `endReasonRawValue`; every surface reads and writes this.
    var endReason: WeightGoalEndReason? {
        get { endReasonRawValue.flatMap(WeightGoalEndReason.init(rawValue:)) }
        set { endReasonRawValue = newValue?.rawValue }
    }
}

extension WeightGoal {
    static var history: FetchDescriptor<WeightGoal> { FetchDescriptor(sortBy: [SortDescriptor(\.startedAt, order: .reverse)]) }

    static func byID(_ id: UUID) -> FetchDescriptor<WeightGoal> {
        let predicate = #Predicate<WeightGoal> { $0.id == id }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        return descriptor
    }

    static var active: FetchDescriptor<WeightGoal> {
        let predicate = #Predicate<WeightGoal> { $0.endedAt == nil }
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        descriptor.fetchLimit = 1
        return descriptor
    }
    
    static var inactiveLatest: FetchDescriptor<WeightGoal> {
        let predicate = #Predicate<WeightGoal> { $0.endedAt != nil }
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        descriptor.fetchLimit = 1
        return descriptor
    }
    
    static var latestEnded: FetchDescriptor<WeightGoal> {
        let predicate = #Predicate<WeightGoal> { $0.endedAt != nil }
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.endedAt, order: .reverse)])
        descriptor.fetchLimit = 1
        return descriptor
    }

    func contains(_ date: Date) -> Bool {
        guard date >= startedAt else { return false }
        guard let endedAt else { return true }
        return date < endedAt
    }

    func reachesTarget(with weight: Double, toleranceKg: Double) -> Bool {
        switch type {
        case .cut:
            return weight <= targetWeight + toleranceKg
        case .bulk:
            return weight >= targetWeight - toleranceKg
        case .maintain:
            return false
        }
    }
}
