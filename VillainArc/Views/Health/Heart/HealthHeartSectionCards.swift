import Charts
import SwiftData
import SwiftUI

struct HealthHeartRateSectionCard: View {
    let router = AppRouter.shared
    @Query(HealthHeart.summary, animation: .smooth) private var entries: [HealthHeart]

    private var latestEntry: HealthHeart? { entries.first { $0.minHeartRate != nil || $0.maxHeartRate != nil } }
    private var rangePoints: [HealthRangeChartPoint] {
        entries.compactMap { entry in
            guard let low = entry.minHeartRate, let high = entry.maxHeartRate else { return nil }
            return HealthRangeChartPoint(date: entry.date, low: low, high: high)
        }
    }

    var body: some View {
        HealthVitalMetricCard(
            title: "Heart Rate",
            systemImage: "heart.fill",
            tint: .red,
            valueText: latestEntry.flatMap { entry in
                guard let low = entry.minHeartRate, let high = entry.maxHeartRate else { return nil }
                return "\(Int(low.rounded()))-\(Int(high.rounded()))"
            },
            unitText: "bpm",
            dateText: latestEntry.map { formattedCompactRecentDay($0.date) },
            emptyText: "Heart rate ranges will show up here after Apple Health syncs.",
            destination: .heartRateHistory
        ) {
            HealthVitalsMiniRangeChart(points: rangePoints, tint: .red)
        }
    }
}

struct HealthRestingHeartRateSectionCard: View {
    @Query(HealthHeart.summary, animation: .smooth) private var entries: [HealthHeart]

    private var latestEntry: HealthHeart? { entries.first { $0.restingHeartRate != nil } }
    private var samples: [TimeSeriesSample] {
        entries.compactMap { entry in entry.restingHeartRate.map { TimeSeriesSample(date: entry.date, value: $0) } }
    }

    var body: some View {
        HealthVitalMetricCard(
            title: "Resting HR",
            systemImage: "heart.text.square.fill",
            tint: .pink,
            valueText: latestEntry?.restingHeartRate.map { "\(Int($0.rounded()))" },
            unitText: "bpm",
            dateText: latestEntry.map { formattedCompactRecentDay($0.date) },
            emptyText: "Resting heart rate will show up here after Apple Health syncs.",
            destination: .restingHeartRateHistory
        ) {
            HealthVitalsMiniLineChart(samples: samples, tint: .pink)
        }
    }
}

struct HealthWalkingHeartRateSectionCard: View {
    @Query(HealthHeart.summary, animation: .smooth) private var entries: [HealthHeart]

    private var latestEntry: HealthHeart? { entries.first { $0.walkingHeartRateAverage != nil } }
    private var samples: [TimeSeriesSample] {
        entries.compactMap { entry in entry.walkingHeartRateAverage.map { TimeSeriesSample(date: entry.date, value: $0) } }
    }

    var body: some View {
        HealthVitalMetricCard(
            title: "Walking HR",
            systemImage: "figure.walk",
            tint: .orange,
            valueText: latestEntry?.walkingHeartRateAverage.map { "\(Int($0.rounded()))" },
            unitText: "bpm",
            dateText: latestEntry.map { formattedCompactRecentDay($0.date) },
            emptyText: "Walking heart rate will show up here after Apple Health syncs.",
            destination: .walkingHeartRateHistory
        ) {
            HealthVitalsMiniLineChart(samples: samples, tint: .orange)
        }
    }
}

struct HealthHeartRateVariabilitySectionCard: View {
    @Query(HealthHeart.summary, animation: .smooth) private var entries: [HealthHeart]

    private var latestEntry: HealthHeart? { entries.first { $0.heartRateVariabilitySDNN != nil } }
    private var samples: [TimeSeriesSample] {
        entries.compactMap { entry in entry.heartRateVariabilitySDNN.map { TimeSeriesSample(date: entry.date, value: $0) } }
    }

    var body: some View {
        HealthVitalMetricCard(
            title: "HRV",
            systemImage: "waveform.path.ecg",
            tint: .purple,
            valueText: latestEntry?.heartRateVariabilitySDNN.map { "\(Int($0.rounded()))" },
            unitText: "ms",
            dateText: latestEntry.map { formattedCompactRecentDay($0.date) },
            emptyText: "Heart rate variability will show up here after Apple Health syncs.",
            destination: .heartRateVariabilityHistory
        ) {
            HealthVitalsMiniLineChart(samples: samples, tint: .purple)
        }
    }
}

private struct HealthVitalMetricCard<ChartContent: View>: View {
    let title: String
    let systemImage: String
    let tint: Color
    let valueText: String?
    let unitText: String
    let dateText: String?
    let emptyText: String
    let destination: AppRouter.Destination
    @ViewBuilder let chart: () -> ChartContent

    private let router = AppRouter.shared

    var body: some View {
        Button {
            router.push(to: destination)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 0) {
                    Image(systemName: systemImage)
                        .font(.subheadline)
                        .foregroundStyle(tint.gradient)
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(tint.gradient)
                    Spacer()
                    if let dateText {
                        Text(dateText)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }
                }

                if let valueText {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .lastTextBaseline, spacing: 3) {
                            Text(valueText)
                                .font(.title2)
                                .bold()
                                .fontDesign(.rounded)
                            Text(unitText)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                        }

                        chart()
                            .frame(height: 58)
                            .accessibilityHidden(true)
                    }
                } else {
                    Text(emptyText)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
            }
            .healthVitalCardSizing()
            .padding()
            .appCardStyle()
            .tint(.primary)
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier(AccessibilityIdentifiers.healthHeartSectionCard(title))
    }
}
