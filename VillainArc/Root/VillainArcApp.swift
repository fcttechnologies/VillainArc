import AppIntents
import CoreSpotlight
import SwiftUI
import SwiftData

@main
struct VillainArcApp: App {
    var body: some Scene {
        WindowGroup {
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
                .onContinueUserActivity("com.villainarc.siri.endWorkout") { _ in
                    // Just opens the app — user finishes via normal UI
                }
        }
        .modelContainer(SharedModelContainer.container)
    }
}
