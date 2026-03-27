import SwiftUI
import SwiftData
import Charts

struct HealthStepsSectionCard: View {
    private static let visibleDayCount = 7

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let router = AppRouter.shared
    @Query private var stepEntries: [HealthStepsDistance]
    @Query(HealthStepsDistance.latest) private var latestStepEntries: [HealthStepsDistance]

    init() {
        _stepEntries = Query(HealthStepsDistance.recent(days: Self.visibleDayCount), animation: .smooth)
    }

    private var hasAnyStepData: Bool {
        !latestStepEntries.isEmpty
    }

    private var todayStart: Date {
        Calendar.autoupdatingCurrent.startOfDay(for: .now)
    }

    private var todayStepCount: Int {
        stepEntries.first(where: { Calendar.autoupdatingCurrent.isDate($0.date, inSameDayAs: todayStart) })?.stepCount ?? 0
    }

    private var chartPoints: [HealthStepsChartPoint] {
        let calendar = Calendar.autoupdatingCurrent
        let entriesByDay = Dictionary(uniqueKeysWithValues: stepEntries.map { (calendar.startOfDay(for: $0.date), $0.stepCount) })

        return (0..<Self.visibleDayCount).compactMap { index in
            guard let date = calendar.date(byAdding: .day, value: index - (Self.visibleDayCount - 1), to: todayStart) else { return nil }
            return HealthStepsChartPoint(date: date, steps: entriesByDay[date] ?? 0)
        }
    }

    private var cardAccessibilityLabel: String {
        if !hasAnyStepData {
            return String(localized: "Steps. Update Apple Health permissions so your health metrics appear here.")
        }
        return AccessibilityText.healthStepsSectionValue(stepCount: todayStepCount)
    }

    var body: some View {
        Button {
            router.navigate(to: .stepsDistanceHistory)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 3) {
                    Image(systemName: "figure.walk")
                        .font(.subheadline)
                        .foregroundStyle(.red.gradient)
                    Text("Steps")
                        .fontWeight(.semibold)
                    
                    Spacer()
                }

                if hasAnyStepData {
                    HStack(alignment: .bottom, spacing: 0) {
                        HStack(alignment: .lastTextBaseline, spacing: 2) {
                            Text(todayStepCount, format: .number)
                                .font(.largeTitle)
                                .bold()
                                .contentTransition(.numericText(value: Double(todayStepCount)))
                                .animation(reduceMotion ? nil : .smooth, value: todayStepCount)

                            Text(todayStepCount == 1 ? "Step" : "Steps")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                                .fontWeight(.semibold)
                        }
                        .lineLimit(1)
                        .fontDesign(.rounded)

                        Spacer()

                        HealthStepsSparkBarChart(points: chartPoints)
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
        .accessibilityIdentifier(AccessibilityIdentifiers.healthStepsSectionCard)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(cardAccessibilityLabel)
        .accessibilityHint(AccessibilityText.healthStepsSectionHint)
    }
}

private struct HealthStepsSparkBarChart: View {
    let points: [HealthStepsChartPoint]

    private var yDomain: ClosedRange<Double> {
        0...max(points.map { Double($0.steps) }.max() ?? 0, 1) * 1.15
    }

    var body: some View {
        Chart(points) { point in
            BarMark(x: .value("Date", point.date, unit: .day), y: .value("Steps", point.steps), width: .ratio(0.92))
                .foregroundStyle(.red.gradient)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4))
        }
        .chartYScale(domain: yDomain)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
    }
}

private struct HealthStepsChartPoint: Identifiable {
    let date: Date
    let steps: Int
    let id = UUID()
}
