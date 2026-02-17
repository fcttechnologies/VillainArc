import AppIntents
import CoreSpotlight
import SwiftUI
import SwiftData

@main
struct VillainArcApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
                    .task {
                        VillainArcShortcuts.updateAppShortcutParameters()
                    }
                    .onContinueUserActivity(CSSearchableItemActionType) { userActivity in
                        Task { @MainActor in
                            AppRouter.shared.handleSpotlight(userActivity)
                        }
                    }
                    .onContinueUserActivity("com.villainarc.siri.startWorkout") { userActivity in
                        Task { @MainActor in
                            AppRouter.shared.handleSiriWorkout(userActivity)
                        }
                    }
                    .onContinueUserActivity("com.villainarc.siri.cancelWorkout") { userActivity in
                        Task { @MainActor in
                            AppRouter.shared.handleSiriCancelWorkout(userActivity)
                        }
                    }
                    .onContinueUserActivity("com.villainarc.siri.endWorkout") { _ in }
            } else {
                OnboardingView()
            }
        }
        .modelContainer(SharedModelContainer.container)
    }
}
