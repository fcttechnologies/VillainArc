import SwiftUI
import SwiftData
import Charts

struct WeightHistoryView: View {
    private let router = AppRouter.shared
    
    @Query(WeightEntry.history, animation: .smooth) private var weightEntries: [WeightEntry]
    @Query(WeightGoal.active) private var activeGoals: [WeightGoal]
    @Query(WeightGoal.inactiveLatest) private var inactiveGoals: [WeightGoal]
    @Query(AppSettings.single) private var appSettings: [AppSettings]
    
    @State private var showAddWeightEntrySheet = false
    @State private var showNewWeightGoalSheet = false
    
    private var activeGoal: WeightGoal? {
        activeGoals.first
    }
    
    private var goalAnalysis: WeightGoalAnalysis? {
        guard let activeGoal else { return nil }
        return WeightGoalAnalysis(goal: activeGoal, entries: weightEntries)
    }
    
    private var hasGoalHistory: Bool {
        !inactiveGoals.isEmpty
    }

    private var weightUnit: WeightUnit {
        appSettings.first?.weightUnit ?? .systemDefault
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                WeightGoalSummaryCard(activeGoal: activeGoal, analysis: goalAnalysis, entries: weightEntries, weightUnit: weightUnit, hasGoalHistory: hasGoalHistory) {
                    Haptics.selection()
                    if activeGoal != nil || hasGoalHistory {
                        router.navigate(to: .weightGoalHistory)
                        Task { await IntentDonations.donateShowWeightGoalHistory() }
                    } else {
                        showNewWeightGoalSheet = true
                    }
                }
                
                WeightHistoryMainSection(entries: weightEntries, activeGoal: activeGoal, weightUnit: weightUnit) {
                    showAddWeightEntrySheet = true
                }
                
                Button {
                    Haptics.selection()
                    router.navigate(to: .allWeightEntriesList)
                    Task { await IntentDonations.donateShowAllWeightEntries() }
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct EntrySnapshot {
        let date: Date
        let weight: Double
    }

    private struct SummaryStat: Identifiable {
        let id: String
        let title: String
        let text: String
    }

    private struct CachedRangeData {
        let layout: TimeSeriesChartLayout
        let yDomain: ClosedRange<Double>
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
    @State private var selectedRange: TimeSeriesRangeFilter = .month
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
        return selectedTimeSeriesPoint(in: currentRangeData.layout.points, for: selectedDate)
    }

    private var headerDetailTitle: String? {
        if let selectedPoint, selectedPoint.sampleCount > 1 { return String(localized: "Entries") }
        return nil
    }

    private var headerDetailText: String? {
        if let selectedPoint, selectedPoint.sampleCount > 1 {
            return "\(selectedPoint.sampleCount)"
        }
        return nil
    }
    
    private var displayedDateText: String {
        if let selectedPoint {
            let baseText = selectedPointDateText(selectedPoint)
            if selectedPoint.sampleCount > 1 {
                return "\(baseText) • \(String(localized: "Average"))"
            }
            return baseText
        }
        guard let latestEntry else { return String(localized: "No entries in this range") }
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

    private var chartAccessibilityValue: String {
        let weightText = displayedWeightValue.map { "\($0.formatted(.number.precision(.fractionLength(0...1)))) \(weightUnit.unitLabel)" } ?? String(localized: "No weight data")
        return AccessibilityText.healthWeightHistoryChartValue(dateText: displayedDateText, weightText: weightText)
    }
    
    private var summaryStats: [SummaryStat] {
        guard selectedRange != .day else { return [] }
        guard let currentRangeData, currentRangeData.entryCount > 0 else { return [] }
        var stats = [SummaryStat(id: "change", title: String(localized: "Change"), text: changeText(for: currentRangeData))]
        if let trendText = trendText(for: currentRangeData) {
            stats.append(SummaryStat(id: "trend", title: String(localized: "Trend"), text: trendText))
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
                VStack(spacing: 0) {
                    HStack(alignment: .bottom) {
                        Text(displayedDateText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Spacer()
                        if let headerDetailTitle {
                            Text(headerDetailTitle)
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fontWeight(.semibold)
                    
                    HStack(alignment: .bottom) {
                        Group {
                            if let displayedWeightValue {
                                HStack(alignment: .lastTextBaseline, spacing: 4) {
                                    Text(displayedWeightValue, format: .number.precision(.fractionLength(0...1)))
                                    Text(weightUnit.unitLabel)
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                Text("-")
                            }
                        }
                        Spacer()
                        if let headerDetailText {
                            Text(headerDetailText)
                        }
                    }
                    .font(.largeTitle)
                    .bold()
                    .fontDesign(.rounded)
                }

                if let currentRangeData {
                    Chart {
                        if showsCurrentTargetLine, let targetWeightKg {
                            RuleMark(y: .value("Goal Target", targetWeightKg))
                                .foregroundStyle(Color.green.opacity(0.7))
                                .lineStyle(.init(lineWidth: 1.5, dash: [5, 4]))
                                .zIndex(-1)
                        }
                        ForEach(currentRangeData.layout.points) { point in
                            LineMark(x: .value("Date", point.date), y: .value("Weight", point.value), series: .value("Series", "Weight"))
                                .foregroundStyle(tint)
                                .interpolationMethod(.catmullRom)
                                .symbol(.circle)
                        }
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
                    .healthHistoryChartScaffold(selectedDate: $selectedDate, layout: currentRangeData.layout)
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
                    .overlay {
                        if currentRangeData.layout.points.isEmpty {
                            emptyStateView()
                        }
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.healthWeightHistoryChart)
                    .accessibilityLabel(AccessibilityText.healthWeightHistoryChartLabel)
                    .accessibilityValue(chartAccessibilityValue)

                    if let visibleRangeText, currentRangeData.entryCount > 0 {
                        VStack(spacing: 5) {
                            HStack {
                                if let averageWeightKg = currentRangeData.averageWeightKg {
                                    HealthHistoryMetadataValue(title: String(localized: "Avg"), text: formattedWeightText(averageWeightKg, unit: weightUnit, fractionDigits: 0...1), animationValue: weightUnit.fromKg(averageWeightKg))
                                }
                                Spacer()
                                if let lowWeightKg = currentRangeData.lowWeightKg {
                                    HealthHistoryMetadataValue(title: String(localized: "Low"), text: formattedWeightText(lowWeightKg, unit: weightUnit, fractionDigits: 0...1), animationValue: weightUnit.fromKg(lowWeightKg))
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
                                    HealthHistoryMetadataValue(title: String(localized: "High"), text: formattedWeightText(highWeightKg, unit: weightUnit, fractionDigits: 0...1), animationValue: weightUnit.fromKg(highWeightKg))
                                }
                            }
                        }
                    }
                } else {
                    ProgressView("Updating chart")
                        .frame(maxWidth: .infinity, minHeight: 260)
                }

                Picker("Range", selection: $selectedRange) {
                    ForEach(TimeSeriesRangeFilter.allCases) { range in
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
        .animation(reduceMotion ? nil : .smooth, value: latestEntry?.weight)
        .task(id: cacheSeed) {
            prepareRangeCache()
        }
    }
    
    private func selectedPointDateText(_ point: TimeSeriesBucketedPoint) -> String {
        timeSeriesBucketLabelText(for: point, bucketStyle: currentRangeData?.layout.bucketStyle ?? .day)
    }

    @ViewBuilder
    private func emptyStateView() -> some View {
        ContentUnavailableView {
            Label(AccessibilityText.healthWeightHistoryEmptyTitle, systemImage: "chart.line.uptrend.xyaxis")
        } description: {
            Text(AccessibilityText.healthWeightHistoryEmptyDescription(for: selectedRange))
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
        return String(localized: "\(sign)\(delta.formatted(.number.precision(.fractionLength(0...1)))) \(weightUnit.unitLabel)")
    }

    private func trendText(for data: CachedRangeData) -> String? {
        guard let trendKgPerWeek = data.trendKgPerWeek else { return nil }
        let pacePerWeek = weightUnit.fromKg(trendKgPerWeek)
        let direction = pacePerWeek > 0.05 ? String(localized: "Up") : pacePerWeek < -0.05 ? String(localized: "Down") : String(localized: "Flat")
        if direction == String(localized: "Flat") { return String(localized: "Flat") }
        return String(localized: "\(direction) \(formattedWeightPerWeekText(abs(trendKgPerWeek), unit: weightUnit, fractionDigits: 0...1))")
    }

    private func shouldShowTargetLine(in data: CachedRangeData, targetWeightKg: Double) -> Bool {
        guard !data.layout.points.isEmpty else { return false }
        let naturalSpan = data.yDomain.upperBound - data.yDomain.lowerBound
        guard naturalSpan > 0 else { return false }
        let expandedDomain = weightYDomain(for: data.layout.points.map(\.value) + [targetWeightKg])
        let expandedSpan = expandedDomain.upperBound - expandedDomain.lowerBound
        return expandedSpan <= naturalSpan * 1.4
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

    private static func trendKgPerWeek(from entries: [EntrySnapshot]) -> Double? {
        let smoothedPoints = smoothedDailyPoints(from: entries)
        guard smoothedPoints.count >= 2, let firstPoint = smoothedPoints.first, let lastPoint = smoothedPoints.last else { return nil }
        let spanDays = lastPoint.date.timeIntervalSince(firstPoint.date) / 86_400
        guard spanDays > 0 else { return nil }
        return ((lastPoint.value - firstPoint.value) / spanDays) * 7
    }

    private func buildRangeData(for range: TimeSeriesRangeFilter, samples: [TimeSeriesSample], entrySnapshots: [EntrySnapshot], now: Date, calendar: Calendar) -> CachedRangeData {
        let layout = TimeSeriesChartLayout(rangeFilter: range, samples: samples, now: now, calendar: calendar, aggregation: .average)
        let visibleEntries = entrySnapshots.filter { layout.currentDomain.contains($0.date) }.sorted { $0.date < $1.date }
        let averageWeightKg = visibleEntries.isEmpty ? nil : (visibleEntries.reduce(0) { $0 + $1.weight } / Double(visibleEntries.count))
        let changeKg = layout.points.count >= 2 ? (layout.points.last!.value - layout.points.first!.value) : nil
        let lowWeightKg = visibleEntries.map(\.weight).min()
        let highWeightKg = visibleEntries.map(\.weight).max()
        return CachedRangeData(layout: layout, yDomain: weightYDomain(for: layout.points.map(\.value)), averageWeightKg: averageWeightKg, entryCount: visibleEntries.count, changeKg: changeKg, trendKgPerWeek: Self.trendKgPerWeek(from: visibleEntries), lowWeightKg: lowWeightKg, highWeightKg: highWeightKg)
    }

    private func prepareRangeCache() {
        let samples = timeSeriesSamples
        let entrySnapshots = entrySnapshots
        let now = Date()
        let calendar = Calendar.autoupdatingCurrent
        progressivelyRebuildRangeCache(existing: rangeCache, buildOrder: [.month, .week, .day, .sixMonths, .year, .all], publish: { newCache in
            if rangeCache.isEmpty {
                rangeCache = newCache
            } else if reduceMotion {
                rangeCache = newCache
            } else {
                withAnimation(.smooth) { rangeCache = newCache }
            }
        }) { range in
            buildRangeData(for: range, samples: samples, entrySnapshots: entrySnapshots, now: now, calendar: calendar)
        }
    }
}

#Preview(traits: .sampleData) {
    NavigationStack {
        WeightHistoryView()
    }
}
