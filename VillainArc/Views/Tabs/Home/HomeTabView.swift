import SwiftUI

struct HomeTabView: View {
    @State private var router = AppRouter.shared

    var body: some View {
        NavigationStack(path: Binding(get: { router.homeTabPath }, set: { router.homeTabPath = $0; router.noteNavigationStateChanged() })) {
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
            .quickActionContentBottomInset()
            .appBackground()
            .navBar(title: "Workout", includePadding: false) {
                ProfileSheetLauncherButton(accessibilityIdentifier: AccessibilityIdentifiers.homeProfileButton)
            }
            .scrollIndicators(.hidden)
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
                default:
                    EmptyView()
                }
            }
        }
        .id(router.homeTabResetToken)
    }
}

#Preview(traits: .sampleData) {
    HomeTabView()
}
