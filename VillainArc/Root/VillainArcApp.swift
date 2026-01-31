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
                        handleSpotlight(userActivity)
                    }
                }
        }
        .modelContainer(SharedModelContainer.container)
    }

    @MainActor
    private func handleSpotlight(_ userActivity: NSUserActivity) {
        guard AppRouter.shared.activeWorkoutSession == nil, AppRouter.shared.activeWorkoutPlan == nil else {
            return
        }
        guard let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String else {
            return
        }

        let context = SharedModelContainer.container.mainContext
        if identifier.hasPrefix(SpotlightIndexer.workoutSessionIdentifierPrefix) {
            let idString = String(identifier.dropFirst(SpotlightIndexer.workoutSessionIdentifierPrefix.count))
            guard let id = UUID(uuidString: idString) else { return }
            let predicate = #Predicate<WorkoutSession> { $0.id == id }
            var descriptor = FetchDescriptor(predicate: predicate)
            descriptor.fetchLimit = 1
            if let workoutSession = try? context.fetch(descriptor).first {
                AppRouter.shared.popToRoot()
                AppRouter.shared.navigate(to: .workoutSessionDetail(workoutSession))
            }
            return
        }

        if identifier.hasPrefix(SpotlightIndexer.workoutPlanIdentifierPrefix) {
            let idString = String(identifier.dropFirst(SpotlightIndexer.workoutPlanIdentifierPrefix.count))
            guard let id = UUID(uuidString: idString) else { return }
            let predicate = #Predicate<WorkoutPlan> { $0.id == id }
            var descriptor = FetchDescriptor(predicate: predicate)
            descriptor.fetchLimit = 1
            if let workoutPlan = try? context.fetch(descriptor).first {
                AppRouter.shared.popToRoot()
                AppRouter.shared.navigate(to: .workoutPlanDetail(workoutPlan))
            }
        }
    }
}
