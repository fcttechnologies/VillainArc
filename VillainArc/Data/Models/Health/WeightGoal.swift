import Foundation
import SwiftData

@Model final class WeightGoal {
    #Index<WeightGoal>([\.startedAt], [\.endedAt])

    var id: UUID = UUID()
    var type: WeightGoalType = WeightGoalType.maintain
    var startedAt: Date = Date()
    var endedAt: Date?
    var endReason: WeightGoalEndReason?
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
