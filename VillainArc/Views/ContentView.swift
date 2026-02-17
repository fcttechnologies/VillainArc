import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @State private var router = AppRouter.shared

    var body: some View {
        NavigationStack(path: $router.path) {
            ScrollView {
                WorkoutSplitSectionView()
                    .padding()
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(AccessibilityText.homeWorkoutSplitLabel)
                    .accessibilityHint(AccessibilityText.homeWorkoutSplitHint)
                    .accessibilityIdentifier(AccessibilityIdentifiers.homeWorkoutSplitSection)
                RecentWorkoutSectionView()
                    .padding()
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(AccessibilityText.homeRecentWorkoutLabel)
                    .accessibilityHint(AccessibilityText.homeRecentWorkoutHint)
                    .accessibilityIdentifier(AccessibilityIdentifiers.homeRecentWorkoutSection)
                RecentWorkoutPlanSectionView()
                    .padding()
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(AccessibilityText.homeRecentWorkoutPlanLabel)
                    .accessibilityHint(AccessibilityText.homeRecentWorkoutPlanHint)
                    .accessibilityIdentifier(AccessibilityIdentifiers.homeRecentWorkoutPlanSection)
            }
            .navBar(title: "Home")
            .toolbar {
                ToolbarSpacer(.flexible, placement: .bottomBar)
                ToolbarItem(placement: .bottomBar) {
                    Menu("Options", systemImage: "plus") {
                        Button("Start Empty Workout", systemImage: "figure.strengthtraining.traditional") {
                            router.startWorkoutSession()
                            Task { await IntentDonations.donateStartWorkout() }
                        }
                        .accessibilityLabel(AccessibilityText.homeStartWorkoutLabel)
                        .accessibilityIdentifier(AccessibilityIdentifiers.homeStartWorkoutButton)
                        .accessibilityHint(AccessibilityText.homeStartWorkoutHint)
                        Button("Create Workout Plan", systemImage: "list.clipboard") {
                            router.createWorkoutPlan()
                            Task { await IntentDonations.donateCreateWorkoutPlan() }
                        }
                        .accessibilityLabel(AccessibilityText.homeCreatePlanLabel)
                        .accessibilityIdentifier(AccessibilityIdentifiers.homeCreatePlanButton)
                        .accessibilityHint(AccessibilityText.homeCreatePlanHint)
                    }
                    .labelStyle(.iconOnly)
                    .accessibilityLabel(AccessibilityText.homeOptionsMenuLabel)
                    .accessibilityIdentifier(AccessibilityIdentifiers.homeOptionsMenu)
                    .accessibilityHint(AccessibilityText.homeOptionsMenuHint)
                }
            }
            .task {
                await DataManager.seedExercisesIfNeeded(context: context)
                router.checkForUnfinishedData()
            }
            .fullScreenCover(item: $router.activeWorkoutSession) {
                WorkoutSessionContainer(workout: $0)
            }
            .fullScreenCover(item: $router.activeWorkoutPlan) {
                WorkoutPlanView(plan: $0)
            }
            .navigationDestination(for: AppRouter.Destination.self) { destination in
                switch destination {
                case .workoutSessionsList:
                    WorkoutsListView()
                case .workoutSessionDetail(let session):
                    WorkoutDetailView(workout: session)
                case .workoutPlansList:
                    WorkoutPlansListView()
                case .workoutPlanDetail(let plan, let showsUseOnly):
                    WorkoutPlanDetailView(plan: plan, showsUseOnly: showsUseOnly)
                case .splitList(let autoPresentBuilder):
                    WorkoutSplitView(autoPresentBuilder: autoPresentBuilder)
                case .splitDettail(let split):
                    WorkoutSplitCreationView(split: split)
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .sampleDataContainer()
}
