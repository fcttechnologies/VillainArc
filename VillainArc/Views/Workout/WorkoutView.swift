import SwiftUI
import SwiftData

struct WorkoutView: View {
    @Bindable var workout: Workout
    let isEditing: Bool
    let onDeleteFromEdit: (() -> Void)?
    
    @State private var activeExercise: WorkoutExercise?
    @State private var showExerciseListView: Bool = false
    @State private var showAddExerciseSheet: Bool = false
    @State private var showRestTimerSheet: Bool = false
    @State private var showWorkoutSettingsSheet: Bool = false
    @State private var restTimer = RestTimerState()
    @State private var showDeleteWorkoutConfirmation: Bool = false
    
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    
    @Namespace private var animation
    
    init(workout: Workout, isEditing: Bool = false, onDeleteFromEdit: (() -> Void)? = nil) {
        self.workout = workout
        self.isEditing = isEditing
        self.onDeleteFromEdit = onDeleteFromEdit
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
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isEditing {
                        Button("Done") {
                            Haptics.impact(.medium)
                            saveContext(context: context)
                            dismiss()
                        }
                    } else {
                        Button {
                            showRestTimerSheet = true
                            Haptics.impact(.light)
                        } label: {
                            timerToolbarLabel
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if workout.exercises.isEmpty {
                        Button(role: .close) {
                            deleteWorkout()
                        }
                    } else {
                        toolBarMenu
                    }
                }
                ToolbarSpacer(.flexible, placement: .bottomBar)
                ToolbarItem(placement: .bottomBar) {
                    Button("Add Exercise", systemImage: "plus") {
                        Haptics.impact(.medium)
                        showAddExerciseSheet = true
                    }
                    .matchedTransitionSource(id: "addExercise", in: animation)
                }
            }
            .animation(.smooth, value: showExerciseListView)
            .sheet(isPresented: $showAddExerciseSheet) {
                AddExerciseView(workout: workout, isEditing: isEditing)
                    .navigationTransition(.zoom(sourceID: "addExercise", in: animation))
                    .interactiveDismissDisabled()
            }
            .sheet(isPresented: $showRestTimerSheet) {
                RestTimerView()
                    .presentationDetents([.medium, .large])
                    .presentationBackground(Color(.systemBackground))
            }
            .sheet(isPresented: $showWorkoutSettingsSheet) {
                WorkoutSettingsView(workout: workout, isEditing: isEditing, onFinish: finishWorkout, onDelete: deleteWorkout)
            }
            .onAppear {
                restTimer.refreshIfExpired()
            }
            .onChange(of: scenePhase) {
                if scenePhase == .active {
                    restTimer.refreshIfExpired()
                    Task {
                        await restTimer.scheduleStopIfNeeded()
                    }
                }
            }
            .task(id: restTimer.endDate) {
                await restTimer.scheduleStopIfNeeded()
            }
        }
        .alert("Delete Workout?", isPresented: $showDeleteWorkoutConfirmation) {
            Button("Delete Workout", role: .destructive) {
                deleteWorkoutFromEdit()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This is the last exercise. Deleting it will delete the workout.")
        }
        .environment(restTimer)
    }
    
    var exerciseTabView: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    if workout.exercises.isEmpty {
                        ContentUnavailableView("No Exercises Added", systemImage: "dumbbell.fill", description: Text("Click the '\(Image(systemName: "plus"))' icon to add some exercises."))
                            .containerRelativeFrame(.horizontal)
                    } else {
                        ForEach(workout.sortedExercises) { exercise in
                            ExerciseView(exercise: exercise, isEditing: isEditing)
                                .containerRelativeFrame(.horizontal)
                                .id(exercise)
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $activeExercise)
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
                    .padding(.horizontal, 6)
                    .padding(.vertical)
                }
                .listRowBackground(Color.clear)
                .buttonStyle(.glass)
                .buttonBorderShape(.roundedRectangle)
                .listRowSeparator(.hidden)
            }
            .onDelete(perform: deleteExercise)
            .onMove(perform: moveExercise)
        }
        .scrollIndicators(.hidden)
        .listStyle(.plain)
        .listRowInsets(.all, 0)
    }
    
    var toolBarMenu: some View {
        Menu("Options", systemImage: "ellipsis") {
            ControlGroup {
                Toggle(isOn: Binding(get: { showExerciseListView }, set: { _ in
                    showExerciseListView = true
                    Haptics.impact(.light)
                })) {
                    Label("List View", systemImage: "list.dash")
                }
                Toggle(isOn: Binding(get: { !showExerciseListView }, set: { _ in
                    showExerciseListView = false
                    Haptics.impact(.light)
                })) {
                    Label("Exercise View", systemImage: "list.clipboard")
                }
            }
            Divider()
            Button("Settings", systemImage: "gearshape") {
                Haptics.impact(.light)
                showWorkoutSettingsSheet = true
            }
        }
    }
    
    private func finishWorkout(action: WorkoutFinishAction) {
        showWorkoutSettingsSheet = false
        
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
                Haptics.warning()
                restTimer.stop()
                context.delete(workout)
                saveContext(context: context)
                dismiss()
                return
            }
        }
        Haptics.success()
        workout.completed = true
        workout.endTime = Date.now
        restTimer.stop()
        saveContext(context: context)
        dismiss()
    }
    
    private func deleteWorkout() {
        Haptics.warning()
        showWorkoutSettingsSheet = false
        restTimer.stop()
        context.delete(workout)
        saveContext(context: context)
        dismiss()
    }
    
    private func deleteExercise(offsets: IndexSet) {
        guard !offsets.isEmpty else { return }
        if isEditing, workout.exercises.count - offsets.count == 0 {
            showDeleteWorkoutConfirmation = true
            return
        }
        deleteExercises(at: offsets)
    }
    
    private func deleteExercises(at offsets: IndexSet) {
        Haptics.impact(.light)
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
        Haptics.warning()
        showWorkoutSettingsSheet = false
        onDeleteFromEdit?()
    }
    
    private func moveExercise(from source: IndexSet, to destination: Int) {
        workout.moveExercise(from: source, to: destination)
        saveContext(context: context)
    }
    
    @ViewBuilder
    private var timerToolbarLabel: some View {
        if restTimer.isRunning, let endDate = restTimer.endDate {
            Text(endDate, style: .timer)
                .fontWeight(.semibold)
        } else if restTimer.isPaused {
            Text(secondsToTime(restTimer.pausedRemainingSeconds))
                .fontWeight(.semibold)
        } else {
            Image(systemName: "timer")
        }
    }
    
}

#Preview {
    WorkoutView(workout: sampleIncompleteWorkout())
        .sampleDataContainerIncomplete()
}

#Preview("New Workout") {
    WorkoutView(workout: Workout())
}
