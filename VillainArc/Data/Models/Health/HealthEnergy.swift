import Foundation
import SwiftData

@Model final class HealthEnergy {
    #Index<HealthEnergy>([\.date])

    var date: Date = Date()
    var activeEnergyBurned: Double = 0
    var restingEnergyBurned: Double = 0

    private static let calendar = Calendar.autoupdatingCurrent

    var totalEnergyBurned: Double { activeEnergyBurned + restingEnergyBurned }

    init(date: Date, activeEnergyBurned: Double = 0, restingEnergyBurned: Double = 0) {
        self.date = Self.calendar.startOfDay(for: date)
        self.activeEnergyBurned = activeEnergyBurned
        self.restingEnergyBurned = restingEnergyBurned
    }
}

extension HealthEnergy {
    static var history: FetchDescriptor<HealthEnergy> { FetchDescriptor(sortBy: [SortDescriptor(\.date, order: .reverse)]) }

    static func recent(days: Int, now: Date = .now) -> FetchDescriptor<HealthEnergy> {
        let calendar = Calendar.autoupdatingCurrent
        let safeDayCount = max(1, days)
        let startDate = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -(safeDayCount - 1), to: now) ?? now)
        let predicate = #Predicate<HealthEnergy> { $0.date >= startDate }
        return FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.date, order: .reverse)])
    }

    static var latest: FetchDescriptor<HealthEnergy> {
        var descriptor = history
        descriptor.fetchLimit = 1
        return descriptor
    }

    static func forDay(_ date: Date) -> FetchDescriptor<HealthEnergy> {
        let normalizedDate = calendar.startOfDay(for: date)
        let predicate = #Predicate<HealthEnergy> { $0.date == normalizedDate }
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.date)])
        descriptor.fetchLimit = 1
        return descriptor
    }
}
