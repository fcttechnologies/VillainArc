import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    
    @Namespace private var animation
    
    @Query(Workout.incompleteWorkout) private var incompleteWorkout: [Workout]
    @State private var router = WorkoutRouter()

    var body: some View {
        NavigationStack {
            ScrollView {
                RecentWorkoutSectionView()
                    .padding()
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Recent workout")
                    .accessibilityIdentifier("homeRecentWorkoutSection")
            }
            .navigationTitle("Home")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarSpacer(.flexible, placement: .bottomBar)
                ToolbarItem(placement: .bottomBar) {
                    Button("Start Workout", systemImage: "plus") {
                        startWorkout()
                    }
                    .matchedTransitionSource(id: "startWorkout", in: animation)
                    .accessibilityIdentifier("homeStartWorkoutButton")
                    .accessibilityHint("Starts a new workout session.")
                }
            }
            .task {
                DataManager.seedExercisesIfNeeded(context: context)
                checkForUnfinishedWorkout()
            }
            .fullScreenCover(item: $router.activeWorkout) {
                WorkoutView(workout: $0)
                    .navigationTransition(.zoom(sourceID: "startWorkout", in: animation))
                    .interactiveDismissDisabled()
            }
        }
        .environment(router)
    }

    private func startWorkout() {
        Haptics.selection()
        router.start(context: context)
    }
    
    private func checkForUnfinishedWorkout() {
        guard router.activeWorkout == nil else { return }
        if let unfinishedWorkout = incompleteWorkout.first {
            router.resume(unfinishedWorkout)
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
