import Foundation
import SwiftData

@Model
final class WeightGoal {
    #Index<WeightGoal>([\.startedAt], [\.endedAt])

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
    static var history: FetchDescriptor<WeightGoal> {
        FetchDescriptor(sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
    }

    static var active: FetchDescriptor<WeightGoal> {
        let predicate = #Predicate<WeightGoal> { $0.endedAt == nil }
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        descriptor.fetchLimit = 1
        return descriptor
    }
}
