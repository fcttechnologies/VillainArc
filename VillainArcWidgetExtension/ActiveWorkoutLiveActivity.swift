import ActivityKit
import SwiftUI
import WidgetKit
import AppIntents

private enum WorkoutLiveActivityAccessibilityText {
    static let resumeRestTimerLabel = String(localized: "Resume rest timer")
    static let completeSetLabel = String(localized: "Complete next set")
    static let completedWithPRsLabel = String(localized: "Workout completed with personal records")
    static let completedLabel = String(localized: "Workout completed")
    static let tapToAddExercise = String(localized: "Tap to add an exercise")
    static let allSetsComplete = String(localized: "All sets complete")
    static let exercisesTitle = String(localized: "Exercises")
    static let setsTitle = String(localized: "Sets")
    static let prsTitle = String(localized: "PRs")
    static let volumeTitle = String(localized: "Volume")
    static let done = String(localized: "Done")
}

struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            WorkoutLiveActivityExpandedView(attributes: context.attributes, state: context.state)
        } dynamicIsland: { context in
            if context.state.isSummaryMode {
                let slots = summaryCompactMetrics(attributes: context.attributes, state: context.state)

                return DynamicIsland {
                    DynamicIslandExpandedRegion(.leading) {
                        WorkoutLiveActivitySummaryIslandMetricView(metric: slots.first)
                            .padding(.leading, 6)
                    }
                    DynamicIslandExpandedRegion(.trailing) {
                        WorkoutLiveActivitySummaryIslandMetricView(metric: slots.dropFirst().first, alignment: .trailing)
                            .padding(.trailing, 6)
                    }
                    DynamicIslandExpandedRegion(.bottom) {
                        WorkoutLiveActivitySummaryStatRow(state: context.state, isCompact: true)
                            .padding(.horizontal, 6)
                    }
                } compactLeading: {
                    WorkoutLiveActivitySummaryCompactMetricView(metric: slots.first)
                } compactTrailing: {
                    WorkoutLiveActivitySummaryCompactMetricView(metric: slots.dropFirst().first, alignment: .trailing)
                } minimal: {
                    Image(systemName: context.state.hasSummaryPRs ? "trophy.fill" : "checkmark.circle.fill")
                        .foregroundStyle(context.state.hasSummaryPRs ? .yellow : .green)
                        .accessibilityLabel(context.state.hasSummaryPRs ? WorkoutLiveActivityAccessibilityText.completedWithPRsLabel : WorkoutLiveActivityAccessibilityText.completedLabel)
                }
            } else {
                return DynamicIsland {
                    DynamicIslandExpandedRegion(.leading) {
                        WorkoutLiveActivityIslandLeadingMetricView(state: context.state)
                            .padding(.leading, 6)
                    }
                    DynamicIslandExpandedRegion(.trailing) {
                        Group {
                            if context.state.isTimerRunning, let endDate = context.state.timerEndDate {
                                Text(timerInterval: Date.now...endDate, countsDown: true)
                                    .font(.title2)
                                    .bold()
                                    .frame(maxWidth: 55, alignment: .trailing)
                                    .lineLimit(1)
                            } else if context.state.isTimerPaused, let remaining = context.state.timerPausedRemaining {
                                Button(intent: LiveActivityResumeRestTimerIntent()) {
                                    HStack(spacing: 2) {
                                        Image(systemName: "pause.fill")
                                        Text(formatSeconds(remaining))
                                            .bold()
                                            .font(.title2)
                                    }
                                    .foregroundStyle(.yellow)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(WorkoutLiveActivityAccessibilityText.resumeRestTimerLabel)
                                .accessibilityValue(formatSeconds(remaining))
                            } else {
                                let time = Date.now.timeIntervalSince(context.attributes.startDate)
                                Text(context.attributes.startDate, style: .timer)
                                    .font(.title2)
                                    .bold()
                                    .frame(maxWidth: time >= 600 ? (time >= 3600 ? 83 : 65) : 55, alignment: .trailing)
                                    .lineLimit(1)
                            }
                        }
                        .fontDesign(.rounded)
                    }
                    DynamicIslandExpandedRegion(.bottom) {
                        if let transientStatusText = context.state.transientStatusText {
                            WorkoutLiveActivityTransientStatusView(text: transientStatusText)
                        } else if let name = context.state.exerciseName {
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
                                Text(WorkoutLiveActivityAccessibilityText.tapToAddExercise)
                                    .fontWeight(.semibold)
                                    .fontDesign(.rounded)
                                    .font(.title2)
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            Text(WorkoutLiveActivityAccessibilityText.allSetsComplete)
                                .fontWeight(.semibold)
                                .font(.title2)
                                .fontDesign(.rounded)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                } compactLeading: {
                    if let liveHeartRateBPM = context.state.liveHeartRateBPM {
                        HStack(spacing: 2) {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(.red)
                            Text(Int(liveHeartRateBPM.rounded()), format: .number)
                                .bold()
                                .font(.title2)
                        }
                    } else if let liveActiveEnergyBurned = context.state.liveActiveEnergyBurned {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(.orange)
                            Text(displayedLiveEnergyValue(for: liveActiveEnergyBurned, unit: context.state.energyUnit), format: .number.precision(.fractionLength(0)))
                                .bold()
                                .font(.title2)
                        }
                    } else {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .foregroundStyle(.green)
                    }
                } compactTrailing: {
                    Group {
                        if context.state.isTimerRunning, let endDate = context.state.timerEndDate {
                            Text(timerInterval: Date.now...endDate, countsDown: true)
                                .frame(maxWidth: 35)
                                .bold()
                                .font(.title2)
                        } else if context.state.isTimerPaused, let remaining = context.state.timerPausedRemaining {
                            HStack(spacing: 2) {
                                Image(systemName: "pause.fill")
                                Text(formatSeconds(remaining))
                                    .bold()
                                    .font(.title2)
                            }
                            .foregroundStyle(.yellow)
                        } else {
                            let time = Date.now.timeIntervalSince(context.attributes.startDate)
                            Text(context.attributes.startDate, style: .timer)
                                .frame(maxWidth: time >= 600 ? (time >= 3600 ? 57 : 45) : 35, alignment: .trailing)
                                .bold()
                                .font(.title2)
                        }
                    }
                    .fontDesign(.rounded)
                } minimal: {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .foregroundStyle(.green)
                }
            }
        }
        .supplementalActivityFamilies([.small])
    }
}

struct WorkoutLiveActivityExpandedView: View {
    @Environment(\.activityFamily) private var activityFamily
    let attributes: WorkoutActivityAttributes
    let state: WorkoutActivityAttributes.ContentState
    
    var body: some View {
        let isSmall = activityFamily == .small

        VStack(alignment: .leading, spacing: isSmall ? 6 : 8) {
            if state.isSummaryMode {
                if activityFamily == .small {
                    WorkoutLiveActivitySummarySmallTopRow(attributes: attributes, state: state)
                } else {
                    WorkoutLiveActivitySummaryTopRow(attributes: attributes, state: state)
                }

                Divider()

                WorkoutLiveActivitySummaryBottomContent(state: state, isSmall: isSmall)
            } else {
                if activityFamily == .small {
                    WorkoutLiveActivitySmallTopRow(attributes: attributes, state: state)
                } else {
                    WorkoutLiveActivityExpandedTopRow(attributes: attributes, state: state)
                }

                Divider()

                WorkoutLiveActivityExpandedBottomContent(state: state, isSmall: isSmall)
            }
        }
        .padding(isSmall ? 8 : 16)
        .activityBackgroundTint(isSmall ? .black : .clear)
    }
}

private enum WorkoutLiveActivitySummaryMetric: Hashable {
    case averageHeartRate(Double)
    case totalEnergy(Double, String?)
    case duration(Date, Date?)
    case personalRecords(Int)
    case completed
}

private struct WorkoutLiveActivitySummaryStatItem: Identifiable {
    let id: String
    let title: String
    let value: String
}

private struct WorkoutLiveActivitySummaryTopRow: View {
    let attributes: WorkoutActivityAttributes
    let state: WorkoutActivityAttributes.ContentState

    private var canShowMetricRow: Bool {
        state.averageHeartRateBPM != nil && state.totalEnergyBurned != nil
    }

    var body: some View {
        if canShowMetricRow {
            HStack(spacing: 12) {
                WorkoutLiveActivitySummaryTopMetricView(metric: .averageHeartRate(state.averageHeartRateBPM ?? 0))
                Spacer(minLength: 0)
                WorkoutLiveActivitySummaryTopMetricView(metric: .totalEnergy(state.totalEnergyBurned ?? 0, state.energyUnit))
                Spacer(minLength: 0)
                WorkoutLiveActivitySummaryTopMetricView(metric: .duration(attributes.startDate, state.endedAt))
            }
            .fontWeight(.semibold)
        } else {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(state.title)
                        .font(.title2)
                        .lineLimit(1)
                    Text(formattedWorkoutTimeRange(start: attributes.startDate, end: state.endedAt))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .fontDesign(.rounded)
                .fontWeight(.semibold)

                Spacer()

                WorkoutLiveActivitySummaryTopMetricView(metric: .duration(attributes.startDate, state.endedAt), unitVisibility: .always)
            }
        }
    }
}

private struct WorkoutLiveActivitySummarySmallTopRow: View {
    let attributes: WorkoutActivityAttributes
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(summaryCompactMetrics(attributes: attributes, state: state).prefix(2).enumerated()), id: \.offset) { _, metric in
                WorkoutLiveActivitySummaryCompactMetricView(metric: metric)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct WorkoutLiveActivitySummaryBottomContent: View {
    let state: WorkoutActivityAttributes.ContentState
    let isSmall: Bool

    var body: some View {
        WorkoutLiveActivitySummaryStatRow(state: state, isCompact: isSmall)
    }
}

private struct WorkoutLiveActivitySummaryTopMetricView: View {
    enum UnitVisibility {
        case automatic
        case always
    }

    let metric: WorkoutLiveActivitySummaryMetric
    var unitVisibility: UnitVisibility = .automatic

    var body: some View {
        HStack(spacing: 4) {
            metricIcon
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                Text(metricValue)
                    .font(.title3)
                    .lineLimit(1)
                    .monospacedDigit()

                if let unitText = metricUnitText, unitVisibility == .always || !unitText.isEmpty {
                    Text(unitText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .fontDesign(.rounded)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(metricAccessibilityLabel)
    }

    @ViewBuilder
    private var metricIcon: some View {
        switch metric {
        case .averageHeartRate:
            Image(systemName: "heart.fill")
                .foregroundStyle(.red)
        case .totalEnergy:
            Image(systemName: "flame.fill")
                .foregroundStyle(.orange)
        case .duration:
            Image(systemName: "clock.fill")
                .foregroundStyle(.blue)
        case .personalRecords:
            Image(systemName: "trophy.fill")
                .foregroundStyle(.yellow)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
    }

    private var metricValue: String {
        switch metric {
        case let .averageHeartRate(value):
            "\(Int(value.rounded()))"
        case let .totalEnergy(value, unit):
            Int(displayedLiveEnergyValue(for: value, unit: unit).rounded()).formatted(.number)
        case let .duration(startDate, endDate):
            formattedWorkoutDuration(start: startDate, end: endDate)
        case let .personalRecords(count):
            "\(count)"
        case .completed:
            WorkoutLiveActivityAccessibilityText.done
        }
    }

    private var metricUnitText: String? {
        switch metric {
        case .averageHeartRate:
            String(localized: "bpm")
        case let .totalEnergy(_, unit):
            displayedLiveEnergyUnitText(for: unit)
        case .duration:
            String(localized: "Duration")
        case .personalRecords:
            WorkoutLiveActivityAccessibilityText.prsTitle
        case .completed:
            nil
        }
    }

    private var metricAccessibilityLabel: String {
        switch metric {
        case let .averageHeartRate(value):
            String(localized: "Average heart rate \(Int(value.rounded())) beats per minute")
        case let .totalEnergy(value, unit):
            String(localized: "Total calories \(Int(displayedLiveEnergyValue(for: value, unit: unit).rounded())) \(displayedLiveEnergyUnitText(for: unit))")
        case let .duration(startDate, endDate):
            String(localized: "Duration \(formattedWorkoutDuration(start: startDate, end: endDate))")
        case let .personalRecords(count):
            String(localized: "\(count) personal records")
        case .completed:
            WorkoutLiveActivityAccessibilityText.completedLabel
        }
    }
}

private struct WorkoutLiveActivitySummaryCompactMetricView: View {
    let metric: WorkoutLiveActivitySummaryMetric?
    var alignment: Alignment = .leading

    var body: some View {
        if let metric {
            HStack(spacing: 2) {
                summaryMetricIcon(metric)
                    .accessibilityHidden(true)

                Text(summaryCompactMetricText(metric))
                    .bold()
                    .font(.title3)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: alignment)
            .fontDesign(.rounded)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(summaryMetricAccessibilityLabel(metric))
        }
    }
}

private struct WorkoutLiveActivitySummaryIslandMetricView: View {
    let metric: WorkoutLiveActivitySummaryMetric?
    var alignment: Alignment = .leading

    var body: some View {
        if let metric {
            HStack(spacing: 4) {
                summaryMetricIcon(metric)
                    .accessibilityHidden(true)

                Text(summaryExpandedMetricText(metric))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: alignment)
            .fontDesign(.rounded)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(summaryMetricAccessibilityLabel(metric))
        }
    }
}

private struct WorkoutLiveActivitySummaryStatRow: View {
    let state: WorkoutActivityAttributes.ContentState
    let isCompact: Bool

    private var statItems: [WorkoutLiveActivitySummaryStatItem] {
        var items = [
            WorkoutLiveActivitySummaryStatItem(id: "exercises", title: WorkoutLiveActivityAccessibilityText.exercisesTitle, value: "\(state.completedExerciseCount ?? 0)"),
            WorkoutLiveActivitySummaryStatItem(id: "sets", title: WorkoutLiveActivityAccessibilityText.setsTitle, value: "\(state.completedSetCount ?? 0)")
        ]

        if let prCount = state.summaryPRCount, prCount > 0 {
            items.append(.init(id: "prs", title: WorkoutLiveActivityAccessibilityText.prsTitle, value: "\(prCount)"))
        }

        if let summaryVolume = state.summaryVolume {
            items.append(.init(id: "volume", title: WorkoutLiveActivityAccessibilityText.volumeTitle, value: formattedSummaryVolume(summaryVolume, unit: state.weightUnit)))
        }

        return items
    }

    var body: some View {
        HStack(spacing: isCompact ? 8 : 10) {
            ForEach(statItems) { item in
                VStack(spacing: isCompact ? 2 : 4) {
                    Text(item.title)
                        .font(isCompact ? .caption2 : .caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(item.value)
                        .font(isCompact ? .caption : .headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity)
                .fontDesign(.rounded)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String(localized: "\(item.title), \(item.value)"))
            }
        }
    }
}

private struct WorkoutLiveActivityExpandedBottomContent: View {
    let state: WorkoutActivityAttributes.ContentState
    let isSmall: Bool

    var body: some View {
        if let transientStatusText = state.transientStatusText {
            WorkoutLiveActivityTransientStatusView(text: transientStatusText, isExpanded: !isSmall)
        } else if let exerciseName = state.exerciseName {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: isSmall ? 1 : 2) {
                    Text(exerciseName)
                        .font(isSmall ? .caption : .title2)
                        .lineLimit(1)
                    Text(isSmall ? compactSetDescription(state) : setDescription(state))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .font(isSmall ? .caption2 : .headline)
                }
                .fontDesign(.rounded)
                .fontWeight(.semibold)
                Spacer()
                Button(intent: LiveActivityCompleteSetIntent()) {
                    Image(systemName: "checkmark")
                        .font(isSmall ? .caption : .title2)
                        .fontWeight(.bold)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel(WorkoutLiveActivityAccessibilityText.completeSetLabel)
            }
        } else if !state.hasExercises {
            Button(intent: LiveActivityAddExerciseIntent()) {
                Text(WorkoutLiveActivityAccessibilityText.tapToAddExercise)
                    .fontDesign(.rounded)
                    .font(isSmall ? .footnote : .title2)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.plain)
        } else {
            Text(WorkoutLiveActivityAccessibilityText.allSetsComplete)
                .fontDesign(.rounded)
                .font(isSmall ? .footnote : .title2)
                .fontWeight(.semibold)
        }
    }
}

private struct WorkoutLiveActivitySmallTopRow: View {
    let attributes: WorkoutActivityAttributes
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 0) {
            if let liveHeartRateBPM = state.liveHeartRateBPM {
                WorkoutLiveActivityIslandMetricView(symbolName: "heart.fill", number: Double(Int(liveHeartRateBPM.rounded())), tint: .red, isSmall: true)
                Spacer()
            }

            if let liveActiveEnergyBurned = state.liveActiveEnergyBurned {
                WorkoutLiveActivityIslandMetricView(symbolName: "flame.fill", number: displayedLiveEnergyValue(for: liveActiveEnergyBurned, unit: state.energyUnit), tint: .orange, isSmall: true)
            }

            Spacer()
            Group {
                if state.isTimerRunning, let endDate = state.timerEndDate {
                    HStack(spacing: 2) {
                        Image(systemName: "timer")
                        Text(timerInterval: Date.now...endDate, countsDown: true)
                            .frame(maxWidth: 35, alignment: .trailing)
                    }
                } else if state.isTimerPaused, let remaining = state.timerPausedRemaining {
                    HStack(spacing: 2) {
                        Image(systemName: "pause.fill")
                        Text(formatSeconds(remaining))
                    }
                    .foregroundStyle(.yellow)
                } else {
                    let time = Date.now.timeIntervalSince(attributes.startDate)
                    HStack(spacing: 2) {
                        Image(systemName: "clock")
                        Text(attributes.startDate, style: .timer)
                            .frame(maxWidth: time >= 600 ? (time >= 3600 ? 50 : 40) : 35, alignment: .trailing)
                    }
                }
            }
            .fontDesign(.rounded)
            .fontWeight(.semibold)
            .font(.caption2)

        }
        .lineLimit(1)
    }
}

private struct WorkoutLiveActivityExpandedTopRow: View {
    let attributes: WorkoutActivityAttributes
    let state: WorkoutActivityAttributes.ContentState

    private var visibleTopItemCount: Int {
        var count = 0
        if state.liveHeartRateBPM != nil { count += 1 }
        if state.liveActiveEnergyBurned != nil { count += 1 }
        if state.isTimerActive { count += 1 }
        return count
    }

    var body: some View {
        Group {
            if visibleTopItemCount > 1 {
                HStack {
                    if let liveHeartRateBPM = state.liveHeartRateBPM {
                        WorkoutLiveActivityExpandedMetricView(symbolName: "heart.fill", number: Double(Int(liveHeartRateBPM.rounded())), tint: .red)
                        if state.liveActiveEnergyBurned != nil || state.isTimerActive { Spacer() }
                    }

                    if let liveActiveEnergyBurned = state.liveActiveEnergyBurned {
                        WorkoutLiveActivityExpandedMetricView(symbolName: "flame.fill", number: displayedLiveEnergyValue(for: liveActiveEnergyBurned, unit: state.energyUnit), unitText: displayedLiveEnergyUnitText(for: state.energyUnit), tint: .orange)
                        if state.isTimerActive { Spacer() }
                    }

                    topRowTimerView
                }
                .fontDesign(.rounded)
                .fontWeight(.semibold)
            } else {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(state.title)
                            .font(.title2)
                            .lineLimit(1)
                        Text(attributes.startDate, style: .date)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .fontDesign(.rounded)
                    .fontWeight(.semibold)

                    Spacer()

                    if let liveHeartRateBPM = state.liveHeartRateBPM {
                        WorkoutLiveActivityExpandedMetricView(symbolName: "heart.fill", number: Double(Int(liveHeartRateBPM.rounded())), tint: .red)
                    } else if let liveActiveEnergyBurned = state.liveActiveEnergyBurned {
                        WorkoutLiveActivityExpandedMetricView(symbolName: "flame.fill", number: displayedLiveEnergyValue(for: liveActiveEnergyBurned, unit: state.energyUnit), unitText: displayedLiveEnergyUnitText(for: state.energyUnit), tint: .orange)
                    } else {
                        topRowTimerView
                    }
                }
                .fontDesign(.rounded)
                .fontWeight(.semibold)
            }
        }
    }

    @ViewBuilder
    private var topRowTimerView: some View {
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
        }
    }
}

private struct WorkoutLiveActivityTransientStatusView: View {
    let text: String
    var isExpanded: Bool = false

    var body: some View {
        HStack(spacing: isExpanded ? 12 : 8) {
            Image(systemName: "bell.badge.fill")
                .font(isExpanded ? .title2 : .title3)
                .foregroundStyle(.yellow)
                .accessibilityHidden(true)

            Text(text)
                .font(isExpanded ? .title : .title2)
                .bold()
        }
        .fontDesign(.rounded)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
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
                WorkoutLiveActivityIslandMetricView(symbolName: "flame.fill", number: displayedLiveEnergyValue(for: liveActiveEnergyBurned, unit: state.energyUnit), tint: .orange)
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
    var isSmall: Bool = false

    var body: some View {
        HStack(spacing: isSmall ? 2 : 4) {
            Image(systemName: symbolName)
                .font(isSmall ? .caption2 : nil)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(number, format: .number.precision(.fractionLength(0)))
                .font(isSmall ? .caption2 : .title2)
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

private func displayedLiveEnergyValue(for kilocalories: Double, unit: String?) -> Double {
    switch unit {
    case "kJ":
        return Double(Int((kilocalories * 4.184).rounded()))
    default:
        return Double(Int(kilocalories.rounded()))
    }
}

private func displayedLiveEnergyUnitText(for unit: String?) -> String {
    switch unit {
    case "kJ":
        return "kJ"
    default:
        return "kcal"
    }
}

private func summaryCompactMetrics(attributes: WorkoutActivityAttributes, state: WorkoutActivityAttributes.ContentState) -> [WorkoutLiveActivitySummaryMetric] {
    var metrics: [WorkoutLiveActivitySummaryMetric] = []

    if let averageHeartRateBPM = state.averageHeartRateBPM {
        metrics.append(.averageHeartRate(averageHeartRateBPM))
    }

    if let totalEnergyBurned = state.totalEnergyBurned {
        metrics.append(.totalEnergy(totalEnergyBurned, state.energyUnit))
    }

    metrics.append(.duration(attributes.startDate, state.endedAt))

    if let prCount = state.summaryPRCount, prCount > 0 {
        metrics.append(.personalRecords(prCount))
    } else {
        metrics.append(.completed)
    }

    return Array(metrics.prefix(2))
}

@ViewBuilder
private func summaryMetricIcon(_ metric: WorkoutLiveActivitySummaryMetric) -> some View {
    switch metric {
    case .averageHeartRate:
        Image(systemName: "heart.fill")
            .foregroundStyle(.red)
    case .totalEnergy:
        Image(systemName: "flame.fill")
            .foregroundStyle(.orange)
    case .duration:
        Image(systemName: "clock.fill")
            .foregroundStyle(.blue)
    case .personalRecords:
        Image(systemName: "trophy.fill")
            .foregroundStyle(.yellow)
    case .completed:
        Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(.green)
    }
}

private func summaryCompactMetricText(_ metric: WorkoutLiveActivitySummaryMetric) -> String {
    switch metric {
    case let .averageHeartRate(value):
        Int(value.rounded()).formatted(.number)
    case let .totalEnergy(value, unit):
        Int(displayedLiveEnergyValue(for: value, unit: unit).rounded()).formatted(.number)
    case let .duration(startDate, endDate):
        formattedWorkoutDuration(start: startDate, end: endDate)
    case let .personalRecords(count):
        "\(count)"
    case .completed:
        WorkoutLiveActivityAccessibilityText.done
    }
}

private func summaryExpandedMetricText(_ metric: WorkoutLiveActivitySummaryMetric) -> String {
    switch metric {
    case let .averageHeartRate(value):
        String(localized: "\(Int(value.rounded())) bpm")
    case let .totalEnergy(value, unit):
        "\(Int(displayedLiveEnergyValue(for: value, unit: unit).rounded()).formatted(.number)) \(displayedLiveEnergyUnitText(for: unit))"
    case let .duration(startDate, endDate):
        formattedWorkoutDuration(start: startDate, end: endDate)
    case let .personalRecords(count):
        String(localized: "\(count) PRs")
    case .completed:
        WorkoutLiveActivityAccessibilityText.done
    }
}

private func summaryMetricAccessibilityLabel(_ metric: WorkoutLiveActivitySummaryMetric) -> String {
    switch metric {
    case let .averageHeartRate(value):
        String(localized: "Average heart rate \(Int(value.rounded())) beats per minute")
    case let .totalEnergy(value, unit):
        String(localized: "Total calories \(Int(displayedLiveEnergyValue(for: value, unit: unit).rounded())) \(displayedLiveEnergyUnitText(for: unit))")
    case let .duration(startDate, endDate):
        String(localized: "Duration \(formattedWorkoutDuration(start: startDate, end: endDate))")
    case let .personalRecords(count):
        String(localized: "\(count) personal records")
    case .completed:
        WorkoutLiveActivityAccessibilityText.completedLabel
    }
}

private func formattedWorkoutDuration(start: Date, end: Date?) -> String {
    let endDate = end ?? .now
    let totalSeconds = max(0, Int(endDate.timeIntervalSince(start)))
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60

    if hours > 0 {
        return String(localized: "\(hours)h \(minutes)m")
    }

    return String(localized: "\(minutes)m")
}

private func formattedWorkoutTimeRange(start: Date, end: Date?) -> String {
    guard let end else {
        return start.formatted(date: .omitted, time: .shortened)
    }

    return "\(start.formatted(date: .omitted, time: .shortened)) - \(end.formatted(date: .omitted, time: .shortened))"
}

private func formattedSummaryVolume(_ volumeInKilograms: Double, unit: String?) -> String {
    let displayedVolume: Double
    switch unit {
    case "lbs":
        displayedVolume = volumeInKilograms * 2.2046226218
    default:
        displayedVolume = volumeInKilograms
    }

    let formatted = displayedVolume.formatted(.number.precision(.fractionLength(0...1)))
    return "\(formatted) \(unit ?? "kg")"
}

private func setDescription(_ state: WorkoutActivityAttributes.ContentState) -> String {
    guard let setNumber = state.setNumber,
          let totalSets = state.totalSets else {
        return ""
    }
    
    var parts: [String] = [String(localized: "Set \(setNumber)/\(totalSets)")]
    
    if let reps = state.reps, reps > 0 {
        parts.append(String(localized: "\(reps) reps"))
    }

    if let weight = state.weight, weight > 0 {
        let unit = state.weightUnit ?? "lbs"
        let formatted = weight.formatted(.number.precision(.fractionLength(0...1)))
        parts.append("\(formatted) \(unit)")
    }
    
    if let targetRPE = state.targetRPE {
        parts.append(String(localized: "RPE \(targetRPE)"))
    }
    
    return parts.joined(separator: " · ")
}

private func compactSetDescription(_ state: WorkoutActivityAttributes.ContentState) -> String {
    var parts: [String] = []
    let reps = state.reps.flatMap { $0 > 0 ? $0 : nil }
    let weight = state.weight.flatMap { $0 > 0 ? $0 : nil }
    let unit = state.weightUnit ?? "lbs"
    let formattedWeight = weight?.formatted(.number.precision(.fractionLength(0...1)))

    if let targetRPE = state.targetRPE,
       let reps,
       let formattedWeight {
        parts.append("\(reps)x\(formattedWeight) \(unit)")
        parts.append(String(localized: "RPE \(targetRPE)"))
        return parts.joined(separator: " · ")
    }

    if let reps {
        parts.append(String(localized: "\(reps) reps"))
    }

    if let formattedWeight {
        parts.append("\(formattedWeight) \(unit)")
    }

    if let targetRPE = state.targetRPE {
        parts.append(String(localized: "RPE \(targetRPE)"))
    }

    return parts.joined(separator: " · ")
}
