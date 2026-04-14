import SwiftUI
import SwiftData
import AppIntents

struct WorkoutView: View {
    @Bindable var workout: WorkoutSession
    private let restTimer = RestTimerState.shared
    @State private var router = AppRouter.shared
    
    @State private var showExerciseEditSheet = false
    @State private var showLiveHealthSheet = false
    @State private var showTitleEditorSheet = false
    @State private var showNotesEditorSheet = false
    @State private var pendingEffortSelection = 0
    @State private var autoAdvanceTargetIndex: Int?
    
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(AppSettings.single) private var appSettings: [AppSettings]

    private var appSettingsSnapshot: AppSettingsSnapshot { AppSettingsSnapshot(settings: appSettings.first) }
    private var weightUnit: WeightUnit { appSettingsSnapshot.weightUnit }
    private var shouldPromptForPreWorkoutContext: Bool { appSettingsSnapshot.promptForPreWorkoutContext }
    private var shouldPromptForPostWorkoutEffort: Bool { appSettingsSnapshot.promptForPostWorkoutEffort }

    private var unfinishedSetSummary: UnfinishedSetSummary {
        workout.unfinishedSetSummary
    }

    var body: some View {
        NavigationStack {
            exerciseTabView
            .navigationTitle(workout.title)
            .navigationSubtitle(Text(workout.startedAt, style: .date))
            .toolbarTitleMenu {
                Button("Change Title", systemImage: "pencil") {
                    showTitleEditorSheet = true
                }
                Button("Workout Notes", systemImage: "note.text") {
                    showNotesEditorSheet = true
                }
                Button("Pre Workout Context", systemImage: "bolt.fill") {
                    router.presentWorkoutSheet(.preWorkoutContext)
                    Task { await IntentDonations.donateOpenPreWorkoutContext() }
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutPreMoodButton)
                .accessibilityHint(AccessibilityText.workoutPreMoodHint)
            }
            .toolbarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .appBackground()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        router.presentWorkoutSheet(.restTimer)
                        Task { await IntentDonations.donateOpenRestTimer() }
                    } label: {
                        timerToolbarLabel
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutRestTimerButton)
                    .accessibilityHint(AccessibilityText.workoutRestTimerHint)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    workoutOptionsToolbarLabel
                }
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        showLiveHealthSheet = true
                        Haptics.selection()
                    } label: {
                        Image(systemName: "heart.text.square")
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutLiveHealthButton)
                    .accessibilityLabel(AccessibilityText.workoutLiveHealthLabel)
                    .accessibilityValue(WorkoutLiveStatsView.toolbarAccessibilityValue(for: workout.id))
                    .accessibilityHint(AccessibilityText.workoutLiveHealthHint)
                }
                ToolbarSpacer(.flexible, placement: .bottomBar)
                ToolbarItem(placement: .bottomBar) {
                    Button("Add Exercise", systemImage: "plus") {
                        router.presentWorkoutSheet(.addExercise)
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutAddExerciseButton)
                    .accessibilityHint(AccessibilityText.workoutAddExerciseHint)
                }
            }
            .sheet(isPresented: $showExerciseEditSheet) {
                NavigationStack {
                    exerciseListView
                        .navigationTitle("Edit Exercises")
                        .toolbarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button(role: .confirm) {
                                    showExerciseEditSheet = false
                                }
                            }
                        }
                }
                .presentationBackground(Color.sheetBg)
            }
            .sheet(isPresented: addExerciseSheetBinding, onDismiss: handleAddExerciseSheetDismiss) {
                AddExerciseView(workout: workout)
                    .interactiveDismissDisabled()
                    .presentationBackground(Color.sheetBg)
                    .task {
                        prepareForAddExerciseSheet()
                    }
            }
            .sheet(isPresented: restTimerSheetBinding) {
                RestTimerView(workout: workout, appSettingsSnapshot: appSettingsSnapshot)
                    .presentationDetents([.medium, .large])
                    .presentationBackground(Color.sheetBg)
            }
            .sheet(isPresented: $showLiveHealthSheet) {
                WorkoutLiveStatsView(workout: workout)
                    .presentationDetents([.height(240)])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Color.sheetBg)
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutLiveHealthSheet)
            }
            .sheet(isPresented: $showNotesEditorSheet) {
                TextEntryEditorView(title: "Notes", promptText: "Workout Notes", text: $workout.notes, accessibilityIdentifier: AccessibilityIdentifiers.workoutNotesEditorField)
                    .presentationDetents([.fraction(0.4)])
                    .presentationBackground(Color.sheetBg)
                    .onChange(of: workout.notes) {
                        scheduleSave(context: context)
                    }
                    .onDisappear {
                        saveContext(context: context)
                    }
            }
            .sheet(isPresented: preWorkoutSheetBinding) {
                PreWorkoutContextView(preWorkoutContext: workout.preWorkoutContext ?? PreWorkoutContext())
                    .presentationDetents([.fraction(0.4)])
                    .presentationBackground(Color.sheetBg)
                    .onDisappear {
                        saveContext(context: context)
                    }
            }
            .sheet(isPresented: $showTitleEditorSheet) {
                TextEntryEditorView(title: "Title", promptText: "Workout Title", text: $workout.title, accessibilityIdentifier: AccessibilityIdentifiers.workoutTitleEditorField, isTitle: true)
                    .presentationDetents([.fraction(0.2)])
                    .presentationBackground(Color.sheetBg)
                    .onChange(of: workout.title) {
                        scheduleSave(context: context)
                    }
                    .onDisappear {
                        if workout.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            workout.title = "New Workout"
                        }
                        saveContext(context: context)
                        WorkoutActivityManager.update(for: workout)
                    }
            }
            .sheet(isPresented: workoutSettingsSheetBinding) {
                WorkoutSettingsView(workout: workout)
                    .presentationBackground(Color.sheetBg)
            }
            .sheet(isPresented: effortPromptSheetBinding) {
                WorkoutEffortPromptView(
                    selectedEffort: $pendingEffortSelection,
                    onClose: {
                        router.activeWorkoutSheet = nil
                        pendingEffortSelection = 0
                    },
                    onSkip: {
                        if let action = activeEffortPromptAction {
                            commitEffortAndFinish(nil, action: action)
                        }
                    },
                    onConfirm: {
                        if let action = activeEffortPromptAction {
                            commitEffortAndFinish(pendingEffortSelection, action: action)
                        }
                    }
                )
                .interactiveDismissDisabled()
            }
            .onChange(of: workout.activeExercise?.id) {
                scheduleSave(context: context)
            }
            .userActivity("com.villainarc.workoutSession.active", element: workout) { session, activity in
                activity.title = session.title
                activity.isEligibleForSearch = false
                activity.isEligibleForPrediction = true
                let entity = WorkoutSessionEntity(workoutSession: session)
                activity.appEntityIdentifier = .init(for: entity)
            }
            .task {
                if shouldPromptForPreWorkoutContext, workout.preWorkoutContext?.feeling == .notSet {
                    router.presentWorkoutSheet(.preWorkoutContext)
                }
            }
            .onAppear {
                WorkoutActivityManager.start(workout: workout)
                Task {
                    await HealthLiveWorkoutSessionCoordinator.shared.ensureRunning(for: workout)
                }
            }
        }
    }
    
    var exerciseTabView: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    if workout.exercises?.isEmpty ?? true {
                        ContentUnavailableView("No Exercises Added", systemImage: "dumbbell.fill", description: Text("Tap the \(Image(systemName: "plus")) button to add exercises."))
                            .containerRelativeFrame(.horizontal)
                            .accessibilityIdentifier(AccessibilityIdentifiers.workoutExercisesEmptyState)
                    } else {
                        ForEach(workout.sortedExercises) { exercise in
                            ExerciseView(exercise: exercise, appSettingsSnapshot: appSettingsSnapshot) {
                                deleteExercise(exercise)
                            }
                            .containerRelativeFrame(.horizontal)
                            .id(exercise)
                            .accessibilityIdentifier(AccessibilityIdentifiers.workoutExercisePage(exercise))
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.paging)
            .scrollDisabled(workout.exercises?.isEmpty ?? true)
            .scrollPosition(id: $workout.activeExercise)
            .accessibilityIdentifier(AccessibilityIdentifiers.workoutExercisePager)
            .onAppear {
                if workout.activeExercise == nil {
                    workout.activeExercise = workout.sortedExercises.first
                }
                if let activeExercise = workout.activeExercise {
                    proxy.scrollTo(activeExercise)
                }
            }
        }
    }
    
    var exerciseListView: some View {
        List {
            ForEach(workout.sortedExercises) { exercise in
                let totalSets = exercise.sortedSets.count
                let completedSets = exercise.sortedSets.filter { $0.complete }.count
                Button {
                    workout.activeExercise = exercise
                    showExerciseEditSheet = false
                } label: {
                    VStack(alignment: .leading) {
                        Text(exercise.name)
                            .font(.title3)
                            .bold()
                            .lineLimit(1)
                        HStack(alignment: .bottom) {
                            Text(exercise.equipmentType.displayName)
                                .foregroundStyle(.secondary)
                                .fontWeight(.semibold)
                                .font(.headline)
                            Spacer()
                            Text(exerciseSetStatusText(totalSets: totalSets, completedSets: completedSets))
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        }
                    }
                }
                .buttonStyle(.borderless)
                .tint(.primary)
                .listRowSeparator(.hidden)
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutExerciseListRow(exercise))
                .accessibilityLabel(exercise.name)
                .accessibilityValue(AccessibilityText.workoutExerciseListValue(for: exercise))
                .accessibilityHint(AccessibilityText.workoutExerciseListRowHint)
            }
            .onDelete(perform: deleteExercise)
            .onMove(perform: moveExercise)
        }
        .scrollIndicators(.hidden)
        .environment(\.editMode, .constant(.active))
        .accessibilityIdentifier(AccessibilityIdentifiers.workoutExerciseList)
        .scrollContentBackground(.hidden)
        .sheetBackground()
    }

    private func exerciseSetStatusText(totalSets: Int, completedSets: Int) -> String {
        if totalSets > 0, completedSets == totalSets {
            return "All sets complete"
        }
        if completedSets > 0 {
            return "\(completedSets) of \(localizedCountText(totalSets, singular: "set", plural: "sets")) complete"
        }
        return localizedCountText(totalSets, singular: "set", plural: "sets")
    }

    @ViewBuilder
    private var timerToolbarLabel: some View {
        if restTimer.isRunning, let endDate = restTimer.endDate, endDate > Date() {
            Text(timerInterval: .now...endDate, countsDown: true)
                .fontWeight(.semibold)
        } else if restTimer.isPaused {
            Text(secondsToTime(restTimer.pausedRemainingSeconds))
                .fontWeight(.semibold)
                .foregroundStyle(.yellow)
        } else {
            Image(systemName: "timer")
        }
    }
    
    @ViewBuilder
    private var workoutOptionsToolbarLabel: some View {
        Group {
            if workout.exercises?.isEmpty ?? true {
                Button("Cancel Workout", systemImage: "xmark", role: .close) {
                    deleteWorkout()
                }
                .labelStyle(.iconOnly)
                .accessibilityLabel(AccessibilityText.workoutDeleteEmptyLabel)
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutDeleteEmptyButton)
                .accessibilityHint(AccessibilityText.workoutDeleteEmptyHint)
            } else {
                Menu("Workout Options", systemImage: "ellipsis") {
                    Button("Workout Settings", systemImage: "gear") {
                        router.presentWorkoutSheet(.settings)
                        Task { await IntentDonations.donateOpenWorkoutSettings() }
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutSettingsButton)
                    .accessibilityHint(AccessibilityText.workoutSettingsHint)
                    Button("Edit Exercises", systemImage: "pencil") {
                        Haptics.selection()
                        showExerciseEditSheet = true
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutEditExercisesButton)
                    .accessibilityHint(AccessibilityText.workoutEditExercisesHint)
                    Button("Finish Workout", systemImage: "checkmark") {
                        handleFinishTapped()
                    }
                    .tint(.green)
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutFinishButton)
                    .accessibilityHint(AccessibilityText.workoutFinishHint)
                    Button("Cancel Workout", systemImage: "xmark", role: .destructive) {
                        router.presentWorkoutDialog(.cancel)
                    }
                    .tint(.red)
                    .buttonStyle(.glassProminent)
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutDeleteButton)
                    .accessibilityHint(AccessibilityText.workoutDeleteHint)
                }
                .labelStyle(.iconOnly)
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutOptionsMenu)
                .accessibilityHint(AccessibilityText.workoutOptionsMenuHint)
            }
        }
        .confirmationDialog("Cancel Workout", isPresented: cancelWorkoutDialogBinding) {
            Button("Cancel Workout", role: .destructive) {
                deleteWorkout()
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.workoutConfirmDeleteButton)
        } message: {
            Text("Are you sure you want to delete this workout?")
        }
        .confirmationDialog("Finish Workout", isPresented: finishWorkoutDialogBinding) {
            let summary = unfinishedSetSummary
            switch summary.caseType {
            case .emptyAndLogged:
                Button("Mark logged sets as complete") {
                    queueBeginFinishFlow(action: .markLoggedComplete)
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutFinishMarkSetsCompleteButton)
                Button("Delete all unfinished sets", role: .destructive) {
                    queueBeginFinishFlow(action: .deleteUnfinished)
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutFinishDeleteIncompleteSetsButton)
            case .loggedOnly:
                Button("Mark as complete") {
                    queueBeginFinishFlow(action: .markLoggedComplete)
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutFinishMarkSetsCompleteButton)
                Button("Delete these sets", role: .destructive) {
                    queueBeginFinishFlow(action: .deleteUnfinished)
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutFinishDeleteIncompleteSetsButton)
            case .emptyOnly:
                Button("Delete empty sets", role: .destructive) {
                    queueBeginFinishFlow(action: .deleteEmpty)
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutFinishDeleteEmptySetsButton)
                Button("Go back", role: .cancel) {
                    Haptics.selection()
                }
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutFinishGoBackButton)
            case .none:
                Button("Finish") {
                    queueBeginFinishFlow(action: .finish)
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutFinishConfirmButton)
            }
        } message: {
            let summary = unfinishedSetSummary
            switch summary.caseType {
            case .emptyAndLogged:
                Text("You have \(localizedCountText(summary.loggedCount, singular: "logged set", plural: "logged sets")) and \(localizedCountText(summary.emptyCount, singular: "empty set", plural: "empty sets")) with no data.")
            case .loggedOnly:
                Text("You have \(localizedCountText(summary.loggedCount, singular: "set", plural: "sets")) with data, but not marked complete.")
            case .emptyOnly:
                Text("You have \(localizedCountText(summary.emptyCount, singular: "empty set", plural: "empty sets")).\nLog them or remove them before finishing.")
            case .none:
                Text("Finish and save workout?")
            }
        }
    }

    private func queueBeginFinishFlow(action: WorkoutFinishAction) {
        router.activeWorkoutDialog = nil
        beginFinishFlow(action: action)
    }

    private func handleFinishTapped() {
        if unfinishedSetSummary.caseType == .none, shouldPromptForPostWorkoutEffort {
            beginFinishFlow(action: .finish)
        } else {
            router.presentWorkoutDialog(.finish)
        }
    }

    private func beginFinishFlow(action: WorkoutFinishAction) {
        if workout.predictedFinishResult(action: action) == .workoutDeleted {
            finishWorkout(action: action)
            return
        }

        if !shouldPromptForPostWorkoutEffort {
            finishWorkout(action: action)
            return
        }

        pendingEffortSelection = 0
        router.presentWorkoutSheet(.effortPrompt(action))
    }

    private func commitEffortAndFinish(_ effort: Int?, action: WorkoutFinishAction) {
        workout.postEffort = effort ?? 0
        router.activeWorkoutSheet = nil
        pendingEffortSelection = 0
        finishWorkout(action: action)
    }

    private func finishWorkout(action: WorkoutFinishAction) {
        let result = workout.finish(action: action, context: context)

        switch result {
        case .finished:
            workout.convertSetWeightsToKg(from: weightUnit)
            saveContext(context: context)
            endWorkoutSession(shouldDismiss: false, endLiveActivity: false)
            WorkoutActivityManager.update(for: workout)
            Task {
                await HealthLiveWorkoutSessionCoordinator.shared.finishIfRunning(for: workout, context: context)
                WorkoutActivityManager.update(for: workout)
                await IntentDonations.donateFinishWorkout()
                await IntentDonations.donateLastWorkoutSummary()
            }
        case .workoutDeleted:
            saveContext(context: context)
            HealthLiveWorkoutSessionCoordinator.shared.discardIfRunning(for: workout)
            endWorkoutSession(shouldDismiss: true, endLiveActivity: true)
        }
    }

    private func deleteWorkout() {
        HealthLiveWorkoutSessionCoordinator.shared.discardIfRunning(for: workout)
        context.delete(workout)
        Task { await IntentDonations.donateCancelWorkout() }
        endWorkoutSession(shouldDismiss: true, endLiveActivity: true)
    }

    private func endWorkoutSession(shouldDismiss: Bool, endLiveActivity: Bool) {
        Haptics.selection()
        restTimer.stop()
        router.activeWorkoutDialog = nil
        router.activeWorkoutSheet = nil
        if endLiveActivity {
            WorkoutActivityManager.end()
        }
        if shouldDismiss {
            dismiss()
        }
    }
    
    private func deleteExercise(offsets: IndexSet) {
        guard !offsets.isEmpty else { return }
        Haptics.selection()
        let exercisesToDelete = offsets.map { workout.sortedExercises[$0] }

        for exercise in exercisesToDelete {
            workout.deleteExercise(exercise)
            context.delete(exercise)
        }
        saveContext(context: context)

        if let active = workout.activeExercise, exercisesToDelete.contains(active) {
            workout.activeExercise = workout.sortedExercises.first
        }

        if workout.exercises?.isEmpty ?? true {
            showExerciseEditSheet = false
        }
        WorkoutActivityManager.update(for: workout)
    }

    private func deleteExercise(_ exercise: ExercisePerformance) {
        let deletedIndex = exercise.index
        Haptics.selection()
        workout.deleteExercise(exercise)
        context.delete(exercise)
        saveContext(context: context)

        if let active = workout.activeExercise, active == exercise {
            let remainingExercises = workout.sortedExercises
            if remainingExercises.isEmpty {
                workout.activeExercise = nil
            } else {
                let nextIndex = min(deletedIndex, remainingExercises.count - 1)
                workout.activeExercise = remainingExercises[nextIndex]
            }
        }
        WorkoutActivityManager.update(for: workout)
    }

    private func moveExercise(from source: IndexSet, to destination: Int) {
        workout.moveExercise(from: source, to: destination)
        saveContext(context: context)
        WorkoutActivityManager.update(for: workout)
    }

    private func prepareForAddExerciseSheet() {
        let count = workout.sortedExercises.count
        let isActiveLast = workout.activeExercise?.index == count - 1
        if activeExerciseAllSetsComplete(), isActiveLast {
            autoAdvanceTargetIndex = count
        } else {
            autoAdvanceTargetIndex = nil
        }
    }

    private func handleAddExerciseSheetDismiss() {
        defer { autoAdvanceTargetIndex = nil }
        let exercises = workout.sortedExercises
        if let target = autoAdvanceTargetIndex, target < exercises.count {
            withAnimation(reduceMotion ? nil : .smooth) {
                workout.activeExercise = exercises[target]
            }
            WorkoutActivityManager.update(for: workout)
            return
        }
        if workout.activeExercise == nil {
            workout.activeExercise = exercises.first
        }
        WorkoutActivityManager.update(for: workout)
    }

    private func activeExerciseAllSetsComplete() -> Bool {
        guard let activeExercise = workout.activeExercise else { return false }
        let sets = activeExercise.sortedSets
        guard !sets.isEmpty else { return false }
        return sets.allSatisfy { $0.complete }
    }

    private var addExerciseSheetBinding: Binding<Bool> {
        Binding(
            get: { router.activeWorkoutSheet == .addExercise },
            set: { isPresented in
                if !isPresented, router.activeWorkoutSheet == .addExercise {
                    router.activeWorkoutSheet = nil
                }
            }
        )
    }

    private var restTimerSheetBinding: Binding<Bool> {
        Binding(
            get: { router.activeWorkoutSheet == .restTimer },
            set: { isPresented in
                if !isPresented, router.activeWorkoutSheet == .restTimer {
                    router.activeWorkoutSheet = nil
                }
            }
        )
    }

    private var preWorkoutSheetBinding: Binding<Bool> {
        Binding(
            get: { router.activeWorkoutSheet == .preWorkoutContext },
            set: { isPresented in
                if !isPresented, router.activeWorkoutSheet == .preWorkoutContext {
                    router.activeWorkoutSheet = nil
                }
            }
        )
    }

    private var workoutSettingsSheetBinding: Binding<Bool> {
        Binding(
            get: { router.activeWorkoutSheet == .settings },
            set: { isPresented in
                if !isPresented, router.activeWorkoutSheet == .settings {
                    router.activeWorkoutSheet = nil
                }
            }
        )
    }

    private var effortPromptSheetBinding: Binding<Bool> {
        Binding(
            get: {
                if case .effortPrompt = router.activeWorkoutSheet { return true }
                return false
            },
            set: { isPresented in
                if !isPresented {
                    if case .effortPrompt = router.activeWorkoutSheet {
                        router.activeWorkoutSheet = nil
                    }
                }
            }
        )
    }

    private var cancelWorkoutDialogBinding: Binding<Bool> {
        Binding(
            get: { router.activeWorkoutDialog == .cancel },
            set: { isPresented in
                if !isPresented, router.activeWorkoutDialog == .cancel {
                    router.activeWorkoutDialog = nil
                }
            }
        )
    }

    private var finishWorkoutDialogBinding: Binding<Bool> {
        Binding(
            get: { router.activeWorkoutDialog == .finish },
            set: { isPresented in
                if !isPresented, router.activeWorkoutDialog == .finish {
                    router.activeWorkoutDialog = nil
                }
            }
        )
    }

    private var activeEffortPromptAction: WorkoutFinishAction? {
        guard case .effortPrompt(let action) = router.activeWorkoutSheet else { return nil }
        return action
    }
}

#Preview(traits: .sampleDataIncomplete) {
    WorkoutView(workout: sampleIncompleteSession())
}

#Preview("New Workout", traits: .sampleData) {
    WorkoutView(workout: WorkoutSession())
}
