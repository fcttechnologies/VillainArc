import Charts
import SwiftData
import SwiftUI

struct HealthSleepSectionCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let router = AppRouter.shared
    @Query(HealthSleepNight.summary, animation: .smooth) private var summaryEntries: [HealthSleepNight]

    private var latestEntry: HealthSleepNight? { summaryEntries.first }

    private var cardAccessibilityLabel: String {
        guard let latestEntry else { return AccessibilityText.healthSleepSectionEmptyValue }

        return AccessibilityText.healthSleepSectionValue(
            dateText: formattedSleepWakeDay(latestEntry.wakeDay),
            sleepText: formattedSleepDurationAccessibilityText(latestEntry.timeAsleep),
            timingText: formattedSleepTimingText(for: latestEntry),
            secondaryText: nil
        )
    }

    var body: some View {
        Button {
            Haptics.selection()
            router.navigate(to: .sleepHistory)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    HStack(spacing: 3) {
                        Image(systemName: "bed.double.fill")
                            .font(.subheadline)
                            .foregroundStyle(.indigo.gradient)
                            .accessibilityHidden(true)
                        Text("Sleep")
                            .fontWeight(.semibold)
                            .foregroundStyle(.indigo.gradient)
                    }

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
                        VStack(alignment: .leading, spacing: 0) {
                            SleepDurationValueView(duration: latestEntry.timeAsleep)
                            Text(formattedSleepTimingText(for: latestEntry))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fontDesign(.rounded)
                                .fontWeight(.semibold)
                        }

                        Spacer()

                        if summaryEntries.count > 1 {
                            HealthSleepSparkBarChart(entries: summaryEntries)
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
            .tint(.primary)
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier(AccessibilityIdentifiers.healthSleepSectionCard)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(cardAccessibilityLabel)
        .accessibilityHint(AccessibilityText.healthSleepSectionHint)
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
            BarMark(x: .value("Wake Day", HealthSleepNight.displayDate(forWakeDay: entry.wakeDay), unit: .day), y: .value("Time Asleep", entry.timeAsleep), width: .ratio(0.92))
                .foregroundStyle(entry.wakeDay == latestWakeDay ? AnyShapeStyle(Color.indigo.gradient) : AnyShapeStyle(Color.indigo.opacity(0.3).gradient))
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4))
        }
        .chartYScale(domain: yDomain)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
    }
}

func formattedSleepDurationText(_ duration: TimeInterval) -> String {
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

func formattedSleepDurationAccessibilityText(_ duration: TimeInterval) -> String {
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

func formattedSleepWakeDay(_ wakeDay: Date) -> String { formattedRecentDay(HealthSleepNight.displayDate(forWakeDay: wakeDay)) }

func formattedSleepTimingText(start: Date?, end: Date?) -> String {
    guard let start, let end else { return "No overnight sleep window" }
    return "\(start.formatted(date: .omitted, time: .shortened)) - \(end.formatted(date: .omitted, time: .shortened))"
}

func formattedSleepTimingText(for entry: HealthSleepNight) -> String { formattedSleepTimingText(start: entry.sleepStart, end: entry.sleepEnd) }

struct SleepDurationValueView: View {
    let duration: TimeInterval

    private var hours: Int { Int((duration / 3_600).rounded(.down)) }
    private var minutes: Int { max(0, Int((duration / 60).rounded()) - (hours * 60)) }

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            if hours > 0 {
                HStack(alignment: .lastTextBaseline, spacing: 0) {
                    Text(hours, format: .number)
                        .font(.largeTitle)
                    Text("hr")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .fontWeight(.semibold)
                }
                .padding(.trailing, 2)
            }
            HStack(alignment: .lastTextBaseline, spacing: 0) {
                Text(minutes, format: .number)
                    .font(.largeTitle)
                Text("min")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .fontWeight(.semibold)
            }
        }
        .bold()
        .fontDesign(.rounded)
    }
}
