import FCTMetrics
import SwiftData
import SwiftUI

struct HealthWristTemperatureHistoryView: View {
    @Query(HealthWristTemperature.history, animation: .smooth) private var entries: [HealthWristTemperature]
    @Query(AppSettings.single) private var appSettings: [AppSettings]
    @State private var selectedRange: TimeSeriesRangeFilter = .month

    private var latestEntry: HealthWristTemperature? { entries.first }
    private var temperatureUnit: TemperatureUnit { appSettings.first?.temperatureUnit ?? .systemDefault }
    private var samples: [TimeSeriesSample] {
        entries.map { TimeSeriesSample(date: $0.date, value: temperatureUnit.fromCelsius($0.temperature)) }
    }
    private var baselineTemperature: Double? {
        guard samples.count >= 5 else { return nil }
        return samples.reduce(0) { $0 + $1.value } / Double(samples.count)
    }

    var body: some View {
        HealthVitalsHistoryScreen(title: "Wrist Temperature") {
            VStack(alignment: .leading, spacing: 24) {
                HealthVitalsLineHistorySection(
                    samples: samples,
                    selectedRange: $selectedRange,
                    tint: .cyan,
                    latestDate: latestEntry?.date,
                    latestValue: latestEntry.map { temperatureUnit.fromCelsius($0.temperature) },
                    valueFormatter: { $0.formatted(.number.precision(.fractionLength(0...1))) },
                    unitText: temperatureUnit.unitLabel,
                    yAxisFormatter: { "\($0.formatted(.number.precision(.fractionLength(0...1)))) \(temperatureUnit.unitLabel)" },
                    baselineValue: baselineTemperature
                )

                HealthVitalsTrendSection(
                    samples: samples,
                    tint: .cyan,
                    metricDescription: "Sleeping wrist temperature is measured by Apple Watch during sleep and reflects your body's thermoregulatory state overnight. The dashed line shows your personal baseline — the average across all your readings. Wrist temperature is most meaningful as a deviation from your own norm rather than as an absolute number.",
                    upTrendDescription: "Rising wrist temperature during sleep can indicate illness, inflammation, hormonal changes, or a disrupted circadian rhythm.",
                    downTrendDescription: "Falling wrist temperature during sleep is common after recovering from illness or when sleep quality and consistency improve."
                )
            }
        }
        .diagScreen(VACrumb.healthWristTemperatureHistory)
    }
}
