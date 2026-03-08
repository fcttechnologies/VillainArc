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
                    cleanupEditingWorkoutPlanCopies()
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
        }
        .modelContainer(SharedModelContainer.container)
    }

    @MainActor
    private func cleanupEditingWorkoutPlanCopies() {
        let context = ModelContext(SharedModelContainer.container)
        let editingCopies = (try? context.fetch(WorkoutPlan.editingCopies)) ?? []
        guard !editingCopies.isEmpty else { return }
        for copy in editingCopies {
            context.delete(copy)
        }
        saveContext(context: context)
    }
}
