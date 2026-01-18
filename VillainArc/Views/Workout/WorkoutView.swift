import SwiftUI
import SwiftData

struct WorkoutView: View {
    @Bindable var workout: Workout
    @State private var activeExercise: WorkoutExercise?
    @State private var showExerciseListView: Bool = false
    @State private var showAddExerciseSheet: Bool = false
    @State private var showRestTimerSheet: Bool = false
    @State private var showWorkoutSettingsSheet: Bool = false
    @State private var restTimer = RestTimerState()
    
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Namespace private var animation
    
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
                    Button {
                        showRestTimerSheet = true
                    } label: {
                        timerToolbarLabel
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    toolBarMenu
                }
                ToolbarSpacer(.flexible, placement: .bottomBar)
                ToolbarItem(placement: .bottomBar) {
                    Button("Add Exercise", systemImage: "plus") {
                        Haptics.impact(.light)
                        showAddExerciseSheet = true
                    }
                    .matchedTransitionSource(id: "addExercise", in: animation)
                }
            }
            .animation(.smooth, value: showExerciseListView)
            .sheet(isPresented: $showAddExerciseSheet) {
                AddExerciseView(workout: workout)
                    .navigationTransition(.zoom(sourceID: "addExercise", in: animation))
                    .interactiveDismissDisabled()
                    .presentationBackground(Color(.systemBackground))
            }
            .sheet(isPresented: $showRestTimerSheet) {
                RestTimerView()
                    .presentationDetents([.medium, .large])
                    .presentationBackground(Color(.systemBackground))
            }
            .sheet(isPresented: $showWorkoutSettingsSheet) {
                WorkoutSettingsView(workout: workout, onFinish: finishWorkout, onDelete: deleteWorkout)
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
                            ExerciseView(exercise: exercise)
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
                    Haptics.selection()
                    activeExercise = exercise
                    showExerciseListView = false
                } label: {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(exercise.name)
                            .font(.title3)
                            .bold()
                        Text(exercise.displayMuscle)
                            .foregroundStyle(.secondary)
                            .fontWeight(.semibold)
                            .font(.headline)
                        ForEach(exercise.sortedSets) { set in
                            Text("\(set.reps)x\(Int(set.weight)) lbs")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
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
    }

    var toolBarMenu: some View {
        Menu("Options", systemImage: "ellipsis") {
            if workout.exercises.isEmpty {
                Button("Cancel Workout", systemImage: "xmark") {
                    deleteWorkout()
                }
            } else {
                ControlGroup {
                    Toggle(isOn: Binding(get: { showExerciseListView }, set: { _ in
                        showExerciseListView = true
                        Haptics.selection()
                    })) {
                        Label("List View", systemImage: "list.dash")
                    }
                    Toggle(isOn: Binding(get: { !showExerciseListView }, set: { _ in
                        showExerciseListView = false
                        Haptics.selection()
                    })) {
                        Label("Exercise View", systemImage: "list.clipboard")
                    }
                }
                Divider()
                Button("Settings", systemImage: "gearshape") {
                    Haptics.selection()
                    showWorkoutSettingsSheet = true
                }
            }
        }
    }
    
    private func finishWorkout() {
        Haptics.success()
        showWorkoutSettingsSheet = false
        workout.completed = true
        if workout.endTime == nil {
            workout.endTime = Date.now
        }
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
        Haptics.warning()
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
    
    private func moveExercise(from source: IndexSet, to destination: Int) {
        Haptics.impact(.light)
        workout.moveExercise(from: source, to: destination)
        saveContext(context: context)
    }

    @ViewBuilder
    private var timerToolbarLabel: some View {
        if restTimer.isRunning, let endDate = restTimer.endDate {
            Text(endDate, style: .timer)
                .fontWeight(.semibold)
                .monospacedDigit()
                .contentTransition(.numericText())
        } else if restTimer.isPaused {
            Text(secondsToTime(restTimer.pausedRemainingSeconds))
                .fontWeight(.semibold)
                .monospacedDigit()
                .contentTransition(.numericText())
        } else {
            Image(systemName: "timer")
        }
    }
    
}

#Preview {
    WorkoutView(workout: sampleWorkout())
        .sampleDataConainer()
        .environment(RestTimerState())
}
