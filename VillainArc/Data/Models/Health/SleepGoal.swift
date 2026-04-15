import Foundation
import SwiftData

@Model final class SleepGoal {
    #Index<SleepGoal>([\.startedOnDay])
    var startedOnDay: Date = Date()
    var endedOnDay: Date?
    var targetSleepDuration: TimeInterval = 0

    init(startedOnDay: Date = Date(), targetSleepDuration: TimeInterval) {
        self.startedOnDay = Self.calendar.startOfDay(for: startedOnDay)
        self.targetSleepDuration = max(0, targetSleepDuration)
    }

    private static let calendar = Calendar.autoupdatingCurrent
}

extension SleepGoal {
    static var history: FetchDescriptor<SleepGoal> {
        FetchDescriptor(sortBy: [SortDescriptor(\.startedOnDay, order: .reverse)])
    }

    static var active: FetchDescriptor<SleepGoal> {
        let predicate = #Predicate<SleepGoal> { $0.endedOnDay == nil }
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.startedOnDay, order: .reverse)])
        descriptor.fetchLimit = 1
        return descriptor
    }

    static func forDay(_ day: Date) -> FetchDescriptor<SleepGoal> {
        let normalizedDay = Calendar.autoupdatingCurrent.startOfDay(for: day)
        let predicate = #Predicate<SleepGoal> {
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

    @discardableResult
    static func replaceActiveGoal(with targetSleepDuration: TimeInterval, on day: Date = .now, context: ModelContext) throws -> Bool {
        let calendar = Calendar.autoupdatingCurrent
        let normalizedDay = calendar.startOfDay(for: day)
        let effectiveStartDay = calendar.date(byAdding: .day, value: 1, to: normalizedDay) ?? normalizedDay
        let activeGoal = try context.fetch(active).first

        if let activeGoal, activeGoal.targetSleepDuration == targetSleepDuration, calendar.isDate(activeGoal.startedOnDay, inSameDayAs: effectiveStartDay) {
            return false
        }

        if let activeGoal {
            if activeGoal.startedOnDay > normalizedDay || calendar.isDate(activeGoal.startedOnDay, inSameDayAs: effectiveStartDay) {
                context.delete(activeGoal)
            } else {
                activeGoal.endedOnDay = normalizedDay
            }
        }

        context.insert(SleepGoal(startedOnDay: effectiveStartDay, targetSleepDuration: targetSleepDuration))
        return true
    }
}
