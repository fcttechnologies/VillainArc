import SwiftData
import SwiftUI

struct HealthWristTemperatureSectionCard: View {
    let router = AppRouter.shared
    @Query(HealthWristTemperature.summary, animation: .smooth) private var entries: [HealthWristTemperature]
    @Query(AppSettings.single) private var appSettings: [AppSettings]

    private var latestEntry: HealthWristTemperature? { entries.first }
    private var temperatureUnit: TemperatureUnit { appSettings.first?.temperatureUnit ?? .systemDefault }
    private var samples: [TimeSeriesSample] {
        entries.map { TimeSeriesSample(date: $0.date, value: temperatureUnit.fromCelsius($0.temperature)) }
    }

    var body: some View {
        Button {
            router.push(to: .wristTemperatureHistory)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 4) {
                    Image(systemName: "thermometer.medium")
                        .font(.subheadline)
                        .foregroundStyle(Color.cyan.gradient)
                    Text("Wrist Temperature")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.cyan.gradient)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Spacer()
                    if let latestEntry {
                        Text(formattedCompactRecentDay(latestEntry.date))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }
                }

                if let latestEntry {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .lastTextBaseline, spacing: 3) {
                            Text(temperatureUnit.fromCelsius(latestEntry.temperature), format: .number.precision(.fractionLength(1)))
                                .font(.title2)
                                .bold()
                                .fontDesign(.rounded)
                            Text(temperatureUnit.unitLabel)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                        }

                        HealthVitalsMiniLineChart(samples: samples, tint: .cyan)
                            .frame(height: 58)
                            .accessibilityHidden(true)
                    }
                } else {
                    Text("Sleeping wrist temperature will show up here after Apple Health syncs.")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
            }
            .healthVitalCardSizing()
            .padding()
            .appCardStyle()
            .tint(.primary)
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier(AccessibilityIdentifiers.healthWristTemperatureSectionCard)
    }
}
