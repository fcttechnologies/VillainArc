import ActivityKit
import SwiftUI
import WidgetKit
import AppIntents

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
                    VStack(alignment: .leading) {
                        Text(context.state.title)
                            .font(.headline)
                            .lineLimit(1)
                        Text(context.attributes.startDate, style: .date)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fontWeight(.semibold)
                    }
                    .padding(.leading)
                    .fontDesign(.rounded)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isTimerRunning,
                       let endDate = context.state.timerEndDate {
                        Text(timerInterval: Date.now...endDate, countsDown: true)
                            .font(.title2)
                            .fontWeight(.bold)
                            .frame(maxWidth: 70)
                            .fontDesign(.rounded)
                    } else if context.state.isTimerPaused,
                              let remaining = context.state.timerPausedRemaining {
                        Button(intent: LiveActivityResumeRestTimerIntent()) {
                            HStack(spacing: 0) {
                                Image(systemName: "pause.fill")
                                Text(formatSeconds(remaining))
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .frame(maxWidth: 60)
                            }
                            .foregroundStyle(.yellow)
                            .fontDesign(.rounded)
                        }
                        .buttonStyle(.plain)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let name = context.state.exerciseName {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(name)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                                Text(setDescription(context.state))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fontWeight(.semibold)
                            }
                            .fontDesign(.rounded)
                            Spacer()
                            Button(intent: LiveActivityCompleteSetIntent()) {
                                Image(systemName: "checkmark")
                                    .font(.body)
                                    .fontWeight(.bold)
                            }
                        }
                        .padding(.horizontal)
                    } else if !context.state.hasExercises {
                        Text("Add an exercise to begin")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.leading)
                            .fontWeight(.semibold)
                            .fontDesign(.rounded)
                    } else {
                        Text("All sets complete")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.leading)
                            .fontWeight(.semibold)
                            .fontDesign(.rounded)
                    }
                }
            } compactLeading: {
                Image(systemName: "figure.strengthtraining.traditional")
                    .foregroundStyle(.green)
            } compactTrailing: {
                if context.state.isTimerRunning,
                   let endDate = context.state.timerEndDate {
                    Text(timerInterval: Date.now...endDate, countsDown: true)
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                } else {
                    Text(context.attributes.startDate, style: .timer)
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
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
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(attributes.startDate, style: .date)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
                .fontDesign(.rounded)
                Spacer()
                if state.isTimerRunning, let endDate = state.timerEndDate {
                    Text(timerInterval: Date.now...endDate, countsDown: true)
                        .font(.title)
                        .fontWeight(.bold)
                        .frame(maxWidth: 70)
                        .fontDesign(.rounded)
                        .lineLimit(1)
                } else if state.isTimerPaused, let remaining = state.timerPausedRemaining {
                    Button(intent: LiveActivityResumeRestTimerIntent()) {
                        HStack(spacing: 4) {
                            Image(systemName: "pause.fill")
                            Text(formatSeconds(remaining))
                                .font(.title)
                                .fontWeight(.bold)
                        }
                        .foregroundStyle(.yellow)
                        .fontDesign(.rounded)
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            if let exerciseName = state.exerciseName {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exerciseName)
                            .font(.subheadline)
                            .lineLimit(1)
                        Text(setDescription(state))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
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
                }
            } else if !state.hasExercises {
                Text("Add an exercise to begin")
                    .foregroundStyle(.secondary)
                    .fontDesign(.rounded)
                    .fontWeight(.semibold)
            } else {
                Text("All sets complete")
                    .foregroundStyle(.secondary)
                    .fontDesign(.rounded)
                    .fontWeight(.semibold)
            }
        }
        .padding()
    }
}

private func formatSeconds(_ seconds: Int) -> String {
    let m = max(0, seconds / 60)
    let s = max(0, seconds % 60)
    return "\(m):" + String(format: "%02d", s)
}

private func setDescription(_ state: WorkoutActivityAttributes.ContentState) -> String {
    guard let setNumber = state.setNumber,
          let totalSets = state.totalSets else {
        return ""
    }

    var parts: [String] = ["Set \(setNumber)/\(totalSets)"]

    if let weight = state.weight, weight > 0 {
        let formatted = weight.formatted(.number.precision(.fractionLength(0...1)))
        parts.append("\(formatted) lbs")
    }

    if let reps = state.reps, reps > 0 {
        parts.append("\(reps) reps")
    }

    if let rawType = state.setTypeRawValue, rawType != ExerciseSetType.regular.rawValue {
        parts.append(rawType)
    }

    return parts.joined(separator: " · ")
}
