import SwiftUI
import SwiftData
import Charts

struct WeightSectionCard: View {
    private static let recentChartWindowDays = 35

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let router = AppRouter.shared
    @Query private var recentEntries: [WeightEntry]
    @Query(WeightEntry.latest, animation: .smooth) private var latestEntries: [WeightEntry]
    @Query(WeightGoal.active, animation: .smooth) private var activeGoals: [WeightGoal]
    @Query(AppSettings.single) private var appSettings: [AppSettings]

    init() {
        _recentEntries = Query(WeightEntry.recent(days: Self.recentChartWindowDays), animation: .smooth)
    }

    private var weightUnit: WeightUnit {
        appSettings.first?.weightUnit ?? .systemDefault
    }

    private var activeGoal: WeightGoal? {
        activeGoals.first
    }

    private var latestEntry: WeightEntry? {
        latestEntries.first
    }

    private var chartPoints: [WeightChartPoint] {
        recentEntries.reversed().map(WeightChartPoint.init)
    }

    private var activeGoalText: String? {
        guard let activeGoal else { return nil }
        if activeGoal.type == .maintain {
            return "Maintain"
        }
        return "Goal: \(formattedWeightText(activeGoal.targetWeight, unit: weightUnit))"
    }

    private var cardAccessibilityLabel: String {
        guard let latestEntry else { return AccessibilityText.healthWeightSectionEmptyValue }
        return AccessibilityText.healthWeightSectionValue(dateText: formattedRecentDay(latestEntry.date), weightText: formattedWeightText(latestEntry.weight, unit: weightUnit), goalText: activeGoalText)
    }

    var body: some View {
        Button {
            router.navigate(to: .weightHistory)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    HStack(spacing: 3) {
                        Image(systemName: "scalemass.fill")
                            .font(.subheadline)
                            .foregroundStyle(.blue.gradient)
                        Text("Weight")
                            .fontWeight(.semibold)
                    }

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

                if let latestEntry {
                    HStack(alignment: .bottom, spacing: 0) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(formattedRecentDay(latestEntry.date))
                                .font(.subheadline)

                            HStack(alignment: .lastTextBaseline, spacing: 3) {
                                Text(formattedWeightValue(latestEntry.weight, unit: weightUnit, fractionDigits: 0...1))
                                    .font(.largeTitle)
                                    .bold()
                                    .contentTransition(.numericText(value: latestEntry.weight))
                                    .animation(reduceMotion ? nil : .smooth, value: latestEntry.weight)
                                    .foregroundStyle(.primary)
                                
                                Text(weightUnit.rawValue)
                                    .font(.title)
                            }
                            .lineLimit(1)
                        }
                        .fontDesign(.rounded)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        if chartPoints.count > 1 {
                            WeightSparklineChart(points: chartPoints)
                                .frame(width: 160, height: 80)
                                .accessibilityHidden(true)
                        }
                    }
                } else {
                    Text("Your weight data will show up here once you add or sync body weight entries")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fontWeight(.semibold)
                }
            }
            .padding()
            .glassEffect(.regular, in: .rect(cornerRadius: 12))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityIdentifiers.healthWeightSectionCard)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(cardAccessibilityLabel)
        .accessibilityHint(AccessibilityText.healthWeightSectionHint)
    }
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
