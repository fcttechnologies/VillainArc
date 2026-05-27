import Charts
import SwiftData
import SwiftUI

struct SleepTimingInsightsView: View {
    @Query(HealthSleepNight.history, animation: .smooth) private var entries: [HealthSleepNight]

    private var windowEntries: [HealthSleepNight] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return entries.filter { $0.wakeDay >= cutoff && $0.sleepStart != nil && $0.sleepEnd != nil }
    }

    private var trendEntries: [HealthSleepNight] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        return entries
            .filter { $0.wakeDay >= cutoff && $0.sleepStart != nil && $0.sleepEnd != nil }
            .sorted { $0.wakeDay < $1.wakeDay }
    }

    private var bedTimeStats: TimingStats? {
        TimingStats.compute(values: windowEntries.compactMap { $0.sleepStart.map { minutesFromMidnightCentered(at: $0) } })
    }

    private var wakeTimeStats: TimingStats? {
        TimingStats.compute(values: windowEntries.compactMap { $0.sleepEnd.map { minutesFromMidnightCentered(at: $0, isWake: true) } })
    }

    private var avgSleepHours: Double? {
        let totals = windowEntries.map(\.timeAsleep).filter { $0 > 0 }
        guard !totals.isEmpty else { return nil }
        return (totals.reduce(0, +) / Double(totals.count)) / 3600
    }

    private var sleepEfficiency: Double? {
        let pairs = windowEntries.compactMap { entry -> (Double, Double)? in
            guard entry.timeInBed > 0, entry.timeAsleep > 0 else { return nil }
            return (entry.timeAsleep, entry.timeInBed)
        }
        guard !pairs.isEmpty else { return nil }
        let asleep = pairs.map(\.0).reduce(0, +)
        let inBed = pairs.map(\.1).reduce(0, +)
        return min(1.0, asleep / max(inBed, 1))
    }

    private var consistencyScore: Int? {
        guard let bedStd = bedTimeStats?.stdDevMinutes, let wakeStd = wakeTimeStats?.stdDevMinutes else { return nil }
        let combined = (bedStd + wakeStd) / 2
        let normalized = max(0, min(1, 1 - (combined / 120)))
        return Int((normalized * 100).rounded())
    }

    private var bedTimeShiftMinutes: Int? {
        timingShiftMinutes(values: trendEntries.compactMap { $0.sleepStart.map { minutesFromMidnightCentered(at: $0) } })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if windowEntries.count < 3 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Need a few more nights")
                            .font(.headline)
                        Text("Log or sync at least 3 nights of sleep to see your timing patterns.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .appCardStyle()
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        TimingStatTile(title: String(localized: "Avg Bedtime"), value: formattedTime(bedTimeStats?.meanMinutes), spread: bedTimeStats?.stdDevMinutes, tint: .indigo, systemImage: "moon.fill")
                        TimingStatTile(title: String(localized: "Avg Wake"), value: formattedTime(wakeTimeStats?.meanMinutes, isWake: true), spread: wakeTimeStats?.stdDevMinutes, tint: .yellow, systemImage: "sun.max.fill")
                        TimingStatTile(title: String(localized: "Avg Sleep"), value: avgSleepHours.map { formatHours($0) } ?? "—", spread: nil, tint: .teal, systemImage: "bed.double.fill")
                        TimingStatTile(title: String(localized: "Consistency"), value: consistencyScore.map { "\($0)" } ?? "—", spread: nil, tint: .purple, systemImage: "waveform.path.ecg")
                    }

                    if let efficiency = sleepEfficiency {
                        HStack(spacing: 12) {
                            Image(systemName: "gauge.medium")
                                .foregroundStyle(.green.gradient)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Sleep Efficiency")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(Int((efficiency * 100).rounded()))%")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .fontDesign(.rounded)
                            }
                            Spacer()
                            Text("of time in bed asleep")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .appCardStyle()
                    }

                    if trendEntries.count >= 3 {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Bed & Wake — Last 14 Days")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Chart {
                                ForEach(trendEntries, id: \.wakeDay) { entry in
                                    if let start = entry.sleepStart {
                                        PointMark(x: .value("Day", HealthSleepNight.displayDate(forWakeDay: entry.wakeDay)), y: .value("Bedtime", minutesFromMidnightCentered(at: start)))
                                            .foregroundStyle(Color.indigo)
                                            .symbol(.circle)
                                    }
                                    if let end = entry.sleepEnd {
                                        PointMark(x: .value("Day", HealthSleepNight.displayDate(forWakeDay: entry.wakeDay)), y: .value("Wake", minutesFromMidnightCentered(at: end, isWake: true)))
                                            .foregroundStyle(Color.yellow)
                                            .symbol(.square)
                                    }
                                }
                            }
                            .chartYAxis {
                                AxisMarks(values: .automatic(desiredCount: 6)) { value in
                                    AxisGridLine()
                                    AxisValueLabel {
                                        if let minutes = value.as(Double.self) {
                                            Text(formattedTime(minutes))
                                        }
                                    }
                                }
                            }
                            .chartXAxis {
                                AxisMarks(values: .automatic(desiredCount: 4))
                            }
                            .frame(height: 220)
                            .accessibilityLabel(Text("Bed and wake time chart over the last 14 days"))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .appCardStyle()
                    }

                    if let shift = bedTimeShiftMinutes, abs(shift) >= 5 {
                        InsightCard(text: insightText(forShift: shift))
                    } else if windowEntries.count >= 7 {
                        InsightCard(text: String(localized: "Your bed time has stayed remarkably steady over the last week."))
                    }
                }
            }
            .padding()
        }
        .quickActionContentBottomInset()
        .appBackground()
        .navigationTitle("Sleep Timing")
        .toolbarTitleDisplayMode(.inline)
        .accessibilityIdentifier(AccessibilityIdentifiers.sleepTimingInsightsRoot)
        .task { await IntentDonations.donateShowSleepInsights() }
    }

    private func insightText(forShift shiftMinutes: Int) -> String {
        let direction = shiftMinutes > 0 ? String(localized: "later") : String(localized: "earlier")
        return String(localized: "Your bed time has shifted \(direction) by \(abs(shiftMinutes)) min over the last week.")
    }
}

private struct InsightCard: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(.yellow.gradient)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding()
        .appCardStyle()
    }
}

private struct TimingStatTile: View {
    let title: String
    let value: String
    let spread: Double?
    let tint: Color
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.caption)
                    .foregroundStyle(tint.gradient)
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(tint.gradient)
            }
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .fontDesign(.rounded)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let spread {
                Text("± \(Int(spread.rounded())) min")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text(" ")
                    .font(.caption2)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardStyle()
    }
}

struct TimingStats {
    let meanMinutes: Double
    let stdDevMinutes: Double

    static func compute(values: [Double]) -> TimingStats? {
        guard values.count >= 2 else { return nil }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        return TimingStats(meanMinutes: mean, stdDevMinutes: sqrt(variance))
    }
}

/// For bedtime values where time can wrap past midnight, returns minutes from
/// midnight on a -360...+1080 scale centered around evening (so 11pm = -60, 1am = 60).
nonisolated func minutesFromMidnightCentered(at date: Date, isWake: Bool = false) -> Double {
    let components = Calendar.current.dateComponents([.hour, .minute], from: date)
    let mins = Double(components.hour ?? 0) * 60 + Double(components.minute ?? 0)
    if isWake {
        // wake times around 5am-11am, keep 0..1440
        return mins
    } else {
        // bedtime: if before noon, treat as next-day early-morning bedtime (e.g. 1am = 1500 minutes)
        if mins < 12 * 60 {
            return mins + 24 * 60
        }
        return mins
    }
}

nonisolated func formattedTime(_ centeredMinutes: Double?, isWake: Bool = false) -> String {
    guard let centeredMinutes else { return "—" }
    var minutes = Int(centeredMinutes.rounded())
    if !isWake, minutes >= 24 * 60 { minutes -= 24 * 60 }
    let hour = (minutes / 60) % 24
    let minute = ((minutes % 60) + 60) % 60
    var comps = DateComponents()
    comps.hour = hour
    comps.minute = minute
    let date = Calendar.current.date(from: comps) ?? Date()
    return date.formatted(date: .omitted, time: .shortened)
}

nonisolated func formatHours(_ hours: Double) -> String {
    let totalMinutes = Int((hours * 60).rounded())
    let h = totalMinutes / 60
    let m = totalMinutes % 60
    if h > 0 && m > 0 { return "\(h)h \(m)m" }
    if h > 0 { return "\(h)h" }
    return "\(m)m"
}

private func timingShiftMinutes(values: [Double]) -> Int? {
    guard values.count >= 4 else { return nil }
    let half = values.count / 2
    let earlier = values.prefix(half)
    let later = values.suffix(values.count - half)
    guard !earlier.isEmpty, !later.isEmpty else { return nil }
    let earlierMean = earlier.reduce(0, +) / Double(earlier.count)
    let laterMean = later.reduce(0, +) / Double(later.count)
    return Int((laterMean - earlierMean).rounded())
}

#Preview(traits: .sampleData) {
    NavigationStack { SleepTimingInsightsView() }
}
