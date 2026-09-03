import SwiftUI

struct WatchRestTimerView: View {
    @Environment(WatchSessionStore.self) private var store

    private static let presetSeconds = [30, 60, 90, 120, 180, 300]

    var body: some View {
        Group {
            if let timer = store.payload?.restTimer, timer.isActive {
                activeTimerView(timer)
            } else {
                presetListView
            }
        }
        .navigationTitle("Rest Timer")
    }

    // MARK: - Active timer

    @ViewBuilder
    private func activeTimerView(_ timer: WatchRestTimerSnapshot) -> some View {
        ScrollView {
            VStack(spacing: 10) {
                countdownDial(timer)
                HStack(spacing: 8) {
                    adjustButton(label: "-15s", systemImage: "minus", deltaSeconds: -15)
                    pauseResumeButton(timer)
                    adjustButton(label: "+15s", systemImage: "plus", deltaSeconds: 15)
                }
                Button {
                    store.send(.stopRestTimer)
                } label: {
                    Label("Skip", systemImage: "forward.end.fill")
                }
                .tint(.red)
            }
        }
    }

    @ViewBuilder
    private func countdownDial(_ timer: WatchRestTimerSnapshot) -> some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 7)
            TimelineView(.periodic(from: .now, by: 0.5)) { context in
                Circle()
                    .trim(from: 0, to: remainingFraction(timer, at: context.date))
                    .stroke(.orange, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            VStack(spacing: 0) {
                if let endDate = timer.endDate, !timer.isPaused {
                    Text(timerInterval: Date.now...endDate, countsDown: true)
                        .font(.system(.title2, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .multilineTextAlignment(.center)
                } else {
                    Text(timeText(seconds: timer.pausedRemainingSeconds))
                        .font(.system(.title2, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                    Text("Paused")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 108, height: 108)
        .padding(.top, 2)
    }

    private func remainingFraction(_ timer: WatchRestTimerSnapshot, at date: Date) -> Double {
        guard timer.startedSeconds > 0 else { return 0 }
        let remaining: Double
        if let endDate = timer.endDate, !timer.isPaused {
            remaining = max(0, endDate.timeIntervalSince(date))
        } else {
            remaining = Double(timer.pausedRemainingSeconds)
        }
        return min(1, remaining / Double(timer.startedSeconds))
    }

    private func adjustButton(label: LocalizedStringKey, systemImage: String, deltaSeconds: Int) -> some View {
        Button {
            store.send(.adjustRestTimer(deltaSeconds: deltaSeconds))
        } label: {
            Image(systemName: systemImage)
        }
        .accessibilityLabel(Text(label))
    }

    @ViewBuilder
    private func pauseResumeButton(_ timer: WatchRestTimerSnapshot) -> some View {
        if timer.isPaused {
            Button {
                store.send(.resumeRestTimer)
            } label: {
                Image(systemName: "play.fill")
            }
            .tint(.green)
            .accessibilityLabel(Text("Resume"))
        } else {
            Button {
                store.send(.pauseRestTimer)
            } label: {
                Image(systemName: "pause.fill")
            }
            .accessibilityLabel(Text("Pause"))
        }
    }

    // MARK: - Presets

    private var presetListView: some View {
        ScrollView {
            VStack(spacing: 6) {
                Text("Start a rest timer on your wrist.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(Self.presetSeconds, id: \.self) { seconds in
                        Button {
                            store.send(.startRestTimer(seconds: seconds))
                        } label: {
                            Text(timeText(seconds: seconds))
                                .font(.system(.body, design: .rounded, weight: .semibold))
                                .monospacedDigit()
                        }
                        .tint(.orange)
                    }
                }
                if !store.isPhoneReachable {
                    Label("Open Villain Arc on iPhone", systemImage: "iphone.slash")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }
        }
    }

    private func timeText(seconds: Int) -> String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        // A literal `%d:%02d` against two `Int`s — the pairing C varargs cannot check, and no
        // `FormatStyle` produces zero-padded fixed-width clock digits.
        return unsafe String(format: "%d:%02d", minutes, remainder)
    }
}
