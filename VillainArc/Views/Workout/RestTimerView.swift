import SwiftUI
import SwiftData

struct RestTimerView: View {
    @Environment(\.dismiss) private var dismiss
    private let restTimer = RestTimerState.shared
    @Environment(\.modelContext) private var context
    @Query(RestTimeHistory.recents) private var recentTimes: [RestTimeHistory]
    @State private var selectedSeconds = RestTimePolicy.defaultRestSeconds
    @Bindable var workout: WorkoutSession
    
    var body: some View {
        NavigationStack {
            List {
                Group {
                    VStack(spacing: 0) {
                        timerDisplay
                        nextSetView
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowSeparator(.hidden)
                .accessibilityIdentifier("restTimerCountdown")
                .accessibilityLabel("Rest timer")
                .accessibilityValue(restTimer.isPaused ? "Paused" : restTimer.isRunning ? "Running" : "Ready")
                
                if !restTimer.isActive {
                    TimerDurationPicker(seconds: $selectedSeconds, showZero: false)
                        .frame(height: 60)
                        .listRowSeparator(.hidden)
                        .accessibilityIdentifier("restTimerDurationPicker")
                }
                
                controls
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowSeparator(.hidden)
                
                if !restTimer.isActive && !recentTimes.isEmpty {
                    Section("Recents") {
                        ForEach(recentTimes) { history in
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
                                .accessibilityIdentifier("restTimerRecentStartButton-\(history.seconds)")
                                .accessibilityLabel("Start \(secondsToTime(history.seconds)) timer")
                                .accessibilityHint("Starts the rest timer.")
                            }
                            .accessibilityIdentifier(AccessibilityIdentifiers.restTimerRecentRow(history))
                        }
                        .onDelete(perform: deleteRecentTimes)
                    }
                }
            }
            .listStyle(.plain)
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("restTimerList")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) {
                        Haptics.selection()
                        dismiss()
                    }
                    .accessibilityLabel("Close")
                    .accessibilityIdentifier("restTimerCloseButton")
                }
            }
            .onAppear {
                if let recent = recentTimes.first {
                    selectedSeconds = recent.seconds
                }
            }
        }
    }
    
    @ViewBuilder
    private var controls: some View {
        if restTimer.isRunning {
            HStack(spacing: 16) {
                Button {
                    Haptics.selection()
                    restTimer.stop()
                    Task { await IntentDonations.donateStopRestTimer() }
                } label: {
                    Text("Stop")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .padding(.vertical, 5)
                }
                .buttonSizing(.flexible)
                .buttonStyle(.glassProminent)
                .tint(.red)
                .accessibilityIdentifier("restTimerStopButton")
                .accessibilityHint("Stops the rest timer.")
                
                Button {
                    Haptics.selection()
                    restTimer.pause()
                    Task { await IntentDonations.donatePauseRestTimer() }
                } label: {
                    Text("Pause")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .padding(.vertical, 5)
                }
                .buttonSizing(.flexible)
                .buttonStyle(.glassProminent)
                .tint(.yellow)
                .accessibilityIdentifier("restTimerPauseButton")
                .accessibilityHint("Pauses the rest timer.")
            }
        } else if restTimer.isPaused {
            HStack(spacing: 16) {
                Button {
                    Haptics.selection()
                    restTimer.stop()
                    Task { await IntentDonations.donateStopRestTimer() }
                } label: {
                    Text("Stop")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .padding(.vertical, 5)
                }
                .buttonSizing(.flexible)
                .buttonStyle(.glassProminent)
                .tint(.red)
                .accessibilityIdentifier("restTimerStopButton")
                .accessibilityHint("Stops the rest timer.")
                
                Button {
                    Haptics.selection()
                    restTimer.resume()
                    Task { await IntentDonations.donateResumeRestTimer() }
                } label: {
                    Text("Resume")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .padding(.vertical, 5)
                }
                .buttonSizing(.flexible)
                .buttonStyle(.glassProminent)
                .tint(.green)
                .accessibilityIdentifier("restTimerResumeButton")
                .accessibilityHint("Resumes the rest timer.")
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
            .accessibilityIdentifier("restTimerStartButton")
            .accessibilityHint("Starts the rest timer.")
        }
    }

    @ViewBuilder
    private var timerDisplay: some View {
        if restTimer.isRunning, let endDate = restTimer.endDate, endDate > Date() {
            VStack(spacing: 6) {
                Text("\(Image(systemName: "bell")) \(endDate.formatted(date: .omitted, time: .shortened))")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    adjustButton(deltaSeconds: -15)

                    Text(endDate, style: .timer)
                        .font(.system(size: 80, weight: .bold))

                    adjustButton(deltaSeconds: 15)
                }
            }
        } else {
            let displayText = secondsToTime(restTimer.isPaused ? restTimer.pausedRemainingSeconds : selectedSeconds)

            if restTimer.isPaused {
                HStack(spacing: 12) {
                    adjustButton(deltaSeconds: -15)

                    Text(displayText)
                        .font(.system(size: 80, weight: .bold))
                        .contentTransition(.numericText())

                    adjustButton(deltaSeconds: 15)
                }
            } else {
                Text(displayText)
                    .font(.system(size: 80, weight: .bold))
                    .contentTransition(.numericText())
            }
        }
    }

    private func adjustButton(deltaSeconds: Int) -> some View {
        Button {
            Haptics.selection()
            restTimer.adjust(by: deltaSeconds)
        } label: {
            Text("\(deltaSeconds < 0 ? "-" : "+")15")
                .fontWeight(.semibold)
                .padding(5)
                .font(.subheadline)
        }
        .buttonBorderShape(.circle)
        .buttonStyle(.glass)
        .tint(deltaSeconds < 0 ? .red : .blue)
        .accessibilityIdentifier(AccessibilityIdentifiers.restTimerAdjustButton(deltaSeconds: deltaSeconds))
        .accessibilityLabel(deltaSeconds < 0 ? "Decrease rest time by 15 seconds" : "Increase rest time by 15 seconds")
        .accessibilityHint("Adjusts the rest timer.")
    }

    @ViewBuilder
    private var nextSetView: some View {
        if let (exercise, nextSet) = workout.activeExerciseAndSet() {
            Text("Next Set: \(exercise.name) - \(nextSet.reps) x \(formattedWeight(nextSet.weight)) lbs")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier(AccessibilityIdentifiers.restTimerNextSet)
                .accessibilityLabel("Next set")
                .accessibilityValue("\(exercise.name), \(nextSet.reps) reps, \(formattedWeight(nextSet.weight)) pounds")
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
}

#Preview {
    RestTimerView(workout: sampleIncompleteSession())
        .sampleDataContainer()
}
