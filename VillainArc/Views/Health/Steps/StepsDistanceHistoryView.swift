import SwiftUI
import SwiftData
import Charts

struct StepsDistanceHistoryView: View {
    @Query(HealthStepsDistance.history, animation: .smooth) private var entries: [HealthStepsDistance]
    @Query(AppSettings.single) private var appSettings: [AppSettings]

    private var distanceUnit: DistanceUnit {
        appSettings.first?.distanceUnit ?? .systemDefault
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                StepsDistanceMainChartSection(entries: entries, distanceUnit: distanceUnit)

                StepsDistanceWeekdayChartSection(entries: entries)

                StepsDistancePeriodHighlightsSection(entries: entries)
            }
            .padding()
        }
        .navigationTitle("Steps")
        .toolbarTitleDisplayMode(.inline)
    }
}

private struct StepsDistanceCachedRangeData {
    let layout: TimeSeriesChartLayout
    let distanceLayout: TimeSeriesChartLayout
    let yDomain: ClosedRange<Double>
    let totalSteps: Double?
    let averageSteps: Double?
    let highSteps: Double?
}

private struct StepsDistanceMainChartSection: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedRange: TimeSeriesRangeFilter = .month
    @State private var selectedDate: Date?
    @State private var rangeCache: [TimeSeriesRangeFilter: StepsDistanceCachedRangeData] = [:]

    let entries: [HealthStepsDistance]
    let distanceUnit: DistanceUnit

    private let tint = Color.red
    private let stepsSampleNamespace: UInt64 = 0x5354455053000001
    private let distanceSampleNamespace: UInt64 = 0x5354455053000002

    private var stepSamples: [TimeSeriesSample] {
        entries.map { TimeSeriesSample(id: stableTimeSeriesSampleID(namespace: stepsSampleNamespace, date: $0.date), date: $0.date, value: Double($0.stepCount)) }
    }

    private var distanceSamples: [TimeSeriesSample] {
        entries.map { TimeSeriesSample(id: stableTimeSeriesSampleID(namespace: distanceSampleNamespace, date: $0.date), date: $0.date, value: $0.distance) }
    }

    private var latestEntry: HealthStepsDistance? {
        entries.first
    }

    private var hasAnyData: Bool {
        !entries.isEmpty
    }

    private var currentRangeData: StepsDistanceCachedRangeData? {
        rangeCache[selectedRange]
    }

    private var cacheKey: Int {
        var hasher = Hasher()
        hasher.combine(entries.count)
        for entry in entries {
            hasher.combine(entry.date)
            hasher.combine(entry.stepCount)
            hasher.combine(entry.distance.bitPattern)
        }
        return hasher.finalize()
    }

    private var selectedPoint: TimeSeriesBucketedPoint? {
        guard let currentRangeData, let selectedDate else { return nil }
        return selectedTimeSeriesPoint(in: currentRangeData.layout.points, for: selectedDate)
    }

    private var selectedDistancePoint: TimeSeriesBucketedPoint? {
        guard let currentRangeData, let selectedPoint else { return nil }
        return currentRangeData.distanceLayout.points.first { $0.startDate == selectedPoint.startDate && $0.endDate == selectedPoint.endDate }
    }

    private var displayedDateText: String {
        if let selectedPoint {
            let baseText = timeSeriesBucketLabelText(for: selectedPoint, bucketStyle: currentRangeData?.layout.bucketStyle ?? .day)
            if selectedPoint.sampleCount > 1 {
                return "\(baseText) • \(String(localized: "Average"))"
            }
            return baseText
        }
        guard let latestEntry else { return "No entries in this range" }
        return formattedRecentDay(latestEntry.date)
    }

    private var displayedSteps: Int? {
        if let selectedPoint { return Int(selectedPoint.value.rounded()) }
        return latestEntry?.stepCount
    }

    private var displayedDistanceMeters: Double? {
        if selectedPoint != nil { return selectedDistancePoint?.value ?? 0 }
        return latestEntry?.distance
    }

    private var displayedDistanceValueText: String {
        guard let displayedDistanceMeters else { return "-" }
        return distanceUnit.fromMeters(displayedDistanceMeters).formatted(.number.precision(.fractionLength(0...2)))
    }

    private var visibleRangeText: String? {
        guard let currentRangeData else { return nil }
        return formattedAbsoluteDateRange(start: currentRangeData.layout.currentDomain.lowerBound, end: currentRangeData.layout.currentDomain.upperBound)
    }

    private var chartAccessibilityValue: String {
        let dateText = displayedDateText
        let stepsText = displayedSteps.map { "\($0.formatted(.number)) \($0 == 1 ? String(localized: "step") : String(localized: "steps"))" } ?? String(localized: "No step data")
        return AccessibilityText.healthStepsHistoryChartValue(dateText: dateText, stepsText: stepsText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(spacing: 0) {
                HStack(alignment: .bottom) {
                    Text(displayedDateText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer()
                    if displayedDistanceMeters != nil {
                        Text("Distance")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                HStack(alignment: .bottom) {
                    Group {
                        if let displayedSteps {
                            HStack(alignment: .lastTextBaseline, spacing: 4) {
                                Text(displayedSteps, format: .number)
                                Text(displayedSteps == 1 ? "Step" : "Steps")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text("-")
                        }
                    }
                    .font(.largeTitle)
                    Spacer()
                    if displayedDistanceMeters != nil {
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text(displayedDistanceValueText)
                            Text(distanceUnit.rawValue)
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
                    if let selectedPoint {
                        RuleMark(x: .value("Selected Date", selectedPoint.date))
                            .foregroundStyle(tint)
                            .lineStyle(.init(lineWidth: 1, dash: [4, 4]))
                            .zIndex(-1)
                    }

                    ForEach(currentRangeData.layout.points) { point in
                        BarMark(x: .value("Date", point.startDate, unit: chartCalendarComponent(for: currentRangeData.layout.bucketStyle)), y: .value("Steps", point.value), width: .ratio(0.92))
                            .foregroundStyle(tint.gradient)
                            .opacity(selectedPoint == nil || selectedPoint?.id == point.id ? 1 : 0.5)
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
                .accessibilityIdentifier(AccessibilityIdentifiers.healthStepsHistoryChart)
                .accessibilityLabel(AccessibilityText.healthStepsHistoryChartLabel)
                .accessibilityValue(chartAccessibilityValue)

                if let visibleRangeText, !currentRangeData.layout.points.isEmpty {
                    VStack(spacing: 5) {
                        if currentRangeData.averageSteps != nil || currentRangeData.highSteps != nil {
                            HStack {
                                if let averageSteps = currentRangeData.averageSteps {
                                    metadataStepsValue(title: "Avg", steps: averageSteps)
                                }
                                Spacer()
                                if let highSteps = currentRangeData.highSteps {
                                    metadataStepsValue(title: "High", steps: highSteps)
                                }
                            }
                        }

                        HStack {
                            Text(visibleRangeText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .fontWeight(.semibold)
                            Spacer()
                            if let totalSteps = currentRangeData.totalSteps {
                                metadataStepsValue(title: "Total", steps: totalSteps)
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
        .animation(.smooth, value: latestEntry?.stepCount)
        .onChange(of: selectedRange) { selectedDate = nil }
        .task(id: cacheKey) {
            let calendar = Calendar.autoupdatingCurrent
            let now = Date()
            progressivelyRebuildRangeCache(existing: rangeCache, publish: { newCache in
                if rangeCache.isEmpty { rangeCache = newCache } else { withAnimation(.smooth) { rangeCache = newCache } }
            }) { range in
                let layout = TimeSeriesChartLayout(rangeFilter: range, samples: stepSamples, now: now, calendar: calendar, aggregation: .average)
                let distanceLayout = TimeSeriesChartLayout(rangeFilter: range, samples: distanceSamples, now: now, calendar: calendar, aggregation: .average)
                let pointValues = layout.points.map(\.value)
                let visibleEntries = entries.filter { layout.currentDomain.contains($0.date) }
                let totalSteps = visibleEntries.reduce(0) { $0 + Double($1.stepCount) }
                let maximumValue = max(pointValues.max() ?? 0, 1)
                let yDomain = 0...(maximumValue * 1.15)
                let averageSteps = visibleEntries.isEmpty ? nil : (visibleEntries.reduce(0) { $0 + Double($1.stepCount) } / Double(visibleEntries.count))
                let highSteps = visibleEntries.map(\.stepCount).max().map(Double.init)
                return StepsDistanceCachedRangeData(layout: layout, distanceLayout: distanceLayout, yDomain: yDomain, totalSteps: pointValues.isEmpty ? nil : totalSteps, averageSteps: averageSteps, highSteps: highSteps)
            }
        }
    }

    @ViewBuilder
    private func emptyStateView() -> some View {
        if hasAnyData {
            ContentUnavailableView {
                Label(AccessibilityText.healthStepsHistoryEmptyTitle, systemImage: "figure.walk")
            } description: {
                Text(AccessibilityText.healthStepsHistoryEmptyDescription(for: selectedRange))
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
    private func metadataStepsValue(title: String, steps: Double) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(Int(steps.rounded()), format: .number)
                .font(.subheadline)
                .fontWeight(.semibold)
                .fontDesign(.rounded)
                .contentTransition(.numericText(value: steps))
        }
        .animation(reduceMotion ? nil : .smooth, value: steps)
        .accessibilityElement(children: .combine)
    }
}

private struct StepsDistanceWeekdayChartSection: View {
    let entries: [HealthStepsDistance]

    @State private var selectedWeekday: Weekday?
    @State private var points: [WeekdayAveragePoint] = []

    private let tint = Color.red

    private var cacheKey: Int {
        var hasher = Hasher()
        hasher.combine(entries.count)
        for entry in entries {
            hasher.combine(entry.date)
            hasher.combine(entry.stepCount)
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
            return WeekdayAverageChartPresentation(headline: Text(summaryText), accessibilityValue: AccessibilityText.healthStepsWeekdayChartValue(summaryText: summaryText), isAvailable: false, unavailableTitle: "Need More Data", unavailableMessage: "Log at least 2 entries for every weekday to unlock averages.")
        }
        guard let displayedWeekdayPoint else {
            let summaryText = String(localized: "Weekday step averages are unavailable")
            return WeekdayAverageChartPresentation(headline: Text(summaryText), accessibilityValue: AccessibilityText.healthStepsWeekdayChartValue(summaryText: summaryText), isAvailable: false, unavailableTitle: "Need More Data", unavailableMessage: "Log at least 2 entries for every weekday to unlock averages.")
        }
        let stepsText = Int(displayedWeekdayPoint.averageValue.rounded()).formatted(.number)
        let valueText = Text(stepsText).foregroundStyle(tint)
        let weekdayText = displayedWeekdayPoint.weekday.pluralLabel()
        if selectedWeekdayPoint != nil {
            let summaryText = String(localized: "On average, you walk \(stepsText) steps on \(weekdayText).")
            return WeekdayAverageChartPresentation(headline: Text("On average, you walk \(valueText) steps on \(weekdayText)."), accessibilityValue: AccessibilityText.healthStepsWeekdayChartValue(summaryText: summaryText), isAvailable: true, unavailableTitle: "Need More Data", unavailableMessage: "Log at least 2 entries for every weekday to unlock averages.")
        }
        let summaryText = String(localized: "On average, you walk the most on \(weekdayText). \(stepsText) steps.")
        return WeekdayAverageChartPresentation(headline: Text("On average, you walk the most on \(weekdayText). \(valueText) steps."), accessibilityValue: AccessibilityText.healthStepsWeekdayChartValue(summaryText: summaryText), isAvailable: true, unavailableTitle: "Need More Data", unavailableMessage: "Log at least 2 entries for every weekday to unlock averages.")
    }

    var body: some View {
        WeekdayAverageChart(presentation: presentation, points: points, tint: tint, selectedWeekday: $selectedWeekday, accessibilityLabel: AccessibilityText.healthStepsWeekdayChartLabel)
            .padding()
            .glassEffect(.regular, in: .rect(cornerRadius: 18))
            .task(id: cacheKey) {
                let newPoints = makeWeekdayAveragePoints(from: entries, date: \.date, value: { Double($0.stepCount) })
                points = newPoints
                if !(newPoints.count == 7 && newPoints.allSatisfy { $0.sampleCount >= 2 }) { selectedWeekday = nil }
            }
    }
}

private struct StepsDistancePeriodHighlightsSection: View {
    let entries: [HealthStepsDistance]

    private let tint = Color.red

    private var monthlyHighlight: PeriodComparisonHighlight? { makePeriodComparisonHighlight(entries: entries, kind: .month, date: \.date, value: { Double($0.stepCount) }) }

    private var yearlyHighlight: PeriodComparisonHighlight? { makePeriodComparisonHighlight(entries: entries, kind: .year, date: \.date, value: { Double($0.stepCount) }) }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            if let monthlyHighlight {
                PeriodComparisonHighlightCard(summary: stepsSummaryText(for: monthlyHighlight), accessibilitySummary: stepsSummary(for: monthlyHighlight), currentValue: monthlyHighlight.currentAverage, previousValue: monthlyHighlight.previousAverage, currentLabel: monthlyHighlight.currentLabel, previousLabel: monthlyHighlight.previousLabel, unitText: "steps/day", tint: tint)
            }
            if let yearlyHighlight {
                PeriodComparisonHighlightCard(summary: stepsSummaryText(for: yearlyHighlight), accessibilitySummary: stepsSummary(for: yearlyHighlight), currentValue: yearlyHighlight.currentAverage, previousValue: yearlyHighlight.previousAverage, currentLabel: yearlyHighlight.currentLabel, previousLabel: yearlyHighlight.previousLabel, unitText: "steps/day", tint: tint)
            }
        }
    }

    private func stepsSummaryText(for highlight: PeriodComparisonHighlight) -> Text {
        switch (highlight.kind, highlight.trend) {
        case (.month, .up):
            return Text("On average, you're walking \(Text("more").foregroundStyle(tint)) this month than you did last month.")
        case (.month, .down):
            return Text("On average, you're walking \(Text("less").foregroundStyle(tint)) this month than you did last month.")
        case (.month, .flat):
            return Text("On average, you're walking \(Text("about the same").foregroundStyle(tint)) this month as you did last month.")
        case (.year, .up):
            return Text("So far this year, you're taking \(Text("more").foregroundStyle(tint)) steps a day than you did last year.")
        case (.year, .down):
            return Text("So far this year, you're taking \(Text("fewer").foregroundStyle(tint)) steps a day than you did last year.")
        case (.year, .flat):
            return Text("So far this year, you're taking \(Text("about the same").foregroundStyle(tint)) number of steps a day as you did last year.")
        }
    }

    private func stepsSummary(for highlight: PeriodComparisonHighlight) -> String {
        switch (highlight.kind, highlight.trend) {
        case (.month, .up):
            return "On average, you're walking more this month than you did last month."
        case (.month, .down):
            return "On average, you're walking less this month than you did last month."
        case (.month, .flat):
            return "On average, you're walking about the same this month as you did last month."
        case (.year, .up):
            return "So far this year, you're taking more steps a day than you did last year."
        case (.year, .down):
            return "So far this year, you're taking fewer steps a day than you did last year."
        case (.year, .flat):
            return "So far this year, you're taking about the same number of steps a day as you did last year."
        }
    }
}

#Preview {
    NavigationStack {
        StepsDistanceHistoryView()
            .sampleDataContainer()
    }
}
