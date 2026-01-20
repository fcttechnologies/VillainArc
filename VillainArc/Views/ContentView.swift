import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    
    @Namespace private var animation
    
    @Query(sort: \Workout.startTime, order: .reverse) private var workouts: [Workout]
    @State private var workout: Workout?
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(workouts) { workout in
                    WorkoutRowView(workout: workout, onStartFromWorkout: { template in
                        startWorkout(from: template)
                    }, onDeleteWorkout: deleteWorkout)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                .onDelete(perform: deleteWorkout)
            }
            .navigationTitle("Home")
            .toolbarTitleDisplayMode(.inlineLarge)
            .listStyle(.plain)
            .toolbar {
                ToolbarSpacer(.flexible, placement: .bottomBar)
                ToolbarItem(placement: .bottomBar) {
                    Button("Start Workout", systemImage: "plus") {
                        startWorkout()
                    }
                    .matchedTransitionSource(id: "startWorkout", in: animation)
                }
            }
            .onAppear {
                DataManager.seedExercisesIfNeeded(context: context)
                checkForUnfinishedWorkout()
            }
            .fullScreenCover(item: $workout) {
                WorkoutView(workout: $0)
                    .navigationTransition(.zoom(sourceID: "startWorkout", in: animation))
                    .interactiveDismissDisabled()
            }
        }
    }
    
    private func startWorkout(from template: Workout? = nil) {
        Haptics.impact(.medium)
        let newWorkout = template.map { Workout(previous: $0) } ?? Workout()
        context.insert(newWorkout)
        saveContext(context: context)
        workout = newWorkout
    }
    
    private func checkForUnfinishedWorkout() {
        if let unfinishedWorkout = workouts.first(where: { !$0.completed }) {
            workout = unfinishedWorkout
        }
    }
    
    private func deleteWorkout(offsets: IndexSet) {
        guard !offsets.isEmpty else { return }
        for index in offsets {
            deleteWorkout(workouts[index])
        }
    }
    
    private func deleteWorkout(_ workout: Workout) {
        Haptics.warning()
        context.delete(workout)
        saveContext(context: context)
    }
}

#Preview {
    ContentView()
        .sampleDataConainer()
}

#Preview("No Workouts") {
    ContentView()
}
