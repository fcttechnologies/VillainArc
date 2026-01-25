import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    
    @Namespace private var animation
    
    @State private var router = AppRouter.shared

    var body: some View {
        NavigationStack(path: $router.path) {
            ScrollView {
                RecentWorkoutSectionView()
                    .padding()
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Recent workout")
                    .accessibilityIdentifier("homeRecentWorkoutSection")
                RecentTemplatesSectionView()
                    .padding()
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Recent templates")
                    .accessibilityIdentifier("homeRecentTemplatesSection")
            }
            .navBar(title: "Home")
            .toolbar {
                ToolbarSpacer(.flexible, placement: .bottomBar)
                ToolbarItem(placement: .bottomBar) {
                    Menu("Options", systemImage: "plus") {
                        Button("Start Empty Workout", systemImage: "figure.strengthtraining.traditional") {
                            startWorkout()
                        }
                        .matchedTransitionSource(id: "startWorkout", in: animation)
                        .accessibilityIdentifier("homeStartWorkoutButton")
                        .accessibilityHint("Starts a new workout session.")
                        Button("Create Template", systemImage: "list.clipboard") {
                            createTemplate()
                        }
                        .matchedTransitionSource(id: "createTemplate", in: animation)
                        .accessibilityIdentifier("homeCreateTemplateButton")
                        .accessibilityHint("Creates a new template.")
                    }
                    .labelStyle(.iconOnly)
                    .accessibilityIdentifier("homeOptionsMenu")
                    .accessibilityHint("Shows workout and template options.")
                }
            }
            .task {
                DataManager.seedExercisesIfNeeded(context: context)
                router.checkForUnfinishedData()
            }
            .fullScreenCover(item: $router.activeWorkout) {
                WorkoutView(workout: $0)
                    .navigationTransition(.zoom(sourceID: "startWorkout", in: animation))
                    .interactiveDismissDisabled()
            }
            .fullScreenCover(item: $router.activeTemplate) {
                TemplateView(template: $0)
                    .navigationTransition(.zoom(sourceID: "createTemplate", in: animation))
                    .interactiveDismissDisabled()
            }
            .navigationDestination(for: AppRouter.Destination.self) { destination in
                switch destination {
                case .workoutsList:
                    WorkoutsListView()
                case .workoutDetail(let workout):
                    WorkoutDetailView(workout: workout)
                case .templateList:
                    TemplatesListView()
                case .templateDetail(let template):
                    TemplateDetailView(template: template)
                }
            }
        }
        .environment(router)
    }

    private func startWorkout() {
        router.startWorkout()
        Task { await IntentDonations.donateStartWorkout() }
    }
    
    private func createTemplate() {
        router.createTemplate()
        Task { await IntentDonations.donateCreateTemplate() }
    }
}

#Preview {
    ContentView()
        .sampleDataConainer()
}

#Preview {
    ContentView()
}
