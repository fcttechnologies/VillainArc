import SwiftUI

struct WatchLiveSessionView: View {
    @Environment(WatchSessionStore.self) private var store

    var body: some View {
        Group {
            if let live = store.payload?.liveSession {
                ScrollView {
                    switch live.kind {
                    case .strength:
                        strengthView(live)
                    case .cardio:
                        cardioView(live)
                    }
                }
            } else {
                noSessionView
            }
        }
        .navigationTitle("Workout")
    }

    // MARK: - Strength

    @ViewBuilder
    private func strengthView(_ live: WatchLiveSessionSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            header(live)

            if let exerciseName = live.exerciseName {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exerciseName)
                        .font(.headline)
                        .lineLimit(2)
                    if let setPosition = live.setPosition, let setCount = live.setCount {
                        Text("Set \(setPosition) of \(setCount)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if let targetText = live.targetText {
                        Text(targetText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 10))
            } else {
                Text("All sets complete")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let completedSets = live.completedSets, let totalSets = live.totalSets, totalSets > 0 {
                Gauge(value: Double(completedSets), in: 0...Double(totalSets)) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .gaugeStyle(.accessoryLinearCapacity)
                .tint(.orange)
                Text("\(completedSets) of \(totalSets) sets")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if live.exerciseName != nil {
                Button {
                    store.send(.completeActiveSet)
                } label: {
                    Label("Complete Set", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
        }
    }

    // MARK: - Cardio

    @ViewBuilder
    private func cardioView(_ live: WatchLiveSessionSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            header(live)

            VStack(alignment: .leading, spacing: 6) {
                if let distanceText = live.distanceText {
                    metricRow(title: "Distance", value: distanceText)
                }
                if let paceText = live.paceText {
                    metricRow(title: "Pace", value: paceText)
                }
                if let activeEnergyText = live.activeEnergyText {
                    metricRow(title: "Energy", value: activeEnergyText)
                }
                if live.distanceText == nil && live.paceText == nil && live.activeEnergyText == nil {
                    Text("Metrics appear as your session records.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 10))
        }
    }

    private func metricRow(title: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.footnote, design: .rounded, weight: .semibold))
                .monospacedDigit()
        }
    }

    // MARK: - Shared

    @ViewBuilder
    private func header(_ live: WatchLiveSessionSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(live.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(timerInterval: live.startedAt...Date.distantFuture, countsDown: false)
                    .font(.system(.footnote, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.orange)
            }
            WatchHeartRateLabel(heartRateBPM: live.heartRateBPM, zones: store.payload?.heartRateZones)
        }
    }

    private var noSessionView: some View {
        VStack(spacing: 6) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No Active Session")
                .font(.headline)
            Text("Start a workout on your iPhone to see it here live.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}
