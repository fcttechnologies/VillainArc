import SwiftUI

struct ContentView: View {
    @State private var router = AppRouter.shared
    @State private var isMorphingTabBarExpanded = false
    @Namespace private var animation
    
    var body: some View {
        TabView(selection: tabSelectionBinding) {
            HomeTabView(transitionNamespace: animation)
                .tag(AppTab.home)
                .toolbar(.hidden, for: .tabBar)
            
            HealthTabView(transitionNamespace: animation)
                .tag(AppTab.health)
                .toolbar(.hidden, for: .tabBar)
        }
        .safeAreaBar(edge: .bottom) {
            if !router.isQuickActionsBarHidden {
                VStack(spacing: 12) {
                    if router.hasHiddenActiveFlowPresentation {
                        activeFlowResumeBar
                            .padding(.horizontal, 15)
                    }
                    MorphingQuickActionsBar(activeTab: tabSelectionBinding, isExpanded: $isMorphingTabBarExpanded, actions: homeExpandedActions + additionalExpandedActions(for: router.additionalQuickActionContext))
                }
                .matchedTransitionSource(id: TransitionSourceID.toolbar, in: animation)
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
        .fullScreenCover(isPresented: workoutSessionCoverBinding) {
            if let workout = router.activeWorkoutSession {
                WorkoutSessionContainer(workout: workout)
                    .navigationTransition(.zoom(sourceID: TransitionSourceID.toolbar, in: animation))
            }
        }
        .fullScreenCover(isPresented: workoutPlanCoverBinding, onDismiss: {
            guard router.activeWorkoutPlan == nil else { return }
            let cleanup = router.pendingWorkoutPlanDismissCleanup
            router.pendingWorkoutPlanDismissCleanup = nil
            cleanup?()
        }) {
            if let plan = router.activeWorkoutPlan {
                WorkoutPlanView(plan: plan, originalPlan: router.activeWorkoutPlanOriginal)
                    .navigationTransition(.zoom(sourceID: TransitionSourceID.toolbar, in: animation))
            }
        }
        .fullScreenCover(item: $router.activeWeightGoalCompletion) {
            WeightGoalCompletionView(route: $0)
        }
        .fullScreenCover(item: $router.activeGenerationCover) { generationCover in
            GenerationCoverView(route: generationCover)
        }
        .sheet(item: $router.activeAppSheet) { appSheet in
            switch appSheet {
            case .profile:
                ProfileSheetView()
                    .presentationBackground(Color.sheetBg)
            case .settings:
                AppSettingsView()
                    .presentationBackground(Color.sheetBg)
            case .createWorkoutPlan:
                CreateWorkoutPlanView {
                    router.createWorkoutPlan()
                }
            }
        }
        .sheet(isPresented: addWeightEntrySheetBinding) {
            NewWeightEntryView()
                .presentationDetents([.fraction(0.6)])
                .presentationBackground(Color.sheetBg)
        }
        .sheet(isPresented: newWeightGoalSheetBinding) {
            NewWeightGoalView()
                .presentationBackground(Color.sheetBg)
        }
        .sheet(isPresented: newStepsGoalSheetBinding) {
            NewStepsGoalView()
                .presentationDetents([.fraction(0.4)])
                .presentationBackground(Color.sheetBg)
        }
        .sheet(isPresented: newSleepGoalSheetBinding) {
            NewSleepGoalView()
                .presentationDetents([.fraction(0.6)])
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
        case .sleepGoalHistory:
            sleepGoalExpandedActions
        case .stepsGoalHistory:
            stepsGoalExpandedActions
        case nil:
            []
        }
    }
    
    private var homeExpandedActions: [ExpandedAction] {
        var actions: [ExpandedAction] = []

        if !router.hasActiveAuthoringFlow {
            actions.append(
                ExpandedAction("New Workout", icon: "figure.strengthtraining.traditional", accessibilityIdentifier: AccessibilityIdentifiers.morphingStartWorkoutButton, accessibilityHint: AccessibilityText.morphingStartWorkoutHint) {
                    collapseMorphingTabBar()
                    router.startWorkoutSession()
                    Task { await IntentDonations.donateStartWorkout() }
                }
            )

            actions.append(
                ExpandedAction("Create Plan", icon: "list.clipboard", accessibilityIdentifier: AccessibilityIdentifiers.morphingCreatePlanButton, accessibilityHint: AccessibilityText.morphingCreatePlanHint) {
                    collapseMorphingTabBar()
                    router.presentCreateWorkoutPlanSheet()
                    Task { await IntentDonations.donateCreateWorkoutPlan() }
                }
            )
        }

        actions.append(
            ExpandedAction("Add Weight", icon: "scalemass", accessibilityIdentifier: AccessibilityIdentifiers.morphingAddWeightButton, accessibilityHint: AccessibilityText.morphingAddWeightHint) {
                collapseMorphingTabBar()
                router.presentHealthSheet(.addWeightEntry)
            }
        )

        if shouldShowStartTodaysWorkoutAction {
            actions.append(ExpandedAction("Start Today's Workout", icon: "figure.strengthtraining.traditional", accessibilityIdentifier: AccessibilityIdentifiers.morphingStartTodaysWorkoutButton, accessibilityHint: AccessibilityText.morphingStartTodaysWorkoutHint) {
                    collapseMorphingTabBar()
                    if router.startTodaysWorkoutFromExpandedAction() {
                        Task { await IntentDonations.donateStartTodaysWorkout() }
                    }
                })
        }

        return actions
    }

    private var shouldShowStartTodaysWorkoutAction: Bool {
        guard router.canShowStartTodaysWorkoutExpandedAction() else { return false }

        if case let .workoutPlanDetail(plan, _) = router.additionalQuickActionContext,
           router.isTodaysActiveSplitPlan(plan) {
            return false
        }

        return true
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
            actions.append(ExpandedAction("Open Plan", icon: "arrowshape.turn.up.right", accessibilityIdentifier: AccessibilityIdentifiers.morphingOpenWorkoutPlanButton, accessibilityHint: AccessibilityText.workoutDetailOpenWorkoutPlanHint) {
                    collapseMorphingTabBar()
                    router.navigate(to: .workoutPlanDetail(linkedPlan, false))
                    Task { await IntentDonations.donateOpenWorkoutPlan(workoutPlan: linkedPlan) }
                })
        } else {
            actions.append(ExpandedAction("Save as Plan", icon: "list.clipboard", accessibilityIdentifier: AccessibilityIdentifiers.morphingSaveWorkoutPlanButton, accessibilityHint: AccessibilityText.workoutDetailSaveWorkoutPlanHint) {
                    collapseMorphingTabBar()
                    router.createWorkoutPlan(from: workout)
                })
        }

        return actions
    }

    private func workoutPlanExpandedActions(plan: WorkoutPlan, showsUseOnly: Bool) -> [ExpandedAction] {
        guard !router.hasActiveAuthoringFlow else { return [] }

        var actions = [
            ExpandedAction("Use Plan", icon: "figure.strengthtraining.traditional", accessibilityIdentifier: AccessibilityIdentifiers.morphingUsePlanButton, accessibilityHint: AccessibilityText.workoutPlanDetailStartWorkoutHint) {
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
                Task { await IntentDonations.donateCreateWeightGoal() }
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

    private var sleepGoalExpandedActions: [ExpandedAction] {
        [
            ExpandedAction("New Goal", icon: "target", accessibilityIdentifier: AccessibilityIdentifiers.morphingNewSleepGoalButton, accessibilityHint: AccessibilityText.healthSleepGoalHistoryAddHint) {
                collapseMorphingTabBar()
                router.presentHealthSheet(.newSleepGoal)
                Task { await IntentDonations.donateCreateSleepGoal() }
            }
        ]
    }
    
    private func collapseMorphingTabBar() {
        guard isMorphingTabBarExpanded else { return }
        withAnimation(.bouncy(duration: 0.35, extraBounce: 0.02)) {
            isMorphingTabBarExpanded = false
        }
    }

    @ViewBuilder
    private var activeFlowResumeBar: some View {
        if let workout = router.activeWorkoutSession, !router.isWorkoutSessionCoverPresented {
            ActiveWorkoutResumeBarButton(workout: workout, isCollapsed: isMorphingTabBarExpanded) {
                router.presentActiveWorkoutSessionIfPossible()
                Task { await IntentDonations.donateOpenActiveWorkout() }
            }
        } else if let plan = router.activeWorkoutPlan, !router.isWorkoutPlanCoverPresented {
            ActivePlanResumeBarButton(plan: plan, isCollapsed: isMorphingTabBarExpanded) {
                router.presentActiveWorkoutPlanIfPossible()
                Task { await IntentDonations.donateOpenActiveWorkoutPlan() }
            }
        }
    }

    private var workoutSessionCoverBinding: Binding<Bool> {
        Binding(
            get: { router.activeWorkoutSession != nil && router.isWorkoutSessionCoverPresented },
            set: { isPresented in
                if isPresented {
                    router.presentActiveWorkoutSessionIfPossible()
                } else {
                    router.dismissActiveWorkoutSessionPresentation()
                }
            }
        )
    }

    private var workoutPlanCoverBinding: Binding<Bool> {
        Binding(
            get: { router.activeWorkoutPlan != nil && router.isWorkoutPlanCoverPresented },
            set: { isPresented in
                if isPresented {
                    router.presentActiveWorkoutPlanIfPossible()
                } else {
                    router.dismissActiveWorkoutPlanPresentation()
                }
            }
        )
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

    private var newSleepGoalSheetBinding: Binding<Bool> {
        Binding(
            get: { router.activeHealthSheet == .newSleepGoal },
            set: { isPresented in
                if !isPresented, router.activeHealthSheet == .newSleepGoal {
                    router.activeHealthSheet = nil
                }
            }
        )
    }
}

#Preview(traits: .sampleData) {
    ContentView()
}
