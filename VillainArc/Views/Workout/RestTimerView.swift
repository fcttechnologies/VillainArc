import SwiftUI
import SwiftData

struct RestTimerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let restTimer = RestTimerState.shared
    @Environment(\.modelContext) private var context
    @Query(RestTimeHistory.recents) private var recentTimes: [RestTimeHistory]
    @State private var selectedSeconds = RestTimeDefaults.restSeconds
    @Bindable var workout: WorkoutSession
    let appSettingsSnapshot: AppSettingsSnapshot
    @ScaledMetric(relativeTo: .largeTitle) private var timerFontSize: CGFloat = 80

    private var weightUnit: WeightUnit { appSettingsSnapshot.weightUnit }
    private var autoStartRestTimerEnabled: Bool { appSettingsSnapshot.autoStartRestTimer }
    private var currentRestSeconds: Int {
        if restTimer.isRunning, let endDate = restTimer.endDate {
            return max(0, Int(endDate.timeIntervalSinceNow.rounded(.up)))
        }
        if restTimer.isPaused {
            return restTimer.pausedRemainingSeconds
        }
        return selectedSeconds
    }

    private var restProgress: Double {
        guard restTimer.isActive else { return 0 }
        let started = max(restTimer.startedSeconds, currentRestSeconds, 1)
        let elapsed = max(0, started - currentRestSeconds)
        return min(max(Double(elapsed) / Double(started), 0), 1)
    }
    
    var body: some View {
        NavigationStack {
            List {
                VStack(spacing: 0) {
                    timerDisplay
                    nextSetView
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .accessibilityIdentifier(AccessibilityIdentifiers.restTimerCountdown)
                .accessibilityLabel(AccessibilityText.restTimerLabel)
                .accessibilityValue(restTimer.isPaused ? AccessibilityText.restTimerValuePaused : restTimer.isRunning ? AccessibilityText.restTimerValueRunning : AccessibilityText.restTimerValueReady)
                
                if !restTimer.isActive {
                    TimerDurationPicker(seconds: $selectedSeconds, showZero: false)
                        .frame(height: 60)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .accessibilityIdentifier(AccessibilityIdentifiers.restTimerDurationPicker)
                }
                
                controls
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                
                if !restTimer.isActive && !recentTimes.isEmpty {
                    Section("Recents") {
                        ForEach(Array(recentTimes.enumerated()), id: \.element.id) { index, history in
                            HStack {
                                Text(secondsToTime(history.seconds))
                                    .font(.title)
                                    .fontWeight(.semibold)
                                
                                Spacer()
                                
                                Button {
                                    Haptics.selection()
                                    restTimer.start(seconds: history.seconds)
                                    RestTimeHistory.record(seconds: history.seconds, context: context)
                                    saveContext(context: context)
                                    Task { await IntentDonations.donateStartRestTimer(seconds: history.seconds) }
                                } label: {
                                    Label("Start Rest Timer", systemImage: "play.fill")
                                        .padding()
                                        .fontWeight(.semibold)
                                        .font(.title2)
                                        .labelStyle(.iconOnly)
                                }
                                .buttonBorderShape(.circle)
                                .buttonStyle(.glassProminent)
                                .tint(.blue)
                                .accessibilityIdentifier(AccessibilityIdentifiers.restTimerRecentStartButton(history))
                                .accessibilityLabel(AccessibilityText.restTimerRecentStartLabel(seconds: history.seconds, secondsToTime: secondsToTime))
                                .accessibilityHint(AccessibilityText.restTimerStartHint)
                            }
                            .appGroupedListRow(position: rowPosition(for: index, count: recentTimes.count))
                            .accessibilityIdentifier(AccessibilityIdentifiers.restTimerRecentRow(history))
                        }
                        .onDelete(perform: deleteRecentTimes)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .accessibilityIdentifier(AccessibilityIdentifiers.restTimerList)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) {
                        Haptics.selection()
                        dismiss()
                    }
                    .accessibilityLabel(AccessibilityText.restTimerCloseLabel)
                    .accessibilityIdentifier(AccessibilityIdentifiers.restTimerCloseButton)
                }
            }
            .onAppear {
                if let recent = recentTimes.first {
                    selectedSeconds = recent.seconds
                }
            }
            .onChange(of: restTimer.completionCount) {
                Haptics.success()
            }
        }
    }

    private func rowPosition(for index: Int, count: Int) -> AppGroupedListRowPosition {
        if count <= 1 { return .single }
        if index == 0 { return .top }
        if index == count - 1 { return .bottom }
        return .middle
    }
    
    @ViewBuilder
    private var controls: some View {
        if restTimer.isRunning {
            HStack(spacing: 12) {
                Button {
                    Haptics.selection()
                    restTimer.stop()
                    Task { await IntentDonations.donateStopRestTimer() }
                } label: {
                    Label("Skip", systemImage: "forward.fill")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .padding(.vertical, 5)
                }
                .buttonSizing(.flexible)
                .buttonStyle(.glassProminent)
                .tint(.red)
                .accessibilityIdentifier(AccessibilityIdentifiers.restTimerStopButton)
                .accessibilityHint(AccessibilityText.restTimerStopHint)

                extendButton(deltaSeconds: 30)
                
                Button {
                    Haptics.selection()
                    restTimer.pause()
                    Task { await IntentDonations.donatePauseRestTimer() }
                } label: {
                    Label("Pause", systemImage: "pause.fill")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .padding(.vertical, 5)
                }
                .buttonSizing(.flexible)
                .buttonStyle(.glassProminent)
                .tint(.yellow)
                .accessibilityIdentifier(AccessibilityIdentifiers.restTimerPauseButton)
                .accessibilityHint(AccessibilityText.restTimerPauseHint)
            }
        } else if restTimer.isPaused {
            HStack(spacing: 12) {
                Button {
                    Haptics.selection()
                    restTimer.stop()
                    Task { await IntentDonations.donateStopRestTimer() }
                } label: {
                    Label("Skip", systemImage: "forward.fill")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .padding(.vertical, 5)
                }
                .buttonSizing(.flexible)
                .buttonStyle(.glassProminent)
                .tint(.red)
                .accessibilityIdentifier(AccessibilityIdentifiers.restTimerStopButton)
                .accessibilityHint(AccessibilityText.restTimerStopHint)

                extendButton(deltaSeconds: 30)
                
                Button {
                    Haptics.selection()
                    restTimer.resume()
                    Task { await IntentDonations.donateResumeRestTimer() }
                } label: {
                    Label("Resume", systemImage: "play.fill")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .padding(.vertical, 5)
                }
                .buttonSizing(.flexible)
                .buttonStyle(.glassProminent)
                .tint(.green)
                .accessibilityIdentifier(AccessibilityIdentifiers.restTimerResumeButton)
                .accessibilityHint(AccessibilityText.restTimerResumeHint)
            }
        } else {
            Button {
                Haptics.selection()
                restTimer.start(seconds: selectedSeconds)
                RestTimeHistory.record(seconds: selectedSeconds, context: context)
                saveContext(context: context)
                Task { await IntentDonations.donateStartRestTimer(seconds: selectedSeconds) }
            } label: {
                Text("Start")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .padding(.vertical, 5)
            }
            .buttonSizing(.flexible)
            .buttonStyle(.glassProminent)
            .tint(.blue)
            .accessibilityIdentifier(AccessibilityIdentifiers.restTimerStartButton)
            .accessibilityHint(AccessibilityText.restTimerStartHint)
        }
    }

    @ViewBuilder
    private var timerDisplay: some View {
        VStack(spacing: 14) {
            if restTimer.isActive {
                Text(restTimer.isPaused ? "Rest Paused" : "Rest")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Rest Length")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            ZStack {
                Circle()
                    .stroke(.secondary.opacity(0.18), lineWidth: 12)
                if restTimer.isActive {
                    Circle()
                        .trim(from: 0, to: restProgress)
                        .stroke(.blue, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(reduceMotion ? nil : .smooth, value: restProgress)
                }

                VStack(spacing: 2) {
                    timerText

                    if restTimer.isRunning, let endDate = restTimer.endDate, endDate > Date() {
                        Label {
                            Text(endDate, format: .dateTime.hour().minute())
                        } icon: {
                            Image(systemName: "bell")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    } else if restTimer.isPaused {
                        Text("Paused")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.yellow)
                    }
                }
                .padding(.horizontal)
            }
            .frame(width: 230, height: 230)

            if restTimer.isActive {
                HStack(spacing: 12) {
                    adjustButton(deltaSeconds: -15)
                    adjustButton(deltaSeconds: 15)
                    adjustButton(deltaSeconds: 60)
                }
            }
        }
    }

    @ViewBuilder
    private var timerText: some View {
        if restTimer.isRunning, let endDate = restTimer.endDate, endDate > Date() {
            Text(timerInterval: .now...endDate, countsDown: true)
                .font(.system(size: timerFontSize, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.62)
                .lineLimit(1)
        } else {
            let displayText = secondsToTime(currentRestSeconds)

            Text(displayText)
                .font(.system(size: timerFontSize, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.62)
                .lineLimit(1)
                .contentTransition(.numericText(value: Double(currentRestSeconds)))
        }
    }

    private func adjustButton(deltaSeconds: Int) -> some View {
        Button {
            Haptics.selection()
            withAnimation(reduceMotion ? nil : .smooth) {
                restTimer.adjust(by: deltaSeconds)
            }
        } label: {
            Text(verbatim: "\(deltaSeconds < 0 ? "-" : "+")\(abs(deltaSeconds))")
                .fontWeight(.semibold)
                .padding(5)
                .font(.subheadline)
        }
        .buttonBorderShape(.circle)
        .buttonStyle(.glass)
        .tint(deltaSeconds < 0 ? .red : .blue)
        .accessibilityIdentifier(AccessibilityIdentifiers.restTimerAdjustButton(deltaSeconds: deltaSeconds))
        .accessibilityLabel(AccessibilityText.restTimerAdjustLabel(deltaSeconds: deltaSeconds))
        .accessibilityHint(AccessibilityText.restTimerAdjustHint)
    }

    private func extendButton(deltaSeconds: Int) -> some View {
        Button {
            Haptics.selection()
            withAnimation(reduceMotion ? nil : .smooth) {
                restTimer.adjust(by: deltaSeconds)
            }
        } label: {
            Label("+\(deltaSeconds)s", systemImage: "plus")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.vertical, 5)
        }
        .buttonSizing(.flexible)
        .buttonStyle(.glassProminent)
        .tint(.blue)
        .accessibilityIdentifier(AccessibilityIdentifiers.restTimerAdjustButton(deltaSeconds: deltaSeconds))
        .accessibilityLabel(AccessibilityText.restTimerAdjustLabel(deltaSeconds: deltaSeconds))
        .accessibilityHint(AccessibilityText.restTimerAdjustHint)
    }

    @ViewBuilder
    private var nextSetView: some View {
        if let (exercise, nextSet) = workout.activeExerciseAndSet() {
            let weightText = formattedWeight(nextSet.weight)
            let isBodyweightSet = nextSet.reps > 0 && nextSet.weight == 0
            let setText = isBodyweightSet
                ? "\(nextSet.reps) reps"
                : "\(nextSet.reps)x\(weightText)\(weightUnit.rawValue)"
            let accessibilityValue = isBodyweightSet
                ? String(localized: "\(exercise.name), \(nextSet.reps) reps")
                : String(localized: "\(exercise.name), \(nextSet.reps) reps, \(weightText) \(weightUnit.rawValue)")

            HStack(spacing: 12) {
                Text("\(exercise.name): \(setText)")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .accessibilityIdentifier(AccessibilityIdentifiers.restTimerNextSet)
                    .accessibilityLabel(AccessibilityText.restTimerNextSetLabel)
                    .accessibilityValue(accessibilityValue)

                Button {
                    completeNextSet()
                } label: {
                    Image(systemName: "checkmark")
                }
                .buttonBorderShape(.circle)
                .buttonStyle(.glass)
                .tint(.blue)
                .accessibilityIdentifier(AccessibilityIdentifiers.restTimerCompleteSetButton)
                .accessibilityLabel(AccessibilityText.restTimerCompleteSetLabel)
                .accessibilityHint(AccessibilityText.restTimerCompleteAndRestartHint)
            }
        }
    }

    private func formattedWeight(_ weight: Double) -> String {
        weight.formatted(.number.precision(.fractionLength(0...2)))
    }
    
    private func deleteRecentTimes(at offsets: IndexSet) {
        guard !offsets.isEmpty else { return }
        Haptics.selection()
        
        for index in offsets {
            let history = recentTimes[index]
            context.delete(history)
        }
        saveContext(context: context)
    }

    private func completeNextSet() {
        guard let (_, nextSet) = workout.activeExerciseAndSet() else { return }
        let shouldPrewarmSuggestions = workout.workoutPlan != nil && workout.isFinalIncompleteSet(nextSet)
        Haptics.selection()
        workout.completeSet(nextSet, settings: appSettingsSnapshot)

        let restSeconds = nextSet.effectiveRestSeconds
        if autoStartRestTimerEnabled {
            restTimer.start(seconds: restSeconds, startedFromSetID: nextSet.id)
            if restSeconds > 0 {
                RestTimeHistory.record(seconds: restSeconds, context: context)
                Task { await IntentDonations.donateStartRestTimer(seconds: restSeconds) }
            }
        }
        saveContext(context: context)
        WorkoutActivityManager.update(for: workout)
        if shouldPrewarmSuggestions {
            FoundationModelPrewarmer.warmup()
        }
        Task { await IntentDonations.donateCompleteActiveSet() }
    }
}

#Preview(traits: .sampleData) {
    RestTimerView(
        workout: sampleIncompleteSession(),
        appSettingsSnapshot: AppSettingsSnapshot(settings: nil)
    )
}
