import SwiftUI
import SwiftData

enum OnboardingState: Equatable {
    case checking
    case noWiFi
    case noiCloud
    case cloudKitUnavailable
    case syncing
    case syncingSlowNetwork  // Taking longer than expected
    case seeding
    case ready
    case error(String)
}

@Observable
@MainActor
class OnboardingManager {
    var state: OnboardingState = .checking
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func startOnboarding() async {
        state = .checking

        // Step 1: Check WiFi
        let networkMonitor = NetworkMonitor()
        try? await Task.sleep(for: .milliseconds(500)) // Give monitor time to update

        guard networkMonitor.isConnected else {
            state = .noWiFi
            return
        }

        // Step 2: Check iCloud
        let iCloudStatus = CloudKitStatusChecker.checkiCloudStatus()
        if iCloudStatus == .disabled {
            state = .noiCloud
            // User can choose to continue without iCloud
            return
        }

        // Step 3: Check CloudKit availability
        let cloudKitStatus = await CloudKitStatusChecker.checkCloudKitAvailability()
        guard cloudKitStatus == .available else {
            state = .cloudKitUnavailable
            return
        }

        // Step 4: Sync from CloudKit (if any data exists)
        state = .syncing

        // Show "slow network" message if taking > 15 seconds
        let slowNetworkTask = Task {
            try? await Task.sleep(for: .seconds(15))
            if state == .syncing {
                state = .syncingSlowNetwork
            }
        }

        do {
            try await DataManager.waitForCloudKitImportPublic()
            slowNetworkTask.cancel()
        } catch {
            slowNetworkTask.cancel()
            state = .error("Failed to sync: \(error.localizedDescription)")
            return
        }

        // Step 5: Seed exercises
        state = .seeding
        do {
            try await DataManager.seedExercisesForOnboarding(context: modelContext)
        } catch {
            state = .error("Failed to set up exercises: \(error.localizedDescription)")
            return
        }

        // Step 6: Complete
        state = .ready
    }

    func retry() async {
        await startOnboarding()
    }

    func continueWithoutiCloud() async {
        // User chose to continue without iCloud
        state = .seeding

        do {
            // Seed exercises locally only
            try await DataManager.seedExercisesForOnboarding(context: modelContext)
            state = .ready
        } catch {
            state = .error("Failed to set up exercises: \(error.localizedDescription)")
        }
    }
}
