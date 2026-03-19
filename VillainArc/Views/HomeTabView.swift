import SwiftUI

struct HomeTabView: View {
    @State private var router = AppRouter.shared
    @State private var showAppSettings = false

    var body: some View {
        NavigationStack(path: $router.homeTabPath) {
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
                RecentExercisesSectionView()
                    .padding()
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier(AccessibilityIdentifiers.homeRecentExercisesSection)
            }
            .navBar(title: "Home", includePadding: false) {
                Button {
                    showAppSettings = true
                    Haptics.selection()
                } label: {
                    Label("Settings", systemImage: "gear")
                        .font(.title2)
                        .labelStyle(.iconOnly)
                }
                .buttonBorderShape(.circle)
                .buttonStyle(.glass)
                .accessibilityLabel(AccessibilityText.homeSettingsLabel)
                .accessibilityIdentifier(AccessibilityIdentifiers.homeSettingsButton)
                .accessibilityHint(AccessibilityText.homeSettingsHint)
            }
            .scrollIndicators(.hidden)
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
            .navigationDestination(for: AppRouter.Destination.self) { destination in
                switch destination {
                case .workoutSessionsList:
                    WorkoutsListView()
                case .workoutSessionDetail(let session):
                    WorkoutDetailView(workout: session)
                case .healthWorkoutDetail(let workout):
                    HealthWorkoutDetailView(workout: workout)
                case .workoutPlansList:
                    WorkoutPlansListView()
                case .workoutPlanDetail(let plan, let showsUseOnly):
                    WorkoutPlanDetailView(plan: plan, showsUseOnly: showsUseOnly)
                case .exercisesList:
                    ExercisesListView()
                case .exerciseDetail(let catalogID):
                    ExerciseDetailView(catalogID: catalogID)
                case .exerciseHistory(let catalogID):
                    ExerciseHistoryView(catalogID: catalogID)
                case .workoutSplit(let autoPresentBuilder):
                    WorkoutSplitView(autoPresentBuilder: autoPresentBuilder)
                case .workoutSplitDetail(let split):
                    WorkoutSplitView(split: split)
                }
            }
        }
        .sheet(isPresented: $showAppSettings) {
            AppSettingsView()
        }
    }
}

#Preview {
    HomeTabView()
        .sampleDataContainer()
}
