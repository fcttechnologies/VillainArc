import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    
    @Namespace private var animation
    
    @Query(Workout.incompleteWorkout) private var incompleteWorkout: [Workout]
    @State private var router = WorkoutRouter()
    @Bindable private var appRouter = AppRouter.shared

    var body: some View {
        NavigationStack(path: $appRouter.path) {
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
            .navigationDestination(for: AppRouter.Destination.self) { destination in
                switch destination {
                case .workoutsList:
                    WorkoutsListView()
                case .workoutDetail(let workout):
                    WorkoutDetailView(workout: workout)
                }
            }
        }
        .environment(router)
        .onReceive(NotificationCenter.default.publisher(for: .workoutStartedFromIntent)) { _ in
            handleIntentWorkoutStart()
        }
    }

    private func startWorkout() {
        Haptics.selection()
        router.start(context: context)
    }
    
    private func checkForUnfinishedWorkout() {
        if let unfinishedWorkout = incompleteWorkout.first {
            Haptics.selection()
            router.resume(unfinishedWorkout)
        }
    }
    
    private func handleIntentWorkoutStart() {
        if let unfinishedWorkout = incompleteWorkout.first {
            router.resume(unfinishedWorkout)
        } else {
            startWorkout()
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
