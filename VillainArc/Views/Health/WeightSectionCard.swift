import SwiftUI
import SwiftData
import Charts

struct WeightSectionCard: View {
    private static let recentTrendWindowDays = 35

    let router = AppRouter.shared
    @Query private var entries: [WeightEntry]
    @Query(WeightGoal.active) private var activeGoals: [WeightGoal]
    @Query(AppSettings.single) private var appSettings: [AppSettings]

    init() {
        _entries = Query(WeightEntry.recent(days: Self.recentTrendWindowDays), animation: .smooth)
    }

    private var weightUnit: WeightUnit {
        appSettings.first?.weightUnit ?? .systemDefault
    }

    private var activeGoal: WeightGoal? {
        activeGoals.first
    }

    private var latestEntry: WeightEntry? {
        entries.first
    }

    private var chartPoints: [WeightChartPoint] {
        entries.reversed().map(WeightChartPoint.init)
    }

    private var trend: WeightTrend {
        WeightTrend(delta: chartDelta)
    }

    private var chartDelta: Double {
        guard let firstPoint = smoothedTrendPoints.first, let lastPoint = smoothedTrendPoints.last else {
            guard let latestEntry, let earliestEntry = entries.last else { return 0 }
            return latestEntry.weight - earliestEntry.weight
        }

        return lastPoint.weight - firstPoint.weight
    }

    private var dailyTrendPoints: [DailyWeightPoint] {
        let calendar = Calendar.autoupdatingCurrent
        let dailyBuckets = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.date) }

        return dailyBuckets
            .compactMap { date, entriesForDay in
                guard let averageWeight = averageWeight(for: entriesForDay) else { return nil }
                return DailyWeightPoint(date: date, weight: averageWeight)
            }
            .sorted { $0.date < $1.date }
    }

    private var smoothedTrendPoints: [DailyWeightPoint] {
        let points = dailyTrendPoints
        guard points.count > 2 else { return points }

        let windowSize = min(7, points.count)
        return points.indices.map { index in
            let lowerBound = max(0, index - windowSize + 1)
            let window = Array(points[lowerBound...index])
            let averageWeight = window.reduce(0) { $0 + $1.weight } / Double(window.count)
            return DailyWeightPoint(date: points[index].date, weight: averageWeight)
        }
    }

    private var activeGoalText: String? {
        guard let activeGoal else { return nil }
        if activeGoal.type == .maintain {
            return "Maintain"
        }
        return "Goal: \(formattedWeightText(activeGoal.targetWeight, unit: weightUnit))"
    }

    private var cardAccessibilityLabel: String {
        guard let latestEntry else { return "Weight. No weight entries yet." }

        var parts = [
            "Weight",
            "Latest weight \(formattedWeightText(latestEntry.weight, unit: weightUnit))",
            "Trend \(trend.title.lowercased())"
        ]

        if let activeGoalText {
            parts.append(activeGoalText)
        }

        return parts.joined(separator: ". ") + "."
    }

    var body: some View {
        Button {
            router.navigate(to: .weightHistory(weightUnit))
        } label: {
            Group {
                if let latestEntry {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top, spacing: 12) {
                            HStack(spacing: 3) {
                                Image(systemName: "scalemass.fill")
                                    .font(.subheadline)
                                Text("Weight")
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(.secondary)

                            Spacer()

                            if let activeGoalText {
                                Text(activeGoalText)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(.blue.gradient, in: Capsule())
                                    .foregroundStyle(.white)
                            }
                        }
                        
                        HStack(alignment: .bottom, spacing: 0) {
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(alignment: .lastTextBaseline, spacing: 3) {
                                    Text(formattedWeightValue(latestEntry.weight, unit: weightUnit, fractionDigits: 0...1))
                                        .font(.largeTitle)
                                        .bold()
                                        .foregroundStyle(.primary)
                                    
                                    Text(weightUnit.rawValue)
                                        .font(.title)
                                }
                                .lineLimit(1)
                                
                                HStack(spacing: 5) {
                                    Image(systemName: trend.icon)
                                    Text(trend.title)
                                }
                            }
                            .fontDesign(.rounded)
                            .foregroundStyle(.secondary)
                            .fontWeight(.semibold)
                            
                            Spacer()
                            
                            if chartPoints.count > 1 {
                                WeightSparklineChart(points: chartPoints)
                                    .frame(width: 160, height: 80)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                } else {
                    SmallUnavailableView(sfIconName: "scalemass.fill", title: "No Weight Recorded", subtitle: "Your weight data will show up here once you add or sync body weight entries")
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)
                }
            }
            .padding()
            .glassEffect(.regular, in: .rect(cornerRadius: 12))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(cardAccessibilityLabel)
        .accessibilityHint("Opens detailed weight history.")
    }

    private func averageWeight(for entries: [WeightEntry]) -> Double? {
        guard !entries.isEmpty else { return nil }
        let total = entries.reduce(0) { $0 + $1.weight }
        return total / Double(entries.count)
    }
}

private struct DailyWeightPoint {
    let date: Date
    let weight: Double
}

private struct WeightSparklineChart: View {
    let points: [WeightChartPoint]

    private let tint = Color.blue

    private var latestPoint: WeightChartPoint? {
        points.last
    }

    private var yDomain: ClosedRange<Double> {
        weightYDomain(for: points.map(\.weight), minimumPadding: 0.5)
    }

    var body: some View {
        Chart {
            ForEach(points) { point in
                LineMark(x: .value("Date", point.date), y: .value("Weight", point.weight))
                    .foregroundStyle(tint)
                    .lineStyle(.init(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
            }

            if let latestPoint {
                PointMark(x: .value("Latest Date", latestPoint.date), y: .value("Latest Weight", latestPoint.weight))
                    .foregroundStyle(tint.opacity(0.2))
                    .symbolSize(280)

                PointMark(x: .value("Latest Date", latestPoint.date), y: .value("Latest Weight", latestPoint.weight))
                    .foregroundStyle(.white)
                    .symbolSize(120)

                PointMark(x: .value("Latest Date", latestPoint.date), y: .value("Latest Weight", latestPoint.weight))
                    .foregroundStyle(tint)
                    .symbolSize(64)
            }
        }
        .chartYScale(domain: yDomain)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }
}

struct WeightChartPoint: Identifiable, Equatable {
    let id: UUID
    let date: Date
    let weight: Double
    let startDate: Date
    let endDate: Date
    let entryCount: Int

    init(id: UUID, date: Date, weight: Double, startDate: Date? = nil, endDate: Date? = nil, entryCount: Int = 1) {
        self.id = id
        self.date = date
        self.weight = weight
        self.startDate = startDate ?? date
        self.endDate = endDate ?? date
        self.entryCount = entryCount
    }

    init(_ entry: WeightEntry) {
        self.init(id: entry.id, date: entry.date, weight: entry.weight)
    }
}

enum WeightTrend {
    case decreasing
    case increasing
    case stable

    init(delta: Double) {
        if delta > 0.5 {
            self = .increasing
        } else if delta < -0.5 {
            self = .decreasing
        } else {
            self = .stable
        }
    }

    var title: String {
        switch self {
        case .decreasing:
            return "Decreasing"
        case .increasing:
            return "Increasing"
        case .stable:
            return "Stable"
        }
    }

    var icon: String {
        switch self {
        case .decreasing:
            return "arrow.down.circle.fill"
        case .increasing:
            return "arrow.up.circle.fill"
        case .stable:
            return "minus.circle.fill"
        }
    }
}

func weightYDomain(for values: [Double], minimumPadding: Double = 1) -> ClosedRange<Double> {
    guard let minimum = values.min(), let maximum = values.max() else {
        return 0...1
    }

    if minimum == maximum {
        let padding = max(abs(minimum) * 0.05, minimumPadding)
        return (minimum - padding)...(maximum + padding)
    }

    let range = maximum - minimum
    let padding = max(range * 0.15, minimumPadding)
    return (minimum - padding)...(maximum + padding)
}
