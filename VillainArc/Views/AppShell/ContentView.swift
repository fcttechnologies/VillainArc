import SwiftUI

struct ContentView: View {
    @State private var router = AppRouter.shared
    
    var body: some View {
        TabView(selection: $router.tabSelection) {
            Tab(AppTab.home.title, systemImage: AppTab.home.symbolImage, value: AppTab.home) {
                HomeTabView()
            }

            Tab(AppTab.health.title, systemImage: AppTab.health.symbolImage, value: AppTab.health) {
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

#Preview(traits: .sampleData) {
    ContentView()
}
