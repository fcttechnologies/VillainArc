import FCTMetrics
import SwiftData
import SwiftUI

struct HealthHeartRateHistoryView: View {
    @Query(HealthHeart.history, animation: .smooth) private var entries: [HealthHeart]
    @State private var selectedRange: TimeSeriesRangeFilter = .month

    private var latestEntry: HealthHeart? { entries.first { $0.minHeartRate != nil || $0.maxHeartRate != nil } }
    private var points: [HealthRangeChartPoint] {
        entries.compactMap { entry in
            guard let low = entry.minHeartRate, let high = entry.maxHeartRate else { return nil }
            return HealthRangeChartPoint(date: entry.date, low: low, high: high)
        }
    }
    private var trendSamples: [TimeSeriesSample] {
        points.map { TimeSeriesSample(date: $0.date, value: ($0.low + $0.high) / 2) }
    }

    var body: some View {
        HealthVitalsHistoryScreen(title: "Heart Rate") {
            VStack(alignment: .leading, spacing: 24) {
                HealthVitalsRangeHistorySection(
                    points: points,
                    selectedRange: $selectedRange,
                    tint: .red,
                    latestDate: latestEntry?.date,
                    latestLow: latestEntry?.minHeartRate,
                    latestHigh: latestEntry?.maxHeartRate,
                    valueFormatter: { "\(Int($0.rounded()))" },
                    unitText: "bpm",
                    yAxisFormatter: { "\(Int($0.rounded()))" }
                )

                HealthVitalsTrendSection(
                    samples: trendSamples,
                    tint: .red,
                    metricDescription: "Heart rate range shows the spread between your lowest and highest measured heart rate during the day. A wide range with a low floor generally indicates strong cardiovascular fitness. The typical resting range is 60–100 bpm.",
                    upTrendDescription: "Your average heart rate has been trending higher. This can result from increased activity, reduced recovery, elevated stress, or illness.",
                    downTrendDescription: "Your average heart rate has been trending lower. This often reflects improving cardiovascular efficiency or better recovery."
                )
            }
        }
        .diagScreen(VACrumb.healthHeartRateHistory)
    }
}

struct HealthRestingHeartRateHistoryView: View {
    @Query(HealthHeart.history, animation: .smooth) private var entries: [HealthHeart]
    @State private var selectedRange: TimeSeriesRangeFilter = .month

    private var latestEntry: HealthHeart? { entries.first { $0.restingHeartRate != nil } }
    private var samples: [TimeSeriesSample] {
        entries.compactMap { entry in entry.restingHeartRate.map { TimeSeriesSample(date: entry.date, value: $0) } }
    }

    var body: some View {
        HealthVitalsHistoryScreen(title: "Resting Heart Rate") {
            VStack(alignment: .leading, spacing: 24) {
                HealthVitalsLineHistorySection(
                    samples: samples,
                    selectedRange: $selectedRange,
                    tint: .pink,
                    latestDate: latestEntry?.date,
                    latestValue: latestEntry?.restingHeartRate,
                    valueFormatter: { "\(Int($0.rounded()))" },
                    unitText: "bpm",
                    yAxisFormatter: { "\(Int($0.rounded()))" }
                )

                HealthVitalsTrendSection(
                    samples: samples,
                    tint: .pink,
                    metricDescription: "Resting heart rate is the number of times your heart beats per minute at complete rest. The typical range is 60–100 bpm. Trained athletes often see 40–60 bpm. A lower resting heart rate generally indicates a stronger, more efficient heart.",
                    upTrendDescription: "A rising resting heart rate can signal accumulated fatigue, illness, reduced fitness, or elevated stress. Poor sleep and overtraining are common contributors.",
                    downTrendDescription: "A declining resting heart rate often reflects improving cardiovascular fitness, better recovery, or reduced chronic stress."
                )
            }
        }
        .diagScreen(VACrumb.healthRestingHeartRateHistory)
    }
}

struct HealthWalkingHeartRateHistoryView: View {
    @Query(HealthHeart.history, animation: .smooth) private var entries: [HealthHeart]
    @State private var selectedRange: TimeSeriesRangeFilter = .month

    private var latestEntry: HealthHeart? { entries.first { $0.walkingHeartRateAverage != nil } }
    private var samples: [TimeSeriesSample] {
        entries.compactMap { entry in entry.walkingHeartRateAverage.map { TimeSeriesSample(date: entry.date, value: $0) } }
    }

    var body: some View {
        HealthVitalsHistoryScreen(title: "Walking Heart Rate") {
            VStack(alignment: .leading, spacing: 24) {
                HealthVitalsLineHistorySection(
                    samples: samples,
                    selectedRange: $selectedRange,
                    tint: .orange,
                    latestDate: latestEntry?.date,
                    latestValue: latestEntry?.walkingHeartRateAverage,
                    valueFormatter: { "\(Int($0.rounded()))" },
                    unitText: "bpm",
                    yAxisFormatter: { "\(Int($0.rounded()))" }
                )

                HealthVitalsTrendSection(
                    samples: samples,
                    tint: .orange,
                    metricDescription: "Walking heart rate average is the mean heart rate measured while you are in motion during the day. A lower walking heart rate generally reflects better cardiovascular efficiency and aerobic conditioning. The typical range is 60–100 bpm.",
                    upTrendDescription: "A rising walking heart rate can indicate reduced cardiovascular efficiency, fatigue, illness, or increased physical demand from daily activity.",
                    downTrendDescription: "A declining walking heart rate often reflects improving aerobic fitness and cardiovascular efficiency from consistent physical activity."
                )
            }
        }
        .diagScreen(VACrumb.healthWalkingHeartRateHistory)
    }
}

struct HealthHeartRateVariabilityHistoryView: View {
    @Query(HealthHeart.history, animation: .smooth) private var entries: [HealthHeart]
    @State private var selectedRange: TimeSeriesRangeFilter = .month

    private var latestEntry: HealthHeart? { entries.first { $0.heartRateVariabilitySDNN != nil } }
    private var samples: [TimeSeriesSample] {
        entries.compactMap { entry in entry.heartRateVariabilitySDNN.map { TimeSeriesSample(date: entry.date, value: $0) } }
    }

    var body: some View {
        HealthVitalsHistoryScreen(title: "HRV") {
            VStack(alignment: .leading, spacing: 24) {
                HealthVitalsLineHistorySection(
                    samples: samples,
                    selectedRange: $selectedRange,
                    tint: .purple,
                    latestDate: latestEntry?.date,
                    latestValue: latestEntry?.heartRateVariabilitySDNN,
                    valueFormatter: { "\(Int($0.rounded()))" },
                    unitText: "ms",
                    yAxisFormatter: { "\(Int($0.rounded()))" }
                )

                HealthVitalsTrendSection(
                    samples: samples,
                    tint: .purple,
                    metricDescription: "Heart rate variability (HRV) measures the variation in time between consecutive heartbeats. Higher HRV generally reflects better recovery capacity, aerobic fitness, and resilience to stress. HRV varies significantly between individuals and naturally declines with age.",
                    upTrendDescription: "Rising HRV is a positive signal. It often reflects better recovery, lower chronic stress, improved aerobic fitness, or higher sleep quality.",
                    downTrendDescription: "Falling HRV can indicate accumulated training stress, illness, poor sleep, or elevated anxiety. A sustained downward trend is worth monitoring."
                )
            }
        }
        .diagScreen(VACrumb.healthHeartRateVariabilityHistory)
    }
}

struct HealthVitalsHistoryScreen<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            content()
                .padding()
        }
        .quickActionContentBottomInset()
        .appBackground()
        .navigationTitle(title)
        .toolbarTitleDisplayMode(.inline)
    }
}
