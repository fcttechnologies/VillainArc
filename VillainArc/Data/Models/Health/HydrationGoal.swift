import Foundation
import SwiftData

@Model final class HydrationGoal {
    #Index<HydrationGoal>([\.startedOnDay])
    var startedOnDay: Date = Date()
    var endedOnDay: Date?
    var targetML: Double = 3000

    init(startedOnDay: Date = Date(), targetML: Double) {
        self.startedOnDay = Self.calendar.startOfDay(for: startedOnDay)
        self.targetML = max(0, targetML)
    }

    private static let calendar = Calendar.autoupdatingCurrent
}

extension HydrationGoal {
    static var history: FetchDescriptor<HydrationGoal> {
        FetchDescriptor(sortBy: [SortDescriptor(\.startedOnDay, order: .reverse)])
    }

    static var active: FetchDescriptor<HydrationGoal> {
        let predicate = #Predicate<HydrationGoal> { $0.endedOnDay == nil }
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.startedOnDay, order: .reverse)])
        descriptor.fetchLimit = 1
        return descriptor
    }

    static func forDay(_ day: Date) -> FetchDescriptor<HydrationGoal> {
        let normalizedDay = Calendar.autoupdatingCurrent.startOfDay(for: day)
        let predicate = #Predicate<HydrationGoal> {
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
