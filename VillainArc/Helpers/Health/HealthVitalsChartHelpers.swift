import Charts
import Foundation
import SwiftUI

/// Shared minimum content height for the small Health vital cards in the two-column grid, so empty
/// and populated cards render at the same size instead of leaving the grid ragged. A minimum (not a
/// hard fixed height) keeps every card equal at default Dynamic Type while still growing without
/// clipping at larger accessibility sizes.
let healthVitalCardMinContentHeight: CGFloat = 132

extension View {
    /// Pins a small Health vital card to uniform width and a shared minimum height, top-aligned,
    /// so the two-column grid stays even regardless of whether a card has data yet.
    func healthVitalCardSizing() -> some View {
        frame(maxWidth: .infinity, minHeight: healthVitalCardMinContentHeight, alignment: .topLeading)
    }
}

struct HealthRangeChartPoint: Identifiable {
    let id: UUID
    let date: Date
    let low: Double
    let high: Double

    init(id: UUID = UUID(), date: Date, low: Double, high: Double) {
        self.id = id
        self.date = date
        self.low = low
        self.high = high
    }
}

struct HealthRangeBucketedPoint: Identifiable {
    let id: UUID
    let date: Date
    let low: Double
    let high: Double
    let startDate: Date
    let endDate: Date
    let sampleCount: Int

    init(id: UUID = UUID(), date: Date, low: Double, high: Double, startDate: Date, endDate: Date, sampleCount: Int) {
        self.id = id
        self.date = date
        self.low = low
        self.high = high
        self.startDate = startDate
        self.endDate = endDate
        self.sampleCount = sampleCount
    }
}

struct HealthRangeChartLayout {
    let timeSeriesLayout: TimeSeriesChartLayout
    let points: [HealthRangeBucketedPoint]

    init(rangeFilter: TimeSeriesRangeFilter, points: [HealthRangeChartPoint], now: Date, calendar: Calendar) {
        let lowSamples = points.map { TimeSeriesSample(date: $0.date, value: $0.low) }
        let highSamples = points.map { TimeSeriesSample(date: $0.date, value: $0.high) }
        let lowLayout = TimeSeriesChartLayout(rangeFilter: rangeFilter, samples: lowSamples, now: now, calendar: calendar, aggregation: .average)
        let highLayout = TimeSeriesChartLayout(rangeFilter: rangeFilter, samples: highSamples, now: now, calendar: calendar, aggregation: .average)
        let highByStart = Dictionary(uniqueKeysWithValues: highLayout.points.map { ($0.startDate, $0) })

        self.timeSeriesLayout = lowLayout
        self.points = lowLayout.points.compactMap { lowPoint in
            guard let highPoint = highByStart[lowPoint.startDate] else { return nil }
            return HealthRangeBucketedPoint(
                id: stableTimeSeriesSampleID(namespace: 0x52414E4745565400, date: lowPoint.startDate),
                date: lowPoint.date,
                low: lowPoint.value,
                high: highPoint.value,
                startDate: lowPoint.startDate,
                endDate: lowPoint.endDate,
                sampleCount: min(lowPoint.sampleCount, highPoint.sampleCount)
            )
        }
    }
}

private struct HealthVitalsLineCachedRangeData {
    let layout: TimeSeriesChartLayout
    let yDomain: ClosedRange<Double>
}

private struct HealthVitalsRangeCachedRangeData {
    let layout: HealthRangeChartLayout
    let yDomain: ClosedRange<Double>
}

func healthVitalsYDomain(for values: [Double], minimumPadding: Double = 1) -> ClosedRange<Double> {
    guard let minimum = values.min(), let maximum = values.max() else { return 0...1 }
    if minimum == maximum {
        let padding = max(abs(minimum) * 0.05, minimumPadding)
        return (minimum - padding)...(maximum + padding)
    }

    let padding = max((maximum - minimum) * 0.18, minimumPadding)
    return (minimum - padding)...(maximum + padding)
}

struct HealthVitalsMiniLineChart: View {
    let samples: [TimeSeriesSample]
    let tint: Color

    private var yDomain: ClosedRange<Double> {
        healthVitalsYDomain(for: samples.map(\.value))
    }

    var body: some View {
        Chart {
            ForEach(samples) { sample in
                LineMark(x: .value("Date", sample.date), y: .value("Value", sample.value))
                    .foregroundStyle(tint)
                    .lineStyle(.init(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
                    .symbol(.circle)
            }
        }
        .chartYScale(domain: yDomain)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }
}

struct HealthVitalsInsightSections: View {
    let samples: [TimeSeriesSample]
    let tint: Color
    let metricName: String
    let unitText: String
    let valueText: (Double) -> String
    var flatThreshold: Double = 0

    @State private var selectedWeekday: Weekday?

    private var sortedSamples: [TimeSeriesSample] {
        samples.sorted { $0.date > $1.date }
    }

    private var weekdayPoints: [WeekdayAveragePoint] {
        makeWeekdayAveragePoints(from: sortedSamples, date: \.date, value: \.value)
    }

    private var isWeekdayChartAvailable: Bool {
        weekdayPoints.count == 7 && weekdayPoints.allSatisfy { $0.sampleCount >= 2 }
    }

    private var selectedWeekdayPoint: WeekdayAveragePoint? {
        guard let selectedWeekday else { return nil }
        return weekdayPoints.first { $0.weekday == selectedWeekday }
    }

    private var strongestWeekdayPoint: WeekdayAveragePoint? {
        weekdayPoints.filter { $0.sampleCount > 0 }.max(by: { $0.averageValue < $1.averageValue })
    }

    private var displayedWeekdayPoint: WeekdayAveragePoint? {
        selectedWeekdayPoint ?? strongestWeekdayPoint
    }

    private var weekdayPresentation: WeekdayAverageChartPresentation {
        guard isWeekdayChartAvailable, let displayedWeekdayPoint else {
            let summaryText = String(localized: "\(metricName) weekday averages need at least 2 entries for every weekday.")
            return WeekdayAverageChartPresentation(
                headline: Text(summaryText),
                accessibilityValue: summaryText,
                isAvailable: false,
                unavailableTitle: String(localized: "Need More Data"),
                unavailableMessage: String(localized: "Sync at least 2 entries for every weekday to unlock averages.")
            )
        }

        let formattedValue = valueText(displayedWeekdayPoint.averageValue)
        let weekdayText = displayedWeekdayPoint.weekday.pluralLabel()
        if selectedWeekdayPoint != nil {
            let summaryText = String(localized: "\(metricName) averages \(formattedValue) \(unitText) on \(weekdayText).")
            return WeekdayAverageChartPresentation(
                headline: Text("\(metricName) averages \(Text(formattedValue).foregroundStyle(tint)) \(unitText) on \(weekdayText)."),
                accessibilityValue: summaryText,
                isAvailable: true,
                unavailableTitle: String(localized: "Need More Data"),
                unavailableMessage: String(localized: "Sync at least 2 entries for every weekday to unlock averages.")
            )
        }

        let summaryText = String(localized: "\(metricName) is highest on \(weekdayText). \(formattedValue) \(unitText).")
        return WeekdayAverageChartPresentation(
            headline: Text("\(metricName) is highest on \(weekdayText). \(Text(formattedValue).foregroundStyle(tint)) \(unitText)."),
            accessibilityValue: summaryText,
            isAvailable: true,
            unavailableTitle: String(localized: "Need More Data"),
            unavailableMessage: String(localized: "Sync at least 2 entries for every weekday to unlock averages.")
        )
    }

    private var monthlyHighlight: PeriodComparisonHighlight? {
        makePeriodComparisonHighlight(entries: sortedSamples, kind: .month, date: \.date, value: \.value, flatThreshold: flatThreshold)
    }

    private var yearlyHighlight: PeriodComparisonHighlight? {
        makePeriodComparisonHighlight(entries: sortedSamples, kind: .year, date: \.date, value: \.value, flatThreshold: flatThreshold)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            WeekdayAverageChart(
                presentation: weekdayPresentation,
                points: weekdayPoints,
                tint: tint,
                selectedWeekday: $selectedWeekday,
                accessibilityLabel: String(localized: "\(metricName) weekday averages"),
                yAxisValueLabel: { valueText($0) }
            )
            .padding()
            .appCardStyle()

            if let monthlyHighlight {
                PeriodComparisonHighlightCard(
                    summary: comparisonSummaryText(for: monthlyHighlight),
                    accessibilitySummary: comparisonSummary(for: monthlyHighlight),
                    currentValue: monthlyHighlight.currentAverage,
                    previousValue: monthlyHighlight.previousAverage,
                    currentLabel: monthlyHighlight.currentLabel,
                    previousLabel: monthlyHighlight.previousLabel,
                    unitText: unitText,
                    tint: tint,
                    valueText: valueText,
                    accessibilityValueText: { "\(valueText($0)) \(unitText)" }
                )
            }

            if let yearlyHighlight {
                PeriodComparisonHighlightCard(
                    summary: comparisonSummaryText(for: yearlyHighlight),
                    accessibilitySummary: comparisonSummary(for: yearlyHighlight),
                    currentValue: yearlyHighlight.currentAverage,
                    previousValue: yearlyHighlight.previousAverage,
                    currentLabel: yearlyHighlight.currentLabel,
                    previousLabel: yearlyHighlight.previousLabel,
                    unitText: unitText,
                    tint: tint,
                    valueText: valueText,
                    accessibilityValueText: { "\(valueText($0)) \(unitText)" }
                )
            }
        }
    }

    private func comparisonSummaryText(for highlight: PeriodComparisonHighlight) -> Text {
        let leadIn = highlight.kind == .year ? "\(yearComparisonLeadIn()), " : ""
        let periodText = highlight.kind == .month ? String(localized: "this month") : String(localized: "this year")
        let previousText = highlight.kind == .month ? String(localized: "last month") : String(localized: "last year")

        switch highlight.trend {
        case .up:
            return Text("\(leadIn)\(metricName) is \(Text("higher").foregroundStyle(tint)) \(periodText) than \(previousText).")
        case .down:
            return Text("\(leadIn)\(metricName) is \(Text("lower").foregroundStyle(tint)) \(periodText) than \(previousText).")
        case .flat:
            return Text("\(leadIn)\(metricName) is \(Text("about the same").foregroundStyle(tint)) \(periodText) as \(previousText).")
        }
    }

    private func comparisonSummary(for highlight: PeriodComparisonHighlight) -> String {
        let leadIn = highlight.kind == .year ? "\(yearComparisonLeadIn()), " : ""
        let periodText = highlight.kind == .month ? String(localized: "this month") : String(localized: "this year")
        let previousText = highlight.kind == .month ? String(localized: "last month") : String(localized: "last year")

        switch highlight.trend {
        case .up:
            return String(localized: "\(leadIn)\(metricName) is higher \(periodText) than \(previousText).")
        case .down:
            return String(localized: "\(leadIn)\(metricName) is lower \(periodText) than \(previousText).")
        case .flat:
            return String(localized: "\(leadIn)\(metricName) is about the same \(periodText) as \(previousText).")
        }
    }
}

struct HealthVitalsMiniRangeChart: View {
    let points: [HealthRangeChartPoint]
    let tint: Color

    private var yDomain: ClosedRange<Double> {
        healthVitalsYDomain(for: points.flatMap { [$0.low, $0.high] })
    }

    var body: some View {
        Chart(points) { point in
            BarMark(
                x: .value("Date", point.date, unit: .day),
                yStart: .value("Low", point.low),
                yEnd: .value("High", point.high),
                width: .ratio(0.42)
            )
            .foregroundStyle(point.date == points.map(\.date).max() ? tint.gradient : tint.opacity(0.32).gradient)
            .clipShape(Capsule())
        }
        .chartYScale(domain: yDomain)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }
}

struct HealthVitalsLineHistorySection: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let samples: [TimeSeriesSample]
    @Binding var selectedRange: TimeSeriesRangeFilter
    let tint: Color
    let latestDate: Date?
    let latestValue: Double?
    let valueFormatter: (Double) -> String
    let unitText: String
    let yAxisFormatter: (Double) -> String
    var baselineValue: Double? = nil

    @State private var selectedDate: Date?
    @State private var rangeCache: [TimeSeriesRangeFilter: HealthVitalsLineCachedRangeData] = [:]

    private var currentRangeData: HealthVitalsLineCachedRangeData? {
        rangeCache[selectedRange]
    }

    private var selectedPoint: TimeSeriesBucketedPoint? {
        guard let currentRangeData, let selectedDate else { return nil }
        return selectedTimeSeriesPoint(in: currentRangeData.layout.points, for: selectedDate)
    }

    private var displayedDateText: String {
        if let selectedPoint {
            let baseText = timeSeriesBucketLabelText(for: selectedPoint, bucketStyle: currentRangeData?.layout.bucketStyle ?? .day)
            if selectedPoint.sampleCount > 1 {
                return "\(baseText) • \(String(localized: "Average"))"
            }
            return baseText
        }
        return latestDate.map { formattedRecentDay($0) } ?? String(localized: "No data")
    }

    private var displayedValue: Double? {
        selectedPoint?.value ?? latestValue
    }

    private var cacheSeed: Int {
        var hasher = Hasher()
        hasher.combine(samples.count)
        for sample in samples {
            hasher.combine(sample.date)
            hasher.combine(sample.value.bitPattern)
        }
        return hasher.finalize()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            if let currentRangeData {
                Chart {
                    if let baselineValue {
                        RuleMark(y: .value("Baseline", baselineValue))
                            .foregroundStyle(tint.opacity(0.5))
                            .lineStyle(.init(lineWidth: 1.5, dash: [5, 4]))
                            .zIndex(-1)
                    }

                    ForEach(currentRangeData.layout.points) { point in
                        LineMark(x: .value("Date", point.date), y: .value("Value", point.value), series: .value("Series", "Value"))
                            .foregroundStyle(tint)
                            .interpolationMethod(.catmullRom)
                            .symbol(.circle)
                    }

                    if let selectedPoint {
                        RuleMark(x: .value("Selected Date", selectedPoint.date))
                            .foregroundStyle(tint)
                            .lineStyle(.init(lineWidth: 1, dash: [4, 4]))

                        PointMark(x: .value("Selected Date", selectedPoint.date), y: .value("Selected Value", selectedPoint.value))
                            .foregroundStyle(.white)
                            .symbolSize(80)

                        PointMark(x: .value("Selected Date", selectedPoint.date), y: .value("Selected Value", selectedPoint.value))
                            .foregroundStyle(tint)
                            .symbolSize(36)
                    }
                }
                .healthHistoryChartScaffold(selectedDate: $selectedDate, layout: currentRangeData.layout)
                .chartYScale(domain: currentRangeData.yDomain)
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let doubleValue = value.as(Double.self) {
                                Text(yAxisFormatter(doubleValue))
                            }
                        }
                    }
                }
                .overlay {
                    if currentRangeData.layout.points.isEmpty {
                        ContentUnavailableView("No Data", systemImage: "chart.line.uptrend.xyaxis")
                    }
                }
            } else {
                ProgressView("Updating chart")
                    .frame(maxWidth: .infinity, minHeight: 260)
            }

            Picker("Range", selection: $selectedRange) {
                ForEach(TimeSeriesRangeFilter.nonDayCases) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier(AccessibilityIdentifiers.healthVitalsLineHistoryRangePicker)
            .onChange(of: selectedRange) { Haptics.selection() }
        }
        .padding()
        .appCardStyle()
        .animation(reduceMotion ? nil : .smooth, value: latestValue)
        .onChange(of: selectedRange) { selectedDate = nil }
        .task(id: cacheSeed) {
            prepareRangeCache()
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom) {
                Text(displayedDateText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
                if let selectedPoint, selectedPoint.sampleCount > 1 {
                    Text("Days")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fontWeight(.semibold)

            HStack(alignment: .bottom) {
                Group {
                    if let displayedValue {
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text(valueFormatter(displayedValue))
                            Text(unitText)
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text(verbatim: "-")
                    }
                }
                Spacer()
                if let selectedPoint, selectedPoint.sampleCount > 1 {
                    Text(selectedPoint.sampleCount.formatted(.number))
                }
            }
            .font(.largeTitle)
            .bold()
            .fontDesign(.rounded)
        }
    }

    private func prepareRangeCache() {
        let samples = samples
        let now = Date()
        let calendar = Calendar.autoupdatingCurrent
        progressivelyRebuildRangeCache(existing: rangeCache, buildOrder: [.month, .week, .sixMonths, .year, .all], publish: { newCache in
            if rangeCache.isEmpty || reduceMotion {
                rangeCache = newCache
            } else {
                withAnimation(.smooth) { rangeCache = newCache }
            }
        }) { range in
            let layout = TimeSeriesChartLayout(rangeFilter: range, samples: samples, now: now, calendar: calendar, aggregation: .average)
            return HealthVitalsLineCachedRangeData(layout: layout, yDomain: healthVitalsYDomain(for: layout.points.map(\.value)))
        }
    }
}

struct HealthVitalsRangeHistorySection: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let points: [HealthRangeChartPoint]
    @Binding var selectedRange: TimeSeriesRangeFilter
    let tint: Color
    let latestDate: Date?
    let latestLow: Double?
    let latestHigh: Double?
    let valueFormatter: (Double) -> String
    let unitText: String
    let yAxisFormatter: (Double) -> String

    @State private var selectedDate: Date?
    @State private var rangeCache: [TimeSeriesRangeFilter: HealthVitalsRangeCachedRangeData] = [:]

    private var currentRangeData: HealthVitalsRangeCachedRangeData? {
        rangeCache[selectedRange]
    }

    private var selectedPoint: HealthRangeBucketedPoint? {
        guard let currentRangeData, let selectedDate else { return nil }
        if let containingPoint = currentRangeData.layout.points.first(where: { ($0.startDate ... $0.endDate).contains(selectedDate) }) {
            return containingPoint
        }
        return currentRangeData.layout.points.min { abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate)) }
    }

    private var displayedDateText: String {
        if let selectedPoint {
            let baseText = timeSeriesBucketLabelText(
                for: TimeSeriesBucketedPoint(id: selectedPoint.id, date: selectedPoint.date, value: selectedPoint.high, startDate: selectedPoint.startDate, endDate: selectedPoint.endDate, sampleCount: selectedPoint.sampleCount),
                bucketStyle: currentRangeData?.layout.timeSeriesLayout.bucketStyle ?? .day
            )
            if selectedPoint.sampleCount > 1 {
                return "\(baseText) • \(String(localized: "Average"))"
            }
            return baseText
        }
        return latestDate.map { formattedRecentDay($0) } ?? String(localized: "No data")
    }

    private var displayedLow: Double? {
        selectedPoint?.low ?? latestLow
    }

    private var displayedHigh: Double? {
        selectedPoint?.high ?? latestHigh
    }

    private var cacheSeed: Int {
        var hasher = Hasher()
        hasher.combine(points.count)
        for point in points {
            hasher.combine(point.date)
            hasher.combine(point.low.bitPattern)
            hasher.combine(point.high.bitPattern)
        }
        return hasher.finalize()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            if let currentRangeData {
                Chart {
                    if let selectedPoint {
                        RuleMark(x: .value("Selected Date", selectedPoint.date))
                            .foregroundStyle(tint)
                            .lineStyle(.init(lineWidth: 1, dash: [4, 4]))
                            .zIndex(-1)
                    }

                    ForEach(currentRangeData.layout.points) { point in
                        BarMark(
                            x: .value("Date", point.startDate, unit: chartCalendarComponent(for: currentRangeData.layout.timeSeriesLayout.bucketStyle)),
                            yStart: .value("Low", point.low),
                            yEnd: .value("High", point.high),
                            width: .ratio(0.5)
                        )
                        .foregroundStyle(tint.gradient)
                        .opacity(selectedPoint == nil || selectedPoint?.id == point.id ? 1 : 0.5)
                        .clipShape(Capsule())
                    }
                }
                .healthHistoryChartScaffold(selectedDate: $selectedDate, layout: currentRangeData.layout.timeSeriesLayout)
                .chartYScale(domain: currentRangeData.yDomain)
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let doubleValue = value.as(Double.self) {
                                Text(yAxisFormatter(doubleValue))
                            }
                        }
                    }
                }
                .overlay {
                    if currentRangeData.layout.points.isEmpty {
                        ContentUnavailableView("No Data", systemImage: "chart.bar")
                    }
                }
            } else {
                ProgressView("Updating chart")
                    .frame(maxWidth: .infinity, minHeight: 260)
            }

            Picker("Range", selection: $selectedRange) {
                ForEach(TimeSeriesRangeFilter.nonDayCases) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier(AccessibilityIdentifiers.healthVitalsRangeHistoryRangePicker)
            .onChange(of: selectedRange) { Haptics.selection() }
        }
        .padding()
        .appCardStyle()
        .animation(reduceMotion ? nil : .smooth, value: latestHigh)
        .onChange(of: selectedRange) { selectedDate = nil }
        .task(id: cacheSeed) {
            prepareRangeCache()
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom) {
                Text(displayedDateText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
                if let selectedPoint, selectedPoint.sampleCount > 1 {
                    Text("Days")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fontWeight(.semibold)

            HStack(alignment: .bottom) {
                Group {
                    if let displayedLow, let displayedHigh {
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text("\(valueFormatter(displayedLow))-\(valueFormatter(displayedHigh))")
                            Text(unitText)
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text(verbatim: "-")
                    }
                }
                Spacer()
                if let selectedPoint, selectedPoint.sampleCount > 1 {
                    Text(selectedPoint.sampleCount.formatted(.number))
                }
            }
            .font(.largeTitle)
            .bold()
            .fontDesign(.rounded)
        }
    }

    private func prepareRangeCache() {
        let points = points
        let now = Date()
        let calendar = Calendar.autoupdatingCurrent
        progressivelyRebuildRangeCache(existing: rangeCache, buildOrder: [.month, .week, .sixMonths, .year, .all], publish: { newCache in
            if rangeCache.isEmpty || reduceMotion {
                rangeCache = newCache
            } else {
                withAnimation(.smooth) { rangeCache = newCache }
            }
        }) { range in
            let layout = HealthRangeChartLayout(rangeFilter: range, points: points, now: now, calendar: calendar)
            return HealthVitalsRangeCachedRangeData(layout: layout, yDomain: healthVitalsYDomain(for: layout.points.flatMap { [$0.low, $0.high] }))
        }
    }
}

private struct TrendEndpoint: Identifiable {
    let id: Int
    let date: Date
    let value: Double
}

struct HealthVitalsTrendSection: View {
    let samples: [TimeSeriesSample]
    let tint: Color
    let metricDescription: String
    let upTrendDescription: String
    let downTrendDescription: String

    private struct WeeklyPoint: Identifiable {
        let id: Date
        let date: Date
        let value: Double
    }

    private var weeklyPoints: [WeeklyPoint] {
        let calendar = Calendar.autoupdatingCurrent
        let now = Date()
        guard let cutoff = calendar.date(byAdding: .weekOfYear, value: -25, to: now) else { return [] }
        let filtered = samples.filter { $0.date >= cutoff }
        guard !filtered.isEmpty else { return [] }
        let grouped = Dictionary(grouping: filtered) { sample -> Date in
            calendar.dateInterval(of: .weekOfYear, for: sample.date)?.start ?? sample.date
        }
        return grouped.sorted { $0.key < $1.key }.map { weekStart, pts in
            let avg = pts.reduce(0) { $0 + $1.value } / Double(pts.count)
            return WeeklyPoint(id: weekStart, date: weekStart, value: avg)
        }
    }

    private func trendEndpoints(from points: [WeeklyPoint]) -> (TrendEndpoint, TrendEndpoint)? {
        guard points.count >= 2 else { return nil }
        let firstDate = points[0].date
        let xs = points.map { $0.date.timeIntervalSince(firstDate) / 86400 }
        let ys = points.map { $0.value }
        let n = Double(points.count)
        let sumX = xs.reduce(0, +)
        let sumY = ys.reduce(0, +)
        let sumXY = zip(xs, ys).reduce(0) { $0 + $1.0 * $1.1 }
        let sumX2 = xs.reduce(0) { $0 + $1 * $1 }
        let denom = n * sumX2 - sumX * sumX
        guard denom != 0 else { return nil }
        let slope = (n * sumXY - sumX * sumY) / denom
        let intercept = (sumY - slope * sumX) / n
        let start = TrendEndpoint(id: 0, date: points[0].date, value: slope * xs[0] + intercept)
        let end = TrendEndpoint(id: 1, date: points[points.count - 1].date, value: slope * xs[xs.count - 1] + intercept)
        return (start, end)
    }

    private var trendDirection: Double? {
        let pts = weeklyPoints
        guard let (start, end) = trendEndpoints(from: pts) else { return nil }
        return end.value - start.value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            let pts = weeklyPoints
            if pts.count >= 2 {
                trendChartCard(points: pts)
            }
            aboutCard
        }
    }

    private func trendChartCard(points: [WeeklyPoint]) -> some View {
        let yValues = points.map(\.value)
        let yDomain = healthVitalsYDomain(for: yValues)
        let endpoints = trendEndpoints(from: points)
        let direction = endpoints.map { $0.1.value - $0.0.value } ?? 0
        let trendLabel = abs(direction) < (yDomain.upperBound - yDomain.lowerBound) * 0.02
            ? "Stable"
            : direction > 0 ? "Trending Up" : "Trending Down"

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("25-Week Trend")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(tint.gradient)
                Spacer()
                Text(trendLabel)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }

            Chart {
                if let (start, end) = endpoints {
                    ForEach([start, end]) { pt in
                        LineMark(x: .value("Date", pt.date), y: .value("Trend", pt.value), series: .value("S", "trend"))
                            .foregroundStyle(tint.opacity(0.4))
                            .lineStyle(.init(lineWidth: 2))
                    }
                }
                ForEach(points) { pt in
                    PointMark(x: .value("Date", pt.date), y: .value("Value", pt.value))
                        .foregroundStyle(tint)
                        .symbolSize(36)
                }
            }
            .chartYScale(domain: yDomain)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.month(.abbreviated), centered: false)
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(v.formatted(.number.precision(.fractionLength(0...1))))
                                .font(.caption)
                        }
                    }
                }
            }
            .frame(height: 180)
        }
        .padding()
        .appCardStyle()
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("About This Metric")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(tint.gradient)

            Text(metricDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let dir = trendDirection {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Label(dir >= 0 ? "Trending Up" : "Trending Down", systemImage: dir >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(tint)
                    Text(dir >= 0 ? upTrendDescription : downTrendDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .appCardStyle()
    }
}
