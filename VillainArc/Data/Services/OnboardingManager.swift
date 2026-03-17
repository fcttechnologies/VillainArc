import SwiftUI
import SwiftData

enum OnboardingState: Equatable {
    case launching
    case checking
    case noWiFi
    case noiCloud
    case cloudKitAccountIssue
    case cloudKitUnavailable
    case syncing
    case syncingSlowNetwork
    case seeding
    case profile(UserProfileOnboardingStep)
    case finishing
    case ready
    case error(String)

    var shouldPresentSheet: Bool {
        switch self {
        case .launching, .ready:
            return false
        default:
            return true
        }
    }
}

@Observable
class OnboardingManager {
    private static let networkRetryPollInterval: Duration = .milliseconds(500)

    var state: OnboardingState = .launching
    var profile: UserProfile?
    private var context: ModelContext { SharedModelContainer.container.mainContext }
    private let networkMonitor = NetworkMonitor()
    private var networkRetryTask: Task<Void, Never>?
    private var onboardingAttemptID = UUID()

    func startOnboarding() async {
        let attemptID = UUID()
        onboardingAttemptID = attemptID

        if DataManager.hasCompletedInitialBootstrap() {
            await handleReturningLaunch()
            return
        }

        state = .checking

        // Step 1: Check network
        guard await NetworkMonitor.checkConnectivity() else {
            state = .noWiFi
            startNetworkMonitoring()
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
        guard attemptID == onboardingAttemptID else { return }

        switch cloudKitStatus {
        case .available:
            break
        case .accountIssue:
            state = .cloudKitAccountIssue
            return
        case .unavailable:
            state = .cloudKitUnavailable
            return
        }

        // Step 4: Sync from CloudKit (if any data exists)
        state = .syncing
        CloudKitImportMonitor.shared.prepareForBootstrapWait()

        // Show "slow network" message if taking > 15 seconds
        let slowNetworkTask = Task {
            try? await Task.sleep(for: .seconds(15))
            guard attemptID == self.onboardingAttemptID else { return }
            if state == .syncing {
                state = .syncingSlowNetwork
            }
        }

        let stalledSyncTask = Task {
            try? await Task.sleep(for: .seconds(60))
            guard attemptID == self.onboardingAttemptID else { return }
            guard state == .syncing || state == .syncingSlowNetwork else { return }

            state = .error(
                "VillainArc couldn't confirm that your iCloud data finished syncing. Please try again."
            )
        }

        let importStatus = await CloudKitImportMonitor.shared.waitForImportCompletion()
        slowNetworkTask.cancel()
        stalledSyncTask.cancel()
        guard attemptID == onboardingAttemptID else { return }

        switch importStatus {
        case .completed:
            break
        case .failed(let message):
            state = .error("Unable to finish syncing your iCloud data: \(message)")
            return
        case .idle, .waiting, .importing:
            state = .error("VillainArc couldn't confirm that your iCloud data finished syncing. Please try again.")
            return
        }

        guard state == .syncing || state == .syncingSlowNetwork else { return }

        // Step 5: Seed exercises
        state = .seeding
        do {
            _ = try await DataManager.seedExercisesForOnboarding()
            SpotlightIndexer.reindexAll(context: context)
        } catch {
            guard attemptID == onboardingAttemptID else { return }
            state = .error("Failed to set up exercises: \(error.localizedDescription)")
            return
        }

        do {
            _ = try SystemState.ensureAppSettings(context: context)
            let profile = try SystemState.ensureUserProfile(context: context)
            guard attemptID == onboardingAttemptID else { return }
            routeFromProfile(profile)
        } catch {
            state = .error("Failed to set up your profile: \(error.localizedDescription)")
        }
    }

    func retry() async {
        networkRetryTask?.cancel()
        networkRetryTask = nil
        await startOnboarding()
    }

    func continueWithoutiCloud() async {
        // User chose to continue without iCloud
        state = .seeding

        do {
            // Seed exercises locally only
            _ = try await DataManager.seedExercisesForOnboarding()
            SpotlightIndexer.reindexAll(context: context)
            _ = try SystemState.ensureAppSettings(context: context)
            let profile = try SystemState.ensureUserProfile(context: context)
            routeFromProfile(profile)
        } catch {
            state = .error("Failed to finish setup: \(error.localizedDescription)")
        }
    }

    func saveName(_ name: String) async -> Bool {
        guard let profile else { return false }
        profile.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return await persistProfileAndAdvance()
    }

    func saveBirthday(_ birthday: Date) async -> Bool {
        guard let profile else { return false }
        profile.birthday = birthday
        return await persistProfileAndAdvance()
    }

    func saveHeight(cm: Double) async {
        guard let profile else { return }
        profile.heightCm = cm

        do {
            try context.save()
        } catch {
            state = .error("Failed to save your height: \(error.localizedDescription)")
            return
        }

        if let nextStep = profile.firstMissingStep {
            state = .profile(nextStep)
            return
        }

        state = .finishing
        await syncCatalogIfNeededBeforeReady()
        transitionToReady()
    }

    func profileStepPath() -> [UserProfileOnboardingStep] {
        guard case .profile(let step) = state else {
            return []
        }
        return UserProfileOnboardingStep.navigationPath(to: step)
    }

    private func handleReturningLaunch() async {
        do {
            _ = try SystemState.ensureAppSettings(context: context)
            let profile = try SystemState.ensureUserProfile(context: context)
            if let missingStep = profile.firstMissingStep {
                self.profile = profile
                state = .profile(missingStep)
                return
            }

            self.profile = profile
            await syncCatalogIfNeededBeforeReady()
            transitionToReady()
        } catch {
            state = .error("Failed to load your profile: \(error.localizedDescription)")
        }
    }

    private func transitionToReady() {
        networkRetryTask?.cancel()
        networkRetryTask = nil
        networkMonitor.stop()
        state = .ready
    }

    private func syncCatalogIfNeededBeforeReady() async {
        guard DataManager.catalogNeedsSync() else { return }

        do {
            let didChange = try await DataManager.seedExercisesIfNeeded()
            if didChange {
                SpotlightIndexer.reindexAll(context: context)
            }
        } catch {
            print("Returning-launch exercise sync failed: \(error)")
        }
    }

    private func routeFromProfile(_ profile: UserProfile) {
        self.profile = profile
        if let missingStep = profile.firstMissingStep {
            state = .profile(missingStep)
        } else {
            transitionToReady()
        }
    }

    private func persistProfileAndAdvance() async -> Bool {
        do {
            try context.save()
        } catch {
            state = .error("Failed to save your profile: \(error.localizedDescription)")
            return false
        }

        guard let profile else { return false }
        routeFromProfile(profile)
        return true
    }

    private func startNetworkMonitoring() {
        networkRetryTask?.cancel()
        networkRetryTask = Task { [weak self] in
            guard let self else { return }
            while case .noWiFi = self.state {
                if Task.isCancelled {
                    return
                }

                if self.networkMonitor.isConnected {
                    await self.startOnboarding()
                    return
                }

                do {
                    try await Task.sleep(for: Self.networkRetryPollInterval)
                } catch {
                    return
                }
            }
        }
    }
}
