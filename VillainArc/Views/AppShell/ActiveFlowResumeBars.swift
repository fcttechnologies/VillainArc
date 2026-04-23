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
        Button(action: openAction) {
            HStack {
                workoutTextStack
                .font(.subheadline)
                .fontWeight(.semibold)
                .fontDesign(.rounded)
                Spacer()

                if restTimer.isRunning, let endDate = restTimer.endDate, endDate > .now {
                    Text(timerInterval: .now...endDate, countsDown: true)
                        .fontWeight(.semibold)
                        .accessibilityLabel(AccessibilityText.activeWorkoutResumeRestTimerLabel)
                } else if restTimer.isPaused {
                    HStack(spacing: 3) {
                        Image(systemName: "pause.fill")
                        Text(secondsToTime(restTimer.pausedRemainingSeconds))
                            .accessibilityLabel(AccessibilityText.activeWorkoutResumeRestTimerLabel)
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(.yellow)
                } else if activeSetInfo != nil {
                    Button {
                        completeNextSet()
                    } label: {
                        Image(systemName: "checkmark")
                            .fontWeight(.semibold)
                            .fontDesign(.rounded)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.regular)
                    .accessibilityIdentifier(AccessibilityIdentifiers.activeWorkoutResumeCompleteSetButton)
                    .accessibilityLabel(AccessibilityText.activeWorkoutResumeCompleteSetLabel)
                    .accessibilityHint(AccessibilityText.activeWorkoutResumeCompleteSetHint)
                }
            }
            .padding(.horizontal, 3)
            .contentShape(.rect)
            .accessibilityElement(children: .combine)
        }
        .accessibilityIdentifier(AccessibilityIdentifiers.activeWorkoutResumeBarButton)
        .accessibilityLabel(workoutAccessibilityLabel())
        .accessibilityHint(AccessibilityText.activeWorkoutResumeHint)
        .accessibilityElement(children: .contain)
        .activeFlowResumeBarChrome(isCollapsed: isCollapsed, reduceMotion: reduceMotion)
    }

    @ViewBuilder
    private var workoutTextStack: some View {
        if shouldFlipActiveSetTextOrder {
            VStack(alignment: .leading, spacing: 1) {
                Text(workoutDetailLine())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(displayTitle())
                    .lineLimit(1)
            }
        } else {
            VStack(alignment: .leading, spacing: 1) {
                Text(displayTitle())
                    .lineLimit(1)

                Text(workoutDetailLine())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
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

    private var shouldFlipActiveSetTextOrder: Bool {
        workout.statusValue == .active && activeSetInfo != nil
    }

    private func displayTitle() -> String {
        switch workout.statusValue {
        case .pending, .summary, .done:
            let trimmedTitle = workout.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedTitle.isEmpty ? "New Workout" : trimmedTitle
        case .active:
            return activeSetInfo?.exercise.name ?? workout.title
        }
    }

    private func pendingSuggestionCount() -> Int {
        guard let plan = workout.workoutPlan else { return 0 }
        return pendingSuggestionEvents(for: plan, in: context).count
    }

    private func workoutAccessibilityLabel() -> String {
        switch workout.statusValue {
        case .pending:
            return String(localized: "Workout pending review. \(displayTitle()). \(workoutDetailLine())")
        case .summary, .done:
            return String(localized: "Workout summary ready. \(displayTitle()). \(workoutDetailLine())")
        case .active:
            return AccessibilityText.activeWorkoutResumeLabel(title: displayTitle(), detail: workoutDetailLine())
        }
    }

    private func workoutDetailLine() -> String {
        switch workout.statusValue {
        case .pending:
            let count = pendingSuggestionCount()
            if count > 0 {
                return localizedCountText(count, singular: "suggestion left", plural: "suggestions left")
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
            restTimer.start(seconds: restSeconds, startedFromSetID: set.id)
            if restSeconds > 0 {
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
        Button(action: openAction) {
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text(displayTitle())
                        .lineLimit(1)
                    Text(planSummaryLine())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .font(.subheadline)
                .fontDesign(.rounded)
                .fontWeight(.semibold)
                .padding(.leading, 3)
                Spacer()
            }
            .contentShape(.rect)
            .accessibilityElement(children: .combine)
        }
        .activeFlowResumeBarChrome(isCollapsed: isCollapsed, reduceMotion: reduceMotion)
        .accessibilityIdentifier(AccessibilityIdentifiers.activePlanResumeBarButton)
        .accessibilityLabel(AccessibilityText.activePlanResumeLabel(title: displayTitle(), detail: planSummaryLine()))
        .accessibilityHint(AccessibilityText.activePlanResumeHint)
    }

    private func displayTitle() -> String {
        let trimmedTitle = plan.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? "New Workout Plan" : trimmedTitle
    }

    private var weightUnit: WeightUnit {
        appSettings.first?.weightUnit ?? .lbs
    }

    private func planSummaryLine() -> String {
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
            .frame(maxWidth: .infinity)
            .buttonStyle(.glass)
            .scaleEffect(x: isCollapsed ? 0.1 : 1, y: isCollapsed ? 0.1 : 1, anchor: .center)
            .opacity(isCollapsed ? 0 : 1)
            .offset(y: isCollapsed ? 36 : 0)
            .allowsHitTesting(!isCollapsed)
            .animation(reduceMotion ? .easeInOut(duration: 0.2) : .bouncy(duration: 0.5, extraBounce: 0.06), value: isCollapsed)
    }
}
