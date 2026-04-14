import SwiftUI

struct HomeTabView: View {
    @State private var router = AppRouter.shared
    @State private var showAppSettings = false

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
            .contentMargins(.bottom, quickActionContentBottomMargin, for: .scrollContent)
            .appBackground()
            .navBar(title: "Workout", includePadding: false) {
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
        .sheet(isPresented: $showAppSettings) {
            AppSettingsView()
                .presentationBackground(Color.sheetBg)
        }
    }
}

#Preview(traits: .sampleData) {
    HomeTabView()
}
