import Foundation
import SwiftData

@Model final class HydrationEntry {
    #Index<HydrationEntry>([\.date], [\.healthSampleUUID])
    var id: UUID = UUID()
    var date: Date = Date()
    var volume: Double = 0
    var hasBeenExportedToHealth: Bool = false
    var healthSampleUUID: UUID?
    var isAvailableInHealthKit: Bool = false
    var day: HydrationDay?

    init(date: Date = .now, volume: Double = 0, hasBeenExportedToHealth: Bool = false, healthSampleUUID: UUID? = nil, isAvailableInHealthKit: Bool = false) {
        self.date = date
        self.volume = volume
        self.hasBeenExportedToHealth = hasBeenExportedToHealth
        self.healthSampleUUID = healthSampleUUID
        self.isAvailableInHealthKit = isAvailableInHealthKit
    }
}

extension HydrationEntry {
    static var history: FetchDescriptor<HydrationEntry> { FetchDescriptor(sortBy: [SortDescriptor(\.date, order: .reverse)]) }

    static func last7Days(now: Date = .now, calendar: Calendar = .autoupdatingCurrent) -> FetchDescriptor<HydrationEntry> {
        let cutoff = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -6, to: now) ?? now)
        let predicate = #Predicate<HydrationEntry> { $0.date >= cutoff }
        return FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.date, order: .reverse)])
    }

    static func forDay(_ date: Date, calendar: Calendar = .autoupdatingCurrent) -> FetchDescriptor<HydrationEntry> {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        let predicate = #Predicate<HydrationEntry> { $0.date >= start && $0.date < end }
        return FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.date)])
    }

    static var latest: FetchDescriptor<HydrationEntry> {
        var descriptor = history
        descriptor.fetchLimit = 1
        return descriptor
    }

    static func byHealthSampleUUID(_ id: UUID) -> FetchDescriptor<HydrationEntry> {
        let predicate = #Predicate<HydrationEntry> { $0.healthSampleUUID == id }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        return descriptor
    }

    static func byID(_ id: UUID) -> FetchDescriptor<HydrationEntry> {
        let predicate = #Predicate<HydrationEntry> { $0.id == id }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        return descriptor
    }

    static var entriesNeedingHealthExport: FetchDescriptor<HydrationEntry> {
        let predicate = #Predicate<HydrationEntry> { $0.hasBeenExportedToHealth == false && $0.healthSampleUUID == nil }
        return FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.date, order: .reverse)])
    }

    static var unavailableEntries: FetchDescriptor<HydrationEntry> {
        let predicate = #Predicate<HydrationEntry> { $0.isAvailableInHealthKit == false && $0.healthSampleUUID != nil }
        return FetchDescriptor(predicate: predicate)
    }

    var isLinkedToHealth: Bool { healthSampleUUID != nil }

    var isImportedFromHealth: Bool { healthSampleUUID != nil && !hasBeenExportedToHealth }

    var canDeleteInApp: Bool { !isImportedFromHealth }
}

struct HydrationDailyTotal: Identifiable, Hashable, Sendable {
    let date: Date
    let totalVolume: Double
    let goalVolume: Double

    var id: Date { date }

    var remainingVolume: Double {
        max(0, goalVolume - totalVolume)
    }

    var overGoalVolume: Double {
        max(0, totalVolume - goalVolume)
    }

    var goalProgress: Double {
        guard goalVolume > 0 else { return 0 }
        return min(max(totalVolume / goalVolume, 0), 1)
    }
}

extension HydrationEntry {
    static func dailyTotals(from entries: [HydrationEntry], goalML: Double, calendar: Calendar = .autoupdatingCurrent) -> [HydrationDailyTotal] {
        let normalizedGoal = max(goalML, 1)
        let totalsByDay = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.date) }
            .mapValues { dayEntries in
                dayEntries.reduce(0) { $0 + max(0, $1.volume) }
            }

        return totalsByDay
            .map { HydrationDailyTotal(date: $0.key, totalVolume: $0.value, goalVolume: normalizedGoal) }
            .sorted { $0.date > $1.date }
    }

    static func todayTotal(from entries: [HydrationEntry], goalML: Double, calendar: Calendar = .autoupdatingCurrent, now: Date = .now) -> HydrationDailyTotal {
        let today = calendar.startOfDay(for: now)
        let total = entries.reduce(0) { partialResult, entry in
            calendar.isDate(entry.date, inSameDayAs: today) ? partialResult + max(0, entry.volume) : partialResult
        }
        return HydrationDailyTotal(date: today, totalVolume: total, goalVolume: max(goalML, 1))
    }
}
