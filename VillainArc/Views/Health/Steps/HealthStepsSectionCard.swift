import SwiftUI
import SwiftData
import Charts

struct HealthStepsSectionCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let router = AppRouter.shared
    @Query(HealthStepsDistance.summary, animation: .smooth) private var summaryEntries: [HealthStepsDistance]
    @Query(StepsGoal.active, animation: .smooth) private var activeGoals: [StepsGoal]

    private var latestEntry: HealthStepsDistance? {
        summaryEntries.first
    }

    private var todayEntry: HealthStepsDistance? {
        summaryEntries.first { Calendar.autoupdatingCurrent.isDateInToday($0.date) }
    }

    private var activeGoal: StepsGoal? {
        activeGoals.first
    }

    private var activeGoalText: String? {
        guard let activeGoal else { return nil }
        if todayEntry?.goalCompleted == true {
            return String(localized: "Goal achieved")
        }
        return String(localized: "Goal: \(compactStepsText(activeGoal.targetSteps))")
    }

    private var cardAccessibilityLabel: String {
        guard let latestEntry else { return AccessibilityText.healthStepsSectionEmptyValue }
        return AccessibilityText.healthStepsSectionValue(dateText: formattedRecentDay(latestEntry.date), stepCount: latestEntry.stepCount)
    }

    var body: some View {
        Button {
            router.navigate(to: .stepsDistanceHistory)
            Task { await IntentDonations.donateShowStepsHistory() }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 3) {
                    Image(systemName: "figure.walk")
                        .font(.subheadline)
                        .foregroundStyle(.red.gradient)
                    Text("Steps")
                        .fontWeight(.semibold)
                        .foregroundStyle(.red.gradient)
                    
                    Spacer()

                    if let latestEntry {
                        Text(formattedRecentDay(latestEntry.date))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }
                }

                if let latestEntry {
                    HStack(alignment: .bottom, spacing: 0) {
                        VStack(alignment: .leading, spacing: 0) {
                            if let activeGoal {
                                stepsGoalLine(for: activeGoal)
                            }

                            HStack(alignment: .lastTextBaseline, spacing: 2) {
                                Text(latestEntry.stepCount, format: .number)
                                    .font(.largeTitle)
                                    .bold()
                                    .contentTransition(.numericText(value: Double(latestEntry.stepCount)))

                                Text(latestEntry.stepCount == 1 ? "Step" : "Steps")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .lineLimit(1)
                        .fontDesign(.rounded)
                        .fontWeight(.semibold)

                        Spacer()

                        HealthStepsSparkBarChart(entries: summaryEntries)
                            .frame(width: 160, height: 80)
                            .accessibilityHidden(true)
                    }
                    .animation(reduceMotion ? nil : .smooth, value: latestEntry.stepCount)
                } else {
                    Text(AccessibilityText.healthHistoryNoHealthDataDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fontWeight(.semibold)
                }
            }
            .padding()
            .appCardStyle()
            .tint(.primary)
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier(AccessibilityIdentifiers.healthStepsSectionCard)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(cardAccessibilityLabel)
        .accessibilityHint(AccessibilityText.healthStepsSectionHint)
    }

    @ViewBuilder
    private func stepsGoalLine(for goal: StepsGoal) -> some View {
        if todayEntry?.goalCompleted == true {
            Text("Goal achieved")
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(1)
        } else {
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text("Goal:")
                    .foregroundStyle(.secondary)
                Text(compactStepsText(goal.targetSteps))
                    .foregroundStyle(.primary)
            }
            .font(.subheadline)
            .lineLimit(1)
        }
    }
}

private struct HealthStepsSparkBarChart: View {
    let entries: [HealthStepsDistance]

    private var latestDate: Date? {
        entries.max(by: { $0.date < $1.date })?.date
    }

    private var yDomain: ClosedRange<Double> {
        0...max(entries.map { Double($0.stepCount) }.max() ?? 0, 1) * 1.15
    }

    var body: some View {
        Chart(entries, id: \.date) { entry in
            BarMark(x: .value("Date", entry.date, unit: .day), y: .value("Steps", entry.stepCount), width: .ratio(0.92))
                .foregroundStyle(entry.date == latestDate ? AnyShapeStyle(Color.red.gradient) : AnyShapeStyle(Color.red.opacity(0.3).gradient))
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4))
        }
        .chartYScale(domain: yDomain)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
    }
}
