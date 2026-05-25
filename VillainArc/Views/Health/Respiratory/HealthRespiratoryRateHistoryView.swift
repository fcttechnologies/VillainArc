import SwiftData
import SwiftUI

struct HealthRespiratoryRateHistoryView: View {
    @Query(HealthRespiratoryRate.history, animation: .smooth) private var entries: [HealthRespiratoryRate]
    @State private var selectedRange: TimeSeriesRangeFilter = .month

    private var latestEntry: HealthRespiratoryRate? { entries.first { $0.minRate != nil || $0.maxRate != nil } }
    private var points: [HealthRangeChartPoint] {
        entries.compactMap { entry in
            guard let low = entry.minRate, let high = entry.maxRate else { return nil }
            return HealthRangeChartPoint(date: entry.date, low: low, high: high)
        }
    }
    private var trendSamples: [TimeSeriesSample] {
        points.map { TimeSeriesSample(date: $0.date, value: ($0.low + $0.high) / 2) }
    }

    var body: some View {
        HealthVitalsHistoryScreen(title: "Respiratory Rate") {
            VStack(alignment: .leading, spacing: 24) {
                HealthVitalsRangeHistorySection(
                    points: points,
                    selectedRange: $selectedRange,
                    tint: .teal,
                    latestDate: latestEntry?.date,
                    latestLow: latestEntry?.minRate,
                    latestHigh: latestEntry?.maxRate,
                    valueFormatter: { $0.formatted(.number.precision(.fractionLength(0...1))) },
                    unitText: "br/min",
                    yAxisFormatter: { $0.formatted(.number.precision(.fractionLength(0...1))) }
                )

                HealthVitalsTrendSection(
                    samples: trendSamples,
                    tint: .teal,
                    metricDescription: "Respiratory rate is the number of breaths taken per minute, typically measured during sleep. The normal range at rest is 12–20 breaths per minute. Apple Watch measures your rate while you sleep. Elevated rates can signal illness, poor sleep quality, or increased physiological stress.",
                    upTrendDescription: "A rising respiratory rate at rest may indicate illness, poorer sleep quality, or elevated stress. Sustained elevation above your normal range is worth monitoring.",
                    downTrendDescription: "A declining respiratory rate at rest generally reflects better sleep quality, reduced stress, or recovery from illness."
                )
            }
        }
    }
}
