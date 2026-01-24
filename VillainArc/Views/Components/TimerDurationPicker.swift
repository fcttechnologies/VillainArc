import SwiftUI
import UIKit

struct TimerDurationPicker: View {
    @Environment(\.colorScheme) private var colorScheme
    // Output in seconds (0...600, step 15)
    @Binding var seconds: Int

    let maxMinutes: Int = 10
    let stepSeconds: Int = 15
    let showZero: Bool

    @State private var dragOffset: CGFloat = 0
    @State private var dragStartIndex: Int = 0
    @State private var isDragging = false
    @State private var lastHapticIndex: Int? = nil

    // Visual tuning
    private let stepWidth: CGFloat = 18

    private var minSeconds: Int { showZero ? 0 : stepSeconds }
    private var maxSeconds: Int { maxMinutes * 60 }

    private var secondsRange: ClosedRange<Int> {
        minSeconds...maxSeconds
    }

    private var ticks: [Int] {
        stride(from: minSeconds, through: maxSeconds, by: stepSeconds).map { $0 }
    }
    
    private var primary: Color {
        colorScheme == .dark ? .white : .black
    }

    var body: some View {
        GeometryReader { geo in
            let center = geo.size.width / 2
            let currentIndex = index(for: seconds)
            let baseIndex = isDragging ? dragStartIndex : currentIndex
            let selectedSeconds = nearestTick(seconds)

            ZStack {
                ForEach(ticks, id: \.self) { tickSeconds in
                    let tickIndex = index(for: tickSeconds)
                    let x = center + CGFloat(tickIndex - baseIndex) * stepWidth + dragOffset

                    VStack(spacing: 6) {
                        Spacer()

                        RoundedRectangle(cornerRadius: 10)
                            .fill(tickSeconds == selectedSeconds ? primary : Color.gray.opacity(0.4))
                            .frame(
                                width: tickSeconds == selectedSeconds ? 3 : 1,
                                height: isWholeMinute(tickSeconds) ? 22 : 10
                            )

                        Text(minuteLabelIfNeeded(tickSeconds))
                            .font(.caption.bold())
                            .foregroundColor(isWholeMinute(tickSeconds) ? .primary : .clear)
                            .offset(y: 10)
                    }
                    .position(x: x, y: geo.size.height / 2)
                }
            }
            .contentShape(Rectangle())
            .animation(
                isDragging ? nil : .interpolatingSpring(stiffness: 120, damping: 20),
                value: seconds
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isDragging {
                            isDragging = true
                            dragStartIndex = currentIndex
                            lastHapticIndex = currentIndex
                        }

                        withAnimation(.interactiveSpring) {
                            let rawOffset = gesture.translation.width
                            let offsetSteps = rawOffset / stepWidth  // in "tick indices"

                            // Project in index-space (not seconds)
                            var projectedIndex = CGFloat(dragStartIndex) - offsetSteps

                            let lowerIndex = CGFloat(0)
                            let upperIndex = CGFloat(ticks.count - 1)

                            // Elastic overscroll
                            if projectedIndex < lowerIndex {
                                let overshoot = lowerIndex - projectedIndex
                                projectedIndex = lowerIndex - log(overshoot + 1) * 2
                            } else if projectedIndex > upperIndex {
                                let overshoot = projectedIndex - upperIndex
                                projectedIndex = upperIndex + log(overshoot + 1) * 2
                            }

                            // Convert back to visual offset
                            dragOffset = (CGFloat(dragStartIndex) - projectedIndex) * stepWidth

                            // Snap temp value to nearest tick
                            let roundedIndex = Int(projectedIndex.rounded()).clamped(to: 0...(ticks.count - 1))
                            seconds = ticks[roundedIndex]

                            // Optional: haptic on change
                            if lastHapticIndex != roundedIndex {
                                Haptics.selection()
                                lastHapticIndex = roundedIndex
                            }
                        }
                    }
                    .onEnded { gesture in
                        let offsetSteps = gesture.translation.width / stepWidth
                        let rawFinalIndex = CGFloat(dragStartIndex) - offsetSteps
                        let finalIndex = Int(rawFinalIndex.rounded()).clamped(to: 0...(ticks.count - 1))
                        let finalSeconds = ticks[finalIndex]

                        withAnimation(.interpolatingSpring(stiffness: 120, damping: 20)) {
                            seconds = finalSeconds
                            dragOffset = 0
                            isDragging = false
                            lastHapticIndex = nil
                        }
                    }
            )
        }
        .onAppear {
            // Ensure binding starts aligned to the tick list
            seconds = nearestTick(seconds)
        }
        .onChange(of: showZero) { _, _ in
            // If showZero toggles off while at 0, bump to first step
            if !showZero && seconds == 0 {
                seconds = stepSeconds
            }
        }
        .accessibilityIdentifier("timerDurationPicker")
        .accessibilityElement()
        .accessibilityLabel("Timer duration")
        .accessibilityValue(secondsToTime(seconds))
        .accessibilityAdjustableAction { direction in
            let delta = direction == .increment ? stepSeconds : -stepSeconds
            let newSeconds = (seconds + delta).clamped(to: secondsRange)
            guard newSeconds != seconds else { return }
            seconds = newSeconds
        }
    }

    // MARK: - Helpers

    private func index(for seconds: Int) -> Int {
        let clampedSeconds = nearestTick(seconds).clamped(to: secondsRange)
        let zeroBased = (clampedSeconds - minSeconds) / stepSeconds
        return zeroBased
    }

    private func nearestTick(_ seconds: Int) -> Int {
        let s = seconds.clamped(to: secondsRange)
        let offset = s - minSeconds
        let roundedSteps = Int((Double(offset) / Double(stepSeconds)).rounded())
        return minSeconds + roundedSteps * stepSeconds
    }

    private func isWholeMinute(_ seconds: Int) -> Bool {
        seconds % 60 == 0
    }

    private func minuteLabelIfNeeded(_ seconds: Int) -> String {
        guard isWholeMinute(seconds) else { return "" }
        return "\(seconds / 60)"
    }
}

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}

// MARK: - Example usage

struct TimerDurationPickerDemo: View {
    @State private var seconds: Int = 60
    @State private var showZero: Bool = true

    var body: some View {
        VStack(spacing: 24) {
            Toggle("Allow 0:00", isOn: $showZero)
                .padding(.horizontal)

            Text(secondsToTime(seconds))
                .font(.system(size: 56, weight: .bold))
                .contentTransition(.numericText())

            TimerDurationPicker(seconds: $seconds, showZero: showZero)
                .frame(height: 50)
        }
        .padding()
    }

}

#Preview {
    TimerDurationPickerDemo()
}
