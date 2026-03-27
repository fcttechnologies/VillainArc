import SwiftUI
import SwiftData
import Charts

private extension TimeSeriesRangeFilter {
    func energyEmptyStateDescription() -> String {
        switch self {
        case .week:
            return String(localized: "No energy data was recorded in the last 7 days.")
        case .month:
            return String(localized: "No energy data was recorded in the last month.")
        case .sixMonths:
            return String(localized: "No energy data was recorded in the last 6 months.")
        case .year:
            return String(localized: "No energy data was recorded in the last year.")
        case .all:
            return String(localized: "No energy data has been recorded yet.")
        }
    }
}

struct HealthEnergyHistoryView: View {
    @Query(HealthEnergy.history, animation: .smooth) private var entries: [HealthEnergy]

    @State private var selectedRange: TimeSeriesRangeFilter = .month

    private var availableRanges: [TimeSeriesRangeFilter] {
        TimeSeriesRangeFilter.allCases
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HealthEnergyHistoryMainSection(entries: entries, selectedRange: $selectedRange, availableRanges: availableRanges)
            }
            .padding()
        }
        .navigationTitle("Energy")
        .toolbarTitleDisplayMode(.inline)
    }
}

private struct HealthEnergyHistoryMainSection: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct CachedRangeData {
        let totalLayout: TimeSeriesChartLayout
        let activeLayout: TimeSeriesChartLayout
        let yDomain: ClosedRange<Double>
        let averageTotalEnergy: Double?
        let averageActiveEnergy: Double?
        let highActiveEnergy: Double?
    }

    private enum MetadataAlignment {
        case leading
        case trailing
    }

    let entries: [HealthEnergy]
    @Binding var selectedRange: TimeSeriesRangeFilter
    let availableRanges: [TimeSeriesRangeFilter]

    @State private var selectedDate: Date?
    @State private var rangeCache: [TimeSeriesRangeFilter: CachedRangeData] = [:]

    private let tint = Color.orange

    private var totalEnergySamples: [TimeSeriesSample] {
        entries.map { TimeSeriesSample(id: UUID(), date: $0.date, value: $0.totalEnergyBurned) }
    }

    private var activeEnergySamples: [TimeSeriesSample] {
        entries.map { TimeSeriesSample(id: UUID(), date: $0.date, value: $0.activeEnergyBurned) }
    }

    private var latestEntry: HealthEnergy? {
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
            hasher.combine(entry.activeEnergyBurned.bitPattern)
            hasher.combine(entry.restingEnergyBurned.bitPattern)
        }
        return hasher.finalize()
    }

    private var selectedTotalPoint: TimeSeriesBucketedPoint? {
        guard let currentRangeData, let selectedDate else { return nil }
        return nearestPoint(in: currentRangeData.totalLayout.points, to: selectedDate)
    }

    private var selectedActivePoint: TimeSeriesBucketedPoint? {
        guard let currentRangeData, let selectedTotalPoint else { return nil }
        return currentRangeData.activeLayout.points.first { $0.startDate == selectedTotalPoint.startDate && $0.endDate == selectedTotalPoint.endDate }
    }

    private var displayedDateText: String {
        if let selectedTotalPoint {
            let baseText = timeSeriesBucketLabelText(for: selectedTotalPoint, bucketStyle: currentRangeData?.totalLayout.bucketStyle ?? .day)
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
        if selectedTotalPoint != nil { return selectedActivePoint?.value ?? 0 }
        return latestEntry?.activeEnergyBurned
    }

    private var visibleRangeText: String? {
        guard let currentRangeData else { return nil }
        return formattedAbsoluteDateRange(start: currentRangeData.totalLayout.currentDomain.lowerBound, end: currentRangeData.totalLayout.currentDomain.upperBound)
    }

    private var chartAccessibilityValue: String {
        let dateText = displayedDateText
        let totalText = displayedTotalEnergy.map { "\(Int($0.rounded()).formatted(.number)) \(String(localized: "total calories"))" } ?? String(localized: "No total energy data")
        let activeText = displayedActiveEnergy.map { "\(Int($0.rounded()).formatted(.number)) \(String(localized: "active calories"))" } ?? String(localized: "No active energy data")
        return AccessibilityText.healthEnergyHistoryChartValue(dateText: dateText, totalText: totalText, activeText: activeText)
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
                        Text("Active")
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
                        
                        Group {
                            if let displayedActiveEnergy {
                                Text("\(Int(displayedActiveEnergy.rounded()).formatted(.number)) cal")
                            } else {
                                Text("-")
                            }
                        }
                        .font(.title)
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
                        }

                        ForEach(currentRangeData.totalLayout.points) { point in
                            BarMark(x: .value("Date", point.startDate, unit: chartCalendarComponent(for: currentRangeData.totalLayout.bucketStyle)), y: .value("Total Energy", point.value), width: .ratio(0.92))
                                .foregroundStyle(.orange.opacity(0.22).gradient)
                                .opacity(selectedTotalPoint == nil || selectedTotalPoint?.id == point.id ? 1 : 0.5)
                        }

                        ForEach(currentRangeData.activeLayout.points) { point in
                            BarMark(x: .value("Date", point.startDate, unit: chartCalendarComponent(for: currentRangeData.activeLayout.bucketStyle)), yStart: .value("Baseline", 0), yEnd: .value("Active Energy", point.value), width: .ratio(0.92))
                                .foregroundStyle(tint.gradient)
                                .opacity(selectedTotalPoint == nil || selectedTotalPoint?.startDate == point.startDate ? 1 : 0.5)
                        }
                    }
                    .chartLegend(.hidden)
                    .chartXSelection(value: $selectedDate)
                    .chartXScale(domain: currentRangeData.totalLayout.currentDomain)
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
                        AxisMarks(values: currentRangeData.totalLayout.axisDates) { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel {
                                if let date = value.as(Date.self) {
                                    Text(timeSeriesAxisLabelText(for: date, style: currentRangeData.totalLayout.axisLabelStyle))
                                }
                            }
                        }
                    }
                    .overlay {
                        if currentRangeData.totalLayout.points.isEmpty {
                            emptyStateView()
                        }
                    }
                    .frame(height: 260)
                    .accessibilityIdentifier(AccessibilityIdentifiers.healthEnergyHistoryChart)
                    .accessibilityLabel(AccessibilityText.healthEnergyHistoryChartLabel)
                    .accessibilityValue(chartAccessibilityValue)

                    if let visibleRangeText, !currentRangeData.totalLayout.points.isEmpty {
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

                Picker("Range", selection: $selectedRange) {
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
                Label("No Energy Data", systemImage: "flame.fill")
            } description: {
                Text(selectedRange.energyEmptyStateDescription())
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

    private func prepareRangeCache() {
        let calendar = Calendar.autoupdatingCurrent
        let now = Date()
        let buildOrder = [TimeSeriesRangeFilter.month, .week, .sixMonths, .year, .all].filter { availableRanges.contains($0) }
        var cache = [TimeSeriesRangeFilter: CachedRangeData]()
        rangeCache = [:]

        for range in buildOrder {
            let totalLayout = TimeSeriesChartLayout(rangeFilter: range, samples: totalEnergySamples, now: now, calendar: calendar, aggregation: .average)
            let activeLayout = TimeSeriesChartLayout(rangeFilter: range, samples: activeEnergySamples, now: now, calendar: calendar, aggregation: .average)
            let totalValues = totalLayout.points.map(\.value)
            let visibleEntries = entries.filter { totalLayout.currentDomain.contains($0.date) }
            let maximumValue = max(totalValues.max() ?? 0, 1)
            let yDomain = 0...(maximumValue * 1.15)
            let averageTotalEnergy = visibleEntries.isEmpty ? nil : (visibleEntries.reduce(0) { $0 + $1.totalEnergyBurned } / Double(visibleEntries.count))
            let averageActiveEnergy = visibleEntries.isEmpty ? nil : (visibleEntries.reduce(0) { $0 + $1.activeEnergyBurned } / Double(visibleEntries.count))
            let highActiveEnergy = visibleEntries.map(\.activeEnergyBurned).max()
            cache[range] = CachedRangeData(totalLayout: totalLayout, activeLayout: activeLayout, yDomain: yDomain, averageTotalEnergy: averageTotalEnergy, averageActiveEnergy: averageActiveEnergy, highActiveEnergy: highActiveEnergy)
            rangeCache = cache
        }
    }
}

#Preview {
    NavigationStack {
        HealthEnergyHistoryView()
            .sampleDataContainer()
    }
}
