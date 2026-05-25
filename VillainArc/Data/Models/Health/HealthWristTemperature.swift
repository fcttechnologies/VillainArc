import Foundation
import SwiftData

@Model final class HealthWristTemperature {
    #Index<HealthWristTemperature>([\.date])
    var date: Date = Date()
    var temperature: Double = 0

    private static let calendar = Calendar.autoupdatingCurrent

    init(date: Date, temperature: Double) {
        self.date = Self.calendar.startOfDay(for: date)
        self.temperature = temperature
    }
}

extension HealthWristTemperature {
    static var history: FetchDescriptor<HealthWristTemperature> {
        FetchDescriptor(sortBy: [SortDescriptor(\.date, order: .reverse)])
    }

    static var latest: FetchDescriptor<HealthWristTemperature> {
        var descriptor = history
        descriptor.fetchLimit = 1
        return descriptor
    }

    static var summary: FetchDescriptor<HealthWristTemperature> {
        var descriptor = history
        descriptor.fetchLimit = 7
        return descriptor
    }

    static func forDay(_ date: Date) -> FetchDescriptor<HealthWristTemperature> {
        let normalizedDate = calendar.startOfDay(for: date)
        let predicate = #Predicate<HealthWristTemperature> { $0.date == normalizedDate }
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.date)])
        descriptor.fetchLimit = 1
        return descriptor
    }

    static func inDayRange(_ dayRange: ClosedRange<Date>) -> FetchDescriptor<HealthWristTemperature> {
        let lowerBound = calendar.startOfDay(for: dayRange.lowerBound)
        let upperBound = calendar.startOfDay(for: dayRange.upperBound)
        let predicate = #Predicate<HealthWristTemperature> { $0.date >= lowerBound && $0.date <= upperBound }
        return FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.date)])
    }
}
