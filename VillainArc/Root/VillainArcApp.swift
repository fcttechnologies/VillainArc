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
        }
        .modelContainer(SharedModelContainer.container)
    }
}
