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
            if !router.isQuickActionsBarHidden {
                MorphingQuickActionsBar(activeTab: tabSelectionBinding, isExpanded: $isMorphingTabBarExpanded, actions: expandedActions)
            }
        }
        .onChange(of: router.navigationEventToken) {
            collapseMorphingTabBar()
        }
        .onChange(of: router.isQuickActionsBarHidden) { _, isHidden in
            if isHidden {
                collapseMorphingTabBar()
            }
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
        .sheet(isPresented: addWeightEntrySheetBinding) {
            NewWeightEntryView()
                .presentationDetents([.fraction(0.5)])
                .presentationBackground(Color.sheetBg)
        }
        .sheet(isPresented: newWeightGoalSheetBinding) {
            NewWeightGoalView()
                .presentationBackground(Color.sheetBg)
        }
        .sheet(isPresented: newStepsGoalSheetBinding) {
            NewStepsGoalView()
                .presentationDetents([.fraction(0.35)])
                .presentationBackground(Color.sheetBg)
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
        case .healthRoot:
            healthExpandedActions
        case .workoutDetail(let workout):
            workoutDetailExpandedActions(workout: workout)
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
                router.presentHealthSheet(.addWeightEntry)
            }
        ]
    }

    private var healthExpandedActions: [ExpandedAction] {
        [
            ExpandedAction("Status", icon: "figure.run", accessibilityIdentifier: "morphing_training_condition_button", accessibilityHint: "Opens your training condition editor.") {
                collapseMorphingTabBar()
                router.presentHealthSheet(.trainingConditionEditor)
            }
        ]
    }
    
    private var workoutSplitExpandedActions: [ExpandedAction] {
        [
            ExpandedAction("New Split", icon: "plus.rectangle.on.folder", accessibilityIdentifier: AccessibilityIdentifiers.morphingCreateSplitButton, accessibilityHint: AccessibilityText.workoutSplitCreateHint) {
                collapseMorphingTabBar()
                router.presentSplitSheet(.builder)
                Task { await IntentDonations.donateCreateWorkoutSplit() }
            }
        ]
    }

    private func workoutDetailExpandedActions(workout: WorkoutSession) -> [ExpandedAction] {
        var actions: [ExpandedAction] = []

        if let linkedPlan = workout.workoutPlan {
            actions.append(
                ExpandedAction("Open Plan", icon: "arrowshape.turn.up.right", accessibilityIdentifier: AccessibilityIdentifiers.morphingOpenWorkoutPlanButton, accessibilityHint: AccessibilityText.workoutDetailOpenWorkoutPlanHint) {
                    collapseMorphingTabBar()
                    router.popToRoot()
                    router.navigate(to: .workoutPlanDetail(linkedPlan, false))
                    Task { await IntentDonations.donateOpenWorkoutPlan(workoutPlan: linkedPlan) }
                }
            )
        } else {
            actions.append(
                ExpandedAction("Save as Plan", icon: "list.clipboard", accessibilityIdentifier: AccessibilityIdentifiers.morphingSaveWorkoutPlanButton, accessibilityHint: AccessibilityText.workoutDetailSaveWorkoutPlanHint) {
                    collapseMorphingTabBar()
                    router.createWorkoutPlan(from: workout)
                }
            )
        }

        return actions
    }

    private func workoutPlanExpandedActions(plan: WorkoutPlan, showsUseOnly: Bool) -> [ExpandedAction] {
        var actions = [
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

        if !showsUseOnly {
            actions.append(
                ExpandedAction("Edit Plan", icon: "pencil", accessibilityIdentifier: AccessibilityIdentifiers.morphingEditPlanButton, accessibilityHint: AccessibilityText.workoutPlanDetailEditHint) {
                    collapseMorphingTabBar()
                    router.editWorkoutPlan(plan)
                }
            )
        }

        return actions
    }
    
    private var weightGoalExpandedActions: [ExpandedAction] {
        [
            ExpandedAction("New Goal", icon: "target", accessibilityIdentifier: AccessibilityIdentifiers.morphingNewWeightGoalButton, accessibilityHint: AccessibilityText.healthWeightGoalHistoryAddHint) {
                collapseMorphingTabBar()
                router.presentHealthSheet(.newWeightGoal)
            }
        ]
    }
    
    private var stepsGoalExpandedActions: [ExpandedAction] {
        [
            ExpandedAction("New Goal", icon: "target", accessibilityIdentifier: AccessibilityIdentifiers.morphingNewStepsGoalButton, accessibilityHint: AccessibilityText.healthStepsGoalHistoryAddHint) {
                collapseMorphingTabBar()
                router.presentHealthSheet(.newStepsGoal)
            }
        ]
    }
    
    private func collapseMorphingTabBar() {
        guard isMorphingTabBarExpanded else { return }
        withAnimation(.bouncy(duration: 0.35, extraBounce: 0.02)) {
            isMorphingTabBarExpanded = false
        }
    }

    private var addWeightEntrySheetBinding: Binding<Bool> {
        Binding(
            get: { router.activeHealthSheet == .addWeightEntry },
            set: { isPresented in
                if !isPresented, router.activeHealthSheet == .addWeightEntry {
                    router.activeHealthSheet = nil
                }
            }
        )
    }

    private var newWeightGoalSheetBinding: Binding<Bool> {
        Binding(
            get: { router.activeHealthSheet == .newWeightGoal },
            set: { isPresented in
                if !isPresented, router.activeHealthSheet == .newWeightGoal {
                    router.activeHealthSheet = nil
                }
            }
        )
    }

    private var newStepsGoalSheetBinding: Binding<Bool> {
        Binding(
            get: { router.activeHealthSheet == .newStepsGoal },
            set: { isPresented in
                if !isPresented, router.activeHealthSheet == .newStepsGoal {
                    router.activeHealthSheet = nil
                }
            }
        )
    }
}

#Preview(traits: .sampleData) {
    ContentView()
}
