import Charts
import SwiftData
import SwiftUI

private struct SleepHistoryCachedRangeData {
    let layout: TimeSeriesChartLayout
    let visibleEntries: [HealthSleepNight]
    let averageTimeAsleep: TimeInterval?
    let averageRemDuration: TimeInterval?
    let averageCoreDuration: TimeInterval?
    let averageDeepDuration: TimeInterval?
    let windowBars: [SleepWindowBucket]
}

private struct SleepWindowBucket: Identifiable {
    let id: String
    let point: TimeSeriesBucketedPoint
    let startOffsetMinutes: Double
    let endOffsetMinutes: Double
    let isFullyUnavailable: Bool
}

struct SleepHistoryView: View {
    @Query(HealthSleepNight.history, animation: .smooth) private var entries: [HealthSleepNight]
    
    @State private var loader = HealthSleepHistoryLoader()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SleepHistoryMainSection(entries: entries, loader: loader)
                SleepWeekdayChartSection(entries: entries)
                SleepPeriodHighlightsSection(entries: entries)
            }
            .padding()
        }
        .navigationTitle("Sleep")
        .toolbarTitleDisplayMode(.inline)
    }
}

private struct SleepWeekdayChartSection: View {
    let entries: [HealthSleepNight]

    @State private var selectedWeekday: Weekday?
    @State private var points: [WeekdayAveragePoint] = []

    private let tint = Color.indigo

    private var cacheKey: Int {
        var hasher = Hasher()
        hasher.combine(entries.count)
        for entry in entries {
            hasher.combine(entry.wakeDay)
            hasher.combine(entry.timeAsleep.bitPattern)
            hasher.combine(entry.isAvailableInHealthKit)
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
            let summaryText = String(localized: "Weekday sleep averages need at least 2 nights for every weekday")
            return WeekdayAverageChartPresentation(headline: Text(summaryText), accessibilityValue: AccessibilityText.healthSleepWeekdayChartValue(summaryText: summaryText), isAvailable: false, unavailableTitle: "Need More Data", unavailableMessage: "Sync at least 2 sleep nights for every weekday to unlock averages.")
        }
        guard let displayedWeekdayPoint else {
            let summaryText = String(localized: "Weekday sleep averages are unavailable")
            return WeekdayAverageChartPresentation(headline: Text(summaryText), accessibilityValue: AccessibilityText.healthSleepWeekdayChartValue(summaryText: summaryText), isAvailable: false, unavailableTitle: "Need More Data", unavailableMessage: "Sync at least 2 sleep nights for every weekday to unlock averages.")
        }
        let sleepText = formattedSleepDurationAccessibilityText(displayedWeekdayPoint.averageValue)
        let valueText = Text(formattedSleepDurationText(displayedWeekdayPoint.averageValue)).foregroundStyle(tint)
        let weekdayText = displayedWeekdayPoint.weekday.pluralLabel()
        if selectedWeekdayPoint != nil {
            let summaryText = String(localized: "You sleep \(sleepText) on \(weekdayText).")
            return WeekdayAverageChartPresentation(headline: Text("You sleep \(valueText) on \(weekdayText)."), accessibilityValue: AccessibilityText.healthSleepWeekdayChartValue(summaryText: summaryText), isAvailable: true, unavailableTitle: "Need More Data", unavailableMessage: "Sync at least 2 sleep nights for every weekday to unlock averages.")
        }
        let summaryText = String(localized: "You sleep the most on \(weekdayText). \(sleepText).")
        return WeekdayAverageChartPresentation(headline: Text("You sleep the most on \(weekdayText). \(valueText)."), accessibilityValue: AccessibilityText.healthSleepWeekdayChartValue(summaryText: summaryText), isAvailable: true, unavailableTitle: "Need More Data", unavailableMessage: "Sync at least 2 sleep nights for every weekday to unlock averages.")
    }

    var body: some View {
        WeekdayAverageChart(presentation: presentation, points: points, tint: tint, selectedWeekday: $selectedWeekday, accessibilityLabel: AccessibilityText.healthSleepWeekdayChartLabel, yAxisValueLabel: formattedSleepDurationText)
            .padding()
            .glassEffect(.regular, in: .rect(cornerRadius: 18))
            .task(id: cacheKey) {
                let newPoints = makeWeekdayAveragePoints(from: entries.filter { $0.timeAsleep > 0 }, date: \.displayWakeDay, value: \.timeAsleep)
                points = newPoints
                if !(newPoints.count == 7 && newPoints.allSatisfy { $0.sampleCount >= 2 }) { selectedWeekday = nil }
            }
    }
}

private struct SleepPeriodHighlightsSection: View {
    let entries: [HealthSleepNight]

    private let tint = Color.indigo

    private var highlightEntries: [HealthSleepNight] {
        entries.filter { $0.timeAsleep > 0 }
    }

    private var monthlyHighlight: PeriodComparisonHighlight? { makePeriodComparisonHighlight(entries: highlightEntries, kind: .month, date: \.displayWakeDay, value: \.timeAsleep, flatThreshold: 30 * 60) }

    private var yearlyHighlight: PeriodComparisonHighlight? { makePeriodComparisonHighlight(entries: highlightEntries, kind: .year, date: \.displayWakeDay, value: \.timeAsleep, flatThreshold: 30 * 60) }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            if let monthlyHighlight {
                PeriodComparisonHighlightCard(summary: sleepSummaryText(for: monthlyHighlight), accessibilitySummary: sleepSummary(for: monthlyHighlight), currentValue: monthlyHighlight.currentAverage, previousValue: monthlyHighlight.previousAverage, currentLabel: monthlyHighlight.currentLabel, previousLabel: monthlyHighlight.previousLabel, unitText: "night", tint: tint, valueText: formattedSleepDurationText, accessibilityValueText: { "\(formattedSleepDurationAccessibilityText($0)) asleep per night" })
            }
            if let yearlyHighlight {
                PeriodComparisonHighlightCard(summary: sleepSummaryText(for: yearlyHighlight), accessibilitySummary: sleepSummary(for: yearlyHighlight), currentValue: yearlyHighlight.currentAverage, previousValue: yearlyHighlight.previousAverage, currentLabel: yearlyHighlight.currentLabel, previousLabel: yearlyHighlight.previousLabel, unitText: "night", tint: tint, valueText: formattedSleepDurationText, accessibilityValueText: { "\(formattedSleepDurationAccessibilityText($0)) asleep per night" })
            }
        }
    }

    private func sleepSummaryText(for highlight: PeriodComparisonHighlight) -> Text {
        let yearLeadIn = yearComparisonLeadIn()
        switch (highlight.kind, highlight.trend) {
        case (.month, .up):
            return Text("You're getting \(Text("more").foregroundStyle(tint)) sleep this month than you did last month.")
        case (.month, .down):
            return Text("You're getting \(Text("less").foregroundStyle(tint)) sleep this month than you did last month.")
        case (.month, .flat):
            return Text("You're getting \(Text("about the same").foregroundStyle(tint)) amount of sleep this month as you did last month.")
        case (.year, .up):
            return Text("\(yearLeadIn), you're sleeping \(Text("more").foregroundStyle(tint)) each night than you did last year.")
        case (.year, .down):
            return Text("\(yearLeadIn), you're sleeping \(Text("less").foregroundStyle(tint)) each night than you did last year.")
        case (.year, .flat):
            return Text("\(yearLeadIn), you're sleeping \(Text("about the same").foregroundStyle(tint)) amount each night as you did last year.")
        }
    }

    private func sleepSummary(for highlight: PeriodComparisonHighlight) -> String {
        let yearLeadIn = yearComparisonLeadIn()
        switch (highlight.kind, highlight.trend) {
        case (.month, .up):
            return "You're getting more sleep this month than you did last month."
        case (.month, .down):
            return "You're getting less sleep this month than you did last month."
        case (.month, .flat):
            return "You're getting about the same amount of sleep this month as you did last month."
        case (.year, .up):
            return "\(yearLeadIn), you're sleeping more each night than you did last year."
        case (.year, .down):
            return "\(yearLeadIn), you're sleeping less each night than you did last year."
        case (.year, .flat):
            return "\(yearLeadIn), you're sleeping about the same amount each night as you did last year."
        }
    }
}

private struct SleepHistoryMainSection: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let tint = Color.indigo
    
    let entries: [HealthSleepNight]
    let loader: HealthSleepHistoryLoader
    
    @State private var selectedRange: TimeSeriesRangeFilter = .day
    @State private var selectedDate: Date?
    @State private var selectedWakeDay: Date?
    @State private var rangeCache: [TimeSeriesRangeFilter: SleepHistoryCachedRangeData] = [:]
    
    private let timeAsleepNamespace: UInt64 = 0x534C4545500001
    
    private var latestEntry: HealthSleepNight? { entries.first }
    
    private var entryByWakeDay: [Date: HealthSleepNight] {
        Dictionary(uniqueKeysWithValues: entries.map { ($0.wakeDay, $0) })
    }
    
    private var timeAsleepSamples: [TimeSeriesSample] {
        entries.map { TimeSeriesSample(id: stableTimeSeriesSampleID(namespace: timeAsleepNamespace, date: $0.displayWakeDay), date: $0.displayWakeDay, value: $0.timeAsleep) }
    }
    
    private var currentRangeData: SleepHistoryCachedRangeData? { rangeCache[selectedRange] }
    
    private var selectedPoint: TimeSeriesBucketedPoint? {
        guard selectedRange != .day else { return nil }
        guard let currentRangeData, let selectedDate else { return nil }
        return selectedTimeSeriesPoint(in: currentRangeData.layout.points, for: selectedDate)
    }

    private var displayedWakeDay: Date? {
        if let selectedWakeDay, selectedRange == .day { return selectedWakeDay }
        return latestEntry?.wakeDay
    }
    
    private var displayedEntry: HealthSleepNight? {
        guard let displayedWakeDay else { return nil }
        return entryByWakeDay[displayedWakeDay]
    }
    
    private var dayIntervals: [HealthSleepStageInterval] {
        guard let displayedEntry else { return [] }
        return effectiveIntervals(for: displayedEntry)
    }

    private var dayStageStats: [(title: String, duration: TimeInterval)] {
        sleepStageStats(remDuration: displayedEntry?.remDuration, coreDuration: displayedEntry?.coreDuration, deepDuration: displayedEntry?.deepDuration)
    }

    private var selectedNonDayEntries: [HealthSleepNight] {
        guard let currentRangeData, let selectedPoint else { return [] }
        return currentRangeData.visibleEntries.filter {
            let wakeDay = $0.displayWakeDay
            return wakeDay >= selectedPoint.startDate && wakeDay <= selectedPoint.endDate
        }
    }

    private var nonDayStageStats: [(title: String, duration: TimeInterval)] {
        if !selectedNonDayEntries.isEmpty {
            let selectedStats = sleepStageStats(
                remDuration: averageDuration(in: selectedNonDayEntries, for: \.remDuration),
                coreDuration: averageDuration(in: selectedNonDayEntries, for: \.coreDuration),
                deepDuration: averageDuration(in: selectedNonDayEntries, for: \.deepDuration)
            )
            if !selectedStats.isEmpty { return selectedStats }
        }

        return sleepStageStats(remDuration: currentRangeData?.averageRemDuration, coreDuration: currentRangeData?.averageCoreDuration, deepDuration: currentRangeData?.averageDeepDuration)
    }
    
    private var selectedDayInterval: HealthSleepStageInterval? {
        guard selectedRange == .day, let selectedDate else { return nil }
        return selectedInterval(in: dayIntervals, for: selectedDate)
    }
    
    private var rangeCacheSeed: Int {
        var hasher = Hasher()
        hasher.combine(entries.count)
        for entry in entries {
            hasher.combine(entry.wakeDay)
            hasher.combine(entry.sleepStart)
            hasher.combine(entry.sleepEnd)
            hasher.combine(entry.allSleepStart)
            hasher.combine(entry.allSleepEnd)
            hasher.combine(entry.timeAsleep.bitPattern)
            hasher.combine(entry.timeInBed.bitPattern)
            hasher.combine(entry.awakeDuration.bitPattern)
            hasher.combine(entry.remDuration.bitPattern)
            hasher.combine(entry.coreDuration.bitPattern)
            hasher.combine(entry.deepDuration.bitPattern)
            hasher.combine(entry.asleepUnspecifiedDuration.bitPattern)
            hasher.combine(entry.napDuration.bitPattern)
            hasher.combine(entry.hasStageBreakdown)
            hasher.combine(entry.isAvailableInHealthKit)
            hasher.combine(entry.blocks?.count ?? 0)
            for block in entry.sortedBlocks {
                hasher.combine(block.startDate)
                hasher.combine(block.endDate)
                hasher.combine(block.isPrimary)
                hasher.combine(block.timeAsleep.bitPattern)
                hasher.combine(block.timeInBed.bitPattern)
                hasher.combine(block.awakeDuration.bitPattern)
                hasher.combine(block.remDuration.bitPattern)
                hasher.combine(block.coreDuration.bitPattern)
                hasher.combine(block.deepDuration.bitPattern)
                hasher.combine(block.asleepUnspecifiedDuration.bitPattern)
            }
        }
        return hasher.finalize()
    }
    
    private var initialLoadKey: Int {
        var hasher = Hasher()
        hasher.combine(latestEntry?.wakeDay)
        hasher.combine(latestEntry?.allSleepStart)
        hasher.combine(latestEntry?.allSleepEnd)
        return hasher.finalize()
    }
    
    private var visibleLoadKey: Int {
        var hasher = Hasher()
        hasher.combine(selectedRange.rawValue)
        hasher.combine(selectedWakeDay)
        return hasher.finalize()
    }
    
    private var headerDuration: TimeInterval? {
        if let selectedDayInterval { return selectedDayInterval.duration }
        if selectedRange == .day { return displayedEntry?.timeAsleep }
        if let selectedPoint { return selectedPoint.value }
        return latestEntry?.timeAsleep
    }

    private var headerSubtitleText: String {
        if let selectedDayInterval {
            let wakeDayText = displayedEntry.map { formattedSleepWakeDay($0.wakeDay) } ?? formattedRecentDay(selectedDayInterval.endDate)
            let timingText = formattedSleepTimingText(start: selectedDayInterval.startDate, end: selectedDayInterval.endDate)
            return "\(wakeDayText) • \(selectedDayInterval.stage.title) • \(timingText)"
        }

        if let selectedPoint {
            let label = timeSeriesBucketLabelText(for: selectedPoint, bucketStyle: currentRangeData?.layout.bucketStyle ?? .day)
            return label
        }

        guard let latestEntry else { return "No sleep data in this range" }
        return formattedSleepWakeDay(latestEntry.wakeDay)
    }
    
    private var visibleRangeText: String? {
        guard let currentRangeData else { return nil }
        return formattedAbsoluteDateRange(start: currentRangeData.layout.currentDomain.lowerBound, end: currentRangeData.layout.currentDomain.upperBound)
    }
    
    private var dayChartDomain: ClosedRange<Date> {
        let calendar = Calendar.autoupdatingCurrent
        guard let displayedEntry else {
            let start = calendar.startOfDay(for: .now)
            return start...calendar.endOfDay(for: .now)
        }
        
        let startCandidates = dayIntervals.map(\.startDate) + [displayedEntry.allSleepStart ?? displayedEntry.sleepStart].compactMap(\.self)
        let endCandidates = dayIntervals.map(\.endDate) + [displayedEntry.allSleepEnd ?? displayedEntry.sleepEnd].compactMap(\.self)
        
        guard let earliestStart = startCandidates.min(), let latestEnd = endCandidates.max() else {
            let start = calendar.startOfDay(for: displayedEntry.displayWakeDay)
            return start...calendar.endOfDay(for: displayedEntry.displayWakeDay)
        }
        
        let lowerBound = roundedDownHour(earliestStart.addingTimeInterval(-30 * 60), calendar: calendar)
        var upperBound = roundedUpHour(latestEnd.addingTimeInterval(30 * 60), calendar: calendar)
        if upperBound <= lowerBound {
            upperBound = calendar.date(byAdding: .hour, value: 6, to: lowerBound) ?? latestEnd
        }
        return lowerBound...upperBound
    }
    
    private var intervalChartYDomain: ClosedRange<Double> {
        return sleepOffsetDomain(startOffsets: currentRangeData?.windowBars.map(\.startOffsetMinutes) ?? [], endOffsets: currentRangeData?.windowBars.map(\.endOffsetMinutes) ?? [])
    }
    
    private var sleepStageAxisDomain: [String] {
        let orderedTopToBottom: [HealthSleepStage] = [.awake, .asleep, .rem, .core, .deep]
        let presentStages = Set(dayIntervals.map(\.stage))
        let visibleStages = orderedTopToBottom.filter { presentStages.contains($0) }
        return (visibleStages.isEmpty ? orderedTopToBottom : visibleStages).map(\.title)
    }
    
    private var chartAccessibilityValue: String {
        if let selectedDayInterval {
            return "\(headerSubtitleText), \(formattedSleepDurationAccessibilityText(selectedDayInterval.duration))"
        }
        
        guard let headerDuration else { return "No sleep data available." }
        return "\(headerSubtitleText), \(formattedSleepDurationAccessibilityText(headerDuration)) asleep"
    }

    private var selectedChartDate: Date? {
        if selectedRange == .day {
            return selectedDate
        }
        return selectedPoint?.date
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(headerSubtitleText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

                if let headerDuration {
                    SleepDurationValueView(duration: headerDuration)
                } else {
                    Text("-")
                        .font(.largeTitle)
                        .bold()
                }
            }
            
            chartView

            VStack(spacing: 3) {
                sleepStageStatsRow(selectedRange == .day ? dayStageStats : nonDayStageStats)
                
                if selectedRange != .day {
                    HStack(alignment: .bottom) {
                        if let visibleRangeText {
                            Text(visibleRangeText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .fontWeight(.semibold)
                        }
                        Spacer()
                        if let averageTimeAsleep = currentRangeData?.averageTimeAsleep {
                            HealthHistoryMetadataValue(title: "Avg Sleep", text: formattedSleepDurationText(averageTimeAsleep), animationValue: averageTimeAsleep)
                        }
                    }
                }
            }
            
            if selectedRange == .day, displayedEntry?.isAvailableInHealthKit == false {
                Text("This sleep night is no longer available in Apple Health. VillainArc is showing the last synced summary.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if let loadErrorMessage = loader.loadErrorMessage, selectedRange == .day {
                Text(loadErrorMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Picker("Range", selection: $selectedRange.animation(reduceMotion ? nil : .easeInOut)) {
                ForEach(TimeSeriesRangeFilter.allCases) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedRange) {
                Haptics.selection()
                selectedDate = nil
            }
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
        .onChange(of: latestEntry?.wakeDay) {
            if let selectedWakeDay, entryByWakeDay[selectedWakeDay] != nil { return }
            selectedWakeDay = latestEntry?.wakeDay
        }
        .task(id: rangeCacheSeed) {
            prepareRangeCache()
        }
        .task(id: initialLoadKey) {
            await loader.loadInitialIfNeeded(latestNight: latestEntry)
        }
        .task(id: visibleLoadKey) {
            if selectedRange == .day, let displayedEntry {
                await loader.loadDayIfNeeded(night: displayedEntry)
            }
        }
        .onAppear {
            if selectedWakeDay == nil { selectedWakeDay = latestEntry?.wakeDay }
        }
    }
    
    @ViewBuilder
    private var chartView: some View {
        if entries.isEmpty {
            emptyStateView()
        } else if selectedRange == .day || currentRangeData != nil {
            adaptiveChartView
        } else {
            ProgressView("Updating chart")
                .frame(maxWidth: .infinity, minHeight: 300)
        }
    }

    @ViewBuilder
    private var adaptiveChartView: some View {
        let chart = Chart {
            if let selectedChartDate {
                RuleMark(x: .value("Selected Date", selectedChartDate))
                    .foregroundStyle(tint)
                    .lineStyle(.init(lineWidth: 1, dash: [4, 4]))
                    .zIndex(-1)
            }

            if selectedRange == .day {
                ForEach(dayIntervals) { interval in
                    BarMark(xStart: .value("Start", interval.startDate), xEnd: .value("End", interval.endDate), y: .value("Stage", interval.stage.title))
                        .foregroundStyle(interval.stage.tint.opacity(interval.isApproximate ? 0.45 : 1).gradient)
                        .opacity(selectedDayInterval == nil || selectedDayInterval?.id == interval.id ? 1 : 0.3)
                }
            } else if let currentRangeData {
                ForEach(currentRangeData.windowBars) { bar in
                    BarMark(x: .value("Bucket", bar.point.date, unit: chartCalendarComponent(for: currentRangeData.layout.bucketStyle)), yStart: .value("Start", bar.startOffsetMinutes), yEnd: .value("End", bar.endOffsetMinutes), width: .ratio(0.8))
                        .foregroundStyle(tint.opacity(bar.isFullyUnavailable ? 0.35 : 0.85).gradient)
                        .opacity(selectedPoint == nil || selectedPoint?.id == bar.point.id ? 1 : 0.22)
                }
            }
        }
        .chartLegend(.hidden)
        .accessibilityIdentifier(AccessibilityIdentifiers.healthSleepHistoryChart)
        .accessibilityLabel(AccessibilityText.healthSleepHistoryChartLabel)
        .accessibilityValue(chartAccessibilityValue)

        if selectedRange == .day {
            chart
                .chartXSelection(value: $selectedDate)
                .chartXScale(domain: dayChartDomain)
                .chartYScale(domain: sleepStageAxisDomain)
                .chartXAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(date.formatted(date: .omitted, time: .shortened))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: sleepStageAxisDomain) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let stageTitle = value.as(String.self) {
                                Text(stageTitle)
                            }
                        }
                    }
                }
                .frame(height: 300)
                .overlay {
                    if dayIntervals.isEmpty {
                        emptyStateView()
                    }
                }
        } else if let currentRangeData {
            chart
                .healthHistoryChartScaffold(selectedDate: $selectedDate, layout: currentRangeData.layout, height: 300)
                .chartYScale(domain: intervalChartYDomain)
                .chartYAxis {
                    AxisMarks(position: .trailing) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let offset = value.as(Double.self) {
                                Text(formattedSleepOffsetLabel(offset))
                            }
                        }
                    }
                }
                .overlay {
                    if currentRangeData.windowBars.isEmpty {
                        emptyStateView()
                    }
                }
        }
    }
    
    @ViewBuilder
    private func emptyStateView() -> some View {
        if entries.isEmpty {
            ContentUnavailableView {
                Label(AccessibilityText.healthHistoryNoHealthDataTitle, systemImage: "heart.text.square")
            } description: {
                Text(AccessibilityText.healthHistoryNoHealthDataDescription)
            }
        } else {
            ContentUnavailableView {
                Label(AccessibilityText.healthSleepHistoryEmptyTitle, systemImage: "bed.double.fill")
            } description: {
                Text(AccessibilityText.healthSleepHistoryEmptyDescription(for: selectedRange))
            }
        }
    }

    @ViewBuilder
    private func sleepStageStatsRow(_ stats: [(title: String, duration: TimeInterval)]) -> some View {
        if !stats.isEmpty {
            HStack(alignment: .bottom) {
                ForEach(Array(stats.enumerated()), id: \.element.title) { index, stat in
                    if index > 0 { Spacer() }
                    HealthHistoryMetadataValue(title: stat.title, text: formattedSleepDurationText(stat.duration), animationValue: stat.duration)
                }
            }
        }
    }
    
    private func prepareRangeCache() {
        let calendar = Calendar.autoupdatingCurrent
        let anchorDate = latestEntry?.displayWakeDay ?? .now
        
        progressivelyRebuildRangeCache(
            existing: rangeCache,
            buildOrder: [.day, .week, .month, .sixMonths, .year, .all],
            publish: { newCache in
                if rangeCache.isEmpty || reduceMotion {
                    rangeCache = newCache
                } else {
                    withAnimation(.smooth) {
                        rangeCache = newCache
                    }
                }
            },
            builder: { range in
                let layout = TimeSeriesChartLayout(rangeFilter: range, samples: timeAsleepSamples, now: anchorDate, calendar: calendar, aggregation: .average)
                let visibleEntries = entries.filter { layout.currentDomain.contains($0.displayWakeDay) }
                let windowBars = makeWindowBars(for: range, points: layout.points, visibleEntries: visibleEntries)
                
                return SleepHistoryCachedRangeData(
                    layout: layout,
                    visibleEntries: visibleEntries,
                    averageTimeAsleep: averageDuration(in: visibleEntries, for: \.timeAsleep),
                    averageRemDuration: averageDuration(in: visibleEntries, for: \.remDuration),
                    averageCoreDuration: averageDuration(in: visibleEntries, for: \.coreDuration),
                    averageDeepDuration: averageDuration(in: visibleEntries, for: \.deepDuration),
                    windowBars: windowBars
                )
            }
        )
    }
    
    private func effectiveIntervals(for entry: HealthSleepNight) -> [HealthSleepStageInterval] {
        let loadedIntervals = loader.intervalsByWakeDay[entry.wakeDay] ?? []
        if !loadedIntervals.isEmpty {
            return loadedIntervals
        }
        return fallbackIntervals(for: entry)
    }
    
    private func fallbackIntervals(for entry: HealthSleepNight) -> [HealthSleepStageInterval] {
        let blockIntervals = entry.sortedBlocks.map {
            HealthSleepStageInterval(wakeDay: entry.wakeDay, startDate: $0.startDate, endDate: $0.endDate, stage: .asleep, timeZoneIdentifier: nil, isApproximate: true)
        }

        if !blockIntervals.isEmpty { return blockIntervals }

        guard let sleepStart = entry.allSleepStart ?? entry.sleepStart, let sleepEnd = entry.allSleepEnd ?? entry.sleepEnd, sleepEnd > sleepStart else { return [] }
        return [HealthSleepStageInterval(wakeDay: entry.wakeDay, startDate: sleepStart, endDate: sleepEnd, stage: .asleep, timeZoneIdentifier: nil, isApproximate: true)]
    }
    
    private func selectedInterval(in intervals: [HealthSleepStageInterval], for date: Date) -> HealthSleepStageInterval? {
        if let containingInterval = intervals.first(where: { $0.startDate <= date && $0.endDate >= date }) {
            return containingInterval
        }
        
        return intervals.min {
            abs($0.endDate.timeIntervalSince(date)) < abs($1.endDate.timeIntervalSince(date))
        }
    }
    
    private func makeWindowBars(for range: TimeSeriesRangeFilter, points: [TimeSeriesBucketedPoint], visibleEntries: [HealthSleepNight]) -> [SleepWindowBucket] {
        if range == .week || range == .month {
            return makeDetailedWindowBars(for: points, visibleEntries: visibleEntries)
        }

        return points.compactMap { point in
            let bucketEntries = visibleEntries.filter { entry in
                let displayWakeDay = entry.displayWakeDay
                return displayWakeDay >= point.startDate && displayWakeDay <= point.endDate
            }
            
            let windows = bucketEntries.compactMap { sleepWindow(for: $0) }
            guard !windows.isEmpty else { return nil }
            
            let averageStart = windows.reduce(0) { $0 + $1.startOffsetMinutes } / Double(windows.count)
            let averageEnd = windows.reduce(0) { $0 + $1.endOffsetMinutes } / Double(windows.count)
            let isFullyUnavailable = !bucketEntries.isEmpty && bucketEntries.allSatisfy { !$0.isAvailableInHealthKit }
            
            return SleepWindowBucket(id: "\(point.id.uuidString)-average", point: point, startOffsetMinutes: averageStart, endOffsetMinutes: averageEnd, isFullyUnavailable: isFullyUnavailable)
        }
    }

    private func makeDetailedWindowBars(for points: [TimeSeriesBucketedPoint], visibleEntries: [HealthSleepNight]) -> [SleepWindowBucket] {
        return points.flatMap { point in
            let bucketEntries = visibleEntries.filter {
                let displayWakeDay = $0.displayWakeDay
                return displayWakeDay >= point.startDate && displayWakeDay <= point.endDate
            }
            let bars = bucketEntries.flatMap { makeDetailedWindowBars(for: $0, point: point) }
            if !bars.isEmpty { return bars }
            return makeFallbackWindowBars(for: point, entries: bucketEntries)
        }
    }

    private func makeDetailedWindowBars(for entry: HealthSleepNight, point: TimeSeriesBucketedPoint) -> [SleepWindowBucket] {
        let isUnavailable = !entry.isAvailableInHealthKit
        return entry.sortedBlocks.enumerated().compactMap { index, block in
            guard block.endDate > block.startDate else { return nil }
            return SleepWindowBucket(id: "\(point.id.uuidString)-\(entry.wakeDay.timeIntervalSinceReferenceDate)-\(index)", point: point, startOffsetMinutes: sleepOffsetMinutes(for: block.startDate, wakeDay: entry.displayWakeDay), endOffsetMinutes: sleepOffsetMinutes(for: block.endDate, wakeDay: entry.displayWakeDay), isFullyUnavailable: isUnavailable)
        }
    }

    private func makeFallbackWindowBars(for point: TimeSeriesBucketedPoint, entries: [HealthSleepNight]) -> [SleepWindowBucket] {
        entries.compactMap { entry in
            guard let window = sleepWindow(for: entry) else { return nil }
            return SleepWindowBucket(id: "\(point.id.uuidString)-\(entry.wakeDay.timeIntervalSinceReferenceDate)-fallback", point: point, startOffsetMinutes: window.startOffsetMinutes, endOffsetMinutes: window.endOffsetMinutes, isFullyUnavailable: !entry.isAvailableInHealthKit)
        }
    }
    
    private func sleepWindow(for entry: HealthSleepNight) -> (startOffsetMinutes: Double, endOffsetMinutes: Double)? {
        guard let sleepStart = entry.allSleepStart ?? entry.sleepStart, let sleepEnd = entry.allSleepEnd ?? entry.sleepEnd, sleepEnd > sleepStart else { return nil }
        return (startOffsetMinutes: sleepOffsetMinutes(for: sleepStart, wakeDay: entry.displayWakeDay), endOffsetMinutes: sleepOffsetMinutes(for: sleepEnd, wakeDay: entry.displayWakeDay))
    }
    
    private func sleepOffsetMinutes(for date: Date, wakeDay: Date) -> Double {
        let startOfWakeDay = Calendar.autoupdatingCurrent.startOfDay(for: wakeDay)
        return date.timeIntervalSince(startOfWakeDay) / 60
    }
    
    private func sleepOffsetDomain(startOffsets: [Double], endOffsets: [Double]) -> ClosedRange<Double> {
        let combinedValues = startOffsets + endOffsets
        guard let minimum = combinedValues.min(), let maximum = combinedValues.max() else { return -60...60 }
        
        if minimum == maximum {
            return (minimum - 60)...(maximum + 60)
        }
        
        let span = maximum - minimum
        let padding = max(span * 0.12, 30)
        return (minimum - padding)...(maximum + padding)
    }
    
    private func formattedSleepOffsetLabel(_ offsetMinutes: Double) -> String {
        let referenceDay = Calendar.autoupdatingCurrent.startOfDay(for: .now)
        let date = referenceDay.addingTimeInterval(offsetMinutes * 60)
        return date.formatted(date: .omitted, time: .shortened)
    }

    private func averageDuration(in entries: [HealthSleepNight], for keyPath: KeyPath<HealthSleepNight, TimeInterval>) -> TimeInterval? {
        guard !entries.isEmpty else { return nil }
        return entries.reduce(0) { $0 + $1[keyPath: keyPath] } / Double(entries.count)
    }

    private func sleepStageStats(remDuration: TimeInterval?, coreDuration: TimeInterval?, deepDuration: TimeInterval?) -> [(title: String, duration: TimeInterval)] {
        [
            (title: "REM", duration: remDuration ?? 0),
            (title: "Core", duration: coreDuration ?? 0),
            (title: "Deep", duration: deepDuration ?? 0)
        ]
        .filter { $0.duration > 0 }
    }
}

private extension HealthSleepStage {
    var tint: Color {
        switch self {
        case .awake:
            return Color.red.opacity(0.72)
        case .rem:
            return Color.cyan
        case .core:
            return Color.blue
        case .asleep:
            return Color.indigo.opacity(0.72)
        case .deep:
            return Color.indigo
        }
    }
}

private func roundedDownHour(_ date: Date, calendar: Calendar) -> Date {
    calendar.dateInterval(of: .hour, for: date)?.start ?? date
}

private func roundedUpHour(_ date: Date, calendar: Calendar) -> Date {
    let roundedDown = roundedDownHour(date, calendar: calendar)
    if roundedDown == date {
        return date
    }
    return calendar.date(byAdding: .hour, value: 1, to: roundedDown) ?? date
}

#Preview {
    NavigationStack {
        SleepHistoryView()
            .sampleDataContainer()
    }
}
