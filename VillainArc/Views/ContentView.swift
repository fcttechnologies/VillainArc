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
                    WorkoutRowView(workout: workout)
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
                        startNewWorkout()
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
    
    private func startNewWorkout() {
        Haptics.impact(.medium)
        let newWorkout = Workout(title: "New Workout")
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
        Haptics.warning()
        for index in offsets {
            let workout = workouts[index]
            context.delete(workout)
            saveContext(context: context)
        }
    }
}

#Preview {
    ContentView()
        .sampleDataConainer()
}

#Preview("No Workouts") {
    ContentView()
}
