import SwiftData
import SwiftUI

struct HealthRespiratoryRateSectionCard: View {
    let router = AppRouter.shared
    @Query(HealthRespiratoryRate.summary, animation: .smooth) private var entries: [HealthRespiratoryRate]

    private var latestEntry: HealthRespiratoryRate? { entries.first { $0.minRate != nil || $0.maxRate != nil } }
    private var rangePoints: [HealthRangeChartPoint] {
        entries.compactMap { entry in
            guard let low = entry.minRate, let high = entry.maxRate else { return nil }
            return HealthRangeChartPoint(date: entry.date, low: low, high: high)
        }
    }

    var body: some View {
        Button {
            router.push(to: .respiratoryRateHistory)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 4) {
                    Image(systemName: "lungs.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color.teal.gradient)
                    Text("Respiratory Rate")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.teal.gradient)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Spacer()
                    if let latestEntry {
                        Text(formattedRecentDay(latestEntry.date))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }
                }

                if let latestEntry, let low = latestEntry.minRate, let high = latestEntry.maxRate {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .lastTextBaseline, spacing: 3) {
                            Text("\(low.formatted(.number.precision(.fractionLength(0...1))))-\(high.formatted(.number.precision(.fractionLength(0...1))))")
                                .font(.title2)
                                .bold()
                                .fontDesign(.rounded)
                            Text("br/min")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                        }

                        HealthVitalsMiniRangeChart(points: rangePoints, tint: .teal)
                            .frame(height: 58)
                            .accessibilityHidden(true)
                    }
                } else {
                    Text("Respiratory rate will show up here after Apple Health syncs.")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .appCardStyle()
            .tint(.primary)
        }
        .buttonStyle(.borderless)
    }
}
