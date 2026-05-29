import ActivityKit
import SwiftUI
import WidgetKit

struct CardioLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CardioActivityAttributes.self) { context in
            CardioLiveActivityExpandedView(attributes: context.attributes, state: context.state)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    CardioLiveActivityMetricView(systemImage: context.attributes.isOutdoor ? "map.fill" : "speedometer", value: formattedDistance(context.state.distanceMeters), title: "Distance")
                        .padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let heartRate = context.state.liveHeartRateBPM {
                        CardioLiveActivityMetricView(systemImage: "heart.fill", value: "\(Int(heartRate.rounded()))", title: "bpm", alignment: .trailing)
                            .foregroundStyle(.red)
                            .padding(.trailing, 6)
                    } else {
                        CardioLiveActivityMetricView(systemImage: "timer", value: timerText(from: context.attributes.startDate), title: "Time", alignment: .trailing)
                            .padding(.trailing, 6)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.state.title)
                                .font(.headline)
                                .lineLimit(1)
                            Text(context.attributes.kindTitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(context.attributes.startDate, style: .timer)
                            .font(.headline.monospacedDigit())
                    }
                    .padding(.horizontal, 6)
                }
            } compactLeading: {
                Image(systemName: context.attributes.isOutdoor ? "map.fill" : "figure.run")
                    .foregroundStyle(.green)
            } compactTrailing: {
                Text(formattedDistance(context.state.distanceMeters, compact: true))
                    .font(.headline.monospacedDigit())
            } minimal: {
                Image(systemName: context.attributes.isOutdoor ? "map.fill" : "figure.run")
                    .foregroundStyle(.green)
            }
        }
        .supplementalActivityFamilies([.small])
    }
}

private struct CardioLiveActivityExpandedView: View {
    @Environment(\.activityFamily) private var activityFamily
    let attributes: CardioActivityAttributes
    let state: CardioActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: activityFamily == .small ? 6 : 10) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(attributes.kindTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(attributes.startDate, style: .timer)
                    .font(.title3.monospacedDigit().weight(.bold))
            }

            Divider()

            HStack(spacing: 12) {
                CardioLiveActivityMetricView(systemImage: "point.topleft.down.curvedto.point.bottomright.up", value: formattedDistance(state.distanceMeters), title: "Distance")
                Spacer(minLength: 0)
                if let pace = state.paceSecondsPerKilometer {
                    CardioLiveActivityMetricView(systemImage: "speedometer", value: formattedPace(secondsPerKilometer: pace), title: "Pace")
                }
                Spacer(minLength: 0)
                if let heartRate = state.liveHeartRateBPM {
                    CardioLiveActivityMetricView(systemImage: "heart.fill", value: "\(Int(heartRate.rounded()))", title: "bpm", alignment: .trailing)
                        .foregroundStyle(.red)
                } else if let energy = state.activeEnergyBurned {
                    CardioLiveActivityMetricView(systemImage: "flame.fill", value: "\(Int(energy.rounded()))", title: "kcal", alignment: .trailing)
                        .foregroundStyle(.orange)
                } else {
                    CardioLiveActivityMetricView(systemImage: attributes.isOutdoor ? "location.fill" : "list.bullet", value: "\(attributes.isOutdoor ? state.routePointCount : state.treadmillIntervalCount)", title: attributes.isOutdoor ? "Points" : "Intervals", alignment: .trailing)
                }
            }
        }
        .padding(activityFamily == .small ? 8 : 16)
        .activityBackgroundTint(activityFamily == .small ? .black : .clear)
    }
}

private struct CardioLiveActivityMetricView: View {
    let systemImage: String
    let value: String
    let title: LocalizedStringKey
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                Text(value)
            }
            .font(.headline.monospacedDigit())
            .fontWeight(.bold)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .lineLimit(1)
    }
}

private func formattedDistance(_ meters: Double, compact: Bool = false) -> String {
    let usesMiles = Locale.current.measurementSystem == .us
    let value = usesMiles ? meters / 1_609.344 : meters / 1_000
    let unit = usesMiles ? "mi" : "km"
    let digits: ClosedRange<Int> = compact ? 0...1 : 0...2
    return "\(value.formatted(.number.precision(.fractionLength(digits)))) \(unit)"
}

private func formattedPace(secondsPerKilometer: Double) -> String {
    let secondsPerUnit = Locale.current.measurementSystem == .us ? secondsPerKilometer * 1.609344 : secondsPerKilometer
    let totalSeconds = max(0, Int(secondsPerUnit.rounded()))
    return "\(totalSeconds / 60):\(String(format: "%02d", totalSeconds % 60))"
}

private func timerText(from startDate: Date) -> String {
    let seconds = max(0, Int(Date().timeIntervalSince(startDate)))
    if seconds >= 3_600 {
        return "\(seconds / 3_600)h"
    }
    return "\(seconds / 60)m"
}
