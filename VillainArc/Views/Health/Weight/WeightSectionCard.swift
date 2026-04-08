import SwiftUI
import SwiftData
import Charts

struct WeightSectionCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let router = AppRouter.shared
    @Query(WeightEntry.summary, animation: .smooth) private var summaryEntries: [WeightEntry]
    @Query(WeightGoal.active, animation: .smooth) private var activeGoals: [WeightGoal]
    @Query(AppSettings.single) private var appSettings: [AppSettings]

    private var weightUnit: WeightUnit {
        appSettings.first?.weightUnit ?? .systemDefault
    }

    private var activeGoal: WeightGoal? {
        activeGoals.first
    }

    private var latestEntry: WeightEntry? {
        summaryEntries.first
    }

    private var activeGoalText: String? {
        guard let activeGoal else { return nil }
        if activeGoal.type == .maintain {
            return String(localized: "Maintain")
        }
        return String(localized: "Goal: \(formattedWeightText(activeGoal.targetWeight, unit: weightUnit))")
    }

    private var cardAccessibilityLabel: String {
        guard let latestEntry else { return AccessibilityText.healthWeightSectionEmptyValue }
        return AccessibilityText.healthWeightSectionValue(dateText: formattedRecentDay(latestEntry.date), weightText: formattedWeightText(latestEntry.weight, unit: weightUnit), goalText: activeGoalText)
    }

    var body: some View {
        Button {
            Haptics.selection()
            router.navigate(to: .weightHistory)
            Task { await IntentDonations.donateShowWeightHistory() }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    HStack(spacing: 3) {
                        Image(systemName: "scalemass.fill")
                            .font(.subheadline)
                            .foregroundStyle(.blue.gradient)
                        Text("Weight")
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue.gradient)
                    }

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
                                weightGoalLine(for: activeGoal)
                            }

                            HStack(alignment: .lastTextBaseline, spacing: 3) {
                                Text(formattedWeightValue(latestEntry.weight, unit: weightUnit, fractionDigits: 0...1))
                                    .font(.largeTitle)
                                    .bold()
                                    .contentTransition(.numericText(value: weightUnit.fromKg(latestEntry.weight)))
                                    .foregroundStyle(.primary)
                                
                                Text(weightUnit.rawValue)
                                    .font(.title2)
                            }
                            .lineLimit(1)
                        }
                        .fontDesign(.rounded)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        if summaryEntries.count > 1 {
                            WeightSparklineChart(entries: summaryEntries, latestEntry: latestEntry)
                                .frame(width: 160, height: 80)
                                .accessibilityHidden(true)
                        }
                    }
                    .animation(reduceMotion ? nil : .smooth, value: weightUnit.fromKg(latestEntry.weight))
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
            .tint(.primary)
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier(AccessibilityIdentifiers.healthWeightSectionCard)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(cardAccessibilityLabel)
        .accessibilityHint(AccessibilityText.healthWeightSectionHint)
    }

    @ViewBuilder
    private func weightGoalLine(for goal: WeightGoal) -> some View {
        if goal.type == .maintain {
            Text("Maintain")
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(1)
        } else {
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text("Goal:")
                    .foregroundStyle(.secondary)
                Text(formattedWeightText(goal.targetWeight, unit: weightUnit))
                    .foregroundStyle(.primary)
            }
            .font(.subheadline)
            .lineLimit(1)
        }
    }
}

private struct WeightSparklineChart: View {
    let entries: [WeightEntry]
    let latestEntry: WeightEntry?

    private let tint = Color.blue

    private var yDomain: ClosedRange<Double> {
        weightYDomain(for: entries.map(\.weight), minimumPadding: 0.5)
    }

    var body: some View {
        Chart {
            ForEach(entries, id: \.id) { entry in
                LineMark(x: .value("Date", entry.date), y: .value("Weight", entry.weight))
                    .foregroundStyle(tint)
                    .lineStyle(.init(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)
            }

            if let latestEntry {
                PointMark(x: .value("Latest Date", latestEntry.date), y: .value("Latest Weight", latestEntry.weight))
                    .foregroundStyle(tint.opacity(0.2))
                    .symbolSize(280)

                PointMark(x: .value("Latest Date", latestEntry.date), y: .value("Latest Weight", latestEntry.weight))
                    .foregroundStyle(.white)
                    .symbolSize(120)

                PointMark(x: .value("Latest Date", latestEntry.date), y: .value("Latest Weight", latestEntry.weight))
                    .foregroundStyle(tint)
                    .symbolSize(64)
            }
        }
        .chartYScale(domain: yDomain)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
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
