import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var router = AppRouter.shared
    @State private var toastManager = ToastManager.shared
    
    var body: some View {
        TabView(selection: $router.tabSelection) {
            Tab(Tabs.home.title, systemImage: Tabs.home.icon, value: Tabs.home) {
                HomeTabView()
            }

            Tab(Tabs.health.title, systemImage: Tabs.health.icon, value: Tabs.health) {
                HealthTabView()
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
        .background {
            ToastOverlaySceneInstaller()
                .allowsHitTesting(false)
        }
        .task {
            toastManager.canPresentToasts = scenePhase == .active
        }
        .onChange(of: scenePhase, initial: true) { _, newPhase in
            toastManager.canPresentToasts = newPhase == .active
        }
    }
}

#Preview {
    ContentView()
        .sampleDataContainer()
}
