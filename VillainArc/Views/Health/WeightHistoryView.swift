import SwiftUI
import SwiftData
import Charts

fileprivate enum WeightHistoryRangeFilter: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"
    case year = "Year"
    case all = "All"

    var id: String { rawValue }

    func includes(_ date: Date, now: Date, calendar: Calendar) -> Bool {
        switch self {
        case .week:
            guard let lowerBound = calendar.date(byAdding: .day, value: -7, to: now) else { return true }
            return date >= lowerBound
        case .month:
            guard let lowerBound = calendar.date(byAdding: .month, value: -1, to: now) else { return true }
            return date >= lowerBound
        case .year:
            guard let lowerBound = calendar.date(byAdding: .year, value: -1, to: now) else { return true }
            return date >= lowerBound
        case .all:
            return true
        }
    }

    var emptyStateDescription: String {
        switch self {
        case .week:
            return "No weight entries were recorded in the last 7 days."
        case .month:
            return "No weight entries were recorded in the last month."
        case .year:
            return "No weight entries were recorded in the last year."
        case .all:
            return "No weight entries have been recorded yet."
        }
    }
}

struct WeightHistoryView: View {
    let weightUnit: WeightUnit

    @Query(WeightEntry.history) private var weightEntries: [WeightEntry]

    @State private var selectedRange: WeightHistoryRangeFilter = .month
    @State private var selectedDate: Date?

    private var filteredEntries: [WeightEntry] {
        let now = Date()
        let calendar = Calendar.current
        return weightEntries.filter { selectedRange.includes($0.recordedAt, now: now, calendar: calendar) }
    }

    private var chartPoints: [WeightChartPoint] {
        filteredEntries.reversed().map(WeightChartPoint.init)
    }

    private var latestOverallEntry: WeightEntry? {
        weightEntries.first
    }

    private var displayedEntry: WeightEntry? {
        if let selectedPoint {
            return filteredEntries.first { $0.id == selectedPoint.id }
        }

        return latestOverallEntry
    }

    private var selectedPoint: WeightChartPoint? {
        guard let selectedDate else { return nil }
        return nearestPoint(to: selectedDate)
    }

    var body: some View {
        ScrollView {
            if weightEntries.isEmpty {
                ContentUnavailableView("No Weight Entries Yet", systemImage: "scalemass", description: Text("Weight history will appear here once you add or sync body weight entries."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
            } else {
                VStack(alignment: .leading, spacing: 24) {
                    WeightHistoryMainSection(
                        displayedEntry: displayedEntry,
                        points: chartPoints,
                        selectedDate: $selectedDate,
                        weightUnit: weightUnit,
                        selectedRange: $selectedRange
                    )

                    // Future section goes here.
                }
                .padding()
            }
        }
        .navigationTitle("Weight")
        .toolbarTitleDisplayMode(.inline)
        .onChange(of: selectedRange) { _, _ in
            selectedDate = nil
        }
        .onChange(of: chartPoints) { _, newPoints in
            guard let selectedDate else { return }
            self.selectedDate = nearestPoint(in: newPoints, to: selectedDate)?.date
        }
    }

    private func nearestPoint(to date: Date) -> WeightChartPoint? {
        nearestPoint(in: chartPoints, to: date)
    }

    private func nearestPoint(in points: [WeightChartPoint], to date: Date) -> WeightChartPoint? {
        points.min { left, right in
            abs(left.date.timeIntervalSince(date)) < abs(right.date.timeIntervalSince(date))
        }
    }
}

private struct WeightHistoryMainSection: View {
    let displayedEntry: WeightEntry?
    let points: [WeightChartPoint]
    @Binding var selectedDate: Date?
    let weightUnit: WeightUnit
    @Binding var selectedRange: WeightHistoryRangeFilter

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(displayedDateText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(displayedWeightText)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .fontDesign(.rounded)
                    .foregroundStyle(.primary)
            }

            Group {
                if points.isEmpty {
                    ContentUnavailableView("No Weight Entries", systemImage: "chart.line.uptrend.xyaxis", description: Text(selectedRange.emptyStateDescription))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else {
                    WeightHistoryChart(
                        points: points,
                        selectedDate: $selectedDate,
                        weightUnit: weightUnit,
                        rangeFilter: selectedRange
                    )
                }
            }
            .frame(height: 260)

            Picker("Range", selection: $selectedRange) {
                ForEach(WeightHistoryRangeFilter.allCases) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding()
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18))
    }

    private var displayedDateText: String {
        displayedEntry?.recordedAt.formatted(date: .abbreviated, time: .omitted) ?? "No entries in this range"
    }

    private var displayedWeightText: String {
        guard let displayedEntry else { return "-" }
        return formattedWeightText(displayedEntry.weight, unit: weightUnit)
    }
}

private struct WeightHistoryChart: View {
    let points: [WeightChartPoint]
    @Binding var selectedDate: Date?
    let weightUnit: WeightUnit
    let rangeFilter: WeightHistoryRangeFilter

    private let tint = Color.blue

    private var selectedPoint: WeightChartPoint? {
        guard let selectedDate else { return nil }
        return nearestPoint(to: selectedDate)
    }

    private var yDomain: ClosedRange<Double> {
        weightYDomain(for: points.map(\.weight))
    }

    var body: some View {
        Chart(points) { point in
            LineMark(
                x: .value("Date", point.date),
                y: .value("Weight", point.weight)
            )
            .foregroundStyle(tint)
            .interpolationMethod(.catmullRom)
            .lineStyle(.init(lineWidth: 2, lineCap: .round, lineJoin: .round))

            if points.count <= 60 {
                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Weight", point.weight)
                )
                .foregroundStyle(tint.opacity(0.8))
                .symbolSize(24)
            }

            if point.id == selectedPoint?.id {
                RuleMark(x: .value("Selected Date", point.date))
                    .foregroundStyle(tint)
                    .lineStyle(.init(lineWidth: 1, dash: [4, 4]))

                PointMark(
                    x: .value("Selected Date", point.date),
                    y: .value("Selected Weight", point.weight)
                )
                .foregroundStyle(.white)
                .symbolSize(80)

                PointMark(
                    x: .value("Selected Date", point.date),
                    y: .value("Selected Weight", point.weight)
                )
                .foregroundStyle(tint)
                .symbolSize(36)
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartYScale(domain: yDomain)
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
            AxisMarks(values: .automatic(desiredCount: rangeFilter == .week ? 7 : 4)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(axisLabel(for: date))
                    }
                }
            }
        }
    }

    private func axisLabel(for date: Date) -> String {
        switch rangeFilter {
        case .week:
            return date.formatted(.dateTime.weekday(.abbreviated))
        case .month:
            return date.formatted(.dateTime.month(.abbreviated).day())
        case .year, .all:
            return date.formatted(.dateTime.month(.abbreviated))
        }
    }

    private func nearestPoint(to date: Date) -> WeightChartPoint? {
        points.min { left, right in
            abs(left.date.timeIntervalSince(date)) < abs(right.date.timeIntervalSince(date))
        }
    }
}

#Preview {
    NavigationStack {
        WeightHistoryView(weightUnit: .lbs)
    }
    .sampleDataContainer()
}
