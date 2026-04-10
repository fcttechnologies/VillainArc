import HealthKit
import SwiftUI
import SwiftData
import WatchKit

final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        Task { @MainActor in
            await WatchWorkoutRuntimeCoordinator.shared.handleWorkoutLaunchRequest(workoutConfiguration)
        }
    }
}

@main
struct VillainArcWatch_Watch_AppApp: App {
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(WatchSharedModelContainer.container)
    }
}
