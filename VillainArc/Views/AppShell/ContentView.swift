import SwiftUI

struct ContentView: View {
    @State private var router = AppRouter.shared
    @State private var isMorphingTabBarExpanded = false
    
    var body: some View {
        TabView(selection: tabSelectionBinding) {
            HomeTabView()
                .tag(AppTab.home)
                .toolbar(.hidden, for: .tabBar)
            
            HealthTabView()
                .tag(AppTab.health)
                .toolbar(.hidden, for: .tabBar)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaBar(edge: .bottom) {
            MorphingQuickActionsBar(activeTab: tabSelectionBinding, isExpanded: $isMorphingTabBarExpanded, actions: expandedActions)
        }
        .onChange(of: router.navigationEventToken) {
            collapseMorphingTabBar()
        }
        .fullScreenCover(item: $router.activeWorkoutSession) {
            WorkoutSessionContainer(workout: $0)
        }
        .fullScreenCover(item: $router.activeWorkoutPlan, onDismiss: {
            router.activeWorkoutPlanOriginal = nil
        }) {
            WorkoutPlanView(plan: $0, originalPlan: router.activeWorkoutPlanOriginal)
        }
        .fullScreenCover(item: $router.activeWeightGoalCompletion) {
            WeightGoalCompletionView(route: $0)
        }
        .background {
            ToastOverlaySceneInstaller()
                .allowsHitTesting(false)
        }
    }
    
    private var tabSelectionBinding: Binding<AppTab> {
        Binding(get: { router.tabSelection }, set: { router.selectTab($0) })
    }
    
    private var expandedActions: [ExpandedAction] {
        homeExpandedActions + additionalExpandedActions(for: router.additionalQuickActionContext)
    }
    
    private func additionalExpandedActions(for context: AppRouter.AdditionalQuickActionContext?) -> [ExpandedAction] {
        switch context {
        case .workoutSplit:
            workoutSplitExpandedActions
        case .workoutPlanDetail(let plan, let showsUseOnly):
            workoutPlanExpandedActions(plan: plan, showsUseOnly: showsUseOnly)
        case .weightGoalHistory:
            weightGoalExpandedActions
        case .stepsGoalHistory:
            stepsGoalExpandedActions
        case nil:
            []
        }
    }
    
    private var homeExpandedActions: [ExpandedAction] {
        [
            ExpandedAction("New Workout", icon: "figure.strengthtraining.traditional", accessibilityIdentifier: AccessibilityIdentifiers.morphingStartWorkoutButton, accessibilityHint: AccessibilityText.morphingStartWorkoutHint) {
                collapseMorphingTabBar()
                router.startWorkoutSession()
                Task { await IntentDonations.donateStartWorkout() }
            },
            ExpandedAction("Create Plan", icon: "list.clipboard", accessibilityIdentifier: AccessibilityIdentifiers.morphingCreatePlanButton, accessibilityHint: AccessibilityText.morphingCreatePlanHint) {
                collapseMorphingTabBar()
                router.createWorkoutPlan()
                Task { await IntentDonations.donateCreateWorkoutPlan() }
            },
            ExpandedAction("Add Weight", icon: "scalemass", accessibilityIdentifier: AccessibilityIdentifiers.morphingAddWeightButton, accessibilityHint: AccessibilityText.morphingAddWeightHint) {
                collapseMorphingTabBar()
                router.tabSelection = .health
                router.activeHealthSheet = .addWeightEntry
            }
        ]
    }
    
    private var workoutSplitExpandedActions: [ExpandedAction] {
        [
            ExpandedAction("New Split", icon: "plus.rectangle.on.folder", accessibilityIdentifier: AccessibilityIdentifiers.morphingCreateSplitButton, accessibilityHint: AccessibilityText.workoutSplitCreateHint) {
                collapseMorphingTabBar()
                router.activeSplitSheet = .builder
                Task { await IntentDonations.donateCreateWorkoutSplit() }
            }
        ]
    }
    
    private func workoutPlanExpandedActions(plan: WorkoutPlan, showsUseOnly: Bool) -> [ExpandedAction] {
        [
            ExpandedAction(showsUseOnly ? "Use Plan" : "Start Workout", icon: "figure.strengthtraining.traditional", accessibilityIdentifier: AccessibilityIdentifiers.morphingUsePlanButton, accessibilityHint: AccessibilityText.workoutPlanDetailStartWorkoutHint) {
                collapseMorphingTabBar()
                router.startWorkoutSession(from: plan)
                Task {
                    await IntentDonations.donateStartWorkoutWithPlan(workoutPlan: plan)
                    if router.isTodaysActiveSplitPlan(plan) {
                        await IntentDonations.donateStartTodaysWorkout()
                    }
                }
            }
        ]
    }
    
    private var weightGoalExpandedActions: [ExpandedAction] {
        [
            ExpandedAction("New Goal", icon: "target", accessibilityIdentifier: AccessibilityIdentifiers.morphingNewWeightGoalButton, accessibilityHint: AccessibilityText.healthWeightGoalHistoryAddHint) {
                collapseMorphingTabBar()
                router.activeHealthSheet = .newWeightGoal
            }
        ]
    }
    
    private var stepsGoalExpandedActions: [ExpandedAction] {
        [
            ExpandedAction("New Goal", icon: "target", accessibilityIdentifier: AccessibilityIdentifiers.morphingNewStepsGoalButton, accessibilityHint: AccessibilityText.healthStepsGoalHistoryAddHint) {
                collapseMorphingTabBar()
                router.activeHealthSheet = .newStepsGoal
            }
        ]
    }
    
    private func collapseMorphingTabBar() {
        guard isMorphingTabBarExpanded else { return }
        withAnimation(.bouncy(duration: 0.35, extraBounce: 0.02)) {
            isMorphingTabBarExpanded = false
        }
    }
}

#Preview(traits: .sampleData) {
    ContentView()
}
