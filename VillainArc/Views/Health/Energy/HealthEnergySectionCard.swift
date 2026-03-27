import SwiftUI
import SwiftData
import Charts

struct HealthEnergySectionCard: View {
    private static let visibleDayCount = 7

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let router = AppRouter.shared
    @Query private var energyEntries: [HealthEnergy]
    @Query(HealthEnergy.latest) private var latestEnergyEntries: [HealthEnergy]

    init() {
        _energyEntries = Query(HealthEnergy.recent(days: Self.visibleDayCount), animation: .smooth)
    }

    private var hasAnyEnergyData: Bool {
        !latestEnergyEntries.isEmpty
    }

    private var todayStart: Date {
        Calendar.autoupdatingCurrent.startOfDay(for: .now)
    }

    private var todayEnergy: HealthEnergy? {
        energyEntries.first(where: { Calendar.autoupdatingCurrent.isDate($0.date, inSameDayAs: todayStart) })
    }

    private var todayActiveEnergy: Double {
        todayEnergy?.activeEnergyBurned ?? 0
    }

    private var todayTotalEnergy: Double {
        todayEnergy?.totalEnergyBurned ?? 0
    }

    private var chartPoints: [HealthEnergyChartPoint] {
        let calendar = Calendar.autoupdatingCurrent
        let entriesByDay = Dictionary(uniqueKeysWithValues: energyEntries.map { (calendar.startOfDay(for: $0.date), $0) })

        return (0..<Self.visibleDayCount).compactMap { index in
            guard let date = calendar.date(byAdding: .day, value: index - (Self.visibleDayCount - 1), to: todayStart) else { return nil }
            let entry = entriesByDay[date]
            let activeEnergy = entry?.activeEnergyBurned ?? 0
            let totalEnergy = entry?.totalEnergyBurned ?? 0
            return HealthEnergyChartPoint(date: date, activeEnergy: activeEnergy, restingEnergy: max(0, totalEnergy - activeEnergy))
        }
    }

    private var cardAccessibilityLabel: String {
        if !hasAnyEnergyData {
            return String(localized: "Energy. Update Apple Health permissions so your health metrics appear here.")
        }
        return AccessibilityText.healthEnergySectionValue(totalEnergy: Int(todayTotalEnergy.rounded()), activeEnergy: Int(todayActiveEnergy.rounded()))
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
                    
                    Spacer()
                }

                if hasAnyEnergyData {
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(alignment: .lastTextBaseline, spacing: 3) {
                                Text(Int(todayActiveEnergy.rounded()), format: .number)
                                    .contentTransition(.numericText(value: todayActiveEnergy))
                                    .font(.title3)

                                Text("Active")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.subheadline)

                            HStack(alignment: .lastTextBaseline, spacing: 2) {
                                Text(Int(todayTotalEnergy.rounded()), format: .number)
                                    .font(.largeTitle)
                                    .bold()
                                    .contentTransition(.numericText(value: todayTotalEnergy))

                                Text("Total")
                                    .font(.title)
                                    .foregroundStyle(.secondary)
                            }
                            .lineLimit(1)
                        }
                        .fontDesign(.rounded)
                        .fontWeight(.semibold)
                        .animation(reduceMotion ? nil : .smooth, value: todayEnergy)

                        Spacer()

                        HealthEnergySparkBarChart(points: chartPoints)
                            .frame(width: 160, height: 80)
                            .accessibilityHidden(true)
                    }
                } else {
                    Text("Update Apple Health permissions so your health metrics appear here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fontWeight(.semibold)
                }
            }
            .padding()
            .glassEffect(.regular, in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityIdentifiers.healthEnergySectionCard)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(cardAccessibilityLabel)
        .accessibilityHint(AccessibilityText.healthEnergySectionHint)
    }
}

private struct HealthEnergySparkBarChart: View {
    let points: [HealthEnergyChartPoint]

    private var yDomain: ClosedRange<Double> {
        0...(max(points.map(\.totalEnergy).max() ?? 0, 1) * 1.15)
    }

    var body: some View {
        Chart(points) { point in
            BarMark(x: .value("Date", point.date, unit: .day), y: .value("Total Energy", point.totalEnergy), width: .ratio(0.92))
                .foregroundStyle(.orange.opacity(0.22).gradient)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4))

            BarMark(x: .value("Date", point.date, unit: .day), yStart: .value("Baseline", 0), yEnd: .value("Active Energy", point.activeEnergy), width: .ratio(0.92))
                .foregroundStyle(.orange.gradient)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4))
        }
        .chartYScale(domain: yDomain)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
    }
}

private struct HealthEnergyChartPoint: Identifiable {
    let date: Date
    let activeEnergy: Double
    let restingEnergy: Double
    var totalEnergy: Double { activeEnergy + restingEnergy }
    let id = UUID()
}
