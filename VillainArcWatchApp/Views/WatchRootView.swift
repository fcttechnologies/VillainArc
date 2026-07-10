import SwiftUI

struct WatchRootView: View {
    @Environment(WatchSessionStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            NavigationStack {
                WatchRestTimerView()
            }
            NavigationStack {
                WatchLiveSessionView()
            }
            NavigationStack {
                WatchStatsView()
            }
        }
        .tabViewStyle(.verticalPage)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                store.requestSync()
            }
        }
    }
}

// Zone tints match the iOS workout detail's zone cards.
func watchZoneColor(for zone: Int) -> Color {
    switch zone {
    case 1: return .blue
    case 2: return .green
    case 3: return .yellow
    case 4: return .orange
    default: return .red
    }
}

struct WatchHeartRateLabel: View {
    let heartRateBPM: Double?
    let zones: WatchHeartRateZoneConfig?

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "heart.fill")
                .foregroundStyle(.red)
            if let heartRateBPM {
                Text("\(Int(heartRateBPM.rounded())) bpm")
                    .monospacedDigit()
                if let zones {
                    let zone = zones.zone(for: heartRateBPM)
                    Text("Z\(zone)")
                        .font(.caption2.bold())
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(watchZoneColor(for: zone).opacity(0.25), in: .capsule)
                        .foregroundStyle(watchZoneColor(for: zone))
                }
            } else {
                Text("--")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.footnote)
    }
}
