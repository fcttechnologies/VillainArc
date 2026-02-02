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
                    }
                    .padding(.leading)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isTimerRunning,
                       let endDate = context.state.timerEndDate {
                        Text(timerInterval: Date.now...endDate, countsDown: true)
                            .font(.title2)
                            .fontWeight(.bold)
                    } else if context.state.isTimerPaused,
                              let remaining = context.state.timerPausedRemaining {
                        Text(formatSeconds(remaining))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.yellow)
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
                            }
                            Spacer()
                            Button(intent: LiveActivityCompleteSetIntent()) {
                                Image(systemName: "checkmark")
                                    .font(.body)
                                    .fontWeight(.bold)
                            }
                            .tint(.blue)
                        }
                        .padding(.horizontal)
                    } else if !context.state.hasExercises {
                        Text("Add an exercise to begin")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.leading)
                    } else {
                        Text("All sets complete")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.leading)
                    }
                }
            } compactLeading: {
                Image(systemName: "figure.strengthtraining.traditional")
                    .foregroundStyle(.blue)
            } compactTrailing: {
                if context.state.isTimerRunning,
                   let endDate = context.state.timerEndDate {
                    Text(timerInterval: Date.now...endDate, countsDown: true)
                        .font(.caption)
                        .frame(width: 40)
                } else {
                    Text(context.attributes.startDate, style: .timer)
                        .font(.caption)
                        .frame(width: 40)
                }
            } minimal: {
                Image(systemName: "figure.strengthtraining.traditional")
                    .foregroundStyle(.blue)
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
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if state.isTimerRunning, let endDate = state.timerEndDate {
                    Text(timerInterval: Date.now...endDate, countsDown: true)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.blue)
                } else if state.isTimerPaused, let remaining = state.timerPausedRemaining {
                    HStack(spacing: 4) {
                        Image(systemName: "pause.fill")
                            .font(.caption)
                        Text(formatSeconds(remaining))
                            .font(.title)
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(.yellow)
                }
            }

            Divider()

            if let exerciseName = state.exerciseName {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exerciseName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                        Text(setDescription(state))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(intent: LiveActivityCompleteSetIntent()) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                    }
                    .tint(.blue)
                }
            } else if !state.hasExercises {
                Text("Add an exercise to begin")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("All sets complete")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
