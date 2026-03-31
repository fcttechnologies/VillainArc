import Foundation

enum TimeSeriesRangeFilter: String, CaseIterable, Identifiable, Sendable {
    case day = "D"
    case week = "W"
    case month = "M"
    case sixMonths = "6M"
    case year = "Y"
    case all = "All"

    static let buildOrder: [TimeSeriesRangeFilter] = [.month, .week, .sixMonths, .year, .all]
    static let nonDayCases: [TimeSeriesRangeFilter] = allCases.filter { $0 != .day }

    var id: String { rawValue }

    func domain(now: Date, calendar: Calendar, dates: [Date]) -> ClosedRange<Date> {
        let startOfToday = calendar.startOfDay(for: now)
        let endOfToday = calendar.endOfDay(for: now)

        switch self {
        case .day:
            return startOfToday...endOfToday
        case .week:
            let lowerBound = calendar.date(byAdding: .day, value: -6, to: startOfToday) ?? startOfToday
            return lowerBound...endOfToday
        case .month:
            let lowerBound = calendar.date(byAdding: .month, value: -1, to: startOfToday) ?? startOfToday
            return calendar.startOfDay(for: lowerBound)...endOfToday
        case .sixMonths:
            let currentWeek = calendar.dateInterval(of: .weekOfYear, for: now) ?? DateInterval(start: startOfToday, end: endOfToday.addingTimeInterval(1))
            let lowerBound = calendar.date(byAdding: .weekOfYear, value: -25, to: currentWeek.start) ?? currentWeek.start
            return lowerBound...currentWeek.chartUpperBound
        case .year:
            let currentMonth = calendar.dateInterval(of: .month, for: now) ?? DateInterval(start: startOfToday, end: endOfToday.addingTimeInterval(1))
            let lowerBound = calendar.date(byAdding: .month, value: -11, to: currentMonth.start) ?? currentMonth.start
            return lowerBound...currentMonth.chartUpperBound
        case .all:
            guard let oldestDate = dates.min(), let latestDate = dates.max() else {
                return startOfToday...endOfToday
            }
            return calendar.startOfDay(for: oldestDate)...calendar.endOfDay(for: latestDate)
        }
    }
}
