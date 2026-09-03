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
                    CardioLiveActivityIslandLeadingMetricView(attributes: context.attributes, state: context.state)
                        .padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CardioLiveActivityElapsedTimerView(startDate: context.attributes.startDate, font: .title2, widths: (55, 65, 83))
                        .padding(.trailing, 6)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    CardioLiveActivityIslandBottomView(attributes: context.attributes, state: context.state)
                        .padding(.horizontal, 6)
                }
            } compactLeading: {
                CardioLiveActivityCompactLeadingView(attributes: context.attributes, state: context.state)
            } compactTrailing: {
                CardioLiveActivityElapsedTimerView(startDate: context.attributes.startDate, font: .title2, widths: (35, 45, 57))
            } minimal: {
                Image(systemName: context.attributes.isOutdoor ? "map.fill" : "figure.run")
                    .foregroundStyle(.green)
            }
        }
        .supplementalActivityFamilies([.small])
    }
}

// MARK: - Lock screen / expanded

private struct CardioLiveActivityExpandedView: View {
    @Environment(\.activityFamily) private var activityFamily
    let attributes: CardioActivityAttributes
    let state: CardioActivityAttributes.ContentState

    var body: some View {
        let isSmall = activityFamily == .small

        VStack(alignment: .leading, spacing: isSmall ? 6 : 10) {
            HStack(alignment: .center, spacing: 12) {
                CardioLiveActivityTitleView(
                    title: state.title,
                    kindTitle: attributes.kindTitle,
                    titleFont: isSmall ? .caption : .title2,
                    subtitleFont: isSmall ? .caption2 : .headline
                )

                Spacer(minLength: 8)

                CardioLiveActivityElapsedTimerView(
                    startDate: attributes.startDate,
                    font: isSmall ? .subheadline : .title2,
                    widths: isSmall ? (44, 52, 66) : (60, 72, 92)
                )
            }

            Divider()

            HStack(spacing: isSmall ? 10 : 12) {
                CardioLiveActivityMetricView(
                    systemImage: attributes.isOutdoor ? "point.topleft.down.curvedto.point.bottomright.up" : "speedometer",
                    value: formattedDistance(state.distanceMeters),
                    title: "Distance",
                    isSmall: isSmall
                )
                Spacer(minLength: 0)
                if let pace = state.paceSecondsPerKilometer {
                    CardioLiveActivityMetricView(systemImage: "speedometer", value: formattedPace(secondsPerKilometer: pace), title: "Pace", isSmall: isSmall)
                    Spacer(minLength: 0)
                }
                CardioLiveActivityTrailingMetricView(attributes: attributes, state: state, alignment: .trailing, isSmall: isSmall)
            }
        }
        .padding(isSmall ? 8 : 16)
        .activityBackgroundTint(isSmall ? .black : .clear)
    }
}

// MARK: - Dynamic Island regions

private struct CardioLiveActivityIslandLeadingMetricView: View {
    let attributes: CardioActivityAttributes
    let state: CardioActivityAttributes.ContentState

    var body: some View {
        CardioLiveActivityMetricView(
            systemImage: attributes.isOutdoor ? "point.topleft.down.curvedto.point.bottomright.up" : "speedometer",
            value: formattedDistance(state.distanceMeters),
            title: "Distance"
        )
    }
}

private struct CardioLiveActivityIslandBottomView: View {
    let attributes: CardioActivityAttributes
    let state: CardioActivityAttributes.ContentState

    var body: some View {
        HStack(alignment: .center) {
            CardioLiveActivityTitleView(
                title: state.title,
                kindTitle: attributes.kindTitle,
                titleFont: .headline,
                subtitleFont: .caption
            )

            Spacer(minLength: 8)

            HStack(spacing: 12) {
                if let pace = state.paceSecondsPerKilometer {
                    CardioLiveActivityInlineMetricView(systemImage: "speedometer", value: formattedPace(secondsPerKilometer: pace))
                }
                if let heartRate = state.liveHeartRateBPM {
                    CardioLiveActivityInlineMetricView(systemImage: "heart.fill", value: "\(Int(heartRate.rounded()))", tint: .red)
                } else if let energy = state.activeEnergyBurned {
                    CardioLiveActivityInlineMetricView(systemImage: "flame.fill", value: "\(Int(energy.rounded()))", tint: .orange)
                }
            }
        }
    }
}

private struct CardioLiveActivityCompactLeadingView: View {
    let attributes: CardioActivityAttributes
    let state: CardioActivityAttributes.ContentState

    var body: some View {
        Group {
            if let heartRate = state.liveHeartRateBPM {
                HStack(spacing: 2) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                    Text("\(Int(heartRate.rounded()))")
                        .bold()
                        .font(.title2)
                }
            } else if let energy = state.activeEnergyBurned {
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("\(Int(energy.rounded()))")
                        .bold()
                        .font(.title2)
                }
            } else {
                Image(systemName: attributes.isOutdoor ? "map.fill" : "figure.run")
                    .foregroundStyle(.green)
            }
        }
        .fontDesign(.rounded)
    }
}

// MARK: - Shared views

// Title + kind subtitle. The kind line is shown only when it differs from the
// title — an unnamed session's `displayTitle` falls back to `kind.title`, so
// showing both would print e.g. "Treadmill Walk" twice.
private struct CardioLiveActivityTitleView: View {
    let title: String
    let kindTitle: String
    var titleFont: Font = .title2
    var subtitleFont: Font = .headline

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(titleFont)
                .lineLimit(1)
            if kindTitle != title {
                Text(kindTitle)
                    .font(subtitleFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .fontDesign(.rounded)
        .fontWeight(.semibold)
    }
}

private struct CardioLiveActivityTrailingMetricView: View {
    let attributes: CardioActivityAttributes
    let state: CardioActivityAttributes.ContentState
    var alignment: HorizontalAlignment = .leading
    var isSmall: Bool = false

    var body: some View {
        if let heartRate = state.liveHeartRateBPM {
            CardioLiveActivityMetricView(systemImage: "heart.fill", value: "\(Int(heartRate.rounded()))", title: "bpm", alignment: alignment, tint: .red, isSmall: isSmall)
        } else if let energy = state.activeEnergyBurned {
            CardioLiveActivityMetricView(systemImage: "flame.fill", value: "\(Int(energy.rounded()))", title: "kcal", alignment: alignment, tint: .orange, isSmall: isSmall)
        } else {
            switch attributes.captureMode {
            case .gpsRoute:
                CardioLiveActivityMetricView(systemImage: "location.fill", value: "\(state.routePointCount)", title: "Points", alignment: alignment, isSmall: isSmall)
            case .machineIntervals:
                CardioLiveActivityMetricView(systemImage: "list.bullet", value: "\(state.treadmillIntervalCount)", title: "Intervals", alignment: alignment, isSmall: isSmall)
            case .healthKitOnly:
                // No app-recorded count — heart rate/energy fill this slot once collection warms up.
                CardioLiveActivityMetricView(systemImage: "heart.text.square", value: "Live", title: "Apple Health", alignment: alignment, tint: .red, isSmall: isSmall)
            }
        }
    }
}

private struct CardioLiveActivityMetricView: View {
    let systemImage: String
    let value: String
    let title: LocalizedStringKey
    var alignment: HorizontalAlignment = .leading
    var tint: Color = .primary
    var isSmall: Bool = false

    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                Text(value)
            }
            .font((isSmall ? Font.subheadline : Font.headline).weight(.bold))
            Text(title)
                .font(isSmall ? .caption2 : .caption)
                .foregroundStyle(.secondary)
        }
        .fontDesign(.rounded)
        .lineLimit(1)
    }
}

private struct CardioLiveActivityInlineMetricView: View {
    let systemImage: String
    let value: String
    var tint: Color = .primary

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
            Text(value)
        }
        .font(.subheadline.weight(.semibold))
        .fontDesign(.rounded)
        .lineLimit(1)
    }
}

// MARK: - Elapsed timer (width-restricted so the digits never shift the layout)

private struct CardioLiveActivityElapsedTimerView: View {
    let startDate: Date
    var font: Font = .title2
    // (under 10 min, 10 min–1 hr, 1 hr+) — the string widens as it crosses each
    // threshold, so cap the frame per tier and keep the right edge pinned.
    var widths: (base: CGFloat, tenMinute: CGFloat, hour: CGFloat) = (55, 65, 83)

    var body: some View {
        let elapsed = Date.now.timeIntervalSince(startDate)
        let maxWidth = elapsed >= 3_600 ? widths.hour : (elapsed >= 600 ? widths.tenMinute : widths.base)

        Text(startDate, style: .timer)
            .font(font)
            .fontWeight(.bold)
            .fontDesign(.rounded)
            .monospacedDigit()
            .lineLimit(1)
            .frame(maxWidth: maxWidth, alignment: .trailing)
    }
}

// MARK: - Formatting

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
    // A literal `%02d` against an `Int` — the pairing C varargs cannot check, and no `FormatStyle`
    // produces zero-padded fixed-width clock digits.
    let paddedSeconds = unsafe String(format: "%02d", totalSeconds % 60)
    return "\(totalSeconds / 60):\(paddedSeconds)"
}
