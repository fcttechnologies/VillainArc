import SwiftUI
import SwiftData
import AppIntents

struct WorkoutView: View {
    @Bindable var workout: WorkoutSession
    private let restTimer = RestTimerState.shared
    
    @State private var showExerciseListView = false
    @State private var showAddExerciseSheet = false
    @State private var showRestTimerSheet = false
    @State private var showDeleteWorkoutAlert = false
    @State private var showTitleEditorSheet = false
    @State private var showNotesEditorSheet = false
    @State private var showPreWorkoutSheet = false
    @State private var showDeleteConfirmation = false
    @State private var showSaveConfirmation = false
    @State private var autoAdvanceTargetIndex: Int?
    
    private let router = AppRouter.shared

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    private var unfinishedSetSummary: UnfinishedSetSummary {
        workout.unfinishedSetSummary
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if showExerciseListView {
                    exerciseListView
                } else {
                    exerciseTabView
                }
            }
            .navigationTitle(workout.title)
            .navigationSubtitle(Text(workout.startedAt, style: .date))
            .toolbarTitleMenu {
                Button("Change Title", systemImage: "pencil") {
                    showTitleEditorSheet = true
                }
                Button("Workout Notes", systemImage: "note.text") {
                    showNotesEditorSheet = true
                }
                Button("Pre Workout Energy", systemImage: "bolt.fill") {
                    showPreWorkoutSheet = true
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutPreMoodButton)
                .accessibilityHint("Updates your pre-workout energy.")
            }
            .toolbarTitleDisplayMode(.inline)
            .animation(.bouncy, value: showExerciseListView)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showRestTimerSheet = true
                        Haptics.selection()
                    } label: {
                        timerToolbarLabel
                    }
                    .accessibilityIdentifier("workoutRestTimerButton")
                    .accessibilityHint("Shows the rest timer.")
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
                    .accessibilityIdentifier("workoutAddExerciseButton")
                    .accessibilityHint("Adds an exercise.")
                }
            }
            .animation(.smooth, value: showExerciseListView)
            .sheet(isPresented: $showAddExerciseSheet, onDismiss: handleAddExerciseSheetDismiss) {
                AddExerciseView(workout: workout)
                    .interactiveDismissDisabled()
            }
            .sheet(isPresented: $showRestTimerSheet) {
                RestTimerView(workout: workout)
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
                PreWorkoutStatusView(status: workout.preStatus)
                    .presentationDetents([.fraction(0.4)])
                    .onDisappear {
                        if workout.preStatus.feeling == .notSet {
                            workout.preStatus.feeling = .okay
                            saveContext(context: context)
                        }
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
            .userActivity("com.villainarc.workoutSession.active", element: workout) { session, activity in
                activity.title = session.title
                activity.isEligibleForSearch = false
                activity.isEligibleForPrediction = true
                let entity = WorkoutSessionEntity(workoutSession: session)
                activity.appEntityIdentifier = .init(for: entity)
            }
            .task {
                if workout.preStatus.feeling == .notSet {
                    showPreWorkoutSheet = true
                }
            }
            .onAppear {
                WorkoutActivityManager.start(workout: workout)
            }
        }
    }
    
    var exerciseTabView: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    if workout.exercises.isEmpty {
                        ContentUnavailableView("No Exercises Added", systemImage: "dumbbell.fill", description: Text("Click the '\(Image(systemName: "plus"))' icon to add some exercises."))
                            .containerRelativeFrame(.horizontal)
                            .accessibilityIdentifier("workoutExercisesEmptyState")
                    } else {
                        ForEach(workout.sortedExercises) { exercise in
                            ExerciseView(exercise: exercise) {
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
            .scrollDisabled(workout.exercises.isEmpty)
            .scrollPosition(id: $workout.activeExercise)
            .accessibilityIdentifier("workoutExercisePager")
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
                let isAllSetsComplete = totalSets > 0 && completedSets == totalSets
                Button {
                    workout.activeExercise = exercise
                    showExerciseListView = false
                } label: {
                    VStack(alignment: .leading) {
                        Text(exercise.name)
                            .font(.title3)
                            .bold()
                            .lineLimit(1)
                        HStack(alignment: .bottom) {
                            Text(exercise.displayMuscle)
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
                .opacity(isAllSetsComplete ? 0.4 : 1)
                .buttonStyle(.borderless)
                .tint(.primary)
                .listRowSeparator(.hidden)
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutExerciseListRow(exercise))
                .accessibilityLabel(exercise.name)
                .accessibilityValue(AccessibilityText.workoutExerciseListValue(for: exercise))
                .accessibilityHint("Shows the exercise in the workout.")
            }
            .onDelete(perform: deleteExercise)
            .onMove(perform: moveExercise)
        }
        .scrollIndicators(.hidden)
        .listStyle(.plain)
        .environment(\.editMode, .constant(.active))
        .accessibilityIdentifier("workoutExerciseList")
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
            if workout.exercises.isEmpty {
                Button("Cancel Workout", systemImage: "xmark", role: .close) {
                    deleteWorkout()
                }
                .labelStyle(.iconOnly)
                .accessibilityLabel("Delete Workout")
                .accessibilityIdentifier("workoutDeleteEmptyButton")
                .accessibilityHint("Deletes this workout.")
            } else if showExerciseListView {
                Button("Done Editing", systemImage: "checkmark") {
                    Haptics.selection()
                    showExerciseListView = false
                }
                .labelStyle(.iconOnly)
                .tint(.blue)
                .accessibilityIdentifier("workoutDoneEditingButton")
                .accessibilityHint("Finishes editing the list of exercises.")
            } else {
                Menu("Workout Options", systemImage: "ellipsis") {
                    Button("Edit Exercises", systemImage: "pencil") {
                        Haptics.selection()
                        showExerciseListView = true
                    }
                    .accessibilityIdentifier("workoutEditExercisesButton")
                    .accessibilityHint("Show the list of exercises.")
                    Button("Finish Workout", systemImage: "checkmark", role: .confirm) {
                        showSaveConfirmation = true
                    }
                    .tint(.green)
                    .accessibilityIdentifier("workoutFinishButton")
                    .accessibilityHint("Finishes and saves the workout.")
                    Button("Cancel Workout", systemImage: "xmark", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                    .tint(.red)
                    .buttonStyle(.glassProminent)
                    .accessibilityIdentifier("workoutDeleteButton")
                    .accessibilityHint("Deletes this workout.")
                }
                .labelStyle(.iconOnly)
                .accessibilityIdentifier("workoutOptionsMenu")
                .accessibilityHint("Workout actions.")
            }
        }
        .confirmationDialog("Cancel Workout", isPresented: $showDeleteConfirmation) {
            Button("Cancel Workout", role: .destructive) {
                deleteWorkout()
            }
            .accessibilityIdentifier("workoutConfirmDeleteButton")
        } message: {
            Text("Are you sure you want to delete this workout?")
        }
        .confirmationDialog("Finish Workout", isPresented: $showSaveConfirmation) {
            let summary = unfinishedSetSummary
            switch summary.caseType {
            case .emptyAndLogged:
                Button("Mark logged sets as complete") {
                    finishWorkout(action: .markLoggedComplete)
                }
                .accessibilityIdentifier("workoutFinishMarkSetsCompleteButton")
                Button("Delete all unfinished sets", role: .destructive) {
                    finishWorkout(action: .deleteUnfinished)
                }
                .accessibilityIdentifier("workoutFinishDeleteIncompleteSetsButton")
            case .loggedOnly:
                Button("Mark as complete") {
                    finishWorkout(action: .markLoggedComplete)
                }
                .accessibilityIdentifier("workoutFinishMarkSetsCompleteButton")
                Button("Delete these sets", role: .destructive) {
                    finishWorkout(action: .deleteUnfinished)
                }
                .accessibilityIdentifier("workoutFinishDeleteIncompleteSetsButton")
            case .emptyOnly:
                Button("Delete empty sets", role: .destructive) {
                    finishWorkout(action: .deleteEmpty)
                }
                .accessibilityIdentifier("workoutFinishDeleteEmptySetsButton")
                Button("Go back", role: .cancel) {}
                    .accessibilityIdentifier("workoutFinishGoBackButton")
            case .none:
                Button("Finish", role: .confirm) {
                    finishWorkout(action: .finish)
                }
                .accessibilityIdentifier("workoutFinishConfirmButton")
            }
        } message: {
            let summary = unfinishedSetSummary
            switch summary.caseType {
            case .emptyAndLogged:
                Text("You have ^[\(summary.loggedCount) logged set](inflect: true) and ^[\(summary.emptyCount) set](inflect: true) with no data.")
            case .loggedOnly:
                Text("You have ^[\(summary.loggedCount) set](inflect: true) with data but \(summary.loggedCount == 1 ? "isnt" : "arent") marked complete.")
            case .emptyOnly:
                Text("You have ^[\(summary.emptyCount) empty set](inflect: true).\nTo finish, either log them or remove them.")
            case .none:
                Text("Finish and save workout?")
            }
        }
    }
    
    private func finishWorkout(action: WorkoutFinishAction) {
        let result = workout.finish(action: action, context: context)
        
        switch result {
        case .finished:
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

        if workout.exercises.isEmpty {
            showExerciseListView = false
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
        if !showExerciseListView, activeExerciseAllSetsComplete(), isActiveLast {
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
}

#Preview {
    WorkoutView(workout: sampleIncompleteSession())
        .sampleDataContainerIncomplete()
}

#Preview("New Workout") {
    WorkoutView(workout: WorkoutSession())
        .sampleDataContainer()
}
