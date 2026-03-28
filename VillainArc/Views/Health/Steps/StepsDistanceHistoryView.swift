import SwiftUI
import SwiftData
import Charts

private extension TimeSeriesRangeFilter {
    func stepsEmptyStateDescription() -> String {
        switch self {
        case .week:
            return String(localized: "No step data was recorded in the last 7 days.")
        case .month:
            return String(localized: "No step data was recorded in the last month.")
        case .sixMonths:
            return String(localized: "No step data was recorded in the last 6 months.")
        case .year:
            return String(localized: "No step data was recorded in the last year.")
        case .all:
            return String(localized: "No step data has been recorded yet.")
        }
    }
}

struct StepsDistanceHistoryView: View {
    @Query(HealthStepsDistance.history, animation: .smooth) private var entries: [HealthStepsDistance]
    @Query(AppSettings.single) private var appSettings: [AppSettings]

    @State private var selectedRange: TimeSeriesRangeFilter = .month

    private var distanceUnit: DistanceUnit {
        appSettings.first?.distanceUnit ?? .systemDefault
    }

    private var availableRanges: [TimeSeriesRangeFilter] {
        TimeSeriesRangeFilter.allCases
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                StepsDistanceHistoryMainSection(entries: entries, distanceUnit: distanceUnit, selectedRange: $selectedRange, availableRanges: availableRanges)
            }
            .padding()
        }
        .navigationTitle("Steps")
        .toolbarTitleDisplayMode(.inline)
    }
}

private struct StepsDistanceHistoryMainSection: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct CachedRangeData {
        let layout: TimeSeriesChartLayout
        let distanceLayout: TimeSeriesChartLayout
        let yDomain: ClosedRange<Double>
        let totalSteps: Double?
        let averageSteps: Double?
        let highSteps: Double?
    }

    private enum MetadataAlignment {
        case leading
        case trailing
    }

    let entries: [HealthStepsDistance]
    let distanceUnit: DistanceUnit
    @Binding var selectedRange: TimeSeriesRangeFilter
    let availableRanges: [TimeSeriesRangeFilter]

    @State private var selectedDate: Date?
    @State private var rangeCache: [TimeSeriesRangeFilter: CachedRangeData] = [:]

    private let tint = Color.red

    private var stepSamples: [TimeSeriesSample] {
        entries.map { TimeSeriesSample(id: UUID(), date: $0.date, value: Double($0.stepCount)) }
    }

    private var distanceSamples: [TimeSeriesSample] {
        entries.map { TimeSeriesSample(id: UUID(), date: $0.date, value: $0.distance) }
    }

    private var latestEntry: HealthStepsDistance? {
        entries.first
    }

    private var hasAnyData: Bool {
        !entries.isEmpty
    }

    private var currentRangeData: CachedRangeData? {
        rangeCache[selectedRange]
    }

    private var cacheSeed: Int {
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
        return nearestPoint(in: currentRangeData.layout.points, to: selectedDate)
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

    private var displayedDistanceText: String {
        guard let displayedDistanceMeters else { return "-" }
        return distanceUnit.display(displayedDistanceMeters, fractionDigits: 0...2)
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
            VStack(alignment: .leading, spacing: 18) {
                VStack(spacing: 0) {
                    HStack(alignment: .bottom) {
                        Text(displayedDateText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Spacer()
                        Text("Distance")
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
                        Text(displayedDistanceText)
                            .font(.title)
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
                        }

                        ForEach(currentRangeData.layout.points) { point in
                            BarMark(x: .value("Date", point.startDate, unit: chartCalendarComponent(for: currentRangeData.layout.bucketStyle)), y: .value("Steps", point.value), width: .ratio(0.92))
                                .foregroundStyle(tint.gradient)
                                .opacity(selectedPoint == nil || selectedPoint?.id == point.id ? 1 : 0.5)
                        }
                    }
                    .chartLegend(.hidden)
                    .chartXSelection(value: $selectedDate)
                    .chartXScale(domain: currentRangeData.layout.currentDomain)
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
                    .chartXAxis {
                        AxisMarks(values: currentRangeData.layout.axisDates) { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel {
                                if let date = value.as(Date.self) {
                                    Text(timeSeriesAxisLabelText(for: date, style: currentRangeData.layout.axisLabelStyle))
                                }
                            }
                        }
                    }
                    .overlay {
                        if currentRangeData.layout.points.isEmpty {
                            emptyStateView()
                        }
                    }
                    .frame(height: 260)
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

                Picker("Range", selection: $selectedRange.animation(.easeInOut)) {
                    ForEach(availableRanges) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedRange) { selectedDate = nil; Haptics.selection() }
            }
            .padding()
            .glassEffect(.regular, in: .rect(cornerRadius: 18))
        }
        .onChange(of: selectedRange) { selectedDate = nil }
        .task(id: cacheSeed) {
            prepareRangeCache()
        }
    }

    private func nearestPoint(in points: [TimeSeriesBucketedPoint], to date: Date) -> TimeSeriesBucketedPoint? {
        points.min { left, right in
            abs(left.date.timeIntervalSince(date)) < abs(right.date.timeIntervalSince(date))
        }
    }

    private func chartCalendarComponent(for bucketStyle: TimeSeriesBucketStyle) -> Calendar.Component {
        switch bucketStyle {
        case .day:
            return .day
        case .week:
            return .weekOfYear
        case .month:
            return .month
        }
    }

    @ViewBuilder
    private func emptyStateView() -> some View {
        if hasAnyData {
            ContentUnavailableView {
                Label("No Step Data", systemImage: "figure.walk")
            } description: {
                Text(selectedRange.stepsEmptyStateDescription())
            }
        } else {
            ContentUnavailableView {
                Label("No Health Data", systemImage: "heart.text.square")
            } description: {
                Text("Update Apple Health permissions so your health metrics appear here.")
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

    private func prepareRangeCache() {
        let calendar = Calendar.autoupdatingCurrent
        let now = Date()
        let buildOrder = [TimeSeriesRangeFilter.month, .week, .sixMonths, .year, .all].filter { availableRanges.contains($0) }
        var cache = [TimeSeriesRangeFilter: CachedRangeData]()
        rangeCache = [:]

        for range in buildOrder {
            let layout = TimeSeriesChartLayout(rangeFilter: range, samples: stepSamples, now: now, calendar: calendar, aggregation: .average)
            let distanceLayout = TimeSeriesChartLayout(rangeFilter: range, samples: distanceSamples, now: now, calendar: calendar, aggregation: .average)
            let pointValues = layout.points.map(\.value)
            let visibleEntries = entries.filter { layout.currentDomain.contains($0.date) }
            let totalSteps = visibleEntries.reduce(0) { $0 + Double($1.stepCount) }
            let maximumValue = max(pointValues.max() ?? 0, 1)
            let yDomain = 0...(maximumValue * 1.15)
            let averageSteps = visibleEntries.isEmpty ? nil : (visibleEntries.reduce(0) { $0 + Double($1.stepCount) } / Double(visibleEntries.count))
            let highSteps = visibleEntries.map(\.stepCount).max().map(Double.init)
            cache[range] = CachedRangeData(layout: layout, distanceLayout: distanceLayout, yDomain: yDomain, totalSteps: pointValues.isEmpty ? nil : totalSteps, averageSteps: averageSteps, highSteps: highSteps)
            rangeCache = cache
        }
    }
}

#Preview {
    NavigationStack {
        StepsDistanceHistoryView()
            .sampleDataContainer()
    }
}
