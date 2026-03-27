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
                    WorkoutLiveActivityIslandLeadingMetricView(state: context.state)
                        .padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isTimerRunning, let endDate = context.state.timerEndDate {
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
            WorkoutLiveActivityExpandedTopRow(attributes: attributes, state: state)
            
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

private struct WorkoutLiveActivityExpandedTopRow: View {
    let attributes: WorkoutActivityAttributes
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        Group {
            if state.liveHeartRateBPM != nil || state.liveActiveEnergyBurned != nil {
                HStack {
                    if let liveHeartRateBPM = state.liveHeartRateBPM {
                        WorkoutLiveActivityExpandedMetricView(symbolName: "heart.fill", number: Double(Int(liveHeartRateBPM.rounded())), tint: .red)
                        Spacer()
                    }

                    if let liveActiveEnergyBurned = state.liveActiveEnergyBurned {
                        WorkoutLiveActivityExpandedMetricView(symbolName: "flame.fill", number: Double(Int(liveActiveEnergyBurned.rounded())), unitText: "cal", tint: .orange)
                        Spacer()
                    }

                    if state.isTimerRunning, let endDate = state.timerEndDate {
                        HStack(spacing: 4) {
                            Image(systemName: "timer")
                                .font(.title2)
                                .accessibilityHidden(true)
                            Text(timerInterval: Date.now...endDate, countsDown: true)
                                .font(.title)
                                .bold()
                                .lineLimit(1)
                                .frame(maxWidth: 65)
                        }
                    } else if state.isTimerPaused, let remaining = state.timerPausedRemaining {
                        Button(intent: LiveActivityResumeRestTimerIntent()) {
                            HStack(spacing: 4) {
                                Image(systemName: "pause.fill")
                                    .font(.title)
                                Text(formatSeconds(remaining))
                                    .font(.title)
                                    .bold()
                                    .monospacedDigit()
                            }
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .foregroundStyle(.yellow)
                            .fontDesign(.rounded)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(WorkoutLiveActivityAccessibilityText.resumeRestTimerLabel)
                        .accessibilityValue(formatSeconds(remaining))
                    } else {
                        Spacer()
                    }
                }
                .fontDesign(.rounded)
                .fontWeight(.semibold)
            } else {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(state.title)
                            .font(.title2)
                            .lineLimit(1)
                        Text(attributes.startDate, style: .date)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .fontDesign(.rounded)
                    .fontWeight(.semibold)

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
            }
        }
    }
}

private struct WorkoutLiveActivityExpandedMetricView: View {
    let symbolName: String
    let number: Double
    let unitText: String
    let tint: Color

    init(symbolName: String, number: Double, unitText: String = "", tint: Color) {
        self.symbolName = symbolName
        self.number = number
        self.unitText = unitText
        self.tint = tint
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbolName)
                .font(.title2)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            HStack(spacing: unitText.isEmpty ? 0 : 4) {
                Text(number, format: .number.precision(.fractionLength(0)))
                    .font(.title)
                    .lineLimit(1)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: number))

                if !unitText.isEmpty {
                    Text(unitText)
                        .font(.title)
                        .lineLimit(1)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct WorkoutLiveActivityIslandLeadingMetricView: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        Group {
            if let liveHeartRateBPM = state.liveHeartRateBPM {
                WorkoutLiveActivityIslandMetricView(symbolName: "heart.fill", number: Double(Int(liveHeartRateBPM.rounded())), tint: .red)
            } else if let liveActiveEnergyBurned = state.liveActiveEnergyBurned {
                WorkoutLiveActivityIslandMetricView(symbolName: "flame.fill", number: Double(Int(liveActiveEnergyBurned.rounded())), tint: .orange)
            } else {
                EmptyView()
            }
        }
    }
}

private struct WorkoutLiveActivityIslandMetricView: View {
    let symbolName: String
    let number: Double
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbolName)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(number, format: .number.precision(.fractionLength(0)))
                .font(.title2)
                .monospacedDigit()
                .contentTransition(.numericText(value: number))
        }
        .fontDesign(.rounded)
        .fontWeight(.semibold)
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
