import SwiftUI

/// Lets the user choose which metrics the cardio Live Activity shows (default heart + current pace).
/// The selection is capped at `CardioLiveActivityMetricConfig.maxMetrics`; picking past the cap drops
/// the oldest choice so the newest pick always lands. Persisted to the App Group so the widget reads
/// the same value.
struct CardioLiveActivityMetricPickerView: View {
    @State private var config = CardioLiveActivityMetricStore.load()

    private var metrics: [CardioLiveActivityMetric] { CardioLiveActivityMetric.allCases }

    var body: some View {
        Form {
            Section {
                ForEach(Array(metrics.enumerated()), id: \.element) { index, metric in
                    Button {
                        Haptics.selection()
                        config = config.toggling(metric)
                        CardioLiveActivityMetricStore.save(config)
                    } label: {
                        HStack {
                            Label(metric.displayName, systemImage: metric.systemImage)
                                .foregroundStyle(.primary)
                            Spacer()
                            if config.contains(metric) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.cardioLiveActivityMetricRow(metric.rawValue))
                    .accessibilityAddTraits(config.contains(metric) ? .isSelected : [])
                    .appGroupedListRow(position: rowPosition(for: index, count: metrics.count))
                }
            } header: {
                Text("Live Activity Metrics")
            } footer: {
                Text("Choose up to \(CardioLiveActivityMetricConfig.maxMetrics) metrics to show on the cardio Live Activity. Selecting a new one when two are already chosen replaces the oldest.")
            }
        }
        .navigationTitle("Cardio Metrics")
        .toolbarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .sheetBackground()
    }

    private func rowPosition(for index: Int, count: Int) -> AppGroupedListRowPosition {
        if count == 1 { return .single }
        if index == 0 { return .top }
        if index == count - 1 { return .bottom }
        return .middle
    }
}
