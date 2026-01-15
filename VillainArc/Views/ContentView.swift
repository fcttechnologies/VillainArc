import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    
    @Namespace private var animation
    
    @Query private var workouts: [Workout]
    @State private var workout: Workout?
    
    private func deleteWorkout(offsets: IndexSet) {
        guard !offsets.isEmpty else { return }
        Haptics.warning()
        for index in offsets {
            let workout = workouts[index]
            context.delete(workout)
            saveContext(context: context)
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section("Workouts") {
                    ForEach(workouts) { workout in
                        Text(workout.title)
                    }
                    .onDelete(perform: deleteWorkout)
                }
            }
            .navigationTitle("Workout")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
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
}

#Preview {
    ContentView()
        .sampleDataConainer()
}

#Preview("Empty Workouts") {
    ContentView()
}
