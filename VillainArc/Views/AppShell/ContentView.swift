import SwiftUI

struct ContentView: View {
    @State private var router = AppRouter.shared
    
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
    }
}

#Preview {
    ContentView()
        .sampleDataContainer()
}
