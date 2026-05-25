import Foundation
import SwiftData

@Model final class HealthHeart {
    #Index<HealthHeart>([\.date])
    var date: Date = Date()
    var minHeartRate: Double?
    var maxHeartRate: Double?
    var restingHeartRate: Double?
    var walkingHeartRateAverage: Double?
    var heartRateVariabilitySDNN: Double?

    private static let calendar = Calendar.autoupdatingCurrent

    init(date: Date) {
        self.date = Self.calendar.startOfDay(for: date)
    }
}

extension HealthHeart {
    static var history: FetchDescriptor<HealthHeart> {
        FetchDescriptor(sortBy: [SortDescriptor(\.date, order: .reverse)])
    }

    static var latest: FetchDescriptor<HealthHeart> {
        var descriptor = history
        descriptor.fetchLimit = 1
        return descriptor
    }

    static var summary: FetchDescriptor<HealthHeart> {
        var descriptor = history
        descriptor.fetchLimit = 7
        return descriptor
    }

    static func forDay(_ date: Date) -> FetchDescriptor<HealthHeart> {
        let normalizedDate = calendar.startOfDay(for: date)
        let predicate = #Predicate<HealthHeart> { $0.date == normalizedDate }
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.date)])
        descriptor.fetchLimit = 1
        return descriptor
    }

    static func inDayRange(_ dayRange: ClosedRange<Date>) -> FetchDescriptor<HealthHeart> {
        let lowerBound = calendar.startOfDay(for: dayRange.lowerBound)
        let upperBound = calendar.startOfDay(for: dayRange.upperBound)
        let predicate = #Predicate<HealthHeart> { $0.date >= lowerBound && $0.date <= upperBound }
        return FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.date)])
    }
}
