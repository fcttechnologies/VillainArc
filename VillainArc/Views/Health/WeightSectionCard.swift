import SwiftUI
import SwiftData
import Charts

struct WeightSectionCard: View {
    let router = AppRouter.shared
    @Query(WeightEntry.summary) private var entries: [WeightEntry]
    @Query(AppSettings.single) private var appSettings: [AppSettings]

    private var weightUnit: WeightUnit {
        appSettings.first?.weightUnit ?? .systemDefault
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
        guard let latestEntry, let firstPoint = chartPoints.first else { return 0 }
        return latestEntry.weight - firstPoint.weight
    }

    private var cardAccessibilityLabel: String {
        guard let latestEntry else { return "Weight. No weight entries yet." }
        return "Weight. Latest weight \(formattedWeightText(latestEntry.weight, unit: weightUnit)). Trend \(trend.title.lowercased())."
    }

    var body: some View {
        Button {
            router.navigate(to: .weightHistory(weightUnit))
        } label: {
            Group {
                if let latestEntry {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 3) {
                            Image(systemName: "scalemass.fill")
                                .font(.subheadline)
                            Text("Weight")
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(.secondary)
                        
                        HStack(alignment: .bottom, spacing: 0) {
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(alignment: .lastTextBaseline, spacing: 3) {
                                    Text(formattedWeightValue(latestEntry.weight, unit: weightUnit, fractionDigits: 1...1))
                                        .font(.title2)
                                        .bold()
                                        .foregroundStyle(.primary)
                                    
                                    Text(weightUnit.rawValue)
                                        .font(.title3)
                                }
                                
                                HStack(spacing: 5) {
                                    Image(systemName: trend.icon)
                                    Text(trend.title)
                                        .fontWeight(.semibold)
                                }
                                .foregroundStyle(.secondary)
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

    init(id: UUID, date: Date, weight: Double) {
        self.id = id
        self.date = date
        self.weight = weight
    }

    init(_ entry: WeightEntry) {
        self.init(id: entry.id, date: entry.recordedAt, weight: entry.weight)
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
