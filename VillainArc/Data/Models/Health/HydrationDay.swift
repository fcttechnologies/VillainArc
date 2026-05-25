import Foundation
import SwiftData

nonisolated struct HydrationGoalNotification: Sendable, Equatable {
    let date: Date
    let totalVolume: Double
    let targetML: Double

    var title: String {
        "Hydration Goal Reached"
    }

    var body: String {
        "You logged \(Self.formattedVolumeText(totalVolume)) and reached your \(Self.formattedVolumeText(targetML)) hydration goal."
    }

    func localNotificationVersion(for mode: HydrationEventNotificationMode) -> HydrationGoalNotification? {
        switch mode {
        case .off:
            return nil
        case .goalOnly, .coaching:
            return self
        }
    }

    private static func formattedVolumeText(_ volume: Double) -> String {
        "\(Int(volume.rounded()).formatted(.number)) mL"
    }
}

@Model final class HydrationDay {
    #Index<HydrationDay>([\.date])
    var date: Date = Date()
    var totalVolume: Double = 0
    var goalTargetML: Double?
    var goalCompletedAt: Date?
    @Relationship(deleteRule: .nullify, inverse: \HydrationEntry.day) var entries: [HydrationEntry]? = [HydrationEntry]()

    private static let calendar = Calendar.autoupdatingCurrent

    init(date: Date = .now, totalVolume: Double = 0, goalTargetML: Double? = nil, goalCompletedAt: Date? = nil) {
        self.date = Self.calendar.startOfDay(for: date)
        self.totalVolume = max(0, totalVolume)
        self.goalTargetML = goalTargetML
        self.goalCompletedAt = goalCompletedAt
    }

    var goalCompleted: Bool {
        goalCompletedAt != nil
    }
}

extension HydrationDay {
    static var history: FetchDescriptor<HydrationDay> {
        FetchDescriptor(sortBy: [SortDescriptor(\.date, order: .reverse)])
    }

    static var latest: FetchDescriptor<HydrationDay> {
        var descriptor = history
        descriptor.fetchLimit = 1
        return descriptor
    }

    static var summary: FetchDescriptor<HydrationDay> {
        var descriptor = history
        descriptor.fetchLimit = 7
        return descriptor
    }

    static func forDay(_ date: Date) -> FetchDescriptor<HydrationDay> {
        let normalizedDate = calendar.startOfDay(for: date)
        let predicate = #Predicate<HydrationDay> { $0.date == normalizedDate }
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.date)])
        descriptor.fetchLimit = 1
        return descriptor
    }

    static func inDayRange(_ dayRange: ClosedRange<Date>) -> FetchDescriptor<HydrationDay> {
        let lowerBound = calendar.startOfDay(for: dayRange.lowerBound)
        let upperBound = calendar.startOfDay(for: dayRange.upperBound)
        let predicate = #Predicate<HydrationDay> { $0.date >= lowerBound && $0.date <= upperBound }
        return FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.date)])
    }

    @discardableResult
    static func reconcile(for date: Date, context: ModelContext) throws -> (day: HydrationDay, didCompleteGoal: Bool) {
        let normalizedDate = calendar.startOfDay(for: date)
        let entries = try context.fetch(HydrationEntry.forDay(normalizedDate))
        let goal = try context.fetch(HydrationGoal.forDay(normalizedDate)).first
        let totalVolume = entries.reduce(0) { $0 + max(0, $1.volume) }
        let targetML = goal?.targetML
        let completedAt = completionDate(entries: entries, targetML: targetML)

        let existingDay = try context.fetch(forDay(normalizedDate)).first
        let day = existingDay ?? HydrationDay(date: normalizedDate)
        let wasComplete = day.goalCompleted
        day.totalVolume = totalVolume
        day.goalTargetML = targetML
        day.goalCompletedAt = completedAt
        for entry in entries {
            entry.day = day
        }

        if existingDay == nil {
            context.insert(day)
        }

        return (day, !wasComplete && completedAt != nil)
    }

    static func reconcileAll(context: ModelContext) throws {
        let entries = try context.fetch(HydrationEntry.history)
        let days = Set(entries.map { calendar.startOfDay(for: $0.date) })
        for day in days {
            try reconcile(for: day, context: context)
        }
    }

    private static func completionDate(entries: [HydrationEntry], targetML: Double?) -> Date? {
        guard let targetML, targetML > 0 else { return nil }
        var runningTotal = 0.0
        for entry in entries.sorted(by: { $0.date < $1.date }) {
            runningTotal += max(0, entry.volume)
            if runningTotal >= targetML {
                return entry.date
            }
        }
        return nil
    }
}
