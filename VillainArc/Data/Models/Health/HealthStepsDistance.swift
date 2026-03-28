import Foundation
import SwiftData

@Model final class HealthStepsDistance {
    #Index<HealthStepsDistance>([\.date])

    var date: Date = Date()
    var stepCount: Int = 0
    var distance: Double = 0 // Stored canonically in meters.
    
    private static let calendar = Calendar.autoupdatingCurrent

    init(date: Date, stepCount: Int = 0, distance: Double = 0) {
        self.date = Self.calendar.startOfDay(for: date)
        self.stepCount = stepCount
        self.distance = distance
    }
}

extension HealthStepsDistance {
    static var history: FetchDescriptor<HealthStepsDistance> {
        FetchDescriptor(sortBy: [SortDescriptor(\.date, order: .reverse)])
    }

    static var summary: FetchDescriptor<HealthStepsDistance> {
        var descriptor = history
        descriptor.fetchLimit = 7
        return descriptor
    }

    static func forDay(_ date: Date) -> FetchDescriptor<HealthStepsDistance> {
        let normalizedDate = calendar.startOfDay(for: date)
        let predicate = #Predicate<HealthStepsDistance> { $0.date == normalizedDate }
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.date)])
        descriptor.fetchLimit = 1
        return descriptor
    }
}
