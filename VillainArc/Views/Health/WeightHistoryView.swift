import SwiftUI
import SwiftData
import Charts

fileprivate enum WeightHistoryRangeFilter: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"
    case year = "Year"
    case all = "All"
    
    var id: String { rawValue }
    
    func domain(now: Date, calendar: Calendar, entries: [WeightEntry]) -> ClosedRange<Date> {
        let startOfToday = calendar.startOfDay(for: now)
        let endOfToday = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: startOfToday) ?? now
        
        let lowerBound: Date
        switch self {
        case .week:
            lowerBound = calendar.date(byAdding: .day, value: -7, to: startOfToday) ?? startOfToday
        case .month:
            lowerBound = calendar.date(byAdding: .day, value: -31, to: startOfToday) ?? startOfToday
        case .year:
            lowerBound = calendar.date(byAdding: .year, value: -1, to: startOfToday) ?? startOfToday
        case .all:
            if let oldestEntry = entries.last?.date {
                lowerBound = calendar.startOfDay(for: oldestEntry)
            } else {
                lowerBound = startOfToday
            }
        }
        
        return lowerBound...endOfToday
    }
    
    func includes(_ date: Date, in domain: ClosedRange<Date>) -> Bool {
        domain.contains(date)
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
    
    @State private var showAddWeightEntrySheet = false
    @State private var selectedRange: WeightHistoryRangeFilter = .month
    @State private var selectedDate: Date?
    
    private var currentDomain: ClosedRange<Date> {
        selectedRange.domain(now: Date(), calendar: .autoupdatingCurrent, entries: weightEntries)
    }
    
    private var filteredEntries: [WeightEntry] {
        weightEntries
            .filter { selectedRange.includes($0.date, in: currentDomain) }
            .sorted { $0.date < $1.date }
    }
    
    private var chartData: WeightHistoryChartData {
        WeightHistoryChartData(entries: filteredEntries, rangeFilter: selectedRange)
    }
    
    private var chartPoints: [WeightChartPoint] {
        chartData.points
    }
    
    private var displayedPoint: WeightChartPoint? {
        if let selectedPoint {
            return selectedPoint
        }
        
        return chartPoints.last
    }
    
    private var selectedPoint: WeightChartPoint? {
        guard let selectedDate else { return nil }
        return nearestPoint(to: selectedDate)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                WeightHistoryMainSection(displayedPoint: displayedPoint, points: chartPoints, xDomain: currentDomain, grouping: chartData.grouping, selectedDate: $selectedDate, weightUnit: weightUnit, selectedRange: $selectedRange)
                
                NavigationLink {
                    AllWeightEntriesListView(weightUnit: weightUnit)
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
                        .font(.title2)
                        .padding(5)
                }
                .buttonBorderShape(.circle)
                .buttonStyle(.glass)
                .accessibilityIdentifier(AccessibilityIdentifiers.healthAddWeightEntryButton)
                .accessibilityHint(AccessibilityText.healthAddWeightEntryHint)
            }
        }
        .sheet(isPresented: $showAddWeightEntrySheet) {
            NewWeightEntryView()
                .presentationDetents([.fraction(0.5)])
                .presentationBackground(Color(.systemBackground))
        }
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
    let displayedPoint: WeightChartPoint?
    let points: [WeightChartPoint]
    let xDomain: ClosedRange<Date>
    let grouping: WeightHistoryGrouping
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
            
            WeightHistoryChart(points: points, xDomain: xDomain, grouping: grouping, selectedDate: $selectedDate, weightUnit: weightUnit, rangeFilter: selectedRange)
                .overlay {
                    if points.isEmpty {
                        ContentUnavailableView("No Weight Entries", systemImage: "chart.line.uptrend.xyaxis", description: Text(selectedRange.emptyStateDescription))
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
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
    }
    
    private var displayedDateText: String {
        guard let displayedPoint else { return "No entries in this range" }
        
        if displayedPoint.entryCount > 1 {
            return formattedAbsoluteDateRange(start: displayedPoint.startDate, end: displayedPoint.endDate)
        }
        
        return formattedRecentDayAndTime(displayedPoint.date)
    }
    
    private var displayedWeightText: String {
        guard let displayedPoint else { return "-" }
        
        let formattedWeight = formattedWeightText(displayedPoint.weight, unit: weightUnit)
        if displayedPoint.entryCount > 1 {
            return "Avg \(formattedWeight)"
        }
        return formattedWeight
    }
}

private struct WeightHistoryChart: View {
    let points: [WeightChartPoint]
    let xDomain: ClosedRange<Date>
    let grouping: WeightHistoryGrouping
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
    
    private var axisMode: WeightHistoryAxisMode {
        WeightHistoryAxisMode(rangeFilter: rangeFilter, domain: xDomain)
    }
    
    var body: some View {
        Chart(points) { point in
            LineMark(x: .value("Date", point.date), y: .value("Weight", point.weight))
                .foregroundStyle(tint)
                .interpolationMethod(.catmullRom)
                .lineStyle(.init(lineWidth: 2, lineCap: .round, lineJoin: .round))
            
            if points.count <= 60 {
                PointMark(x: .value("Date", point.date), y: .value("Weight", point.weight))
                    .foregroundStyle(tint.opacity(0.8))
                    .symbolSize(24)
            }
            
            if point.id == selectedPoint?.id {
                RuleMark(x: .value("Selected Date", point.date))
                    .foregroundStyle(tint)
                    .lineStyle(.init(lineWidth: 1, dash: [4, 4]))
                
                PointMark(x: .value("Selected Date", point.date), y: .value("Selected Weight", point.weight))
                    .foregroundStyle(.white)
                    .symbolSize(80)
                
                PointMark(x: .value("Selected Date", point.date), y: .value("Selected Weight", point.weight))
                    .foregroundStyle(tint)
                    .symbolSize(36)
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartXScale(domain: xDomain)
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
            switch axisMode {
            case .week:
                AxisMarks(values: .automatic(desiredCount: 7)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(axisLabel(for: date))
                        }
                    }
                }
            case .month:
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(axisLabel(for: date))
                        }
                    }
                }
            case .year:
                AxisMarks(values: monthAxisDates) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(axisLabel(for: date))
                        }
                    }
                }
            case .multiYear:
                AxisMarks(values: yearAxisDates) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(axisLabel(for: date))
                        }
                    }
                }
            }
        }
    }
    
    private func axisLabel(for date: Date) -> String {
        switch axisMode {
        case .week:
            return date.formatted(.dateTime.weekday(.abbreviated))
        case .month:
            return date.formatted(.dateTime.month(.abbreviated).day())
        case .year:
            return date.formatted(.dateTime.month(.abbreviated))
        case .multiYear:
            return date.formatted(.dateTime.year())
        }
    }
    
    private func nearestPoint(to date: Date) -> WeightChartPoint? {
        points.min { left, right in
            abs(left.date.timeIntervalSince(date)) < abs(right.date.timeIntervalSince(date))
        }
    }
    
    private var monthAxisDates: [Date] {
        let calendar = Calendar.autoupdatingCurrent
        
        if rangeFilter == .year {
            let upperMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: xDomain.upperBound)) ?? xDomain.upperBound
            return (0..<12)
                .compactMap { calendar.date(byAdding: .month, value: -11 + $0, to: upperMonthStart) }
                .filter { xDomain.contains($0) }
        }
        
        return monthTickDates(in: xDomain, calendar: calendar, maxCount: 12)
    }
    
    private var yearAxisDates: [Date] {
        let calendar = Calendar.autoupdatingCurrent
        return yearTickDates(in: xDomain, calendar: calendar)
    }
}

private enum WeightHistoryGrouping {
    case raw
    case multiDay
    case weekly
    case monthly
}

private struct WeightHistoryChartData {
    let points: [WeightChartPoint]
    let grouping: WeightHistoryGrouping
    
    init(entries: [WeightEntry], rangeFilter: WeightHistoryRangeFilter) {
        let grouping = Self.grouping(for: entries, rangeFilter: rangeFilter)
        self.grouping = grouping
        self.points = Self.makePoints(from: entries, grouping: grouping)
    }
    
    private static func grouping(for entries: [WeightEntry], rangeFilter: WeightHistoryRangeFilter) -> WeightHistoryGrouping {
        let sortedEntries = entries.sorted { $0.date < $1.date }
        guard let firstDate = sortedEntries.first?.date, let lastDate = sortedEntries.last?.date else {
            return .raw
        }
        
        let spanDays = max(0, Calendar.autoupdatingCurrent.dateComponents([.day], from: firstDate, to: lastDate).day ?? 0)
        
        switch rangeFilter {
        case .week:
            return .raw
        case .month:
            return entries.count > 45 ? .multiDay : .raw
        case .year:
            return entries.count > 90 || spanDays > 180 ? .weekly : .raw
        case .all:
            if spanDays > 730 || entries.count > 180 {
                return .monthly
            }
            if spanDays > 180 || entries.count > 90 {
                return .weekly
            }
            if spanDays > 45 || entries.count > 45 {
                return .multiDay
            }
            return .raw
        }
    }
    
    private static func makePoints(from entries: [WeightEntry], grouping: WeightHistoryGrouping) -> [WeightChartPoint] {
        let sortedEntries = entries.sorted { $0.date < $1.date }
        
        switch grouping {
        case .raw:
            return sortedEntries.map(WeightChartPoint.init)
        case .multiDay:
            return bucketedPoints(from: sortedEntries, grouping: grouping) { entry, calendar in
                let startOfEntryDay = calendar.startOfDay(for: entry.date)
                let dayNumber = calendar.dateComponents([.day], from: .distantPast, to: startOfEntryDay).day ?? 0
                return "days-\(dayNumber / 3)"
            }
        case .weekly:
            return bucketedPoints(from: sortedEntries, grouping: grouping) { entry, calendar in
                let week = calendar.component(.weekOfYear, from: entry.date)
                let year = calendar.component(.yearForWeekOfYear, from: entry.date)
                return "week-\(year)-\(week)"
            }
        case .monthly:
            return bucketedPoints(from: sortedEntries, grouping: grouping) { entry, calendar in
                let month = calendar.component(.month, from: entry.date)
                let year = calendar.component(.year, from: entry.date)
                return "month-\(year)-\(month)"
            }
        }
    }
    
    private static func bucketedPoints(from entries: [WeightEntry], grouping: WeightHistoryGrouping, key: (WeightEntry, Calendar) -> String) -> [WeightChartPoint] {
        let calendar = Calendar.autoupdatingCurrent
        let buckets = Dictionary(grouping: entries) { key($0, calendar) }
        
        return buckets.values.compactMap { bucketEntries in
            let sortedBucket = bucketEntries.sorted { $0.date < $1.date }
            guard let lastEntry = sortedBucket.last else { return nil }
            guard let firstEntry = sortedBucket.first else { return nil }
            let averageWeight = sortedBucket.reduce(0) { $0 + $1.weight } / Double(sortedBucket.count)
            return WeightChartPoint(id: UUID(), date: lastEntry.date, weight: averageWeight, startDate: firstEntry.date, endDate: lastEntry.date, entryCount: sortedBucket.count)
        }
        .sorted { $0.date < $1.date }
    }
}

private enum WeightHistoryAxisMode {
    case week
    case month
    case year
    case multiYear
    
    init(rangeFilter: WeightHistoryRangeFilter, domain: ClosedRange<Date>) {
        let spanDays = max(0, Calendar.autoupdatingCurrent.dateComponents([.day], from: domain.lowerBound, to: domain.upperBound).day ?? 0)
        
        switch rangeFilter {
        case .week:
            self = .week
        case .month:
            self = .month
        case .year:
            self = .year
        case .all:
            if spanDays <= 8 {
                self = .week
            } else if spanDays <= 31 {
                self = .month
            } else if spanDays <= 366 {
                self = .year
            } else {
                self = .multiYear
            }
        }
    }
}

private func monthTickDates(in domain: ClosedRange<Date>, calendar: Calendar, maxCount: Int) -> [Date] {
    let lowerMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: domain.lowerBound)) ?? domain.lowerBound
    let upperMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: domain.upperBound)) ?? domain.upperBound
    
    var dates: [Date] = []
    var current = lowerMonthStart
    
    while current <= upperMonthStart {
        if domain.contains(current) {
            dates.append(current)
        }
        guard let next = calendar.date(byAdding: .month, value: 1, to: current) else { break }
        current = next
    }
    
    if dates.count <= maxCount {
        return dates
    }
    
    return Array(dates.suffix(maxCount))
}

private func yearTickDates(in domain: ClosedRange<Date>, calendar: Calendar) -> [Date] {
    let lowerYearStart = calendar.date(from: calendar.dateComponents([.year], from: domain.lowerBound)) ?? domain.lowerBound
    let upperYearStart = calendar.date(from: calendar.dateComponents([.year], from: domain.upperBound)) ?? domain.upperBound
    
    var dates: [Date] = []
    var current = lowerYearStart
    
    while current <= upperYearStart {
        if domain.contains(current) {
            dates.append(current)
        }
        guard let next = calendar.date(byAdding: .year, value: 1, to: current) else { break }
        current = next
    }
    
    return dates
}

#Preview {
    NavigationStack {
        WeightHistoryView(weightUnit: .lbs)
    }
    .sampleDataContainer()
}
