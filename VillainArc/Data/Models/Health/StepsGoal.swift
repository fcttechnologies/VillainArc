import Foundation
import SwiftData

@Model final class StepsGoal {
    #Index<StepsGoal>([\.startedOnDay])
    var startedOnDay: Date = Date()
    var endedOnDay: Date?
    var targetSteps: Int = 0

    init(startedOnDay: Date = Date(), targetSteps: Int) {
        self.startedOnDay = Self.calendar.startOfDay(for: startedOnDay)
        self.targetSteps = max(0, targetSteps)
    }
    
    private static let calendar = Calendar.autoupdatingCurrent
}

extension StepsGoal {
    static var history: FetchDescriptor<StepsGoal> {
        FetchDescriptor(sortBy: [SortDescriptor(\.startedOnDay, order: .reverse)])
    }

    static var active: FetchDescriptor<StepsGoal> {
        let predicate = #Predicate<StepsGoal> { $0.endedOnDay == nil }
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.startedOnDay, order: .reverse)])
        descriptor.fetchLimit = 1
        return descriptor
    }

    static func forDay(_ day: Date) -> FetchDescriptor<StepsGoal> {
        let normalizedDay = Calendar.autoupdatingCurrent.startOfDay(for: day)
        let predicate = #Predicate<StepsGoal> {
            $0.startedOnDay <= normalizedDay && ($0.endedOnDay == nil || normalizedDay <= ($0.endedOnDay ?? normalizedDay))
        }
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.startedOnDay, order: .reverse)])
        descriptor.fetchLimit = 1
        return descriptor
    }

    func contains(day: Date) -> Bool {
        let normalizedDay = Self.calendar.startOfDay(for: day)
        guard normalizedDay >= startedOnDay else { return false }
        guard let endedOnDay else { return true }
        return normalizedDay <= endedOnDay
    }
}
