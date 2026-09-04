import FCTMetrics
import Charts
import SwiftData
import SwiftUI

private enum HydrationChartSegmentKind: String, Sendable {
    case logged
    case remaining
    case overGoal
}

private struct HydrationChartSegment: Identifiable, Sendable {
    let id: String
    let date: Date
    let startDate: Date
    let endDate: Date
    let sampleCount: Int
    let kind: HydrationChartSegmentKind
    let value: Double
}

private func hydrationChartSegments(for total: HydrationDailyTotal, startDate: Date? = nil, endDate: Date? = nil, sampleCount: Int = 1) -> [HydrationChartSegment] {
    let startDate = startDate ?? total.date
    let endDate = endDate ?? total.date
    let baseID = startDate.timeIntervalSinceReferenceDate
    let loggedValue = min(total.totalVolume, total.goalVolume)
    let remainingValue = total.remainingVolume
    let overGoalValue = total.overGoalVolume
    var segments: [HydrationChartSegment] = []

    if loggedValue > 0 {
        segments.append(.init(id: "\(baseID)-logged", date: total.date, startDate: startDate, endDate: endDate, sampleCount: sampleCount, kind: .logged, value: loggedValue))
    }

    if remainingValue > 0 {
        segments.append(.init(id: "\(baseID)-remaining", date: total.date, startDate: startDate, endDate: endDate, sampleCount: sampleCount, kind: .remaining, value: remainingValue))
    }

    if overGoalValue > 0 {
        segments.append(.init(id: "\(baseID)-over-goal", date: total.date, startDate: startDate, endDate: endDate, sampleCount: sampleCount, kind: .overGoal, value: overGoalValue))
    }

    if segments.isEmpty {
        segments.append(.init(id: "\(baseID)-remaining", date: total.date, startDate: startDate, endDate: endDate, sampleCount: sampleCount, kind: .remaining, value: total.goalVolume))
    }

    return segments
}

private func hydrationVolumeText(_ ml: Double, unit: HydrationUnit = .ml) -> String {
    let converted = unit.fromML(ml)
    switch unit {
    case .ml:
        return Int(converted.rounded()).formatted(.number)
    case .flOz:
        return converted.formatted(.number.precision(.fractionLength(0...1)))
    }
}

struct HealthHydrationSectionCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let router = AppRouter.shared
    @Query(HydrationEntry.last7Days(), animation: .smooth) private var entries: [HydrationEntry]
    @Query(HydrationGoal.active) private var activeGoals: [HydrationGoal]
    @Query(AppSettings.single) private var appSettings: [AppSettings]

    private var hydrationUnit: HydrationUnit { appSettings.first?.hydrationUnit ?? .systemDefault }
    private var dailyGoalML: Double { activeGoals.first?.targetML ?? 3000 }
    private var todayTotal: HydrationDailyTotal { HydrationEntry.todayTotal(from: entries, goalML: dailyGoalML) }
    private var summaryTotals: [HydrationDailyTotal] { HydrationEntry.dailyTotals(from: entries, goalML: dailyGoalML) }
    private var chartSegments: [HydrationChartSegment] {
        summaryTotals.flatMap { hydrationChartSegments(for: $0) }
    }

    var body: some View {
        Button {
            router.push(to: .hydrationHistory)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 3) {
                    Image(systemName: "drop.fill")
                        .font(.subheadline)
                        .foregroundStyle(.blue.gradient)
                    Text("Hydration")
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue.gradient)

                    Spacer()

                    Text("Today")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(alignment: .lastTextBaseline, spacing: 2) {
                            Text(hydrationVolumeText(todayTotal.totalVolume, unit: hydrationUnit))
                                .font(.largeTitle)
                                .bold()
                                .contentTransition(.numericText(value: todayTotal.totalVolume))
                            Text(hydrationUnit.unitLabel)
                                .font(.title2)
                                .foregroundStyle(.secondary)
                                .fontWeight(.semibold)
                        }
                        .lineLimit(1)
                    }
                    .fontDesign(.rounded)

                    Spacer()

                    HealthHydrationSparkBarChart(segments: chartSegments, tint: .blue)
                        .frame(width: 160, height: 80)
                        .accessibilityHidden(true)
                }
                .animation(reduceMotion ? nil : .smooth, value: todayTotal.totalVolume)
            }
            .padding()
            .appCardStyle()
            .tint(.primary)
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier(AccessibilityIdentifiers.healthHydrationSectionCard)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Hydration today \(hydrationVolumeText(todayTotal.totalVolume, unit: hydrationUnit)) \(hydrationUnit.unitLabel)."))
    }
}

private struct HealthHydrationSparkBarChart: View {
    let segments: [HydrationChartSegment]
    let tint: Color

    private var latestDate: Date? { segments.map(\.date).max() }

    private var yDomain: ClosedRange<Double> {
        let totalsByDate = Dictionary(grouping: segments, by: \.date)
            .mapValues { $0.reduce(0) { $0 + $1.value } }
        return 0...(max(totalsByDate.values.max() ?? 0, 1) * 1.15)
    }

    var body: some View {
        Chart(segments) { segment in
            BarMark(x: .value("Date", segment.date, unit: .day), y: .value(segment.kind.rawValue, segment.value), width: .ratio(0.92))
                .foregroundStyle(barStyle(for: segment))
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: segment.kind == .remaining || segment.kind == .overGoal ? 4 : 1, topTrailingRadius: segment.kind == .remaining || segment.kind == .overGoal ? 4 : 1))
        }
        .chartYScale(domain: yDomain)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
    }

    private func barStyle(for segment: HydrationChartSegment) -> AnyShapeStyle {
        let isLatest = segment.date == latestDate
        switch segment.kind {
        case .logged:
            return isLatest ? AnyShapeStyle(tint.gradient) : AnyShapeStyle(tint.opacity(0.35).gradient)
        case .remaining:
            return isLatest ? AnyShapeStyle(tint.opacity(0.18).gradient) : AnyShapeStyle(tint.opacity(0.08).gradient)
        case .overGoal:
            return isLatest ? AnyShapeStyle(Color.cyan.gradient) : AnyShapeStyle(Color.cyan.opacity(0.35).gradient)
        }
    }
}

struct HealthHydrationHistoryView: View {
    private let router = AppRouter.shared
    @Query(HydrationEntry.history, animation: .smooth) private var entries: [HydrationEntry]
    @Query(HydrationGoal.active) private var activeGoals: [HydrationGoal]
    @Query(HydrationGoal.history) private var goals: [HydrationGoal]
    @Query(AppSettings.single) private var appSettings: [AppSettings]
    private var hydrationUnit: HydrationUnit { appSettings.first?.hydrationUnit ?? .systemDefault }
    private var activeGoal: HydrationGoal? { activeGoals.first }
    private var dailyGoalML: Double { activeGoal?.targetML ?? 3000 }
    private var hasGoalHistory: Bool { !goals.filter { $0.endedOnDay != nil }.isEmpty }

    private var todayTotal: HydrationDailyTotal {
        HydrationEntry.todayTotal(from: entries, goalML: dailyGoalML)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if activeGoal != nil || hasGoalHistory {
                    HydrationGoalSummaryCard(activeGoal: activeGoal, todayTotal: todayTotal, hasGoalHistory: hasGoalHistory, hydrationUnit: hydrationUnit) {
                        router.push(to: .hydrationGoalHistory)
                    }
                    .padding(.horizontal)
                }

                HealthHydrationMainChartSection(entries: entries, dailyGoalML: dailyGoalML, hydrationUnit: hydrationUnit)
                    .padding()
            }
        }
        .quickActionContentBottomInset()
        .appBackground()
        .navigationTitle("Hydration")
        .toolbarTitleDisplayMode(.inline)
        .diagScreen(VACrumb.healthHydrationHistory)
    }
}

private struct HealthHydrationCachedRangeData {
    let layout: TimeSeriesChartLayout
    let chartSegments: [HydrationChartSegment]
    let yDomain: ClosedRange<Double>
    let averageVolume: Double?
}

private struct HealthHydrationMainChartSection: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(HydrationGoal.active) private var activeGoals: [HydrationGoal]
    @State private var selectedRange: TimeSeriesRangeFilter = .month
    @State private var selectedDate: Date?
    @State private var rangeCache: [TimeSeriesRangeFilter: HealthHydrationCachedRangeData] = [:]
    private let router = AppRouter.shared

    let entries: [HydrationEntry]
    let dailyGoalML: Double
    let hydrationUnit: HydrationUnit

    private var activeGoal: HydrationGoal? { activeGoals.first }

    private let tint = Color.blue
    private let sampleNamespace: UInt64 = 0x4859445241544501

    private var dailyTotals: [HydrationDailyTotal] {
        HydrationEntry.dailyTotals(from: entries, goalML: dailyGoalML)
    }

    private var samples: [TimeSeriesSample] {
        dailyTotals.map { TimeSeriesSample(id: stableTimeSeriesSampleID(namespace: sampleNamespace, date: $0.date), date: $0.date, value: $0.totalVolume) }
    }

    private var latestTotal: HydrationDailyTotal {
        HydrationEntry.todayTotal(from: entries, goalML: dailyGoalML)
    }

    private var hasAnyData: Bool {
        !entries.isEmpty
    }

    private var currentRangeData: HealthHydrationCachedRangeData? {
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
        return String(localized: "Today")
    }

    private var displayedVolume: Double {
        selectedPoint?.value ?? latestTotal.totalVolume
    }

    private var displayedGoal: Double {
        latestTotal.goalVolume
    }

    private var visibleRangeText: String? {
        guard let currentRangeData else { return nil }
        return formattedAbsoluteDateRange(start: currentRangeData.layout.currentDomain.lowerBound, end: currentRangeData.layout.currentDomain.upperBound)
    }

    private var cacheKey: Int {
        var hasher = Hasher()
        hasher.combine(entries.count)
        hasher.combine(dailyGoalML.bitPattern)
        for entry in entries {
            hasher.combine(entry.date)
            hasher.combine(entry.volume.bitPattern)
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

                    ForEach(currentRangeData.chartSegments) { segment in
                        BarMark(x: .value("Date", segment.startDate, unit: chartCalendarComponent(for: currentRangeData.layout.bucketStyle)), y: .value(segment.kind.rawValue, segment.value), width: .ratio(0.92))
                            .foregroundStyle(barStyle(for: segment))
                            .opacity(selectedPoint == nil || (selectedPoint?.startDate == segment.startDate && selectedPoint?.endDate == segment.endDate) ? 1 : 0.5)
                            .clipShape(UnevenRoundedRectangle(topLeadingRadius: segment.kind == .remaining || segment.kind == .overGoal ? 4 : 1, topTrailingRadius: segment.kind == .remaining || segment.kind == .overGoal ? 4 : 1))
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
                        emptyStateView
                    }
                }

                if let visibleRangeText, !currentRangeData.layout.points.isEmpty {
                    HStack(alignment: .bottom) {
                        Text(visibleRangeText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .fontWeight(.semibold)
                        Spacer()
                        if let averageVolume = currentRangeData.averageVolume {
                            HealthHistoryMetadataValue(title: String(localized: "Avg"), text: hydrationVolumeText(averageVolume, unit: hydrationUnit), animationValue: averageVolume)
                        }
                    }
                }
            } else {
                ProgressView("Updating chart")
                    .frame(maxWidth: .infinity, minHeight: 260)
            }

            Picker("Range", selection: $selectedRange.animation(reduceMotion ? nil : .easeInOut)) {
                ForEach(TimeSeriesRangeFilter.nonDayCases) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier(AccessibilityIdentifiers.healthHydrationHistoryRangePicker)
            .onChange(of: selectedRange) { Haptics.selection() }
        }
        .padding()
        .appCardStyle()
        .animation(reduceMotion ? nil : .smooth, value: displayedVolume)
        .onChange(of: selectedRange) { selectedDate = nil }
        .task(id: cacheKey) {
            prepareRangeCache()
        }
    }

    private var goalAccessibilityLabel: String {
        if let activeGoal {
            return String(localized: "Hydration goal \(hydrationVolumeText(activeGoal.targetML, unit: hydrationUnit)) \(hydrationUnit.unitLabel). Opens goal history.")
        }
        return String(localized: "Hydration goal not set. Opens goal editor.")
    }

    private func handleGoalTap() {
        Haptics.selection()
        if activeGoal == nil {
            router.presentHealthSheet(.newHydrationGoal)
        } else {
            router.push(to: .hydrationGoalHistory)
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom) {
                Text(displayedDateText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
                Text("Goal")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fontWeight(.semibold)

            HStack(alignment: .center) {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(hydrationVolumeText(displayedVolume, unit: hydrationUnit))
                    Text(hydrationUnit.unitLabel)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .font(.largeTitle)
                Spacer()
                Button(action: handleGoalTap) {
                    Group {
                        if let activeGoal {
                            HStack(alignment: .lastTextBaseline, spacing: 4) {
                                Text(hydrationVolumeText(activeGoal.targetML, unit: hydrationUnit))
                                Text(hydrationUnit.unitLabel)
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text("Not Set")
                        }
                    }
                    .font(.title2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(goalAccessibilityLabel)
                .accessibilityIdentifier(AccessibilityIdentifiers.healthHydrationGoalButton)
            }
            .bold()
            .fontDesign(.rounded)
        }
    }

    private var emptyStateView: some View {
        Group {
            // Device-sourced, so this is not an account claim and never waits on a first pull: the
            // Apple Health mirror is read from HealthKit on this phone and never travels on the wire,
            // so its emptiness is already true at the moment it renders. The goals set over these
            // metrics do sync, and those empty states are wrapped in `RestoringEmptyState`.
            if hasAnyData {
                ContentUnavailableView("No Data", systemImage: "drop.fill", description: Text("No hydration entries are in this range."))
            } else {
                ContentUnavailableView("No Hydration Data", systemImage: "drop.fill", description: Text("Water entries will appear here after you add or sync them."))
            }
        }
    }

    private func prepareRangeCache() {
        let samples = samples
        let now = Date()
        let calendar = Calendar.autoupdatingCurrent
        let goal = max(dailyGoalML, 1)
        progressivelyRebuildRangeCache(existing: rangeCache, buildOrder: [.month, .week, .sixMonths, .year, .all], publish: { newCache in
            if rangeCache.isEmpty || reduceMotion {
                rangeCache = newCache
            } else {
                withAnimation(.smooth) { rangeCache = newCache }
            }
        }) { range in
            let layout = TimeSeriesChartLayout(rangeFilter: range, samples: samples, now: now, calendar: calendar, aggregation: .average)
            let chartSegments = layout.points.flatMap { point in
                hydrationChartSegments(for: HydrationDailyTotal(date: point.date, totalVolume: point.value, goalVolume: goal), startDate: point.startDate, endDate: point.endDate, sampleCount: point.sampleCount)
            }
            let maxValue = max(layout.points.map(\.value).max() ?? 0, goal)
            let averageVolume = layout.points.isEmpty ? nil : layout.points.reduce(0) { $0 + $1.value } / Double(layout.points.count)
            return HealthHydrationCachedRangeData(layout: layout, chartSegments: chartSegments, yDomain: 0...(max(maxValue, 1) * 1.15), averageVolume: averageVolume)
        }
    }

    private func barStyle(for segment: HydrationChartSegment) -> AnyShapeStyle {
        switch segment.kind {
        case .logged:
            return AnyShapeStyle(tint.gradient)
        case .remaining:
            return AnyShapeStyle(tint.opacity(0.18).gradient)
        case .overGoal:
            return AnyShapeStyle(Color.cyan.gradient)
        }
    }
}

#Preview(traits: .sampleData) {
    HealthHydrationSectionCard()
}
