import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    
    @Namespace private var animation
    
    @Query(filter: #Predicate<Workout> { !$0.completed }, sort: \Workout.startTime, order: .reverse) private var incompleteWorkouts: [Workout]
    @Query private var previousWorkouts: [Workout]
    @State private var router = WorkoutRouter()

    init() {
        let predicate = #Predicate<Workout> { $0.completed }
        let sort = [SortDescriptor(\Workout.startTime, order: .reverse)]
        var descriptor = FetchDescriptor(predicate: predicate, sortBy: sort)
        descriptor.fetchLimit = 1
        _previousWorkouts = Query(descriptor)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    NavigationLink {
                        PreviousWorkoutsListView()
                    } label: {
                        HStack(spacing: 0) {
                            Text("Previous Workouts")
                                .fontWeight(.semibold)
                                .fontDesign(.rounded)
                            Image(systemName: "chevron.right")
                                .bold()
                                .foregroundStyle(.secondary)
                        }
                        .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 4)
                    
                    if previousWorkouts.isEmpty {
                        ContentUnavailableView("No Previous Workouts", systemImage: "clock.arrow.circlepath", description: Text("Click the '\(Image(systemName: "plus"))' to start your first workout."))
                            .frame(maxWidth: .infinity)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                    } else {
                        ForEach(previousWorkouts) {
                            WorkoutRowView(workout: $0)
                        }
                    }
                }
                .padding()
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
                }
            }
            .onAppear {
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
        Haptics.impact(.medium)
        router.start(context: context)
    }
    
    private func checkForUnfinishedWorkout() {
        guard router.activeWorkout == nil else { return }
        if let unfinishedWorkout = incompleteWorkouts.first {
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
