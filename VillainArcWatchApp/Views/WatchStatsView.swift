import SwiftUI

struct WatchStatsView: View {
    @Environment(WatchSessionStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                heartSection
                lastWorkoutSection
                if !store.hasReceivedData {
                    Text("Open Villain Arc on your iPhone to sync.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("Stats")
    }

    // MARK: - Heart / zones

    @ViewBuilder
    private var heartSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                WatchHeartRateLabel(heartRateBPM: currentHeartRate, zones: store.payload?.heartRateZones)
                Spacer()
                if let restingHeartRate = store.payload?.quickStats?.restingHeartRateBPM {
                    Text("Resting \(Int(restingHeartRate.rounded()))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            if let zones = store.payload?.heartRateZones {
                zoneList(zones)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 10))
    }

    private var currentHeartRate: Double? {
        store.payload?.liveSession?.heartRateBPM
    }

    @ViewBuilder
    private func zoneList(_ zones: WatchHeartRateZoneConfig) -> some View {
        let currentZone = currentHeartRate.map { zones.zone(for: $0) }
        VStack(alignment: .leading, spacing: 3) {
            ForEach(1...5, id: \.self) { zone in
                let bounds = zones.bounds(for: zone)
                HStack(spacing: 5) {
                    Circle()
                        .fill(watchZoneColor(for: zone))
                        .frame(width: 6, height: 6)
                    Text("Z\(zone)")
                        .font(.caption2.bold())
                        .foregroundStyle(zone == currentZone ? watchZoneColor(for: zone) : .secondary)
                    Spacer()
                    Text(boundsText(bounds))
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func boundsText(_ bounds: (lower: Double?, upper: Double?)) -> String {
        switch (bounds.lower, bounds.upper) {
        case (nil, let upper?):
            return "< \(Int(upper.rounded(.down)))"
        case (let lower?, nil):
            return "\(Int(lower.rounded(.down)))+"
        case (let lower?, let upper?):
            return "\(Int(lower.rounded(.down)))–\(Int(upper.rounded(.down)))"
        default:
            return ""
        }
    }

    // MARK: - Last workout

    @ViewBuilder
    private var lastWorkoutSection: some View {
        if let stats = store.payload?.quickStats, let title = stats.lastWorkoutTitle {
            VStack(alignment: .leading, spacing: 3) {
                Text("Last Workout")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.headline)
                    .lineLimit(2)
                if let date = stats.lastWorkoutDate {
                    Text(date, format: .relative(presentation: .named))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    if let duration = stats.lastWorkoutDurationSeconds, duration > 0 {
                        statText(durationText(duration))
                    }
                    if let sets = stats.lastWorkoutSets, sets > 0 {
                        statText(String(localized: "\(sets) sets"))
                    }
                }
                if let volumeText = stats.lastWorkoutVolumeText {
                    statText(volumeText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 10))
        }
    }

    private func statText(_ text: String) -> some View {
        Text(text)
            .font(.system(.footnote, design: .rounded, weight: .semibold))
            .monospacedDigit()
    }

    private func durationText(_ duration: TimeInterval) -> String {
        Duration.seconds(duration).formatted(.units(allowed: [.hours, .minutes], width: .narrow))
    }
}
