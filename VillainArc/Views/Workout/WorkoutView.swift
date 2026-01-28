import SwiftUI
import SwiftData

struct WorkoutView: View {
    @Bindable var workout: Workout
    let isEditing: Bool
    let onDeleteFromEdit: (() -> Void)?
    private let restTimer = RestTimerState.shared
    
    @State private var activeExercise: WorkoutExercise?
    @State private var showExerciseListView = false
    @State private var showAddExerciseSheet = false
    @State private var showRestTimerSheet = false
    @State private var showDeleteWorkoutAlert = false
    @State private var showTitleEditorSheet = false
    @State private var showNotesEditorSheet = false
    @State private var showDeleteConfirmation = false
    @State private var showSaveConfirmation = false
    
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @Namespace private var animation
    
    init(workout: Workout, isEditing: Bool = false, onDeleteFromEdit: (() -> Void)? = nil) {
        self.workout = workout
        self.isEditing = isEditing
        self.onDeleteFromEdit = onDeleteFromEdit
    }
    
    private var incompleteSetCount: Int {
        workout.exercises.reduce(0) { count, exercise in
            count + exercise.sets.filter { !$0.complete }.count
        }
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
            .navigationSubtitle(Text(workout.startTime, style: .date))
            .toolbarTitleMenu {
                Button("Change Title", systemImage: "pencil") {
                    showTitleEditorSheet = true
                }
                Button("Workout Notes", systemImage: "note.text") {
                    showNotesEditorSheet = true
                }
            }
            .toolbarTitleDisplayMode(.inline)
            .animation(.bouncy, value: showExerciseListView)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isEditing {
                        Button("Done", systemImage: "checkmark") {
                            Haptics.selection()
                            saveContext(context: context)
                            SpotlightIndexer.index(workout: workout)
                            dismiss()
                        }
                        .labelStyle(.titleOnly)
                        .accessibilityIdentifier("workoutDoneEditingButton")
                        .accessibilityHint("Saves changes and closes the workout.")
                    } else {
                        Button {
                            showRestTimerSheet = true
                            Haptics.selection()
                        } label: {
                            timerToolbarLabel
                        }
                        .accessibilityIdentifier("workoutRestTimerButton")
                        .accessibilityHint("Shows the rest timer.")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    workoutOptionsToolbarLabel
                }
                ToolbarSpacer(.flexible, placement: .bottomBar)
                ToolbarItem(placement: .bottomBar) {
                    Button("Add Exercise", systemImage: "plus") {
                        Haptics.selection()
                        showAddExerciseSheet = true
                    }
                    .matchedTransitionSource(id: "addExercise", in: animation)
                    .accessibilityIdentifier("workoutAddExerciseButton")
                    .accessibilityHint("Adds an exercise.")
                }
            }
            .animation(.smooth, value: showExerciseListView)
            .sheet(isPresented: $showAddExerciseSheet) {
                AddExerciseView(workout: workout, isEditing: isEditing)
                    .navigationTransition(.zoom(sourceID: "addExercise", in: animation))
                    .interactiveDismissDisabled()
            }
            .sheet(isPresented: $showRestTimerSheet) {
                RestTimerView(workout: workout)
                    .presentationDetents([.medium, .large])
                    .presentationBackground(Color(.systemBackground))
            }
            .sheet(isPresented: $showNotesEditorSheet) {
                WorkoutNotesEditorView(workout: workout)
                    .presentationDetents([.fraction(0.4)])
            }
            .sheet(isPresented: $showTitleEditorSheet) {
                WorkoutTitleEditorView(workout: workout)
                    .presentationDetents([.fraction(0.2)])
            }
        }
        .alert("Delete Workout?", isPresented: $showDeleteWorkoutAlert) {
            Button("Delete Workout", role: .destructive) {
                deleteWorkoutFromEdit()
            }
            .accessibilityIdentifier("workoutConfirmDeleteButton")
            Button("Cancel", role: .cancel) {}
                .accessibilityIdentifier("workoutCancelDeleteButton")
        } message: {
            Text("This is the last exercise. Deleting it will delete the workout.")
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
                            ExerciseView(exercise: exercise, showRestTimerSheet: $showRestTimerSheet, isEditing: isEditing)
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
            .scrollPosition(id: $activeExercise)
            .accessibilityIdentifier("workoutExercisePager")
            .onAppear {
                if let activeExercise {
                    proxy.scrollTo(activeExercise)
                }
            }
        }
    }
    
    var exerciseListView: some View {
        List {
            ForEach(workout.sortedExercises) { exercise in
                Button {
                    activeExercise = exercise
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
                            Text("^[\(exercise.sortedSets.count) set](inflect: true)")
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
    
    @ViewBuilder
    private var timerToolbarLabel: some View {
        if restTimer.isRunning, let endDate = restTimer.endDate, endDate > Date() {
            Text(endDate, style: .timer)
                .fontWeight(.semibold)
        } else if restTimer.isPaused {
            Text(secondsToTime(restTimer.pausedRemainingSeconds))
                .fontWeight(.semibold)
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
                .confirmationDialog("Finish Workout", isPresented: $showSaveConfirmation) {
                    if incompleteSetCount > 0 {
                        Button("Mark All Sets Complete") {
                            finishWorkout(action: .markAllComplete)
                        }
                        .accessibilityIdentifier("workoutFinishMarkSetsCompleteButton")
                        Button("Delete Incomplete Sets", role: .destructive) {
                            finishWorkout(action: .deleteIncomplete)
                        }
                        .accessibilityIdentifier("workoutFinishDeleteIncompleteSetsButton")
                    } else {
                        Button("Finish", role: .confirm) {
                            finishWorkout(action: .markAllComplete)
                        }
                        .accessibilityIdentifier("workoutFinishConfirmButton")
                    }
                } message: {
                    if incompleteSetCount > 0 {
                        Text("Before finishing, choose how to handle incomplete sets.")
                    } else {
                        Text("Finish and save workout?")
                    }
                }
            }
        }
        .confirmationDialog("Cancel Workout", isPresented: $showDeleteConfirmation) {
            Button("Cancel Workout", role: .destructive) {
                showDeleteConfirmation = false
                deleteWorkout()
            }
            .accessibilityIdentifier("workoutConfirmDeleteButton")
        } message: {
            Text("Are you sure you want to delete this workout?")
        }
    }
    
    private func finishWorkout(action: WorkoutFinishAction) {
        switch action {
        case .markAllComplete:
            for exercise in workout.exercises {
                for set in exercise.sets where !set.complete {
                    set.complete = true
                }
            }
        case .deleteIncomplete:
            for exercise in workout.exercises {
                let incompleteSets = exercise.sets.filter { !$0.complete }
                for set in incompleteSets {
                    exercise.removeSet(set)
                    context.delete(set)
                }
            }
            let emptyExercises = workout.exercises.filter { $0.sets.isEmpty }
            for exercise in emptyExercises {
                workout.removeExercise(exercise)
                context.delete(exercise)
            }
            if workout.exercises.isEmpty {
                Haptics.selection()
                restTimer.stop()
                context.delete(workout)
                saveContext(context: context)
                dismiss()
                return
            }
        }
        Haptics.selection()
        workout.completed = true
        workout.endTime = Date.now
        workout.sourceTemplate?.updateLastUsed()
        restTimer.stop()
        saveContext(context: context)
        SpotlightIndexer.index(workout: workout)
        Task {
            await IntentDonations.donateFinishWorkout()
            await IntentDonations.donateLastWorkoutSummary()
        }
        dismiss()
    }
    
    private func deleteWorkout() {
        Haptics.selection()
        restTimer.stop()
        context.delete(workout)
        saveContext(context: context)
        Task { await IntentDonations.donateCancelWorkout() }
        dismiss()
    }
    
    private func deleteExercise(offsets: IndexSet) {
        guard !offsets.isEmpty else { return }
        if isEditing, workout.exercises.count - offsets.count == 0 {
            showDeleteWorkoutAlert = true
            return
        }
        deleteExercises(at: offsets)
    }
    
    private func deleteExercises(at offsets: IndexSet) {
        Haptics.selection()
        let exercisesToDelete = offsets.map { workout.sortedExercises[$0] }
        
        for exercise in exercisesToDelete {
            workout.removeExercise(exercise)
            context.delete(exercise)
        }
        saveContext(context: context)
        
        if let active = activeExercise, exercisesToDelete.contains(active) {
            activeExercise = workout.sortedExercises.first
        }
        
        if workout.exercises.isEmpty {
            showExerciseListView = false
        }
    }
    
    private func deleteWorkoutFromEdit() {
        Haptics.selection()
        onDeleteFromEdit?()
    }
    
    private func moveExercise(from source: IndexSet, to destination: Int) {
        workout.moveExercise(from: source, to: destination)
        saveContext(context: context)
    }
}

enum WorkoutFinishAction {
    case markAllComplete
    case deleteIncomplete
}

#Preview {
    WorkoutView(workout: sampleIncompleteWorkout())
        .sampleDataContainerIncomplete()
}

#Preview("New Workout") {
    WorkoutView(workout: Workout())
}
