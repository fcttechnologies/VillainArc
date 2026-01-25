import CoreSpotlight
import SwiftUI
import SwiftData

@main
struct VillainArcApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
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
        guard AppRouter.shared.activeWorkout == nil, AppRouter.shared.activeTemplate == nil else {
            return
        }
        guard let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String else {
            return
        }

        let context = SharedModelContainer.container.mainContext
        if identifier.hasPrefix(SpotlightIndexer.workoutIdentifierPrefix) {
            let idString = String(identifier.dropFirst(SpotlightIndexer.workoutIdentifierPrefix.count))
            guard let id = UUID(uuidString: idString) else { return }
            let predicate = #Predicate<Workout> { $0.id == id }
            var descriptor = FetchDescriptor(predicate: predicate)
            descriptor.fetchLimit = 1
            if let workout = try? context.fetch(descriptor).first {
                AppRouter.shared.popToRoot()
                AppRouter.shared.navigate(to: .workoutDetail(workout))
            }
            return
        }

        if identifier.hasPrefix(SpotlightIndexer.templateIdentifierPrefix) {
            let idString = String(identifier.dropFirst(SpotlightIndexer.templateIdentifierPrefix.count))
            guard let id = UUID(uuidString: idString) else { return }
            let predicate = #Predicate<WorkoutTemplate> { $0.id == id }
            var descriptor = FetchDescriptor(predicate: predicate)
            descriptor.fetchLimit = 1
            if let template = try? context.fetch(descriptor).first {
                AppRouter.shared.popToRoot()
                AppRouter.shared.navigate(to: .templateDetail(template))
            }
        }
    }
}
