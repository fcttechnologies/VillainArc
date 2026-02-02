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
    @State private var showMoodSheet = false
    @State private var showDeleteConfirmation = false
    @State private var showSaveConfirmation = false
    @State private var autoAdvanceTargetIndex: Int?
    
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @Namespace private var animation
    
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
            .navigationSubtitle(Text(workout.startedAt, style: .date))
            .toolbarTitleMenu {
                Button("Change Title", systemImage: "pencil") {
                    showTitleEditorSheet = true
                }
                Button("Workout Notes", systemImage: "note.text") {
                    showNotesEditorSheet = true
                }
                Button("Pre Workout Mood", systemImage: "face.smiling") {
                    showMoodSheet = true
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.workoutPreMoodButton)
                .accessibilityHint("Updates your pre-workout mood.")
            }
            .toolbarTitleDisplayMode(.inline)
            .animation(.bouncy, value: showExerciseListView)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    workoutOptionsToolbarLabel
                }
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        showRestTimerSheet = true
                        Haptics.selection()
                    } label: {
                        timerToolbarLabel
                    }
                    .accessibilityIdentifier("workoutRestTimerButton")
                    .accessibilityHint("Shows the rest timer.")
                }
                ToolbarSpacer(.flexible, placement: .bottomBar)
                ToolbarItem(placement: .bottomBar) {
                    Button("Add Exercise", systemImage: "plus") {
                        Haptics.selection()
                        prepareForAddExerciseSheet()
                        showAddExerciseSheet = true
                    }
                    .matchedTransitionSource(id: "addExercise", in: animation)
                    .accessibilityIdentifier("workoutAddExerciseButton")
                    .accessibilityHint("Adds an exercise.")
                }
            }
            .animation(.smooth, value: showExerciseListView)
            .sheet(isPresented: $showAddExerciseSheet, onDismiss: handleAddExerciseSheetDismiss) {
                AddExerciseView(workout: workout)
                    .navigationTransition(.zoom(sourceID: "addExercise", in: animation))
                    .interactiveDismissDisabled()
            }
            .sheet(isPresented: $showRestTimerSheet) {
                RestTimerView(workout: workout)
                    .presentationDetents([.medium, .large])
                    .presentationBackground(Color(.systemBackground))
            }
            .sheet(isPresented: $showNotesEditorSheet) {
                TextEntryEditorView(title: "Notes", placeholder: "Workout Notes", text: $workout.notes, accessibilityIdentifier: AccessibilityIdentifiers.workoutNotesEditorField, axis: .vertical)
                    .presentationDetents([.fraction(0.4)])
                    .onChange(of: workout.notes) {
                        scheduleSave(context: context)
                    }
                    .onDisappear {
                        saveContext(context: context)
                    }
            }
            .sheet(isPresented: $showMoodSheet) {
                if let mood = workout.preMood {
                    PreWorkoutMoodView(mood: mood)
                        .presentationDetents([.fraction(0.4)])
                }
            }
            .sheet(isPresented: $showTitleEditorSheet) {
                TextEntryEditorView(title: "Title", placeholder: "Workout Title", text: $workout.title, accessibilityIdentifier: AccessibilityIdentifiers.workoutTitleEditorField)
                    .presentationDetents([.fraction(0.2)])
                    .onChange(of: workout.title) {
                        scheduleSave(context: context)
                    }
                    .onDisappear {
                        if workout.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            workout.title = "New Workout"
                        }
                        saveContext(context: context)
                    }
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
                if workout.preMood == nil {
                    let mood = PreWorkoutMood(workoutSession: workout)
                    context.insert(mood)
                    workout.preMood = mood
                    saveContext(context: context)
                    showMoodSheet = true
                }
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
                            ExerciseView(exercise: exercise, showRestTimerSheet: $showRestTimerSheet) {
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
    
    private func finishWorkout(action: WorkoutFinishAction) {
        switch action {
        case .markAllComplete:
            for exercise in workout.exercises {
                for set in exercise.sets where !set.complete {
                    set.complete = true
                    set.completedAt = Date()
                }
            }
        case .deleteIncomplete:
            for exercise in workout.exercises {
                let incompleteSets = exercise.sets.filter { !$0.complete }
                for set in incompleteSets {
                    exercise.deleteSet(set)
                    context.delete(set)
                }
            }
            let emptyExercises = workout.exercises.filter { $0.sets.isEmpty }
            for exercise in emptyExercises {
                workout.deleteExercise(exercise)
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
        workout.endedAt = Date()
        workout.activeExercise = nil
        restTimer.stop()
        saveContext(context: context)
        SpotlightIndexer.index(workoutSession: workout)
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
        Task { await IntentDonations.donateCancelWorkout() }
        saveContext(context: context)
        dismiss()
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
    }
    
    private func moveExercise(from source: IndexSet, to destination: Int) {
        workout.moveExercise(from: source, to: destination)
        saveContext(context: context)
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
            return
        }
        if workout.activeExercise == nil {
            workout.activeExercise = exercises.first
        }
    }

    private func activeExerciseAllSetsComplete() -> Bool {
        guard let activeExercise = workout.activeExercise else { return false }
        let sets = activeExercise.sortedSets
        guard !sets.isEmpty else { return false }
        return sets.allSatisfy { $0.complete }
    }
}

enum WorkoutFinishAction {
    case markAllComplete
    case deleteIncomplete
}

#Preview {
    WorkoutView(workout: sampleIncompleteSession())
        .sampleDataContainerIncomplete()
}

#Preview("New Workout") {
    WorkoutView(workout: WorkoutSession())
        .sampleDataContainer()
}
