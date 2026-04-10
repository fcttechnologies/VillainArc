import SwiftData
import SwiftUI

struct WatchLiveWorkoutView: View {
    private struct DisplaySet: Identifiable {
        let id: UUID
        let index: Int
        let complete: Bool
        let reps: Int
        let weight: Double
        let targetRPE: Int?
        let hasTarget: Bool
    }

    let snapshot: ActiveWorkoutSnapshot?
    let fallbackSession: WorkoutSession?
    @State private var runtimeCoordinator: WatchWorkoutRuntimeCoordinator
    @Query(AppSettings.single) private var appSettings: [AppSettings]
    @State private var showCancelConfirmation = false

    init(
        snapshot: ActiveWorkoutSnapshot?,
        fallbackSession: WorkoutSession?,
        runtimeCoordinator: WatchWorkoutRuntimeCoordinator
    ) {
        self.snapshot = snapshot
        self.fallbackSession = fallbackSession
        _runtimeCoordinator = State(initialValue: runtimeCoordinator)
    }

    private var weightUnit: WeightUnit {
        appSettings.first?.weightUnit ?? .lbs
    }

    private var energyUnit: EnergyUnit {
        appSettings.first?.energyUnit ?? .systemDefault
    }

    private var sessionID: UUID? {
        snapshot?.sessionID ?? fallbackSession?.id
    }

    private var titleText: String {
        snapshot?.title ?? fallbackSession?.title ?? "Workout"
    }

    private var startedAt: Date? {
        snapshot?.startedAt ?? fallbackSession?.startedAt
    }

    private var isActive: Bool {
        (snapshot?.status ?? fallbackSession?.statusValue) == .active
    }

    private var canStartLiveMetrics: Bool {
        guard let snapshot else { return false }
        guard snapshot.status == .active else { return false }
        guard snapshot.healthCollectionMode == .exportOnFinish else { return false }
        return runtimeCoordinator.healthAuthorizationState != .unavailable
    }

    private var displayExerciseName: String? {
        if let snapshotExercise = currentExerciseSnapshot {
            return snapshotExercise.name
        }
        if let currentStep = fallbackSession?.activeExerciseAndSet() {
            return currentStep.exercise.name
        }
        return nil
    }

    private var currentExerciseSnapshot: WatchExerciseSnapshot? {
        guard let snapshot else { return nil }
        if let activeExerciseID = snapshot.activeExerciseID,
           let activeExercise = snapshot.exercises.first(where: { $0.exerciseID == activeExerciseID }) {
            return activeExercise
        }
        return snapshot.exercises.first(where: { exercise in
            exercise.sets.contains(where: { !$0.complete })
        }) ?? snapshot.exercises.first
    }

    private var displaySets: [DisplaySet] {
        if let snapshotExercise = currentExerciseSnapshot {
            return snapshotExercise.sets.map { set in
                DisplaySet(
                    id: set.setID,
                    index: set.index,
                    complete: set.complete,
                    reps: set.reps,
                    weight: set.weight,
                    targetRPE: set.targetRPE,
                    hasTarget: set.hasTarget
                )
            }
        }
        guard let fallbackSession, let currentExercise = fallbackSession.activeExerciseAndSet()?.exercise else {
            return []
        }
        return currentExercise.sortedSets.map { set in
            DisplaySet(
                id: set.id,
                index: set.index,
                complete: set.complete,
                reps: set.reps,
                weight: set.weight,
                targetRPE: set.prescription?.visibleTargetRPE,
                hasTarget: set.reps > 0 || set.weight > 0 || set.prescription?.visibleTargetRPE != nil
            )
        }
    }

    private var exerciseProgress: (completed: Int, total: Int)? {
        guard let snapshot else { return nil }
        let total = snapshot.exercises.count
        let completed = snapshot.exercises.filter { exercise in
            exercise.sets.allSatisfy(\.complete)
        }.count
        return (completed, total)
    }

    // MARK: - Body

    var body: some View {
        TabView {
            metricsPage
            exercisePage
            controlsPage
        }
        .tabViewStyle(.verticalPage)
        .navigationTitle(titleText)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Metrics Page

    private var metricsPage: some View {
        VStack(spacing: 8) {
            if let startedAt {
                metricTile(
                    label: "Duration",
                    icon: "timer"
                ) {
                    Text(startedAt, style: .timer)
                        .font(.title2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.primary)
                }
            }

            HStack(spacing: 8) {
                metricTile(
                    label: "HR",
                    icon: "heart.fill",
                    iconColor: .red
                ) {
                    if let hr = runtimeCoordinator.displayHeartRate {
                        Text("\(Int(hr.rounded())) bpm")
                            .font(.title3.monospacedDigit().weight(.semibold))
                    } else {
                        Text("--")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                metricTile(
                    label: "Active",
                    icon: "flame.fill",
                    iconColor: .orange
                ) {
                    if let energy = runtimeCoordinator.displayActiveEnergy {
                        Text(formattedEnergyText(energy, unit: energyUnit))
                            .font(.title3.monospacedDigit().weight(.semibold))
                    } else {
                        Text("--")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            restTimerBanner
            liveMetricsPrompt
        }
        .padding(.horizontal, 4)
        .scenePadding(.bottom)
    }

    @ViewBuilder
    private var restTimerBanner: some View {
        if let restTimer = snapshot?.restTimer {
            if restTimer.isPaused {
                HStack {
                    Image(systemName: "pause.circle.fill")
                        .foregroundStyle(.yellow)
                    Text("Rest Paused")
                        .font(.footnote.weight(.semibold))
                    Spacer()
                    Text(secondsToTime(restTimer.pausedRemainingSeconds))
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 10))
            } else if let endDate = restTimer.endDate {
                HStack {
                    Image(systemName: "timer")
                        .foregroundStyle(.green)
                    Text("Rest")
                        .font(.footnote.weight(.semibold))
                    Spacer()
                    Text(timerInterval: .now...endDate, countsDown: true)
                        .font(.footnote.monospacedDigit().weight(.semibold))
                }
                .padding(8)
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 10))
            }
        }
    }

    @ViewBuilder
    private var liveMetricsPrompt: some View {
        if canStartLiveMetrics {
            Button {
                Task {
                    await runtimeCoordinator.startMirroringForCurrentWorkout()
                }
            } label: {
                Label(runtimeCoordinator.isBusy ? "Starting..." : "Start Live Metrics", systemImage: "waveform.path.ecg")
                    .font(.caption)
            }
            .disabled(runtimeCoordinator.isBusy)
            .frame(minHeight: 36)
        }
    }

    // MARK: - Exercise Page

    private var exercisePage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if let displayExerciseName {
                    exerciseHeader(name: displayExerciseName)

                    if displaySets.isEmpty {
                        VStack(spacing: 8) {
                            Text("Structure changed on iPhone")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            continueOnPhoneButton
                        }
                    } else {
                        ForEach(displaySets) { set in
                            setRow(set)
                        }
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle")
                            .font(.largeTitle)
                            .foregroundStyle(.green)
                        Text("All sets complete")
                            .font(.headline)
                        continueOnPhoneButton
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)
                }
            }
            .padding(.horizontal, 4)
            .scenePadding(.bottom)
        }
    }

    private func exerciseHeader(name: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name)
                .font(.headline)
                .lineLimit(2)

            if let progress = exerciseProgress {
                Text("\(progress.completed)/\(progress.total) exercises")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 4)
    }

    private func setRow(_ set: DisplaySet) -> some View {
        Button {
            guard let sessionID else { return }
            Task {
                await runtimeCoordinator.toggleSet(
                    sessionID: sessionID,
                    setID: set.id,
                    desiredComplete: !set.complete
                )
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: set.complete ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(set.complete ? .green : .secondary)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Set \(set.index + 1)")
                        .font(.caption.weight(.semibold))

                    if set.hasTarget {
                        Text(setTargetLabel(for: set))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No target")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(set.complete ? Color.green.opacity(0.1) : Color.clear, in: .rect(cornerRadius: 8))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(runtimeCoordinator.isBusy)
        .accessibilityLabel(set.complete ? "Set \(set.index + 1), complete" : "Set \(set.index + 1), incomplete")
        .accessibilityHint(set.complete ? "Double tap to mark incomplete" : "Double tap to mark complete")
    }

    private func setTargetLabel(for set: DisplaySet) -> String {
        var parts: [String] = []
        if set.reps > 0 { parts.append("\(set.reps) reps") }
        if set.weight > 0 { parts.append(formattedWeightText(set.weight, unit: weightUnit, fractionDigits: 0...2)) }
        if let rpe = set.targetRPE { parts.append("RPE \(rpe)") }
        return parts.joined(separator: " · ")
    }

    // MARK: - Controls Page

    private var controlsPage: some View {
        VStack(spacing: 12) {
            if let sessionID, isActive {
                if snapshot?.canFinishOnWatch == true {
                    Button {
                        Task {
                            await runtimeCoordinator.finishWorkout(sessionID: sessionID)
                        }
                    } label: {
                        Label("Finish Workout", systemImage: "flag.checkered")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(runtimeCoordinator.isBusy)
                    .frame(minHeight: 44)
                    .tint(.green)
                } else {
                    Button {
                        WatchPhoneHandoffCoordinator.openActiveWorkoutOnPhone()
                    } label: {
                        Label("Finish on iPhone", systemImage: "iphone")
                            .frame(maxWidth: .infinity)
                    }
                    .frame(minHeight: 44)
                }

                Button(role: .destructive) {
                    showCancelConfirmation = true
                } label: {
                    Label("Cancel Workout", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .disabled(runtimeCoordinator.isBusy)
                .frame(minHeight: 44)
                .confirmationDialog("Cancel this workout?", isPresented: $showCancelConfirmation, titleVisibility: .visible) {
                    Button("Cancel Workout", role: .destructive) {
                        Task {
                            await runtimeCoordinator.cancelWorkout(sessionID: sessionID)
                        }
                    }
                }
            } else {
                continueOnPhoneButton
            }

            statusBanner
        }
        .padding(.horizontal, 4)
        .scenePadding(.vertical)
    }

    @ViewBuilder
    private var statusBanner: some View {
        if let statusMessage = runtimeCoordinator.statusMessage {
            VStack(spacing: 6) {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Dismiss") {
                    runtimeCoordinator.clearStatusMessage()
                }
                .font(.caption)
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 10))
        }
    }

    // MARK: - Helpers

    private var continueOnPhoneButton: some View {
        Button {
            WatchPhoneHandoffCoordinator.openActiveWorkoutOnPhone()
        } label: {
            Label("Continue on iPhone", systemImage: "iphone")
                .font(.caption)
        }
        .frame(minHeight: 36)
    }

    private func metricTile<Content: View>(
        label: String,
        icon: String,
        iconColor: Color = .primary,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(iconColor)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        WatchLiveWorkoutView(
            snapshot: nil,
            fallbackSession: WorkoutSession(title: "Leg Day", status: .active),
            runtimeCoordinator: .shared
        )
    }
}
