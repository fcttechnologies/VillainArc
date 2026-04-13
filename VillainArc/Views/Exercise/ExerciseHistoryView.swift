import SwiftUI
import SwiftData

struct ExerciseHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let catalogID: String

    private let workoutExercise: ExercisePerformance?
    private let planExercise: ExercisePrescription?

    @Query private var exercises: [Exercise]
    @Query private var performances: [ExercisePerformance]
    @Query(AppSettings.single) private var appSettings: [AppSettings]
    @State private var pendingCopyRequest: ExerciseHistoryCopyRequest?

    private var weightUnit: WeightUnit { appSettings.first?.weightUnit ?? .lbs }

    init(catalogID: String) {
        self.catalogID = catalogID
        workoutExercise = nil
        planExercise = nil
        _exercises = Query(Exercise.withCatalogID(catalogID))
        _performances = Query(ExercisePerformance.matching(catalogID: catalogID))
    }

    init(exercise: ExercisePerformance) {
        catalogID = exercise.catalogID
        workoutExercise = exercise
        planExercise = nil
        _exercises = Query(Exercise.withCatalogID(exercise.catalogID))
        _performances = Query(ExercisePerformance.matching(catalogID: exercise.catalogID))
    }

    init(exercise: ExercisePrescription) {
        catalogID = exercise.catalogID
        workoutExercise = nil
        planExercise = exercise
        _exercises = Query(Exercise.withCatalogID(catalogID))
        _performances = Query(ExercisePerformance.matching(catalogID: catalogID))
    }

    private var exercise: Exercise? {
        exercises.first
    }

    private var availableCopyModes: [ExerciseHistoryCopyMode] {
        guard workoutExercise != nil || planExercise != nil else { return [] }
        return ExerciseHistoryCopyMode.allCases
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                ForEach(performances) { performance in
                    ExerciseHistoryPerformanceCard(performance: performance, weightUnit: weightUnit, availableCopyModes: availableCopyModes, onCopy: handleCopySelection)
                }
            }
            .fontDesign(.rounded)
            .padding(.horizontal)
            .padding(.vertical, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if performances.isEmpty {
                ContentUnavailableView("No Exercise History", systemImage: "clock.arrow.circlepath", description: Text("Complete this exercise in a workout to see every performance here."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier(AccessibilityIdentifiers.exerciseHistoryEmptyState)
            }
        }
        .appBackground()
        .accessibilityIdentifier(AccessibilityIdentifiers.exerciseHistoryList)
        .navigationTitle(exercise?.name ?? "Exercise History")
        .navigationSubtitle(Text(exercise?.detailSubtitle ?? "Unknown Equipment"))
        .toolbarTitleDisplayMode(.inline)
        .confirmationDialog(pendingCopyRequest?.confirmationTitle ?? "Update Current Exercise?", isPresented: pendingCopyConfirmationBinding, titleVisibility: .visible) {
            if let request = pendingCopyRequest {
                ForEach(pendingCopyStrategies, id: \.self) { strategy in
                    Button(request.buttonLabel(for: strategy), role: strategy == .replaceAll && workoutExercise?.completedSetCount ?? 0 > 0 ? .destructive : nil) {
                        applyCopy(request, strategy: strategy)
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                Haptics.selection()
                pendingCopyRequest = nil
            }
        } message: {
            if let request = pendingCopyRequest {
                Text(request.confirmationMessage(for: workoutExercise))
            }
        }
    }

    private var pendingCopyConfirmationBinding: Binding<Bool> {
        Binding(get: { pendingCopyRequest != nil },
            set: { isPresented in
                if !isPresented {
                    pendingCopyRequest = nil
                }
            }
        )
    }

    private func handleCopySelection(performance: ExercisePerformance, mode: ExerciseHistoryCopyMode) {
        let request = ExerciseHistoryCopyRequest(
            snapshot: ExercisePerformanceSnapshot(performance: performance),
            mode: mode
        )

        guard let workoutExercise else {
            applyCopy(request)
            return
        }

        if workoutExercise.completedSetCount > 0 || workoutExercise.hasLoggedDataForHistoryReplacement {
            pendingCopyRequest = request
            return
        }

        applyCopy(request)
    }

    private func applyCopy(_ request: ExerciseHistoryCopyRequest, strategy: ExerciseHistoryCopyStrategy = .replaceAll) {
        pendingCopyRequest = nil
        Haptics.selection()

        if let workoutExercise {
            stopRestTimerIfNeeded(for: workoutExercise, strategy: strategy)
            workoutExercise.applyHistoryCopy(request.snapshot, mode: request.mode, strategy: strategy, weightUnit: weightUnit, context: context)
            saveContext(context: context)

            if let workout = workoutExercise.workoutSession {
                WorkoutActivityManager.update(for: workout)
            }

            dismiss()
            return
        }

        if let planExercise {
            planExercise.applyHistoryCopy(request.snapshot, mode: request.mode, context: context)
            saveContext(context: context)
            dismiss()
        }
    }

    private func stopRestTimerIfNeeded(for exercise: ExercisePerformance, strategy: ExerciseHistoryCopyStrategy) {
        let restTimer = RestTimerState.shared
        guard let startedFromSetID = restTimer.startedFromSetID else { return }

        let affectedSetIDs: Set<UUID> = switch strategy {
        case .replaceAll:
            Set(exercise.sortedSets.map(\.id))
        case .replaceRemaining:
            Set(exercise.sortedSets.dropFirst(exercise.completedPrefixCount).map(\.id))
        }

        guard affectedSetIDs.contains(startedFromSetID) else { return }
        restTimer.stop()
    }

    private var pendingCopyStrategies: [ExerciseHistoryCopyStrategy] {
        guard let request = pendingCopyRequest, let workoutExercise else {
            return [.replaceAll]
        }

        let completedCount = workoutExercise.completedSetCount
        guard completedCount > 0 else {
            return [.replaceAll]
        }

        let remainingSnapshots = request.snapshot.sets.count - workoutExercise.completedPrefixCount
        let canCopyRemaining = workoutExercise.canSafelyCopyIntoRemainingSets && remainingSnapshots > 0

        return canCopyRemaining ? [.replaceRemaining, .replaceAll] : [.replaceAll]
    }
}

private struct ExerciseHistoryPerformanceCard: View {
    let performance: ExercisePerformance
    let weightUnit: WeightUnit
    let availableCopyModes: [ExerciseHistoryCopyMode]
    let onCopy: ((ExercisePerformance, ExerciseHistoryCopyMode) -> Void)?

    private var exerciseNotes: String {
        performance.notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var workoutNotes: String {
        performance.workoutSession?.notes.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var canCopy: Bool {
        onCopy != nil && !availableCopyModes.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(formattedDateRange(start: performance.date))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if let repRange = performance.repRange, repRange.activeMode != .notSet {
                            Text(repRange.displayText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if canCopy {
                        Menu {
                            ForEach(availableCopyModes) { mode in
                                Button(mode.label, systemImage: "square.on.square") {
                                    onCopy?(performance, mode)
                                }
                            }
                        } label: {
                            Image(systemName: "square.on.square")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .padding(.top, 2)
                        }
                        .accessibilityLabel("Copy from history")
                    }
                }
                .fontWeight(.semibold)

                if !exerciseNotes.isEmpty || !workoutNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        if !exerciseNotes.isEmpty {
                            Text(workoutNotes.isEmpty ? exerciseNotes : "Exercise notes: \(exerciseNotes)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                        }

                        if !workoutNotes.isEmpty {
                            Text("Workout notes: \(workoutNotes)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                    }
                }
            }

            Divider()

            ExerciseSetTable(rows: performance.sortedSets, repsText: { $0.reps > 0 ? "\($0.reps)" : "-" }, weightText: { $0.weight > 0 ? formattedWeightText($0.weight, unit: weightUnit) : "-" }, restText: { $0.effectiveRestSeconds > 0 ? secondsToTime($0.effectiveRestSeconds) : "-" }) { set in
                ExerciseHistorySetIndicator(set: set)
            }
        }
        .padding(16)
        .appCardStyle()
    }
}

private struct ExerciseHistoryCopyRequest {
    let snapshot: ExercisePerformanceSnapshot
    let mode: ExerciseHistoryCopyMode

    var confirmationTitle: String { "Update Current Exercise?" }

    func confirmationMessage(for workoutExercise: ExercisePerformance?) -> String {
        var replacements = ["the current sets"]

        if mode.includesNotes {
            replacements.append("exercise notes")
        }

        if mode.includesRepRange {
            replacements.append("rep range")
        }

        let replacementText = ListFormatter.localizedString(byJoining: replacements)

        guard let workoutExercise else {
            return "This will replace \(replacementText)."
        }

        let completedCount = workoutExercise.completedSetCount
        guard completedCount > 0 else {
            return "This will replace \(replacementText) for this exercise."
        }

        let completedText = localizedCountText(completedCount, singular: "completed set", plural: "completed sets")

        if workoutExercise.canSafelyCopyIntoRemainingSets && snapshot.sets.count > workoutExercise.completedPrefixCount {
            return "You already have \(completedText). You can keep those completed sets and copy this history entry into the remaining unfinished sets, or replace the whole exercise."
        }

        return "You already have \(completedText). Replacing this history entry will clear completed state for any affected sets."
    }

    func buttonLabel(for strategy: ExerciseHistoryCopyStrategy) -> String {
        switch strategy {
        case .replaceAll:
            return "Replace All Sets"
        case .replaceRemaining:
            return "Copy Into Remaining Sets"
        }
    }
}

private struct ExerciseHistorySetIndicator: View {
    let set: SetPerformance

    var body: some View {
        Text(set.type == .working ? String(set.index + 1) : set.type.shortLabel)
            .foregroundStyle(set.type.tintColor)
            .overlay(alignment: .topTrailing) {
                if let visibleRPE = set.visibleRPE {
                    RPEBadge(value: visibleRPE)
                        .offset(x: 7, y: -7)
                }
            }
    }
}

#Preview("Exercise History", traits: .sampleDataSuggestionGeneration) {
    NavigationStack {
        ExerciseHistoryView(catalogID: "dumbbell_incline_bench_press")
    }
}

#Preview("Exercise History Empty", traits: .sampleData) {
    NavigationStack {
        ExerciseHistoryView(catalogID: "barbell_bent_over_row")
    }
}
