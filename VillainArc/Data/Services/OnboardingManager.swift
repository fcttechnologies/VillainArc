import SwiftUI
import SwiftData
import HealthKit

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
    case healthPermissions
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
    private(set) var isNewUser = false
    private(set) var prefetchedBirthday: Date?
    private(set) var prefetchedHeightCm: Double?
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
            isNewUser = true
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
            _ = try SystemState.ensureAppSettings(context: context)
            let profile = try SystemState.ensureUserProfile(context: context)
            isNewUser = true
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
        await transitionAfterSetup()
    }

    func connectAppleHealthDuringOnboarding() async {
        _ = await HealthAuthorizationManager.shared.requestAuthorization()
        await prefillProfileFromHealthKit()
    }

    private func prefillProfileFromHealthKit() async {
        let healthStore = HealthAuthorizationManager.shared.healthStore

        if profile?.birthday == nil {
            if let components = try? healthStore.dateOfBirthComponents(),
               let date = Calendar.current.date(from: components) {
                prefetchedBirthday = date
            }
        }

        if profile?.heightCm == nil {
            let heightType = HKQuantityType(.height)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let sample: HKQuantitySample? = await withCheckedContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: heightType,
                    predicate: nil,
                    limit: 1,
                    sortDescriptors: [sortDescriptor]
                ) { _, samples, _ in
                    continuation.resume(returning: samples?.first as? HKQuantitySample)
                }
                healthStore.execute(query)
            }
            if let sample {
                prefetchedHeightCm = sample.quantity.doubleValue(for: .meterUnit(with: .centi))
            }
        }
    }

    private func handleReturningLaunch() async {
        isNewUser = false
        do {
            _ = try SystemState.ensureAppSettings(context: context)
            let profile = try SystemState.ensureUserProfile(context: context)
            if let missingStep = profile.firstMissingStep {
                self.profile = profile
                let action = await HealthAuthorizationManager.shared.authorizationAction()
                if action == .requestAccess {
                    isNewUser = true
                }
                state = .profile(missingStep)
                return
            }

            self.profile = profile
            await syncCatalogIfNeededBeforeReady()
            await transitionAfterSetup()
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
            Task {
                await transitionAfterSetup()
            }
        }
    }

    private func persistProfileAndAdvance() async -> Bool {
        do {
            try context.save()
        } catch {
            state = .error("Failed to save your profile: \(error.localizedDescription)")
            return false
        }
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

    private func shouldOfferHealthPermissions() async -> Bool {
        let action = await HealthAuthorizationManager.shared.authorizationAction()
        return action == .requestAccess
    }

    private func transitionAfterSetup() async {
        if await shouldOfferHealthPermissions() {
            state = .healthPermissions
        } else {
            transitionToReady()
        }
    }

    func connectAppleHealth() async {
        _ = await HealthAuthorizationManager.shared.requestAuthorization()
        transitionToReady()
    }

}
