import Foundation

enum PeriodComparisonKind: Sendable { case month, year }

enum PeriodComparisonTrend: Sendable { case up, down, flat }

struct PeriodComparisonHighlight: Sendable {
    let kind: PeriodComparisonKind
    let currentLabel: String
    let previousLabel: String
    let currentAverage: Double
    let previousAverage: Double
    let trend: PeriodComparisonTrend
}

func makePeriodComparisonHighlight<Entry>(entries: [Entry], kind: PeriodComparisonKind, now: Date = .now, calendar: Calendar = .autoupdatingCurrent, date: (Entry) -> Date, value: (Entry) -> Double) -> PeriodComparisonHighlight? {
    let normalizedEntries = entries.map { (day: calendar.startOfDay(for: date($0)), value: value($0)) }.sorted { $0.day < $1.day }
    switch kind {
    case .month:
        guard let currentMonthInterval = calendar.dateInterval(of: .month, for: now), let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: now), let previousMonthInterval = calendar.dateInterval(of: .month, for: previousMonthDate) else { return nil }
        let currentEntries = normalizedEntries.filter { currentMonthInterval.contains($0.day) }
        guard let latestCurrentDay = currentEntries.map(\.day).max(), normalizedEntries.contains(where: { previousMonthInterval.contains($0.day) }) else { return nil }
        let currentStart = currentMonthInterval.start
        let previousStart = previousMonthInterval.start
        let previousEnd = previousMonthInterval.chartUpperBound
        let currentAverage = averageDailyValue(entriesByDay: Dictionary(uniqueKeysWithValues: currentEntries.map { ($0.day, $0.value) }), range: currentStart...latestCurrentDay, calendar: calendar)
        let previousAverage = averageDailyValue(entriesByDay: Dictionary(uniqueKeysWithValues: normalizedEntries.filter { previousMonthInterval.contains($0.day) }.map { ($0.day, $0.value) }), range: previousStart...previousEnd, calendar: calendar)
        return PeriodComparisonHighlight(kind: kind, currentLabel: currentStart.formatted(.dateTime.month(.wide)), previousLabel: previousStart.formatted(.dateTime.month(.wide)), currentAverage: currentAverage, previousAverage: previousAverage, trend: comparisonTrend(current: currentAverage, previous: previousAverage))
    case .year:
        let currentYear = calendar.component(.year, from: now)
        let previousYear = currentYear - 1
        let currentEntries = normalizedEntries.filter { calendar.component(.year, from: $0.day) == currentYear }
        guard let latestCurrentDay = currentEntries.map(\.day).max(), normalizedEntries.contains(where: { calendar.component(.year, from: $0.day) == previousYear }) else { return nil }
        let currentStart = calendar.startOfYear(for: now)
        let previousStart = calendar.startOfYear(for: calendar.date(byAdding: .year, value: -1, to: now) ?? now)
        let previousEnd = calendar.endOfYear(for: previousStart)
        let currentAverage = averageDailyValue(entriesByDay: Dictionary(uniqueKeysWithValues: currentEntries.map { ($0.day, $0.value) }), range: currentStart...latestCurrentDay, calendar: calendar)
        let previousAverage = averageDailyValue(entriesByDay: Dictionary(uniqueKeysWithValues: normalizedEntries.filter { calendar.component(.year, from: $0.day) == previousYear }.map { ($0.day, $0.value) }), range: previousStart...previousEnd, calendar: calendar)
        return PeriodComparisonHighlight(kind: kind, currentLabel: currentStart.formatted(.dateTime.year()), previousLabel: previousStart.formatted(.dateTime.year()), currentAverage: currentAverage, previousAverage: previousAverage, trend: comparisonTrend(current: currentAverage, previous: previousAverage))
    }
}

private func averageDailyValue(entriesByDay: [Date: Double], range: ClosedRange<Date>, calendar: Calendar) -> Double {
    let lowerBound = calendar.startOfDay(for: range.lowerBound)
    let upperBound = calendar.startOfDay(for: range.upperBound)
    let dayCount = max((calendar.dateComponents([.day], from: lowerBound, to: upperBound).day ?? 0) + 1, 1)
    return entriesByDay.reduce(0) { $0 + $1.value } / Double(dayCount)
}

private func comparisonTrend(current: Double, previous: Double) -> PeriodComparisonTrend {
    if current > previous { return .up }
    if current < previous { return .down }
    return .flat
}
