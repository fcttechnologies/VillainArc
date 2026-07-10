import SwiftUI

enum WatchPage: Hashable {
    case restTimer
    case liveSession
    case stats
}

struct WatchRootView: View {
    @Environment(WatchSessionStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedPage: WatchPage = .restTimer

    var body: some View {
        TabView(selection: $selectedPage) {
            NavigationStack {
                WatchRestTimerView()
            }
            .tag(WatchPage.restTimer)
            NavigationStack {
                WatchLiveSessionView()
            }
            .tag(WatchPage.liveSession)
            NavigationStack {
                WatchStatsView()
            }
            .tag(WatchPage.stats)
        }
        .tabViewStyle(.verticalPage)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                store.requestSync()
            }
        }
        // Glanceability: jump to what matters the moment it starts — a rest timer
        // takes the wrist over a live session (it's the thing being timed right now).
        .onChange(of: store.payload?.restTimer?.isActive ?? false) { wasActive, isActive in
            if isActive, !wasActive {
                selectedPage = .restTimer
            }
        }
        .onChange(of: store.payload?.liveSession != nil) { hadSession, hasSession in
            if hasSession, !hadSession, !(store.payload?.restTimer?.isActive ?? false) {
                selectedPage = .liveSession
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
