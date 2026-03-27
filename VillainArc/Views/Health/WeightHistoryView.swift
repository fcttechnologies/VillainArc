import SwiftUI
import SwiftData
import Charts

private extension TimeSeriesRangeFilter {
    func emptyStateDescription() -> String {
        switch self {
        case .week:
            return "No weight entries were recorded in the last 7 days."
        case .month:
            return "No weight entries were recorded in the last month."
        case .sixMonths:
            return "No weight entries were recorded in the last 6 months."
        case .year:
            return "No weight entries were recorded in the last year."
        case .all:
            return "No weight entries have been recorded yet."
        }
    }
}

struct WeightHistoryView: View {
    private let router = AppRouter.shared
    
    let weightUnit: WeightUnit
    @Query(WeightEntry.history, animation: .smooth) private var weightEntries: [WeightEntry]
    @Query(WeightGoal.active) private var activeGoals: [WeightGoal]
    @Query(WeightGoal.inactiveLatest) private var inactiveGoals: [WeightGoal]
    
    @State private var showAddWeightEntrySheet = false
    @State private var showNewWeightGoalSheet = false
    @State private var selectedRange: TimeSeriesRangeFilter = .month
    
    private var activeGoal: WeightGoal? {
        activeGoals.first
    }
    
    private var goalAnalysis: WeightGoalAnalysis? {
        guard let activeGoal else { return nil }
        return WeightGoalAnalysis(goal: activeGoal, entries: weightEntries)
    }
    
    private var availableRanges: [TimeSeriesRangeFilter] {
        TimeSeriesRangeFilter.allCases
    }
    
    private var hasGoalHistory: Bool {
        !inactiveGoals.isEmpty
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                WeightGoalSummaryCard(activeGoal: activeGoal, analysis: goalAnalysis, entries: weightEntries, weightUnit: weightUnit, hasGoalHistory: hasGoalHistory) {
                    Haptics.selection()
                    if activeGoal != nil || hasGoalHistory {
                        router.navigate(to: .weightGoalHistory(weightUnit))
                    } else {
                        showNewWeightGoalSheet = true
                    }
                }
                
                WeightHistoryMainSection(entries: weightEntries, activeGoal: activeGoal, weightUnit: weightUnit, selectedRange: $selectedRange, availableRanges: availableRanges) {
                    showAddWeightEntrySheet = true
                }
                
                Button {
                    Haptics.selection()
                    router.navigate(to: .allWeightEntriesList(weightUnit))
                } label: {
                    Text("View All Entries")
                        .fontWeight(.semibold)
                        .padding(.vertical, 6)
                        .font(.title3)
                }
                .buttonStyle(.glass)
                .buttonSizing(.flexible)
                .accessibilityIdentifier(AccessibilityIdentifiers.healthWeightHistoryAllEntriesLink)
                .accessibilityHint(AccessibilityText.healthWeightHistoryAllEntriesHint)
            }
            .padding()
        }
        .navigationTitle("Weight")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Haptics.selection()
                    showAddWeightEntrySheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                .accessibilityLabel(AccessibilityText.healthAddWeightEntryLabel)
                .accessibilityIdentifier(AccessibilityIdentifiers.healthAddWeightEntryButton)
                .accessibilityHint(AccessibilityText.healthAddWeightEntryHint)
            }
        }
        .sheet(isPresented: $showAddWeightEntrySheet) {
            NewWeightEntryView()
                .presentationDetents([.fraction(0.5)])
                .presentationBackground(Color(.systemBackground))
        }
        .sheet(isPresented: $showNewWeightGoalSheet) {
            NewWeightGoalView(weightUnit: weightUnit)
                .presentationDetents([.fraction(0.7), .large])
                .presentationBackground(Color(.systemBackground))
        }
    }
}

private struct WeightHistoryMainSection: View {
    private struct EntrySnapshot {
        let date: Date
        let weight: Double
    }

    private struct SummaryStat: Identifiable {
        let id: String
        let title: String
        let text: String
    }

    private enum MetadataAlignment {
        case leading
        case trailing
    }

    private struct CachedRangeData {
        let layout: TimeSeriesChartLayout
        let yDomain: ClosedRange<Double>
        let linePoints: [TimeSeriesBucketedPoint]
        let averageWeightKg: Double?
        let entryCount: Int
        let changeKg: Double?
        let trendKgPerWeek: Double?
        let lowWeightKg: Double?
        let highWeightKg: Double?
    }

    let entries: [WeightEntry]
    let activeGoal: WeightGoal?
    let weightUnit: WeightUnit
    @Binding var selectedRange: TimeSeriesRangeFilter
    let availableRanges: [TimeSeriesRangeFilter]
    let onAddEntry: () -> Void
    
    @State private var selectedDate: Date?
    @State private var rangeCache: [TimeSeriesRangeFilter: CachedRangeData] = [:]
    
    private let tint = Color.blue
    
    private var timeSeriesSamples: [TimeSeriesSample] {
        entries.map { TimeSeriesSample(id: $0.id, date: $0.date, value: $0.weight) }
    }

    private var entrySnapshots: [EntrySnapshot] {
        entries.map { EntrySnapshot(date: $0.date, weight: $0.weight) }
    }
    
    private var latestEntry: WeightEntry? {
        entries.first
    }

    private var currentRangeData: CachedRangeData? {
        rangeCache[selectedRange]
    }

    private var cacheSeed: Int {
        var hasher = Hasher()
        hasher.combine(entries.count)
        for entry in entries {
            hasher.combine(entry.id)
            hasher.combine(entry.date)
            hasher.combine(entry.weight.bitPattern)
        }
        return hasher.finalize()
    }
    
    private var selectedPoint: TimeSeriesBucketedPoint? {
        guard let currentRangeData else { return nil }
        guard let selectedDate else { return nil }
        return nearestPoint(in: currentRangeData.layout.points, to: selectedDate)
    }

    private var headerDetailTitle: String? {
        if let selectedPoint, selectedPoint.sampleCount > 1 { return "Entries" }
        return nil
    }

    private var headerDetailText: String? {
        if let selectedPoint, selectedPoint.sampleCount > 1 {
            return "\(selectedPoint.sampleCount)"
        }
        return nil
    }
    
    private var displayedDateText: String {
        if let selectedPoint { return selectedPointDateText(selectedPoint) }
        guard let latestEntry else { return "No entries in this range" }
        return formattedRecentDayAndTime(latestEntry.date)
    }

    private var visibleRangeText: String? {
        guard let currentRangeData else { return nil }
        return formattedAbsoluteDateRange(start: currentRangeData.layout.currentDomain.lowerBound, end: currentRangeData.layout.currentDomain.upperBound)
    }
    
    private var displayedWeightValue: Double? {
        if let selectedPoint { return weightUnit.fromKg(selectedPoint.value) }
        guard let latestEntry else { return nil }
        return weightUnit.fromKg(latestEntry.weight)
    }
    
    private var showsAverageContext: Bool {
        (selectedPoint?.sampleCount ?? 0) > 1
    }

    private var summaryStats: [SummaryStat] {
        guard let currentRangeData, currentRangeData.entryCount > 0 else { return [] }
        var stats = [SummaryStat(id: "change", title: "Change", text: changeText(for: currentRangeData))]
        if let trendText = trendText(for: currentRangeData) {
            stats.append(SummaryStat(id: "trend", title: "Trend", text: trendText))
        }
        return stats
    }

    private var targetWeightKg: Double? {
        activeGoal?.targetWeight
    }

    private var chartYDomain: ClosedRange<Double> {
        guard let currentRangeData else { return 0...1 }
        guard let targetWeightKg, shouldShowTargetLine(in: currentRangeData, targetWeightKg: targetWeightKg) else { return currentRangeData.yDomain }
        return weightYDomain(for: currentRangeData.layout.points.map(\.value) + [targetWeightKg])
    }

    private var showsCurrentTargetLine: Bool {
        guard let currentRangeData, let targetWeightKg else { return false }
        return shouldShowTargetLine(in: currentRangeData, targetWeightKg: targetWeightKg)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayedDateText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Group {
                            if let displayedWeightValue {
                                HStack(alignment: .lastTextBaseline, spacing: 4) {
                                    Text("\(displayedWeightValue, format: .number.precision(.fractionLength(0...1))) \(weightUnit.rawValue)")
                                    
                                    if showsAverageContext {
                                        Text("avg")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            } else {
                                Text("-")
                            }
                        }
                        .font(.largeTitle)
                        .bold()
                        .fontDesign(.rounded)
                    }
                    
                    Spacer()
                    
                    if let headerDetailTitle, let headerDetailText {
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(headerDetailTitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            Text(headerDetailText)
                                .font(.largeTitle)
                                .bold()
                                .fontDesign(.rounded)
                        }
                        .multilineTextAlignment(.trailing)
                        .accessibilityElement(children: .combine)
                    }
                }

                if let currentRangeData {
                    Chart {
                        targetRuleMark()
                        historyLineMarks(for: currentRangeData)
                        historyPointMarks(for: currentRangeData)
                        selectedPointMarks()
                    }
                    .chartLegend(.hidden)
                    .chartXSelection(value: $selectedDate)
                    .chartXScale(domain: currentRangeData.layout.currentDomain)
                    .chartYScale(domain: chartYDomain)
                    .chartYAxis {
                        AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let doubleValue = value.as(Double.self) {
                                    Text(formattedWeightValue(doubleValue, unit: weightUnit, fractionDigits: 0...1))
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
                                    Text(axisLabel(for: date, style: currentRangeData.layout.axisLabelStyle))
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

                    if let visibleRangeText, currentRangeData.entryCount > 0 {
                        VStack(spacing: 5) {
                            HStack {
                                if let averageWeightKg = currentRangeData.averageWeightKg {
                                    metadataWeightValue(title: "Avg", weightKg: averageWeightKg, alignment: .leading)
                                }
                                Spacer()
                                if let lowWeightKg = currentRangeData.lowWeightKg {
                                    metadataWeightValue(title: "Low", weightKg: lowWeightKg, alignment: .trailing)
                                }
                            }
                            
                            HStack {
                                Text(visibleRangeText)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .fontWeight(.semibold)
                                Spacer()
                                if let highWeightKg = currentRangeData.highWeightKg {
                                    metadataWeightValue(title: "High", weightKg: highWeightKg, alignment: .trailing)
                                }
                            }
                        }
                    }
                } else {
                    ProgressView("Updating chart")
                        .frame(maxWidth: .infinity, minHeight: 260)
                }

                Picker("Range", selection: $selectedRange) {
                    ForEach(availableRanges) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedRange) { Haptics.selection() }
            }
            .padding()
            .glassEffect(.regular, in: .rect(cornerRadius: 18))
            
            if !summaryStats.isEmpty {
                HStack(spacing: 10) {
                    ForEach(summaryStats) { stat in
                        SummaryStatCard(title: stat.title, text: stat.text)
                    }
                }
            }
        }
        .onChange(of: selectedRange) { selectedDate = nil }
        .task(id: cacheSeed) {
            prepareRangeCache()
        }
    }
    
    private func axisLabel(for date: Date, style: TimeSeriesAxisLabelStyle) -> String {
        timeSeriesAxisLabelText(for: date, style: style)
    }
    
    private func nearestPoint(in points: [TimeSeriesBucketedPoint], to date: Date) -> TimeSeriesBucketedPoint? {
        points.min { left, right in
            abs(left.date.timeIntervalSince(date)) < abs(right.date.timeIntervalSince(date))
        }
    }
    
    private func selectedPointDateText(_ point: TimeSeriesBucketedPoint) -> String {
        timeSeriesBucketLabelText(for: point, bucketStyle: currentRangeData?.layout.bucketStyle ?? .day)
    }

    @ChartContentBuilder
    private func targetRuleMark() -> some ChartContent {
        if showsCurrentTargetLine, let targetWeightKg {
            RuleMark(y: .value("Goal Target", targetWeightKg))
                .foregroundStyle(Color.green.opacity(0.7))
                .lineStyle(.init(lineWidth: 1.5, dash: [5, 4]))
        }
    }

    @ChartContentBuilder
    private func historyLineMarks(for data: CachedRangeData) -> some ChartContent {
        ForEach(data.linePoints) { point in
            LineMark(x: .value("Date", point.date), y: .value("Weight", point.value), series: .value("Series", "Weight"))
                .foregroundStyle(tint)
                .interpolationMethod(.catmullRom)
                .lineStyle(.init(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }

    @ChartContentBuilder
    private func historyPointMarks(for data: CachedRangeData) -> some ChartContent {
        if data.layout.points.count <= 60 {
            ForEach(data.layout.points) { point in
                PointMark(x: .value("Date", point.date), y: .value("Weight", point.value))
                    .foregroundStyle(tint.opacity(0.8))
                    .symbolSize(24)
            }
        }
    }

    @ChartContentBuilder
    private func selectedPointMarks() -> some ChartContent {
        if let selectedPoint {
            RuleMark(x: .value("Selected Date", selectedPoint.date))
                .foregroundStyle(tint)
                .lineStyle(.init(lineWidth: 1, dash: [4, 4]))
            
            PointMark(x: .value("Selected Date", selectedPoint.date), y: .value("Selected Weight", selectedPoint.value))
                .foregroundStyle(.white)
                .symbolSize(80)
            
            PointMark(x: .value("Selected Date", selectedPoint.date), y: .value("Selected Weight", selectedPoint.value))
                .foregroundStyle(tint)
                .symbolSize(36)
        }
    }

    @ViewBuilder
    private func emptyStateView() -> some View {
        ContentUnavailableView {
            Label("No Weight Entries", systemImage: "chart.line.uptrend.xyaxis")
        } description: {
            Text(selectedRange.emptyStateDescription())
        } actions: {
            Button("Log Weight") {
                Haptics.selection()
                onAddEntry()
            }
        }
    }

    private func changeText(for data: CachedRangeData) -> String {
        let delta = weightUnit.fromKg(data.changeKg ?? 0)
        let sign = delta > 0 ? "+" : ""
        return "\(sign)\(delta.formatted(.number.precision(.fractionLength(0...1)))) \(weightUnit.rawValue)"
    }

    @ViewBuilder
    private func metadataWeightValue(title: String, weightKg: Double, alignment: MetadataAlignment) -> some View {
        let displayedWeight = weightUnit.fromKg(weightKg)
        HStack(spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("\(displayedWeight, format: .number.precision(.fractionLength(0...1))) \(weightUnit.rawValue)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .fontDesign(.rounded)
                .monospacedDigit()
                .contentTransition(.numericText(value: displayedWeight))
        }
        .animation(.smooth, value: displayedWeight)
        .accessibilityElement(children: .combine)
    }

    private func trendText(for data: CachedRangeData) -> String? {
        guard let trendKgPerWeek = data.trendKgPerWeek else { return nil }
        let pacePerWeek = weightUnit.fromKg(trendKgPerWeek)
        let direction = pacePerWeek > 0.05 ? "Up" : pacePerWeek < -0.05 ? "Down" : "Flat"
        if direction == "Flat" { return "Flat" }
        return "\(direction) \(abs(pacePerWeek).formatted(.number.precision(.fractionLength(0...1)))) \(weightUnit.rawValue)/wk"
    }

    private func shouldShowTargetLine(in data: CachedRangeData, targetWeightKg: Double) -> Bool {
        guard !data.layout.points.isEmpty else { return false }
        let naturalSpan = data.yDomain.upperBound - data.yDomain.lowerBound
        guard naturalSpan > 0 else { return false }
        let expandedDomain = weightYDomain(for: data.layout.points.map(\.value) + [targetWeightKg])
        let expandedSpan = expandedDomain.upperBound - expandedDomain.lowerBound
        return expandedSpan <= naturalSpan * 1.3
    }

    private static func smoothedDailyPoints(from entries: [EntrySnapshot]) -> [TimeSeriesSample] {
        let calendar = Calendar.autoupdatingCurrent
        let buckets = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.date) }
        let sortedDates: [Date] = buckets.keys.sorted(by: <)
        let dailyPoints: [TimeSeriesSample] = sortedDates.map { date in
            let bucketEntries = buckets[date] ?? []
            let averageWeight = bucketEntries.reduce(0) { $0 + $1.weight } / Double(bucketEntries.count)
            return TimeSeriesSample(date: date, value: averageWeight)
        }
        let windowSize = Swift.min(5, dailyPoints.count)
        guard windowSize > 1 else { return dailyPoints }
        return dailyPoints.indices.map { index in
            let lowerBound = index >= windowSize ? (index - windowSize + 1) : 0
            let window = dailyPoints[lowerBound...index]
            let averageWeight = window.reduce(0) { $0 + $1.value } / Double(window.count)
            return TimeSeriesSample(date: dailyPoints[index].date, value: averageWeight)
        }
    }

    private func prepareRangeCache() {
        let samples = timeSeriesSamples
        let entrySnapshots = entrySnapshots
        let ranges = availableRanges
        let now = Date()
        let calendar = Calendar.autoupdatingCurrent
        let cache = Dictionary(uniqueKeysWithValues: ranges.map { range in
            let layout = TimeSeriesChartLayout(rangeFilter: range, samples: samples, now: now, calendar: calendar, aggregation: .average)
            let visibleEntries = entrySnapshots.filter { layout.currentDomain.contains($0.date) }.sorted { $0.date < $1.date }
            let averageWeightKg = visibleEntries.isEmpty ? nil : (visibleEntries.reduce(0) { $0 + $1.weight } / Double(visibleEntries.count))
            let changeKg = layout.points.count >= 2 ? (layout.points.last!.value - layout.points.first!.value) : nil
            let smoothedPoints = Self.smoothedDailyPoints(from: visibleEntries)
            let trendKgPerWeek: Double?
            if smoothedPoints.count >= 2, let firstPoint = smoothedPoints.first, let lastPoint = smoothedPoints.last {
                let spanDays = lastPoint.date.timeIntervalSince(firstPoint.date) / 86_400
                trendKgPerWeek = spanDays > 0 ? (((lastPoint.value - firstPoint.value) / spanDays) * 7) : nil
            } else {
                trendKgPerWeek = nil
            }
            let lowWeightKg = visibleEntries.map(\.weight).min()
            let highWeightKg = visibleEntries.map(\.weight).max()
            let data = CachedRangeData(layout: layout, yDomain: weightYDomain(for: layout.points.map(\.value)), linePoints: timeSeriesAnchoredLinePoints(points: layout.points, samples: samples, domain: layout.currentDomain), averageWeightKg: averageWeightKg, entryCount: visibleEntries.count, changeKg: changeKg, trendKgPerWeek: trendKgPerWeek, lowWeightKg: lowWeightKg, highWeightKg: highWeightKg)
            return (range, data)
        })
        rangeCache = cache
    }
}

#Preview {
    NavigationStack {
        WeightHistoryView(weightUnit: .lbs)
    }
    .sampleDataContainer()
}
