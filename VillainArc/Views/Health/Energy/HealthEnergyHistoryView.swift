import SwiftUI
import SwiftData
import Charts

private func bucketedEnergyChartSegments(totalPoints: [TimeSeriesBucketedPoint], activePoints: [TimeSeriesBucketedPoint]) -> [HealthEnergy.ChartSegment] {
    totalPoints.flatMap { totalPoint in
        let activePoint = activePoints.first { $0.startDate == totalPoint.startDate && $0.endDate == totalPoint.endDate }
        let activeEnergy = activePoint?.value ?? 0
        let restingEnergy = max(0, totalPoint.value - activeEnergy)
        return HealthEnergy.makeChartSegments(date: totalPoint.startDate, startDate: totalPoint.startDate, endDate: totalPoint.endDate, sampleCount: totalPoint.sampleCount, activeEnergy: activeEnergy, restingEnergy: restingEnergy)
    }
}

struct HealthEnergyHistoryView: View {
    @Query(HealthEnergy.history, animation: .smooth) private var entries: [HealthEnergy]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HealthEnergyMainChartSection(entries: entries)

                HealthEnergyWeekdayChartSection(entries: entries)

                HealthEnergyPeriodHighlightsSection(entries: entries)
            }
            .padding()
        }
        .navigationTitle("Energy")
        .toolbarTitleDisplayMode(.inline)
    }
}

private struct HealthEnergyCachedRangeData {
    let layout: TimeSeriesChartLayout
    let chartSegments: [HealthEnergy.ChartSegment]
    let yDomain: ClosedRange<Double>
    let averageTotalEnergy: Double?
    let averageActiveEnergy: Double?
}

private struct HealthEnergyMainChartSection: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedRange: TimeSeriesRangeFilter = .month
    @State private var selectedDate: Date?
    @State private var rangeCache: [TimeSeriesRangeFilter: HealthEnergyCachedRangeData] = [:]

    let entries: [HealthEnergy]

    private let tint = Color.orange
    private let totalEnergySampleNamespace: UInt64 = 0x454E455247590001
    private let activeEnergySampleNamespace: UInt64 = 0x454E455247590002

    private var totalEnergySamples: [TimeSeriesSample] {
        entries.map { TimeSeriesSample(id: stableTimeSeriesSampleID(namespace: totalEnergySampleNamespace, date: $0.date), date: $0.date, value: $0.totalEnergyBurned) }
    }
    
    private var activeEnergySamples: [TimeSeriesSample] {
        entries.map { TimeSeriesSample(id: stableTimeSeriesSampleID(namespace: activeEnergySampleNamespace, date: $0.date), date: $0.date, value: $0.activeEnergyBurned) }
    }

    private var latestEntry: HealthEnergy? {
        entries.first
    }

    private var hasAnyData: Bool {
        !entries.isEmpty
    }

    private var currentRangeData: HealthEnergyCachedRangeData? {
        rangeCache[selectedRange]
    }

    private var cacheKey: Int {
        var hasher = Hasher()
        hasher.combine(entries.count)
        for entry in entries {
            hasher.combine(entry.date)
            hasher.combine(entry.activeEnergyBurned.bitPattern)
            hasher.combine(entry.restingEnergyBurned.bitPattern)
        }
        return hasher.finalize()
    }

    private var selectedTotalPoint: TimeSeriesBucketedPoint? {
        guard let currentRangeData, let selectedDate else { return nil }
        return selectedTimeSeriesPoint(in: currentRangeData.layout.points, for: selectedDate)
    }
    
    private var selectedActiveSegment: HealthEnergy.ChartSegment? {
        guard let currentRangeData, let selectedTotalPoint else { return nil }
        return currentRangeData.chartSegments.first {
            $0.kind == .active &&
            $0.startDate == selectedTotalPoint.startDate &&
            $0.endDate == selectedTotalPoint.endDate
        }
    }
    
    private var displayedDateText: String {
        if let selectedTotalPoint {
            let baseText = timeSeriesBucketLabelText(for: selectedTotalPoint, bucketStyle: currentRangeData?.layout.bucketStyle ?? .day)
            if selectedTotalPoint.sampleCount > 1 {
                return "\(baseText) • \(String(localized: "Average"))"
            }
            return baseText
        }
        guard let latestEntry else { return "No entries in this range" }
        return formattedRecentDay(latestEntry.date)
    }
    
    private var displayedTotalEnergy: Double? {
        if let selectedTotalPoint { return selectedTotalPoint.value }
        return latestEntry?.totalEnergyBurned
    }
    
    private var displayedActiveEnergy: Double? {
        if selectedTotalPoint != nil { return selectedActiveSegment?.value ?? 0 }
        return latestEntry?.activeEnergyBurned
    }
    
    private var visibleRangeText: String? {
        guard let currentRangeData else { return nil }
        return formattedAbsoluteDateRange(start: currentRangeData.layout.currentDomain.lowerBound, end: currentRangeData.layout.currentDomain.upperBound)
    }
    
    private var chartAccessibilityValue: String {
        let dateText = displayedDateText
        let totalText = displayedTotalEnergy.map { "\(Int($0.rounded()).formatted(.number)) \(String(localized: "total calories"))" } ?? String(localized: "No total energy data")
        let activeText = displayedActiveEnergy.map { "\(Int($0.rounded()).formatted(.number)) \(String(localized: "active calories"))" } ?? String(localized: "No active energy data")
        return AccessibilityText.healthEnergyHistoryChartValue(dateText: dateText, totalText: totalText, activeText: activeText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(spacing: 0) {
                HStack(alignment: .bottom) {
                    Text(displayedDateText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer()
                    if displayedActiveEnergy != nil {
                        Text("Active")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                
                HStack(alignment: .bottom) {
                    Group {
                        if let displayedTotalEnergy {
                            HStack(alignment: .lastTextBaseline, spacing: 4) {
                                Text(Int(displayedTotalEnergy.rounded()), format: .number)
                                Text("Total")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text("-")
                        }
                    }
                    .font(.largeTitle)
                    Spacer()
                    if let displayedActiveEnergy {
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text(Int(displayedActiveEnergy.rounded()), format: .number)
                            Text("cal")
                                .foregroundStyle(.secondary)
                                .font(.title3)
                        }
                        .font(.title)
                    }
                }
                .bold()
                .fontDesign(.rounded)
            }
            
            if let currentRangeData {
                Chart {
                    if let selectedTotalPoint {
                        RuleMark(x: .value("Selected Date", selectedTotalPoint.date))
                            .foregroundStyle(tint)
                            .lineStyle(.init(lineWidth: 1, dash: [4, 4]))
                            .zIndex(-1)
                    }
                    
                    ForEach(currentRangeData.chartSegments) { segment in
                        BarMark(x: .value("Date", segment.startDate, unit: chartCalendarComponent(for: currentRangeData.layout.bucketStyle)), y: .value(segment.kind.rawValue.capitalized, segment.value), width: .ratio(0.92))
                            .foregroundStyle(segment.kind == .active ? AnyShapeStyle(tint.gradient) : AnyShapeStyle(Color.orange.opacity(0.22).gradient))
                            .opacity(selectedTotalPoint == nil || (selectedTotalPoint?.startDate == segment.startDate && selectedTotalPoint?.endDate == segment.endDate) ? 1 : 0.5)
                            .clipShape(UnevenRoundedRectangle(topLeadingRadius: segment.kind == .active ? 1 : 4, topTrailingRadius: segment.kind == .active ? 1 : 4))
                    }
                }
                .healthHistoryChartScaffold(selectedDate: $selectedDate, layout: currentRangeData.layout)
                .chartYScale(domain: currentRangeData.yDomain)
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let doubleValue = value.as(Double.self) {
                                Text(doubleValue.formatted(.number.notation(.compactName).precision(.fractionLength(0))))
                            }
                        }
                    }
                }
                .overlay {
                    if currentRangeData.layout.points.isEmpty {
                        emptyStateView()
                    }
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.healthEnergyHistoryChart)
                .accessibilityLabel(AccessibilityText.healthEnergyHistoryChartLabel)
                .accessibilityValue(chartAccessibilityValue)
                
                if let visibleRangeText, !currentRangeData.layout.points.isEmpty {
                    VStack(spacing: 5) {
                        HStack(alignment: .bottom) {
                            Text(visibleRangeText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .fontWeight(.semibold)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 5) {
                                if let averageActiveEnergy = currentRangeData.averageActiveEnergy {
                                    metadataEnergyValue(title: "Avg Active", energy: averageActiveEnergy)
                                }
                                if let averageTotalEnergy = currentRangeData.averageTotalEnergy {
                                    metadataEnergyValue(title: "Avg Total", energy: averageTotalEnergy)
                                }
                            }
                        }
                    }
                }
            } else {
                ProgressView("Updating chart")
                    .frame(maxWidth: .infinity, minHeight: 260)
            }
            
            Picker("Range", selection: $selectedRange.animation(reduceMotion ? nil : .easeInOut)) {
                ForEach(TimeSeriesRangeFilter.allCases) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedRange) { Haptics.selection() }
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
        .onChange(of: selectedRange) { selectedDate = nil }
        .task(id: cacheKey) {
            let calendar = Calendar.autoupdatingCurrent
            let now = Date()
            progressivelyRebuildRangeCache(existing: rangeCache, publish: { rangeCache = $0 }) { range in
                let totalLayout = TimeSeriesChartLayout(rangeFilter: range, samples: totalEnergySamples, now: now, calendar: calendar, aggregation: .average)
                let activeLayout = TimeSeriesChartLayout(rangeFilter: range, samples: activeEnergySamples, now: now, calendar: calendar, aggregation: .average)
                let chartSegments = bucketedEnergyChartSegments(totalPoints: totalLayout.points, activePoints: activeLayout.points)
                let visibleEntries = entries.filter { totalLayout.currentDomain.contains($0.date) }
                let yDomain = 0...(max(totalLayout.points.map(\.value).max() ?? 0, 1) * 1.15)
                let averageTotalEnergy = visibleEntries.isEmpty ? nil : (visibleEntries.reduce(0) { $0 + $1.totalEnergyBurned } / Double(visibleEntries.count))
                let averageActiveEnergy = visibleEntries.isEmpty ? nil : (visibleEntries.reduce(0) { $0 + $1.activeEnergyBurned } / Double(visibleEntries.count))
                return HealthEnergyCachedRangeData(layout: totalLayout, chartSegments: chartSegments, yDomain: yDomain, averageTotalEnergy: averageTotalEnergy, averageActiveEnergy: averageActiveEnergy)
            }
        }
    }

    @ViewBuilder
    private func emptyStateView() -> some View {
        if hasAnyData {
            ContentUnavailableView {
                Label(AccessibilityText.healthEnergyHistoryEmptyTitle, systemImage: "flame.fill")
            } description: {
                Text(AccessibilityText.healthEnergyHistoryEmptyDescription(for: selectedRange))
            }
        } else {
            ContentUnavailableView {
                Label(AccessibilityText.healthHistoryNoHealthDataTitle, systemImage: "heart.text.square")
            } description: {
                Text(AccessibilityText.healthHistoryNoHealthDataDescription)
            }
        }
    }

    @ViewBuilder
    private func metadataEnergyValue(title: String, energy: Double) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(Int(energy.rounded()), format: .number)
                .font(.subheadline)
                .fontWeight(.semibold)
                .fontDesign(.rounded)
                .contentTransition(.numericText(value: energy))
        }
        .animation(reduceMotion ? nil : .smooth, value: energy)
        .accessibilityElement(children: .combine)
    }
}

private struct HealthEnergyWeekdayChartSection: View {
    let entries: [HealthEnergy]

    @State private var selectedWeekday: Weekday?
    @State private var points: [WeekdayAveragePoint] = []

    private let tint = Color.orange

    private var cacheKey: Int {
        var hasher = Hasher()
        hasher.combine(entries.count)
        for entry in entries {
            hasher.combine(entry.date)
            hasher.combine(entry.activeEnergyBurned.bitPattern)
        }
        return hasher.finalize()
    }

    private var isWeekdayChartAvailable: Bool {
        points.count == 7 && points.allSatisfy { $0.sampleCount >= 2 }
    }

    private var selectedWeekdayPoint: WeekdayAveragePoint? {
        guard let selectedWeekday else { return nil }
        return points.first { $0.weekday == selectedWeekday }
    }

    private var strongestWeekdayPoint: WeekdayAveragePoint? {
        points.filter { $0.sampleCount > 0 }.max(by: { $0.averageValue < $1.averageValue })
    }

    private var displayedWeekdayPoint: WeekdayAveragePoint? {
        selectedWeekdayPoint ?? strongestWeekdayPoint
    }

    private var presentation: WeekdayAverageChartPresentation {
        guard isWeekdayChartAvailable else {
            let summaryText = String(localized: "Weekday averages need at least 2 entries for every weekday")
            return WeekdayAverageChartPresentation(headline: Text(summaryText), accessibilityValue: AccessibilityText.healthEnergyWeekdayChartValue(summaryText: summaryText), isAvailable: false, unavailableTitle: "Need More Data", unavailableMessage: "Log at least 2 entries for every weekday to unlock averages.")
        }
        guard let displayedWeekdayPoint else {
            let summaryText = String(localized: "Weekday calorie averages are unavailable")
            return WeekdayAverageChartPresentation(headline: Text(summaryText), accessibilityValue: AccessibilityText.healthEnergyWeekdayChartValue(summaryText: summaryText), isAvailable: false, unavailableTitle: "Need More Data", unavailableMessage: "Log at least 2 entries for every weekday to unlock averages.")
        }
        let caloriesText = Int(displayedWeekdayPoint.averageValue.rounded()).formatted(.number)
        let valueText = Text(caloriesText).foregroundStyle(tint)
        let weekdayText = displayedWeekdayPoint.weekday.pluralLabel()
        if selectedWeekdayPoint != nil {
            let summaryText = String(localized: "On average, you burn \(caloriesText) calories on \(weekdayText).")
            return WeekdayAverageChartPresentation(headline: Text("On average, you burn \(valueText) calories on \(weekdayText)."), accessibilityValue: AccessibilityText.healthEnergyWeekdayChartValue(summaryText: summaryText), isAvailable: true, unavailableTitle: "Need More Data", unavailableMessage: "Log at least 2 entries for every weekday to unlock averages.")
        }
        let summaryText = String(localized: "On average, you burn the most calories on \(weekdayText). \(caloriesText) calories.")
        return WeekdayAverageChartPresentation(headline: Text("On average, you burn the most calories on \(weekdayText). \(valueText) calories."), accessibilityValue: AccessibilityText.healthEnergyWeekdayChartValue(summaryText: summaryText), isAvailable: true, unavailableTitle: "Need More Data", unavailableMessage: "Log at least 2 entries for every weekday to unlock averages.")
    }

    var body: some View {
        WeekdayAverageChart(presentation: presentation, points: points, tint: tint, selectedWeekday: $selectedWeekday, accessibilityLabel: AccessibilityText.healthEnergyWeekdayChartLabel)
            .padding()
            .glassEffect(.regular, in: .rect(cornerRadius: 18))
            .task(id: cacheKey) {
                let newPoints = makeWeekdayAveragePoints(from: entries, date: \.date, value: \.activeEnergyBurned)
                points = newPoints
                if !(newPoints.count == 7 && newPoints.allSatisfy { $0.sampleCount >= 2 }) { selectedWeekday = nil }
            }
    }
}

private struct HealthEnergyPeriodHighlightsSection: View {
    let entries: [HealthEnergy]

    private let tint = Color.orange

    private var monthlyHighlight: PeriodComparisonHighlight? { makePeriodComparisonHighlight(entries: entries, kind: .month, date: \.date, value: \.activeEnergyBurned) }

    private var yearlyHighlight: PeriodComparisonHighlight? { makePeriodComparisonHighlight(entries: entries, kind: .year, date: \.date, value: \.activeEnergyBurned) }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            if let monthlyHighlight { PeriodComparisonHighlightCard(summary: energySummaryText(for: monthlyHighlight), accessibilitySummary: energySummary(for: monthlyHighlight), currentValue: monthlyHighlight.currentAverage, previousValue: monthlyHighlight.previousAverage, currentLabel: monthlyHighlight.currentLabel, previousLabel: monthlyHighlight.previousLabel, unitText: "cal/day", tint: tint) }
            if let yearlyHighlight { PeriodComparisonHighlightCard(summary: energySummaryText(for: yearlyHighlight), accessibilitySummary: energySummary(for: yearlyHighlight), currentValue: yearlyHighlight.currentAverage, previousValue: yearlyHighlight.previousAverage, currentLabel: yearlyHighlight.currentLabel, previousLabel: yearlyHighlight.previousLabel, unitText: "cal/day", tint: tint) }
        }
    }

    private func energySummaryText(for highlight: PeriodComparisonHighlight) -> Text {
        switch (highlight.kind, highlight.trend) {
        case (.month, .up):
            return Text("On average, you're burning \(Text("more").foregroundStyle(tint)) calories this month than you did last month.")
        case (.month, .down):
            return Text("On average, you're burning \(Text("fewer").foregroundStyle(tint)) calories this month than you did last month.")
        case (.month, .flat):
            return Text("On average, you're burning \(Text("about the same").foregroundStyle(tint)) number of calories this month as you did last month.")
        case (.year, .up):
            return Text("So far this year, you're burning \(Text("more").foregroundStyle(tint)) calories a day than you did last year.")
        case (.year, .down):
            return Text("So far this year, you're burning \(Text("fewer").foregroundStyle(tint)) calories a day than you did last year.")
        case (.year, .flat):
            return Text("So far this year, you're burning \(Text("about the same").foregroundStyle(tint)) number of calories a day as you did last year.")
        }
    }

    private func energySummary(for highlight: PeriodComparisonHighlight) -> String {
        switch (highlight.kind, highlight.trend) {
        case (.month, .up):
            return "On average, you're burning more calories this month than you did last month."
        case (.month, .down):
            return "On average, you're burning fewer calories this month than you did last month."
        case (.month, .flat):
            return "On average, you're burning about the same number of calories this month as you did last month."
        case (.year, .up):
            return "So far this year, you're burning more calories a day than you did last year."
        case (.year, .down):
            return "So far this year, you're burning fewer calories a day than you did last year."
        case (.year, .flat):
            return "So far this year, you're burning about the same number of calories a day as you did last year."
        }
    }
}

#Preview {
    NavigationStack {
        HealthEnergyHistoryView()
            .sampleDataContainer()
    }
}
