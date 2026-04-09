import SwiftUI

struct ContentView: View {
    @State private var router = AppRouter.shared
    @State private var isMorphingTabBarExpanded = false
    @State private var cachedTabViews: [AppTab: AnyView] = Self.makeCachedTabViews()
    
    var body: some View {
        activeTabContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaBar(edge: .bottom) {
                HStack(alignment: .bottom, spacing: 12) {
                    MorphingTabBar(activeTab: tabSelectionBinding, isExpanded: $isMorphingTabBarExpanded) {
                        ExpandedContent(actions: expandedActions)
                    }
                    
                    Button {
                        toggleMorphingTabBar()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 19, weight: .medium))
                            .rotationEffect(.degrees(isMorphingTabBarExpanded ? 45 : 0))
                            .frame(width: 52, height: 52)
                            .foregroundStyle(Color.primary)
                            .contentShape(.circle)
                    }
                    .buttonStyle(PlainGlassButtonEffect(shape: .circle))
                    .contentShape(.circle)
                    .accessibilityLabel(isMorphingTabBarExpanded ? AccessibilityText.morphingCollapseToolbarLabel : AccessibilityText.morphingExpandToolbarLabel)
                    .accessibilityHint(AccessibilityText.morphingToolbarHint)
                    .accessibilityIdentifier(AccessibilityIdentifiers.morphingToolbarToggleButton)
                }
                .padding(.horizontal, 20)
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
    
    private var activeTabContent: AnyView {
        switch router.tabSelection {
        case .home: return cachedTabViews[.home] ?? AnyView(Color.clear)
        case .health: return cachedTabViews[.health] ?? AnyView(Color.clear)
        }
    }
    
    private var tabSelectionBinding: Binding<AppTab> {
        Binding(get: { router.tabSelection }, set: { router.selectTab($0) })
    }
    
    private var expandedActions: [ExpandedAction] {
        switch router.quickActionContext {
        case .home:
            homeExpandedActions
        case .workoutSplit:
            homeExpandedActions + workoutSplitExpandedActions
        }
    }

    private var homeExpandedActions: [ExpandedAction] {
        [
            ExpandedAction(
                title: "New Workout",
                icon: "figure.strengthtraining.traditional",
                accessibilityIdentifier: AccessibilityIdentifiers.morphingStartWorkoutButton,
                accessibilityHint: AccessibilityText.morphingStartWorkoutHint
            ) {
                collapseMorphingTabBar()
                router.startWorkoutSession()
                Task { await IntentDonations.donateStartWorkout() }
            },
            ExpandedAction(
                title: "Create Plan",
                icon: "list.clipboard",
                accessibilityIdentifier: AccessibilityIdentifiers.morphingCreatePlanButton,
                accessibilityHint: AccessibilityText.morphingCreatePlanHint
            ) {
                collapseMorphingTabBar()
                router.createWorkoutPlan()
                Task { await IntentDonations.donateCreateWorkoutPlan() }
            },
            ExpandedAction(
                title: "Add Weight",
                icon: "scalemass",
                accessibilityIdentifier: AccessibilityIdentifiers.morphingAddWeightButton,
                accessibilityHint: AccessibilityText.morphingAddWeightHint
            ) {
                collapseMorphingTabBar()
                router.tabSelection = .health
                router.activeHealthSheet = .addWeightEntry
            }
        ]
    }

    private var workoutSplitExpandedActions: [ExpandedAction] {
        [
            ExpandedAction(
                title: "New Split",
                icon: "plus.rectangle.on.folder",
                accessibilityIdentifier: AccessibilityIdentifiers.workoutSplitCreateButton,
                accessibilityHint: AccessibilityText.workoutSplitCreateHint
            ) {
                collapseMorphingTabBar()
                router.activeSplitSheet = .builder
                Task { await IntentDonations.donateCreateWorkoutSplit() }
            }
        ]
    }
    
    private static func makeCachedTabViews() -> [AppTab: AnyView] {
        [.home: AnyView(HomeTabView()), .health: AnyView(HealthTabView())]
    }
    
    private func toggleMorphingTabBar() {
        withAnimation(.bouncy(duration: 0.5, extraBounce: 0.05)) {
            isMorphingTabBarExpanded.toggle()
        }
    }
    
    private func collapseMorphingTabBar() {
        guard isMorphingTabBarExpanded else { return }
        withAnimation(.bouncy(duration: 0.35, extraBounce: 0.02)) {
            isMorphingTabBarExpanded = false
        }
    }
}

struct ExpandedAction: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let accessibilityIdentifier: String
    let accessibilityHint: String
    let action: () -> Void
}

struct ExpandedContent: View {
    let actions: [ExpandedAction]
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(spacing: 10), count: 4), spacing: 10) {
            ForEach(actions) { action in
                VStack(spacing: 6) {
                    Button {
                        Haptics.selection()
                        action.action()
                    } label: {
                        Image(systemName: action.icon)
                            .font(.title3)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .foregroundStyle(Color.primary)
                            .background(.gray.opacity(0.09), in: .rect(cornerRadius: 16))
                    }
                    .buttonStyle(PlainGlassButtonEffect(shape: .rect(cornerRadius: 16)))
                    .accessibilityLabel(action.title)
                    .accessibilityHint(action.accessibilityHint)
                    .accessibilityIdentifier(action.accessibilityIdentifier)
                    
                    Text(action.title)
                        .font(.system(size: 9))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fontWeight(.semibold)
                        .accessibilityHidden(true)
                }
            }
        }
        .padding(10)
    }
}

#Preview(traits: .sampleData) {
    ContentView()
}
