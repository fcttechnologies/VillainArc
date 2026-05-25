import Foundation
import SwiftData

@Model final class HealthRespiratoryRate {
    #Index<HealthRespiratoryRate>([\.date])
    var date: Date = Date()
    var minRate: Double?
    var maxRate: Double?

    private static let calendar = Calendar.autoupdatingCurrent

    init(date: Date) {
        self.date = Self.calendar.startOfDay(for: date)
    }
}

extension HealthRespiratoryRate {
    static var history: FetchDescriptor<HealthRespiratoryRate> {
        FetchDescriptor(sortBy: [SortDescriptor(\.date, order: .reverse)])
    }

    static var latest: FetchDescriptor<HealthRespiratoryRate> {
        var descriptor = history
        descriptor.fetchLimit = 1
        return descriptor
    }

    static var summary: FetchDescriptor<HealthRespiratoryRate> {
        var descriptor = history
        descriptor.fetchLimit = 7
        return descriptor
    }

    static func forDay(_ date: Date) -> FetchDescriptor<HealthRespiratoryRate> {
        let normalizedDate = calendar.startOfDay(for: date)
        let predicate = #Predicate<HealthRespiratoryRate> { $0.date == normalizedDate }
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.date)])
        descriptor.fetchLimit = 1
        return descriptor
    }

    static func inDayRange(_ dayRange: ClosedRange<Date>) -> FetchDescriptor<HealthRespiratoryRate> {
        let lowerBound = calendar.startOfDay(for: dayRange.lowerBound)
        let upperBound = calendar.startOfDay(for: dayRange.upperBound)
        let predicate = #Predicate<HealthRespiratoryRate> { $0.date >= lowerBound && $0.date <= upperBound }
        return FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.date)])
    }
}
