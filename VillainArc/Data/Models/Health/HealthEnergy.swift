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

    static var latest: FetchDescriptor<HealthEnergy> {
        var descriptor = history
        descriptor.fetchLimit = 1
        return descriptor
    }

    static var summary: FetchDescriptor<HealthEnergy> {
        var descriptor = history
        descriptor.fetchLimit = 7
        return descriptor
    }

    static func forDay(_ date: Date) -> FetchDescriptor<HealthEnergy> {
        let normalizedDate = calendar.startOfDay(for: date)
        let predicate = #Predicate<HealthEnergy> { $0.date == normalizedDate }
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.date)])
        descriptor.fetchLimit = 1
        return descriptor
    }

    enum ChartSegmentKind: String, Sendable {
        case resting
        case active
    }

    struct ChartSegment: Identifiable, Equatable, Sendable {
        let id: String
        let date: Date
        let startDate: Date
        let endDate: Date
        let sampleCount: Int
        let kind: ChartSegmentKind
        let value: Double
    }

    var chartSegments: [ChartSegment] {
        Self.makeChartSegments(date: date, startDate: date, endDate: date, sampleCount: 1, activeEnergy: activeEnergyBurned, restingEnergy: restingEnergyBurned)
    }

    static func makeChartSegments(date: Date, startDate: Date, endDate: Date, sampleCount: Int, activeEnergy: Double, restingEnergy: Double) -> [ChartSegment] {
        let restingEnergy = max(0, restingEnergy)
        let activeEnergy = max(0, activeEnergy)
        var segments: [ChartSegment] = []

        if activeEnergy > 0 {
            segments.append(ChartSegment(id: "\(startDate.timeIntervalSinceReferenceDate)-active", date: date, startDate: startDate, endDate: endDate, sampleCount: sampleCount, kind: .active, value: activeEnergy))
        }

        if restingEnergy > 0 {
            segments.append(ChartSegment(id: "\(startDate.timeIntervalSinceReferenceDate)-resting", date: date, startDate: startDate, endDate: endDate, sampleCount: sampleCount, kind: .resting, value: restingEnergy))
        }

        return segments
    }
}
