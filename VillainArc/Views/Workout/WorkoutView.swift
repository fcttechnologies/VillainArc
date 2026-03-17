import SwiftUI
import SwiftData
import AppIntents

struct WorkoutView: View {
    @Bindable var workout: WorkoutSession
    private let restTimer = RestTimerState.shared
    @State private var router = AppRouter.shared
    
    @State private var showExerciseEditSheet = false
    @State private var showAddExerciseSheet = false
    @State private var showRestTimerSheet = false
    @State private var showTitleEditorSheet = false
    @State private var showNotesEditorSheet = false
    @State private var showPreWorkoutSheet = false
    @State private var showWorkoutSettingsSheet = false
    @State private var showDeleteConfirmation = false
    @State private var showSaveConfirmation = false
    @State private var showEffortPrompt = false
    @State private var pendingFinishAction: WorkoutFinishAction?
    @State private var pendingEffortSelection = 0
    @State private var autoAdvanceTargetIndex: Int?
    
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
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
                    showPreWorkoutSheet = true
                    Task { await IntentDonations.donateOpenPreWorkoutContext() }
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutPreMoodButton)
                .accessibilityHint(AccessibilityText.workoutPreMoodHint)
            }
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showRestTimerSheet = true
                        Haptics.selection()
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
                ToolbarSpacer(.flexible, placement: .bottomBar)
                ToolbarItem(placement: .bottomBar) {
                    Button("Add Exercise", systemImage: "plus") {
                        Haptics.selection()
                        prepareForAddExerciseSheet()
                        showAddExerciseSheet = true
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
            }
            .sheet(isPresented: $showAddExerciseSheet, onDismiss: handleAddExerciseSheetDismiss) {
                AddExerciseView(workout: workout)
                    .interactiveDismissDisabled()
            }
            .sheet(isPresented: $showRestTimerSheet) {
                RestTimerView(workout: workout, appSettingsSnapshot: appSettingsSnapshot)
                    .presentationDetents([.medium, .large])
                    .presentationBackground(Color(.systemBackground))
            }
            .sheet(isPresented: $showNotesEditorSheet) {
                TextEntryEditorView(title: "Notes", promptText: "Workout Notes", text: $workout.notes, accessibilityIdentifier: AccessibilityIdentifiers.workoutNotesEditorField)
                    .presentationDetents([.fraction(0.4)])
                    .onChange(of: workout.notes) {
                        scheduleSave(context: context)
                    }
                    .onDisappear {
                        saveContext(context: context)
                    }
            }
            .sheet(isPresented: $showPreWorkoutSheet) {
                PreWorkoutContextView(preWorkoutContext: workout.preWorkoutContext ?? PreWorkoutContext())
                    .presentationDetents([.fraction(0.4)])
                    .onDisappear {
                        saveContext(context: context)
                    }
            }
            .sheet(isPresented: $showTitleEditorSheet) {
                TextEntryEditorView(title: "Title", promptText: "Workout Title", text: $workout.title, accessibilityIdentifier: AccessibilityIdentifiers.workoutTitleEditorField)
                    .presentationDetents([.fraction(0.2)])
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
            .sheet(isPresented: $showWorkoutSettingsSheet) {
                WorkoutSettingsView(workout: workout)
            }
            .sheet(isPresented: $showEffortPrompt) {
                WorkoutEffortPromptView(
                    selectedEffort: $pendingEffortSelection,
                    onClose: {
                        showEffortPrompt = false
                        pendingFinishAction = nil
                        pendingEffortSelection = 0
                    },
                    onSkip: {
                        commitEffortAndFinish(nil)
                    },
                    onConfirm: {
                        commitEffortAndFinish(pendingEffortSelection)
                    }
                )
                .interactiveDismissDisabled()
            }
            .onChange(of: workout.activeExercise?.id) {
                scheduleSave(context: context)
            }
            .onChange(of: router.showAddExerciseFromLiveActivity) {
                if router.showAddExerciseFromLiveActivity {
                    router.showAddExerciseFromLiveActivity = false
                    prepareForAddExerciseSheet()
                    showAddExerciseSheet = true
                }
            }
            .onChange(of: router.showRestTimerFromIntent) { _, _ in
                presentIntentDrivenSheetsIfNeeded()
            }
            .onChange(of: router.showPreWorkoutContextFromIntent) { _, _ in
                presentIntentDrivenSheetsIfNeeded()
            }
            .onChange(of: router.showWorkoutSettingsFromIntent) { _, _ in
                presentIntentDrivenSheetsIfNeeded()
            }
            .onChange(of: router.showFinishWorkoutFromIntent) { _, _ in
                presentIntentDrivenSheetsIfNeeded()
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
                    showPreWorkoutSheet = true
                }
            }
            .onAppear {
                WorkoutActivityManager.start(workout: workout)
                presentIntentDrivenSheetsIfNeeded()
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
    }

    private func exerciseSetStatusText(totalSets: Int, completedSets: Int) -> LocalizedStringKey {
        if totalSets > 0, completedSets == totalSets {
            return "All sets complete"
        }
        if completedSets > 0 {
            return "\(completedSets)/\(totalSets) sets complete"
        }
        return "^[\(totalSets) set](inflect: true)"
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
                        Haptics.selection()
                        showWorkoutSettingsSheet = true
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
                        showDeleteConfirmation = true
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
        .confirmationDialog("Cancel Workout", isPresented: $showDeleteConfirmation) {
            Button("Cancel Workout", role: .destructive) {
                deleteWorkout()
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.workoutConfirmDeleteButton)
        } message: {
            Text("Are you sure you want to delete this workout?")
        }
        .confirmationDialog("Finish Workout", isPresented: $showSaveConfirmation) {
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
                Button("Go back", role: .cancel) {}
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
                Text("You have ^[\(summary.loggedCount) logged set](inflect: true) and ^[\(summary.emptyCount) empty set](inflect: true) with no data.")
            case .loggedOnly:
                Text("You have ^[\(summary.loggedCount) set](inflect: true) with data, but not marked complete.")
            case .emptyOnly:
                Text("You have ^[\(summary.emptyCount) empty set](inflect: true).\nLog them or remove them before finishing.")
            case .none:
                Text("Finish and save workout?")
            }
        }
    }
    
    private func queueBeginFinishFlow(action: WorkoutFinishAction) {
        showSaveConfirmation = false
        beginFinishFlow(action: action)
    }

    private func handleFinishTapped() {
        if unfinishedSetSummary.caseType == .none, shouldPromptForPostWorkoutEffort {
            beginFinishFlow(action: .finish)
        } else {
            showSaveConfirmation = true
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

        pendingFinishAction = action
        pendingEffortSelection = 0
        showEffortPrompt = true
    }

    private func commitEffortAndFinish(_ effort: Int?) {
        guard let action = pendingFinishAction else { return }

        workout.postEffort = effort ?? 0
        pendingFinishAction = nil
        showEffortPrompt = false
        pendingEffortSelection = 0
        finishWorkout(action: action)
    }

    private func finishWorkout(action: WorkoutFinishAction) {
        let result = workout.finish(action: action, context: context)

        switch result {
        case .finished:
            workout.convertSetWeightsToKg(from: weightUnit)
            saveContext(context: context)
            SpotlightIndexer.index(workoutSession: workout)
            endWorkoutSession(shouldDismiss: false)
            Task {
                await IntentDonations.donateFinishWorkout()
                await IntentDonations.donateLastWorkoutSummary()
            }
        case .workoutDeleted:
            saveContext(context: context)
            endWorkoutSession(shouldDismiss: true)
        }
    }
    
    private func deleteWorkout() {
        context.delete(workout)
        Task { await IntentDonations.donateCancelWorkout() }
        endWorkoutSession(shouldDismiss: true)
    }

    private func endWorkoutSession(shouldDismiss: Bool) {
        Haptics.selection()
        restTimer.stop()
        WorkoutActivityManager.end()
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
            withAnimation(.smooth) {
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

    private func presentIntentDrivenSheetsIfNeeded() {
        if router.showWorkoutSettingsFromIntent {
            router.showWorkoutSettingsFromIntent = false
            showWorkoutSettingsSheet = true
        }
        if router.showRestTimerFromIntent {
            router.showRestTimerFromIntent = false
            showRestTimerSheet = true
        }
        if router.showPreWorkoutContextFromIntent {
            router.showPreWorkoutContextFromIntent = false
            showPreWorkoutSheet = true
        }
        if router.showFinishWorkoutFromIntent {
            router.showFinishWorkoutFromIntent = false
            handleFinishTapped()
        }
    }
}

#Preview {
    WorkoutView(workout: sampleIncompleteSession())
        .sampleDataContainerIncomplete()
}

#Preview("New Workout") {
    WorkoutView(workout: WorkoutSession())
        .sampleDataContainer()
}
