import CoreSpotlight
import SwiftUI
import SwiftData

@main
struct VillainArcApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
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
                .onContinueUserActivity("com.villainarc.siri.endWorkout") { userActivity in
                    Task { @MainActor in
                        AppRouter.shared.handleSiriEndWorkout(userActivity)
                    }
                }
        }
        .modelContainer(SharedModelContainer.container)
    }
}
