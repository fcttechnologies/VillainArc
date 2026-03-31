import Charts
import SwiftData
import SwiftUI

struct HealthSleepSectionCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(HealthSleepNight.summary, animation: .smooth) private var summaryEntries: [HealthSleepNight]

    private var visibleEntries: [HealthSleepNight] {
        let availableEntries = summaryEntries.filter(\.isAvailableInHealthKit)
        return availableEntries.isEmpty ? summaryEntries : availableEntries
    }

    private var latestEntry: HealthSleepNight? { visibleEntries.first }

    private var cardAccessibilityLabel: String {
        guard let latestEntry else { return AccessibilityText.healthSleepSectionEmptyValue }

        return AccessibilityText.healthSleepSectionValue(
            dateText: formattedSleepWakeDay(latestEntry.wakeDay),
            sleepText: formattedSleepDurationAccessibilityText(latestEntry.timeAsleep),
            timingText: sleepTimingText(for: latestEntry),
            secondaryText: secondarySummaryText(for: latestEntry)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 3) {
                Image(systemName: "bed.double.fill")
                    .font(.subheadline)
                    .foregroundStyle(.indigo.gradient)
                    .accessibilityHidden(true)
                Text("Sleep")
                    .fontWeight(.semibold)
                    .foregroundStyle(.indigo.gradient)

                Spacer()

                if let latestEntry {
                    Text(formattedSleepWakeDay(latestEntry.wakeDay))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            if let latestEntry {
                HStack(alignment: .bottom, spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(sleepTimingText(for: latestEntry))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        HStack(alignment: .lastTextBaseline, spacing: 3) {
                            Text(formattedSleepDurationText(latestEntry.timeAsleep))
                                .font(.largeTitle)
                                .bold()
                                .contentTransition(.numericText(value: latestEntry.timeAsleep))

                            Text("Asleep")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                        .lineLimit(1)

                        if let secondarySummary {
                            Text(secondarySummary)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .fontDesign(.rounded)
                    .fontWeight(.semibold)

                    Spacer()

                    if visibleEntries.count > 1 {
                        HealthSleepSparkBarChart(entries: visibleEntries)
                            .frame(width: 160, height: 80)
                            .accessibilityHidden(true)
                    }
                }
                .animation(reduceMotion ? nil : .smooth, value: latestEntry.timeAsleep)
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
        .accessibilityIdentifier(AccessibilityIdentifiers.healthSleepSectionCard)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(cardAccessibilityLabel)
    }

    private var secondarySummary: String? {
        guard let latestEntry else { return nil }
        return secondarySummaryText(for: latestEntry)
    }

    private func secondarySummaryText(for entry: HealthSleepNight) -> String? {
        if !entry.isAvailableInHealthKit {
            return "Removed from Apple Health"
        }

        if entry.hasStageBreakdown {
            var parts: [String] = []
            if entry.deepDuration > 0 {
                parts.append("Deep \(formattedSleepDurationText(entry.deepDuration))")
            }
            if entry.remDuration > 0 {
                parts.append("REM \(formattedSleepDurationText(entry.remDuration))")
            }
            if !parts.isEmpty {
                return parts.joined(separator: " • ")
            }
        }

        var parts: [String] = []
        if entry.awakeDuration > 0 {
            parts.append("Awake \(formattedSleepDurationText(entry.awakeDuration))")
        }
        if entry.timeInBed > 0 {
            parts.append("In Bed \(formattedSleepDurationText(entry.timeInBed))")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private func sleepTimingText(for entry: HealthSleepNight) -> String {
        guard let sleepStart = entry.sleepStart, let sleepEnd = entry.sleepEnd else {
            return "No overnight sleep window"
        }
        return "\(sleepStart.formatted(date: .omitted, time: .shortened)) - \(sleepEnd.formatted(date: .omitted, time: .shortened))"
    }
}

private struct HealthSleepSparkBarChart: View {
    let entries: [HealthSleepNight]

    private var latestWakeDay: Date? { entries.map(\.wakeDay).max() }

    private var yDomain: ClosedRange<Double> {
        0...max(entries.map(\.timeAsleep).max() ?? 0, 1) * 1.15
    }

    var body: some View {
        Chart(entries, id: \.wakeDay) { entry in
            BarMark(
                x: .value("Wake Day", HealthSleepNight.displayDate(forWakeDay: entry.wakeDay), unit: .day),
                y: .value("Time Asleep", entry.timeAsleep),
                width: .ratio(0.92)
            )
            .foregroundStyle(
                entry.wakeDay == latestWakeDay
                ? AnyShapeStyle(Color.indigo.gradient)
                : AnyShapeStyle(Color.indigo.opacity(0.3).gradient)
            )
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4))
        }
        .chartYScale(domain: yDomain)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
    }
}

private func formattedSleepDurationText(_ duration: TimeInterval) -> String {
    let totalMinutes = Int((duration / 60).rounded())
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60

    if hours > 0 && minutes > 0 {
        return "\(hours)h \(minutes)m"
    }

    if hours > 0 {
        return "\(hours)h"
    }

    return "\(minutes)m"
}

private func formattedSleepDurationAccessibilityText(_ duration: TimeInterval) -> String {
    let totalMinutes = Int((duration / 60).rounded())
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60

    var parts: [String] = []
    if hours > 0 {
        parts.append("\(hours) \(hours == 1 ? "hour" : "hours")")
    }
    if minutes > 0 || parts.isEmpty {
        parts.append("\(minutes) \(minutes == 1 ? "minute" : "minutes")")
    }
    return parts.joined(separator: " ")
}

private func formattedSleepWakeDay(_ wakeDay: Date) -> String { formattedRecentDay(HealthSleepNight.displayDate(forWakeDay: wakeDay)) }
