import SwiftUI
import SwiftData
import Charts

struct HealthEnergySectionCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let router = AppRouter.shared
    @Query(HealthEnergy.summary, animation: .smooth) private var summaryEntries: [HealthEnergy]
    @Query(AppSettings.single) private var appSettings: [AppSettings]

    private var energyUnit: EnergyUnit {
        appSettings.first?.energyUnit ?? .systemDefault
    }
    
    private var latestEntry: HealthEnergy? {
        summaryEntries.first
    }
    
    private var chartSegments: [HealthEnergy.ChartSegment] {
        summaryEntries.flatMap { entry in
            HealthEnergy.makeChartSegments(
                date: entry.date,
                startDate: entry.date,
                endDate: entry.date,
                sampleCount: 1,
                activeEnergy: energyUnit.fromKilocalories(entry.activeEnergyBurned),
                restingEnergy: energyUnit.fromKilocalories(entry.restingEnergyBurned)
            )
        }
    }
    
    private var cardAccessibilityLabel: String {
        guard let latestEntry else { return AccessibilityText.healthEnergySectionEmptyValue }
        return AccessibilityText.healthEnergySectionValue(
            dateText: formattedRecentDay(latestEntry.date),
            totalEnergyText: formattedEnergyAccessibilityText(latestEntry.totalEnergyBurned, unit: energyUnit),
            activeEnergyText: formattedEnergyAccessibilityText(latestEntry.activeEnergyBurned, unit: energyUnit)
        )
    }
    
    var body: some View {
        Button {
            router.navigate(to: .energyHistory)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .font(.subheadline)
                        .foregroundStyle(.orange.gradient)
                    Text("Energy")
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange.gradient)
                    
                    Spacer()
                    
                    if let latestEntry {
                        Text(formattedRecentDay(latestEntry.date))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                
                if let latestEntry {
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(alignment: .lastTextBaseline, spacing: 2) {
                                let activeEnergy = energyUnit.fromKilocalories(latestEntry.activeEnergyBurned)

                                Text(Int(activeEnergy.rounded()), format: .number)
                                    .contentTransition(.numericText(value: activeEnergy))
                                    .font(.title3)
                                    .bold()
                                
                                Text("Active")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.subheadline)
                            
                            HStack(alignment: .lastTextBaseline, spacing: 2) {
                                let totalEnergy = energyUnit.fromKilocalories(latestEntry.totalEnergyBurned)

                                Text(Int(totalEnergy.rounded()), format: .number)
                                    .font(.largeTitle)
                                    .contentTransition(.numericText(value: totalEnergy))
                                
                                Text("Total")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                            }
                            .lineLimit(1)
                        }
                        .fontDesign(.rounded)
                        .fontWeight(.semibold)
                        
                        Spacer()
                        
                        HealthEnergySparkBarChart(segments: chartSegments)
                            .frame(width: 160, height: 80)
                            .accessibilityHidden(true)
                    }
                    .animation(reduceMotion ? nil : .smooth, value: latestEntry.totalEnergyBurned)
                } else {
                    Text(AccessibilityText.healthHistoryNoHealthDataDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fontWeight(.semibold)
                }
            }
            .padding()
            .glassEffect(.regular, in: .rect(cornerRadius: 12))
            .tint(.primary)
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier(AccessibilityIdentifiers.healthEnergySectionCard)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(cardAccessibilityLabel)
        .accessibilityHint(AccessibilityText.healthEnergySectionHint)
    }
}

private struct HealthEnergySparkBarChart: View {
    let segments: [HealthEnergy.ChartSegment]

    private var latestDate: Date? {
        segments.map(\.date).max()
    }

    private var yDomain: ClosedRange<Double> {
        let totalsByDate = Dictionary(grouping: segments, by: \.date)
            .mapValues { $0.reduce(0) { $0 + $1.value } }
        return 0...(max(totalsByDate.values.max() ?? 0, 1) * 1.15)
    }
    
    var body: some View {
        Chart(segments) { segment in
            BarMark(x: .value("Date", segment.date, unit: .day), y: .value(segment.kind.rawValue.capitalized, segment.value), width: .ratio(0.92))
            .foregroundStyle(barStyle(for: segment))
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: segment.kind == .active ? 1 : 4, topTrailingRadius: segment.kind == .active ? 1 : 4))
        }
        .chartYScale(domain: yDomain)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
    }

    private func barStyle(for segment: HealthEnergy.ChartSegment) -> AnyShapeStyle {
        let isLatest = segment.date == latestDate
        switch segment.kind {
        case .active:
            return isLatest ? AnyShapeStyle(Color.orange.gradient) : AnyShapeStyle(Color.orange.opacity(0.35).gradient)
        case .resting:
            return isLatest ? AnyShapeStyle(Color.orange.opacity(0.22).gradient) : AnyShapeStyle(Color.orange.opacity(0.1).gradient)
        }
    }
}
