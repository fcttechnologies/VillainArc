import SwiftUI
import SwiftData
import Charts

struct HealthTabView: View {
    @State private var router = AppRouter.shared
    @Query(WeightEntry.history) private var weightEntries: [WeightEntry]
    @Query(AppSettings.single) private var appSettings: [AppSettings]
    
    private var weightUnit: WeightUnit {
        appSettings.first?.weightUnit ?? .systemDefault
    }
    
    var body: some View {
        NavigationStack(path: $router.healthTabPath) {
            ScrollView {
                WeightSectionCard(entries: weightEntries, weightUnit: weightUnit)
                    .padding()
            }
            .navBar(title: "Health", includePadding: false)
            .scrollIndicators(.hidden)
        }
    }
}

private struct WeightSectionCard: View {
    let entries: [WeightEntry]
    let weightUnit: WeightUnit
    
    private var latestEntry: WeightEntry? {
        entries.first
    }
    
    private var chartPoints: [WeightChartPoint] {
        Array(entries.prefix(14).reversed()).map {
            WeightChartPoint(id: $0.id, date: $0.recordedAt, weight: $0.weight)
        }
    }
    
    private var trend: WeightTrend {
        guard let latestEntry, let firstPoint = chartPoints.first else { return .stable }
        let delta = latestEntry.weight - firstPoint.weight
        if delta > 0.5 { return .increasing }
        if delta < -0.5 { return .decreasing }
        return .stable
    }
    
    private var cardAccessibilityLabel: String {
        guard let latestEntry else { return "Weight. No weight entries yet." }
        return "Weight. Latest weight \(formattedWeightText(latestEntry.weight, unit: weightUnit)). Trend \(trend.title.lowercased())."
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 3) {
                Image(systemName: "scalemass.fill")
                    .font(.subheadline)
                Text("Weight")
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.secondary)
            
            if let latestEntry {
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
            } else {
                ContentUnavailableView("No Weight Entries Yet", systemImage: "scalemass", description: Text("Weight summaries will show up here once you add or sync body weight entries."))
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
            }
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(cardAccessibilityLabel)
    }
}

private struct WeightSparklineChart: View {
    let points: [WeightChartPoint]
    
    private let tint = Color.blue
    
    private var latestPoint: WeightChartPoint? {
        points.last
    }
    
    private var yDomain: ClosedRange<Double> {
        let values = points.map(\.weight)
        guard let minimum = values.min(), let maximum = values.max() else {
            return 0...1
        }
        
        if minimum == maximum {
            let padding = max(abs(minimum) * 0.03, 0.5)
            return (minimum - padding)...(maximum + padding)
        }
        
        let range = maximum - minimum
        let padding = max(range * 0.25, 0.5)
        return (minimum - padding)...(maximum + padding)
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

private struct WeightChartPoint: Identifiable, Equatable {
    let id: UUID
    let date: Date
    let weight: Double
}

private enum WeightTrend {
    case decreasing
    case increasing
    case stable
    
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

#Preview {
    HealthTabView()
        .sampleDataContainer()
}
