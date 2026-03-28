import Foundation
import SwiftUI
import Charts

func progressivelyRebuildRangeCache<Data>(existing: [TimeSeriesRangeFilter: Data], buildOrder: [TimeSeriesRangeFilter] = TimeSeriesRangeFilter.buildOrder, publish: ([TimeSeriesRangeFilter: Data]) -> Void, builder: (TimeSeriesRangeFilter) -> Data) {
    var cache = existing
    for range in buildOrder {
        cache[range] = builder(range)
        publish(cache)
    }
}

struct TimeSeriesSample: Identifiable, Equatable, Sendable {
    let id: UUID
    let date: Date
    let value: Double
    
    init(id: UUID = UUID(), date: Date, value: Double) {
        self.id = id
        self.date = date
        self.value = value
    }
}

struct TimeSeriesBucketedPoint: Identifiable, Equatable, Sendable {
    let id: UUID
    let date: Date
    let value: Double
    let startDate: Date
    let endDate: Date
    let sampleCount: Int
    
    init(id: UUID, date: Date, value: Double, startDate: Date, endDate: Date, sampleCount: Int) {
        self.id = id
        self.date = date
        self.value = value
        self.startDate = startDate
        self.endDate = endDate
        self.sampleCount = sampleCount
    }
    
    init(id: UUID = UUID(), date: Date, value: Double) {
        self.init(id: id, date: date, value: value, startDate: date, endDate: date, sampleCount: 1)
    }
}

enum TimeSeriesBucketStyle: Sendable {
    case day
    case week
    case month(monthsPerBucket: Int)
}

enum TimeSeriesAxisLabelStyle: Sendable {
    case weekdayShort
    case monthDay
    case monthAbbreviated
    case monthInitial
    case year
}

enum TimeSeriesAggregationStrategy: Sendable {
    case average
    case maximum
    case sum
    case last
}

struct TimeSeriesChartLayout: Sendable {
    let currentDomain: ClosedRange<Date>
    let points: [TimeSeriesBucketedPoint]
    let bucketStyle: TimeSeriesBucketStyle
    let axisDates: [Date]
    let axisLabelStyle: TimeSeriesAxisLabelStyle
    
    private init(currentDomain: ClosedRange<Date>, points: [TimeSeriesBucketedPoint], bucketStyle: TimeSeriesBucketStyle, axisDates: [Date], axisLabelStyle: TimeSeriesAxisLabelStyle) {
        self.currentDomain = currentDomain
        self.points = points
        self.bucketStyle = bucketStyle
        self.axisDates = axisDates
        self.axisLabelStyle = axisLabelStyle
    }
    
    init(rangeFilter: TimeSeriesRangeFilter, samples: [TimeSeriesSample], now: Date, calendar: Calendar, aggregation: TimeSeriesAggregationStrategy = .average) {
        switch rangeFilter {
        case .week:
            let domain = rangeFilter.domain(now: now, calendar: calendar, dates: samples.map(\.date))
            self.currentDomain = domain
            self.points = Self.dayBucketPoints(from: samples, in: domain, calendar: calendar, aggregation: aggregation)
            self.bucketStyle = .day
            self.axisDates = dayBoundaryDates(in: domain, calendar: calendar)
            self.axisLabelStyle = .weekdayShort
        case .month:
            let domain = rangeFilter.domain(now: now, calendar: calendar, dates: samples.map(\.date))
            self.currentDomain = domain
            self.points = Self.dayBucketPoints(from: samples, in: domain, calendar: calendar, aggregation: aggregation)
            self.bucketStyle = .day
            self.axisDates = weekStartDates(in: domain, calendar: calendar)
            self.axisLabelStyle = .monthDay
        case .sixMonths:
            let domain = rangeFilter.domain(now: now, calendar: calendar, dates: samples.map(\.date))
            self.currentDomain = domain
            self.points = Self.weekBucketPoints(from: samples, in: domain, calendar: calendar, aggregation: aggregation)
            self.bucketStyle = .week
            self.axisDates = monthStartDates(in: domain, stepMonths: 1, calendar: calendar)
            self.axisLabelStyle = .monthAbbreviated
        case .year:
            let domain = rangeFilter.domain(now: now, calendar: calendar, dates: samples.map(\.date))
            self.currentDomain = domain
            self.points = Self.monthBucketPoints(from: samples, in: domain, monthsPerBucket: 1, calendar: calendar, aggregation: aggregation)
            self.bucketStyle = .month(monthsPerBucket: 1)
            self.axisDates = monthStartDates(in: domain, stepMonths: 1, calendar: calendar)
            self.axisLabelStyle = .monthInitial
        case .all:
            self = Self.makeAllLayout(samples: samples, now: now, calendar: calendar, aggregation: aggregation)
        }
    }
    
    private static func makeAllLayout(samples: [TimeSeriesSample], now: Date, calendar: Calendar, aggregation: TimeSeriesAggregationStrategy) -> Self {
        let fallbackDomain = calendar.startOfDay(for: now)...calendar.endOfDay(for: now)
        guard let oldestDate = samples.map(\.date).min(), let latestDate = samples.map(\.date).max() else {
            return TimeSeriesChartLayout(currentDomain: fallbackDomain, points: [], bucketStyle: .day, axisDates: [], axisLabelStyle: .monthDay)
        }
        
        let spanDays = max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: oldestDate), to: calendar.startOfDay(for: latestDate)).day ?? 0)
        
        if spanDays <= 31 {
            let domain = calendar.startOfDay(for: oldestDate)...calendar.endOfDay(for: latestDate)
            let axisDates = spanDays <= 7 ? dayBoundaryDates(in: domain, calendar: calendar) : weekStartDates(in: domain, calendar: calendar)
            let axisLabelStyle: TimeSeriesAxisLabelStyle = spanDays <= 7 ? .weekdayShort : .monthDay
            return TimeSeriesChartLayout(currentDomain: domain, points: dayBucketPoints(from: samples, in: domain, calendar: calendar, aggregation: aggregation), bucketStyle: .day, axisDates: axisDates, axisLabelStyle: axisLabelStyle)
        }
        
        if spanDays <= 182 {
            let lowerWeek = calendar.dateInterval(of: .weekOfYear, for: oldestDate)?.start ?? calendar.startOfDay(for: oldestDate)
            let upperWeek = calendar.dateInterval(of: .weekOfYear, for: latestDate)?.chartUpperBound ?? calendar.endOfDay(for: latestDate)
            let domain = lowerWeek...upperWeek
            return TimeSeriesChartLayout(currentDomain: domain, points: weekBucketPoints(from: samples, in: domain, calendar: calendar, aggregation: aggregation), bucketStyle: .week, axisDates: monthStartDates(in: domain, stepMonths: 1, calendar: calendar), axisLabelStyle: .monthAbbreviated)
        }
        
        let lowerMonth = calendar.startOfMonth(for: oldestDate)
        let upperMonthInterval = calendar.dateInterval(of: .month, for: latestDate) ?? DateInterval(start: calendar.startOfMonth(for: latestDate), end: calendar.endOfDay(for: latestDate).addingTimeInterval(1))
        let upperMonth = upperMonthInterval.chartUpperBound
        let totalMonths = inclusiveMonthCount(from: lowerMonth, to: upperMonthInterval.start, calendar: calendar)
        let monthsPerBucket = totalMonths <= 12 ? 1 : Int(ceil(Double(totalMonths) / 30.0))
        let domain = lowerMonth...upperMonth
        let axisDates: [Date]
        let axisLabelStyle: TimeSeriesAxisLabelStyle
        
        if totalMonths <= 12 {
            axisDates = monthStartDates(in: domain, stepMonths: 1, calendar: calendar)
            axisLabelStyle = .monthInitial
        } else if totalMonths <= 30 {
            let stepMonths = totalMonths <= 20 ? 2 : 3
            axisDates = monthStartDates(in: domain, stepMonths: stepMonths, calendar: calendar)
            axisLabelStyle = .monthAbbreviated
        } else {
            let stepYears: Int
            switch totalMonths {
            case ...72:
                stepYears = 1
            case ...144:
                stepYears = 2
            case ...216:
                stepYears = 3
            case ...360:
                stepYears = 5
            default:
                stepYears = 10
            }
            axisDates = yearStartDates(in: domain, stepYears: stepYears, calendar: calendar)
            axisLabelStyle = .year
        }
        
        return TimeSeriesChartLayout(currentDomain: domain, points: monthBucketPoints(from: samples, in: domain, monthsPerBucket: monthsPerBucket, calendar: calendar, aggregation: aggregation), bucketStyle: .month(monthsPerBucket: monthsPerBucket), axisDates: axisDates, axisLabelStyle: axisLabelStyle)
    }
    
    private static func dayBucketPoints(from samples: [TimeSeriesSample], in domain: ClosedRange<Date>, calendar: Calendar, aggregation: TimeSeriesAggregationStrategy) -> [TimeSeriesBucketedPoint] {
        let buckets = Dictionary(grouping: samples.filter { domain.contains($0.date) }) { calendar.startOfDay(for: $0.date) }
        return buckets.compactMap { dayStart, bucketSamples in
            guard !bucketSamples.isEmpty else { return nil }
            let dayEnd = calendar.endOfDay(for: dayStart)
            let value = aggregate(bucketSamples, using: aggregation)
            return TimeSeriesBucketedPoint(id: UUID(), date: midpointDate(start: dayStart, end: dayEnd), value: value, startDate: dayStart, endDate: dayEnd, sampleCount: bucketSamples.count)
        }
        .sorted { $0.date < $1.date }
    }
    
    private static func weekBucketPoints(from samples: [TimeSeriesSample], in domain: ClosedRange<Date>, calendar: Calendar, aggregation: TimeSeriesAggregationStrategy) -> [TimeSeriesBucketedPoint] {
        let buckets = Dictionary(grouping: samples.filter { domain.contains($0.date) }) { sample in
            calendar.dateInterval(of: .weekOfYear, for: sample.date)?.start ?? calendar.startOfDay(for: sample.date)
        }
        return buckets.compactMap { weekStart, bucketSamples in
            guard !bucketSamples.isEmpty else { return nil }
            let interval = calendar.dateInterval(of: .weekOfYear, for: weekStart) ?? DateInterval(start: weekStart, end: calendar.endOfDay(for: weekStart).addingTimeInterval(1))
            let value = aggregate(bucketSamples, using: aggregation)
            return TimeSeriesBucketedPoint(id: UUID(), date: midpointDate(start: interval.start, end: interval.chartUpperBound), value: value, startDate: interval.start, endDate: interval.chartUpperBound, sampleCount: bucketSamples.count)
        }
        .sorted { $0.date < $1.date }
    }
    
    private static func monthBucketPoints(from samples: [TimeSeriesSample], in domain: ClosedRange<Date>, monthsPerBucket: Int, calendar: Calendar, aggregation: TimeSeriesAggregationStrategy) -> [TimeSeriesBucketedPoint] {
        let filteredSamples = samples.filter { domain.contains($0.date) }
        guard !filteredSamples.isEmpty else { return [] }
        
        let baseMonthStart = calendar.startOfMonth(for: domain.lowerBound)
        let buckets = Dictionary(grouping: filteredSamples) { sample in
            let monthStart = calendar.startOfMonth(for: sample.date)
            let monthOffset = monthOffsetBetween(baseMonthStart, and: monthStart, calendar: calendar)
            return monthOffset / monthsPerBucket
        }
        
        return buckets.compactMap { bucketIndex, bucketSamples in
            guard !bucketSamples.isEmpty else { return nil }
            let bucketStart = calendar.date(byAdding: .month, value: bucketIndex * monthsPerBucket, to: baseMonthStart) ?? baseMonthStart
            let bucketEndStart = calendar.date(byAdding: .month, value: monthsPerBucket, to: bucketStart) ?? bucketStart
            let bucketEnd = bucketEndStart.addingTimeInterval(-1)
            let value = aggregate(bucketSamples, using: aggregation)
            return TimeSeriesBucketedPoint(id: UUID(), date: midpointDate(start: bucketStart, end: bucketEnd), value: value, startDate: bucketStart, endDate: bucketEnd, sampleCount: bucketSamples.count)
        }
        .sorted { $0.date < $1.date }
    }
    
    private static func aggregate(_ samples: [TimeSeriesSample], using aggregation: TimeSeriesAggregationStrategy) -> Double {
        switch aggregation {
        case .average:
            return samples.reduce(0) { $0 + $1.value } / Double(samples.count)
        case .maximum:
            return samples.map(\.value).max() ?? 0
        case .sum:
            return samples.reduce(0) { $0 + $1.value }
        case .last:
            return samples.max(by: { $0.date < $1.date })?.value ?? 0
        }
    }
}

func timeSeriesAnchoredLinePoints(points: [TimeSeriesBucketedPoint], samples: [TimeSeriesSample], domain: ClosedRange<Date>) -> [TimeSeriesBucketedPoint] {
    guard !points.isEmpty else { return [] }
    guard let firstVisiblePoint = points.first, firstVisiblePoint.date > domain.lowerBound else { return points }
    let previousSample = samples.first { $0.date < domain.lowerBound }
    guard let previousSample else { return points }
    
    let anchoredValue = anchoredValueAtDomainStart(domainStart: domain.lowerBound, previousDate: previousSample.date, previousValue: previousSample.value, nextPoint: firstVisiblePoint)
    return [TimeSeriesBucketedPoint(id: UUID(), date: domain.lowerBound, value: anchoredValue)] + points
}

func dayBoundaryDates(in domain: ClosedRange<Date>, calendar: Calendar) -> [Date] {
    var dates: [Date] = []
    var current = calendar.startOfDay(for: domain.lowerBound)
    while current <= domain.upperBound {
        dates.append(current)
        guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
        current = next
    }
    return dates
}

func weekStartDates(in domain: ClosedRange<Date>, calendar: Calendar) -> [Date] {
    let firstWeekStart = calendar.dateInterval(of: .weekOfYear, for: domain.lowerBound)?.start ?? calendar.startOfDay(for: domain.lowerBound)
    var dates: [Date] = []
    var current = firstWeekStart
    while current <= domain.upperBound {
        if domain.contains(current) { dates.append(current) }
        guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: current) else { break }
        current = next
    }
    return dates
}

func monthStartDates(in domain: ClosedRange<Date>, stepMonths: Int, calendar: Calendar) -> [Date] {
    let firstMonthStart = calendar.startOfMonth(for: domain.lowerBound)
    var dates: [Date] = []
    var current = firstMonthStart
    while current <= domain.upperBound {
        if domain.contains(current) { dates.append(current) }
        guard let next = calendar.date(byAdding: .month, value: stepMonths, to: current) else { break }
        current = next
    }
    return dates
}

func yearStartDates(in domain: ClosedRange<Date>, stepYears: Int, calendar: Calendar) -> [Date] {
    let firstYearStart = calendar.date(from: calendar.dateComponents([.year], from: domain.lowerBound)) ?? domain.lowerBound
    var dates: [Date] = []
    var current = firstYearStart
    while current <= domain.upperBound {
        if domain.contains(current) { dates.append(current) }
        guard let next = calendar.date(byAdding: .year, value: stepYears, to: current) else { break }
        current = next
    }
    return dates
}

func midpointDate(start: Date, end: Date) -> Date {
    start.addingTimeInterval(end.timeIntervalSince(start) / 2)
}

func monthOffsetBetween(_ start: Date, and end: Date, calendar: Calendar) -> Int {
    calendar.dateComponents([.month], from: start, to: end).month ?? 0
}

func inclusiveMonthCount(from start: Date, to end: Date, calendar: Calendar) -> Int {
    max(1, monthOffsetBetween(start, and: end, calendar: calendar) + 1)
}

func anchoredValueAtDomainStart(domainStart: Date, previousDate: Date, previousValue: Double, nextPoint: TimeSeriesBucketedPoint) -> Double {
    let totalInterval = nextPoint.date.timeIntervalSince(previousDate)
    guard totalInterval > 0 else { return nextPoint.value }
    let elapsedInterval = domainStart.timeIntervalSince(previousDate)
    let progress = min(max(elapsedInterval / totalInterval, 0), 1)
    return previousValue + ((nextPoint.value - previousValue) * progress)
}

func timeSeriesAxisLabelText(for date: Date, style: TimeSeriesAxisLabelStyle) -> String {
    switch style {
    case .weekdayShort:
        return date.formatted(.dateTime.weekday(.abbreviated))
    case .monthDay:
        return date.formatted(.dateTime.month(.abbreviated).day())
    case .monthAbbreviated:
        return date.formatted(.dateTime.month(.abbreviated))
    case .monthInitial:
        return String(date.formatted(.dateTime.month(.abbreviated)).prefix(1))
    case .year:
        return date.formatted(.dateTime.year())
    }
}

func timeSeriesBucketLabelText(for point: TimeSeriesBucketedPoint, bucketStyle: TimeSeriesBucketStyle) -> String {
    switch bucketStyle {
    case .day:
        return formattedRecentDay(point.startDate)
    case .week:
        return formattedAbsoluteDateRange(start: point.startDate, end: point.endDate)
    case .month(let monthsPerBucket):
        if monthsPerBucket == 1 {
            return point.startDate.formatted(.dateTime.month(.abbreviated).year())
        }
        return formattedTimeSeriesMonthRange(start: point.startDate, end: point.endDate)
    }
}

func selectedTimeSeriesPoint(in points: [TimeSeriesBucketedPoint], for date: Date) -> TimeSeriesBucketedPoint? {
    if let containingPoint = points.first(where: { ($0.startDate ... $0.endDate).contains(date) }) {
        return containingPoint
    }

    return points.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
}

func chartCalendarComponent(for bucketStyle: TimeSeriesBucketStyle) -> Calendar.Component {
    switch bucketStyle {
    case .day:
        return .day
    case .week:
        return .weekOfYear
    case .month:
        return .month
    }
}

func stableTimeSeriesSampleID(namespace: UInt64, date: Date) -> UUID {
    let timestamp = date.timeIntervalSinceReferenceDate.bitPattern
    return UUID(uuid: uuidBytes(high: namespace, low: timestamp))
}

private func uuidBytes(high: UInt64, low: UInt64) -> uuid_t {
    (
        UInt8((high >> 56) & 0xFF),
        UInt8((high >> 48) & 0xFF),
        UInt8((high >> 40) & 0xFF),
        UInt8((high >> 32) & 0xFF),
        UInt8((high >> 24) & 0xFF),
        UInt8((high >> 16) & 0xFF),
        UInt8((high >> 8) & 0xFF),
        UInt8(high & 0xFF),
        UInt8((low >> 56) & 0xFF),
        UInt8((low >> 48) & 0xFF),
        UInt8((low >> 40) & 0xFF),
        UInt8((low >> 32) & 0xFF),
        UInt8((low >> 24) & 0xFF),
        UInt8((low >> 16) & 0xFF),
        UInt8((low >> 8) & 0xFF),
        UInt8(low & 0xFF)
    )
}

private struct HealthHistoryChartScaffoldModifier: ViewModifier {
    @Binding var selectedDate: Date?
    let layout: TimeSeriesChartLayout
    let height: CGFloat

    func body(content: Content) -> some View {
        content
            .chartLegend(.hidden)
            .chartXSelection(value: $selectedDate)
            .chartXScale(domain: layout.currentDomain)
            .chartXAxis {
                AxisMarks(values: layout.axisDates) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(timeSeriesAxisLabelText(for: date, style: layout.axisLabelStyle))
                        }
                    }
                }
            }
            .frame(height: height)
    }
}

extension View {
    func healthHistoryChartScaffold(selectedDate: Binding<Date?>, layout: TimeSeriesChartLayout, height: CGFloat = 260) -> some View {
        modifier(HealthHistoryChartScaffoldModifier(selectedDate: selectedDate, layout: layout, height: height))
    }
}

func formattedTimeSeriesMonthRange(start: Date, end: Date) -> String {
    let calendar = Calendar.autoupdatingCurrent
    let startMonth = start.formatted(.dateTime.month(.abbreviated))
    let endMonth = end.formatted(.dateTime.month(.abbreviated))
    let startYear = calendar.component(.year, from: start)
    let endYear = calendar.component(.year, from: end)
    
    if startYear == endYear {
        return "\(startMonth) - \(endMonth) \(startYear)"
    }
    
    return "\(startMonth) \(startYear) - \(endMonth) \(endYear)"
}
