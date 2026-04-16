import SwiftUI
import SwiftData

struct ActiveWorkoutResumeBarButton: View {
    @Bindable var workout: WorkoutSession
    let isCollapsed: Bool
    let openAction: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var context
    @Query(AppSettings.single) private var appSettings: [AppSettings]
    private let restTimer = RestTimerState.shared

    var body: some View {
        HStack(spacing: 10) {
            Button(action: openAction) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayTitle)
                        .font(.caption.weight(.semibold))
                        .fontDesign(.rounded)
                        .lineLimit(1)

                    Text(workoutDetailLine)
                        .font(.subheadline.weight(.semibold))
                        .fontDesign(.rounded)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(workoutAccessibilityLabel)
                .accessibilityHint(AccessibilityText.activeWorkoutResumeHint)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier(AccessibilityIdentifiers.activeWorkoutResumeBarButton)

            trailingControl
        }
        .activeFlowResumeBarChrome(isCollapsed: isCollapsed, reduceMotion: reduceMotion)
        .accessibilityElement(children: .contain)
    }

    private var weightUnit: WeightUnit {
        appSettings.first?.weightUnit ?? .lbs
    }

    private var autoStartRestTimerEnabled: Bool {
        appSettings.first?.autoStartRestTimer ?? true
    }

    private var activeSetInfo: (exercise: ExercisePerformance, set: SetPerformance)? {
        workout.activeExerciseAndSet()
    }

    private var displayTitle: String {
        switch workout.statusValue {
        case .pending, .summary, .done:
            let trimmedTitle = workout.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedTitle.isEmpty ? "New Workout" : trimmedTitle
        case .active:
            return activeSetInfo?.exercise.name ?? workout.title
        }
    }

    private var pendingSuggestionCount: Int {
        guard let plan = workout.workoutPlan else { return 0 }
        return pendingSuggestionEvents(for: plan, in: context).count
    }

    private var workoutAccessibilityLabel: String {
        switch workout.statusValue {
        case .pending:
            return String(localized: "Workout pending review. \(displayTitle). \(workoutDetailLine)")
        case .summary, .done:
            return String(localized: "Workout summary ready. \(displayTitle). \(workoutDetailLine)")
        case .active:
            return AccessibilityText.activeWorkoutResumeLabel(title: displayTitle, detail: workoutDetailLine)
        }
    }

    @ViewBuilder
    private var trailingControl: some View {
        switch workout.statusValue {
        case .pending, .summary, .done:
            resumeOpenButton
        case .active:
            if restTimer.isRunning, let endDate = restTimer.endDate, endDate > .now {
                Text(timerInterval: .now...endDate, countsDown: true)
                    .font(.headline.weight(.semibold))
                    .fontDesign(.rounded)
                    .frame(minWidth: 62, alignment: .trailing)
                    .accessibilityLabel(AccessibilityText.activeWorkoutResumeRestTimerLabel)
            } else if activeSetInfo != nil {
                Button {
                    completeNextSet()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.semibold))
                        .fontDesign(.rounded)
                        .frame(width: 30, height: 30)
                        .foregroundStyle(.white)
                        .background(.blue, in: .circle)
                }
                .buttonStyle(.plain)
                .frame(width: 46, height: 46)
                .accessibilityIdentifier(AccessibilityIdentifiers.activeWorkoutResumeCompleteSetButton)
                .accessibilityLabel(AccessibilityText.activeWorkoutResumeCompleteSetLabel)
                .accessibilityHint(AccessibilityText.activeWorkoutResumeCompleteSetHint)
            } else {
                Text(timerInterval: workout.startedAt...Date.now, countsDown: false)
                    .font(.headline.weight(.semibold))
                    .fontDesign(.rounded)
                    .frame(minWidth: 62, alignment: .trailing)
                    .accessibilityLabel(AccessibilityText.activeWorkoutResumeElapsedLabel)
            }
        }
    }

    private var resumeOpenButton: some View {
        Button(action: openAction) {
            Image(systemName: "arrow.up.forward")
                .font(.subheadline.weight(.semibold))
                .fontDesign(.rounded)
                .frame(width: 30, height: 30)
                .foregroundStyle(.white)
                .background(.blue, in: .circle)
        }
        .buttonStyle(.plain)
        .frame(width: 46, height: 46)
        .accessibilityIdentifier(AccessibilityIdentifiers.activeWorkoutResumeOpenButton)
        .accessibilityLabel(AccessibilityText.activeWorkoutResumeOpenButtonLabel)
        .accessibilityHint(AccessibilityText.activeWorkoutResumeHint)
    }

    private var workoutDetailLine: String {
        switch workout.statusValue {
        case .pending:
            if pendingSuggestionCount > 0 {
                return localizedCountText(pendingSuggestionCount, singular: "suggestion left", plural: "suggestions left")
            }
            return "Review suggestions to start"
        case .summary, .done:
            var parts = [
                localizedCountText(workout.totalExercises, singular: "exercise", plural: "exercises"),
                localizedCountText(workout.totalSets, singular: "set", plural: "sets")
            ]

            if workout.totalVolume > 0 {
                let formattedVolume = workout.totalVolume.formatted(.number.precision(.fractionLength(0...1)))
                parts.append("\(formattedVolume) \(weightUnit.rawValue) vol")
            }

            let prCount = WorkoutActivityManager.summaryPRCount(for: workout, context: context)
            if prCount > 0 {
                parts.append(localizedCountText(prCount, singular: "PR", plural: "PRs"))
            }

            return parts.joined(separator: " · ")
        case .active:
            guard let activeSetInfo else {
                if workout.exercises?.isEmpty ?? true {
                    return "No exercises added"
                }
                return "All sets complete"
            }

            let set = activeSetInfo.set
            let totalSets = activeSetInfo.exercise.sortedSets.count
            var parts: [String] = ["Set \(set.index + 1)/\(max(1, totalSets))"]

            if set.reps > 0 {
                parts.append("\(set.reps) reps")
            }

            if set.weight > 0 {
                let formattedWeight = set.weight.formatted(.number.precision(.fractionLength(0...1)))
                parts.append("\(formattedWeight) \(weightUnit.rawValue)")
            }

            if let targetRPE = set.prescription?.visibleTargetRPE {
                parts.append("RPE \(targetRPE)")
            }

            return parts.joined(separator: " · ")
        }
    }

    private func completeNextSet() {
        guard let (_, set) = activeSetInfo else { return }

        Haptics.selection()
        let shouldPrewarmSuggestions = workout.workoutPlan != nil && workout.isFinalIncompleteSet(set)
        set.complete = true
        set.completedAt = .now

        if autoStartRestTimerEnabled {
            let restSeconds = set.effectiveRestSeconds
            if restSeconds > 0 {
                restTimer.start(seconds: restSeconds, startedFromSetID: set.id)
                RestTimeHistory.record(seconds: restSeconds, context: context)
                Task { await IntentDonations.donateStartRestTimer(seconds: restSeconds) }
            }
        }

        saveContext(context: context)
        WorkoutActivityManager.update(for: workout)
        Task { await IntentDonations.donateCompleteActiveSet() }
        if shouldPrewarmSuggestions {
            FoundationModelPrewarmer.warmup()
        }
    }
}

struct ActivePlanResumeBarButton: View {
    @Bindable var plan: WorkoutPlan
    let isCollapsed: Bool
    let openAction: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(AppSettings.single) private var appSettings: [AppSettings]

    var body: some View {
        HStack(spacing: 10) {
            Button(action: openAction) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayTitle)
                        .font(.caption.weight(.semibold))
                        .fontDesign(.rounded)
                        .lineLimit(1)
                    Text(planSummaryLine)
                        .font(.subheadline.weight(.semibold))
                        .fontDesign(.rounded)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier(AccessibilityIdentifiers.activePlanResumeBarButton)
            .accessibilityLabel(AccessibilityText.activePlanResumeLabel(title: displayTitle, detail: planSummaryLine))
            .accessibilityHint(AccessibilityText.activePlanResumeHint)

            Button(action: openAction) {
                Image(systemName: "arrow.up.forward")
                    .font(.subheadline.weight(.semibold))
                    .fontDesign(.rounded)
                    .frame(width: 30, height: 30)
                    .foregroundStyle(.white)
                    .background(.blue, in: .circle)
            }
            .buttonStyle(.plain)
            .frame(width: 46, height: 46)
            .accessibilityIdentifier(AccessibilityIdentifiers.activePlanResumeOpenButton)
            .accessibilityLabel(AccessibilityText.activePlanResumeOpenButtonLabel)
            .accessibilityHint(AccessibilityText.activePlanResumeHint)
        }
        .activeFlowResumeBarChrome(isCollapsed: isCollapsed, reduceMotion: reduceMotion)
    }

    private var displayTitle: String {
        let trimmedTitle = plan.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? "New Workout Plan" : trimmedTitle
    }

    private var weightUnit: WeightUnit {
        appSettings.first?.weightUnit ?? .lbs
    }

    private var planSummaryLine: String {
        var parts = [
            localizedCountText(plan.totalExercises, singular: "exercise", plural: "exercises"),
            localizedCountText(plan.totalSets, singular: "set", plural: "sets")
        ]

        if plan.totalVolume > 0 {
            let formattedVolume = plan.totalVolume.formatted(.number.precision(.fractionLength(0...1)))
            parts.append("\(formattedVolume) \(weightUnit.rawValue) vol")
        }

        return parts.joined(separator: " · ")
    }
}

private extension View {
    func activeFlowResumeBarChrome(isCollapsed: Bool, reduceMotion: Bool) -> some View {
        self
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .frame(height: 52)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .glassEffect(.regular.interactive(), in: .capsule)
            .scaleEffect(x: isCollapsed ? 0.1 : 1, y: isCollapsed ? 0.1 : 1, anchor: .center)
            .opacity(isCollapsed ? 0 : 1)
            .offset(y: isCollapsed ? 36 : 0)
            .allowsHitTesting(!isCollapsed)
            .animation(reduceMotion ? .easeInOut(duration: 0.2) : .bouncy(duration: 0.5, extraBounce: 0.06), value: isCollapsed)
    }
}
