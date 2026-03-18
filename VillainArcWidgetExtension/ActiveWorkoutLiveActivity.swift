import ActivityKit
import SwiftUI
import WidgetKit
import AppIntents

private enum WorkoutLiveActivityAccessibilityText {
    static let resumeRestTimerLabel = String(localized: "Resume rest timer")
    static let completeSetLabel = String(localized: "Complete next set")
}

struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            WorkoutLiveActivityExpandedView(
                attributes: context.attributes,
                state: context.state
            )
            .activityBackgroundTint(.clear)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    WorkoutLiveActivityHeaderView(attributes: context.attributes, state: context.state, style: .compact)
                    .padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isTimerRunning,
                       let endDate = context.state.timerEndDate {
                        Text(timerInterval: Date.now...endDate, countsDown: true)
                            .font(.title2)
                            .bold()
                            .lineLimit(1)
                            .frame(maxWidth: 50)
                    } else if context.state.isTimerPaused, let remaining = context.state.timerPausedRemaining {
                        Button(intent: LiveActivityResumeRestTimerIntent()) {
                            HStack(spacing: 4) {
                                Image(systemName: "pause.fill")
                                Text(formatSeconds(remaining))
                                    .font(.title2)
                                    .bold()
                            }
                            .foregroundStyle(.yellow)
                            .fontDesign(.rounded)
                            .fixedSize(horizontal: true, vertical: false)
                            .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(WorkoutLiveActivityAccessibilityText.resumeRestTimerLabel)
                        .accessibilityValue(formatSeconds(remaining))
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let name = context.state.exerciseName {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(name)
                                    .font(.title3)
                                    .lineLimit(1)
                                Text(setDescription(context.state))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .fontDesign(.rounded)
                            .fontWeight(.semibold)
                            Spacer()
                            Button(intent: LiveActivityCompleteSetIntent()) {
                                Image(systemName: "checkmark")
                                    .font(.body)
                                    .fontWeight(.bold)
                            }
                            .accessibilityLabel(WorkoutLiveActivityAccessibilityText.completeSetLabel)
                        }
                        .padding(.leading, 6)
                    } else if !context.state.hasExercises {
                        Button(intent: LiveActivityAddExerciseIntent()) {
                            Text("Add an exercise to begin")
                                .fontWeight(.semibold)
                                .fontDesign(.rounded)
                        }
                        .buttonStyle(.plain)
                        .padding(.leading)
                    } else {
                        Text("All sets complete")
                            .padding(.leading)
                            .fontWeight(.semibold)
                            .fontDesign(.rounded)
                    }
                }
            } compactLeading: {
                Image(systemName: "figure.strengthtraining.traditional")
                    .foregroundStyle(.green)
            } compactTrailing: {
                if context.state.isTimerRunning, let endDate = context.state.timerEndDate {
                    Text(timerInterval: Date.now...endDate, countsDown: true)
                        .bold()
                        .frame(maxWidth: 40)
                } else if context.state.isTimerPaused, let remaining = context.state.timerPausedRemaining {
                    HStack(spacing: 4) {
                        Image(systemName: "pause.fill")
                        Text(formatSeconds(remaining))
                            .font(.title)
                            .bold()
                    }
                    .foregroundStyle(.yellow)
                    .fontDesign(.rounded)
                } else {
                    Text(context.attributes.startDate, style: .timer)
                        .bold()
                        .frame(maxWidth: 55)
                }
            } minimal: {
                Image(systemName: "figure.strengthtraining.traditional")
                    .foregroundStyle(.green)
            }
        }
    }
}

struct WorkoutLiveActivityExpandedView: View {
    let attributes: WorkoutActivityAttributes
    let state: WorkoutActivityAttributes.ContentState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                WorkoutLiveActivityHeaderView(attributes: attributes, state: state, style: .expanded)
                Spacer()
                if state.isTimerRunning, let endDate = state.timerEndDate {
                    Text(timerInterval: Date.now...endDate, countsDown: true)
                        .font(.title)
                        .bold()
                        .lineLimit(1)
                        .frame(maxWidth: 65)
                } else if state.isTimerPaused, let remaining = state.timerPausedRemaining {
                    Button(intent: LiveActivityResumeRestTimerIntent()) {
                        HStack(spacing: 4) {
                            Image(systemName: "pause.fill")
                                .font(.title3)
                            Text(formatSeconds(remaining))
                                .font(.title)
                                .bold()
                        }
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .foregroundStyle(.yellow)
                        .fontDesign(.rounded)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(WorkoutLiveActivityAccessibilityText.resumeRestTimerLabel)
                    .accessibilityValue(formatSeconds(remaining))
                }
            }
            
            Divider()
            
            if let exerciseName = state.exerciseName {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exerciseName)
                            .font(.title3)
                            .lineLimit(1)
                        Text(setDescription(state))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .font(.headline)
                    }
                    .fontDesign(.rounded)
                    .fontWeight(.semibold)
                    Spacer()
                    Button(intent: LiveActivityCompleteSetIntent()) {
                        Image(systemName: "checkmark")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel(WorkoutLiveActivityAccessibilityText.completeSetLabel)
                }
            } else if !state.hasExercises {
                Button(intent: LiveActivityAddExerciseIntent()) {
                    Text("Add an exercise to begin")
                        .fontDesign(.rounded)
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.plain)
            } else {
                Text("All sets complete")
                    .fontDesign(.rounded)
                    .font(.title3)
                    .fontWeight(.semibold)
            }
        }
        .padding()
    }
}

private enum WorkoutLiveActivityHeaderStyle {
    case compact
    case expanded

    var metricSpacing: CGFloat {
        switch self {
        case .compact: 10
        case .expanded: 14
        }
    }

    var metricRowSpacing: CGFloat {
        switch self {
        case .compact: 6
        case .expanded: 8
        }
    }

    var iconFont: Font {
        switch self {
        case .compact: .subheadline
        case .expanded: .title3
        }
    }

    var valueFont: Font {
        switch self {
        case .compact: .subheadline
        case .expanded: .headline
        }
    }

    var titleFont: Font {
        switch self {
        case .compact: .title3
        case .expanded: .title2
        }
    }

    var subtitleFont: Font {
        switch self {
        case .compact: .caption
        case .expanded: .subheadline
        }
    }
}

private struct WorkoutLiveActivityHeaderView: View {
    let attributes: WorkoutActivityAttributes
    let state: WorkoutActivityAttributes.ContentState
    let style: WorkoutLiveActivityHeaderStyle

    private var liveHeartRateText: String? {
        guard let liveHeartRateBPM = state.liveHeartRateBPM else { return nil }
        return "\(Int(liveHeartRateBPM.rounded())) bpm"
    }

    private var liveActiveEnergyText: String? {
        guard let liveActiveEnergyBurned = state.liveActiveEnergyBurned else { return nil }
        return "\(Int(liveActiveEnergyBurned.rounded())) cal"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if state.hasLiveMetrics {
                HStack(spacing: style.metricSpacing) {
                    if let liveHeartRateText {
                        WorkoutLiveActivityMetricRow(symbolName: "heart.fill", text: liveHeartRateText, tint: .red, style: style)
                    }
                    if let liveActiveEnergyText {
                        WorkoutLiveActivityMetricRow(symbolName: "flame.fill", text: liveActiveEnergyText, tint: .orange, style: style)
                    }
                }
            } else {
                Text(state.title)
                    .font(style.titleFont)
                    .lineLimit(1)
                Text(attributes.startDate, style: .date)
                    .font(style.subtitleFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .fontDesign(.rounded)
        .fontWeight(.semibold)
    }
}

private struct WorkoutLiveActivityMetricRow: View {
    let symbolName: String
    let text: String
    let tint: Color
    let style: WorkoutLiveActivityHeaderStyle

    var body: some View {
        HStack(spacing: style.metricRowSpacing) {
            Image(systemName: symbolName)
                .font(style.iconFont)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(text)
                .font(style.valueFont)
                .lineLimit(1)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}

private func formatSeconds(_ seconds: Int) -> String {
    let clampedSeconds = max(0, seconds)
    let minutes = clampedSeconds / 60
    let remainingSeconds = clampedSeconds % 60
    return String(format: "%02d:%02d", minutes, remainingSeconds)
}

private func setDescription(_ state: WorkoutActivityAttributes.ContentState) -> String {
    guard let setNumber = state.setNumber,
          let totalSets = state.totalSets else {
        return ""
    }
    
    var parts: [String] = ["Set \(setNumber)/\(totalSets)"]
    
    if let weight = state.weight, weight > 0 {
        let unit = state.weightUnit ?? "lbs"
        let formatted = weight.formatted(.number.precision(.fractionLength(0...1)))
        parts.append("\(formatted) \(unit)")
    }
    
    if let reps = state.reps, reps > 0 {
        parts.append("\(reps) reps")
    }
    
    if let targetRPE = state.targetRPE {
        parts.append("RPE \(targetRPE)")
    }
    
    return parts.joined(separator: " · ")
}
