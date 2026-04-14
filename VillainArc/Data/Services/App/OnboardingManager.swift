import HealthKit
import SwiftData
import SwiftUI

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
        case .launching, .ready: return false
        default: return true
        }
    }
}

@Observable class OnboardingManager {
    private static let networkRetryPollInterval: Duration = .milliseconds(500)

    var state: OnboardingState = .launching
    var profile: UserProfile?
    private(set) var shouldInsertHealthPermissionsStep = false
    private(set) var prefetchedBirthday: Date?
    private(set) var prefetchedGender: UserGender?
    private(set) var prefetchedHeightCm: Double?
    private var context: ModelContext { SharedModelContainer.container.mainContext }
    private let networkMonitor = NetworkMonitor()
    private var networkRetryTask: Task<Void, Never>?
    private var onboardingAttemptID = UUID()

    func startOnboarding() async {
        // Start monitoring immediately on first bootstrap so we don't miss an
        // import-complete event before the flow reaches the explicit wait.
        CloudKitImportMonitor.shared.start()
        
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
        case .available: break
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
            if state == .syncing { state = .syncingSlowNetwork }
        }

        let stalledSyncTask = Task {
            try? await Task.sleep(for: .seconds(60))
            guard attemptID == self.onboardingAttemptID else { return }
            guard state == .syncing || state == .syncingSlowNetwork else { return }

            state = .error("Villain Arc couldn't confirm that your iCloud data finished syncing. Please try again.")
        }

        let importStatus = await CloudKitImportMonitor.shared.waitForImportCompletion()
        slowNetworkTask.cancel()
        stalledSyncTask.cancel()
        guard attemptID == onboardingAttemptID else { return }

        switch importStatus {
        case .completed: break
        case .failed(let message):
            state = .error("Unable to finish syncing your iCloud data: \(message)")
            return
        case .idle, .waiting, .importing:
            state = .error("Villain Arc couldn't confirm that your iCloud data finished syncing. Please try again.")
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
            _ = try SystemState.ensureHealthSyncState(context: context)
            let profile = try SystemState.ensureUserProfile(context: context)
            guard attemptID == onboardingAttemptID else { return }
            shouldInsertHealthPermissionsStep = await HealthAuthorizationManager.shouldPromptForCurrentPermissionsVersion()
            routeFromProfile(profile)
        } catch { state = .error("Failed to set up your profile: \(error.localizedDescription)") }
    }

    func retry() async {
        networkRetryTask?.cancel()
        networkRetryTask = nil
        await startOnboarding()
    }

    func continueWithoutiCloud() async {
        // User chose to continue without iCloud
        CloudKitImportMonitor.shared.stop()
        state = .seeding

        do {
            // Seed exercises locally only
            _ = try await DataManager.seedExercisesForOnboarding()
            _ = try SystemState.ensureAppSettings(context: context)
            _ = try SystemState.ensureHealthSyncState(context: context)
            let profile = try SystemState.ensureUserProfile(context: context)
            shouldInsertHealthPermissionsStep = await HealthAuthorizationManager.shouldPromptForCurrentPermissionsVersion()
            routeFromProfile(profile)
        } catch { state = .error("Failed to finish setup: \(error.localizedDescription)") }
    }

    func saveName(_ name: String) async -> Bool {
        guard let profile else { return false }
        profile.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        do { try context.save() } catch {
            state = .error("Failed to save your profile: \(error.localizedDescription)")
            return false
        }
        return true
    }

    func saveBirthday(_ birthday: Date) async -> Bool {
        guard let profile else { return false }
        profile.birthday = birthday
        return await persistProfileAndMaybeFinish(saveFailureMessage: "Failed to save your birthday")
    }

    func saveGender(_ gender: UserGender) async -> Bool {
        guard let profile else { return false }
        profile.gender = gender
        return await persistProfileAndMaybeFinish(saveFailureMessage: "Failed to save your gender")
    }

    func saveHeight(cm: Double) async {
        guard let profile else { return }
        profile.heightCm = cm

        _ = await persistProfileAndMaybeFinish(saveFailureMessage: "Failed to save your height")
    }

    func connectAppleHealthDuringOnboarding() async {
        HealthAuthorizationManager.markCurrentPermissionsVersionHandled()
        _ = await HealthAuthorizationManager.requestAuthorization()
        await prefillProfileFromHealthKit()
    }

    func skipAppleHealthDuringOnboarding() {
        HealthAuthorizationManager.markCurrentPermissionsVersionHandled()
    }

    private func prefillProfileFromHealthKit() async {
        let healthStore = HealthAuthorizationManager.healthStore

        if profile?.birthday == nil { if let components = try? healthStore.dateOfBirthComponents(), let date = Calendar.current.date(from: components) { prefetchedBirthday = date } }

        if profile?.gender == .notSet {
            if let biologicalSex = try? healthStore.biologicalSex().biologicalSex {
                let mappedGender = UserGender(healthKitBiologicalSex: biologicalSex)
                if mappedGender != .notSet { prefetchedGender = mappedGender }
            }
        }

        if profile?.heightCm == nil {
            let heightType = HealthKitCatalog.heightType
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let sample: HKQuantitySample? = await withCheckedContinuation { continuation in
                let query = HKSampleQuery(sampleType: heightType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in continuation.resume(returning: samples?.first as? HKQuantitySample) }
                healthStore.execute(query)
            }
            if let sample { prefetchedHeightCm = sample.quantity.doubleValue(for: HealthKitCatalog.centimeterUnit) }
        }
    }

    private func handleReturningLaunch() async {
        do {
            _ = try SystemState.ensureAppSettings(context: context)
            _ = try SystemState.ensureHealthSyncState(context: context)
            let profile = try SystemState.ensureUserProfile(context: context)
            shouldInsertHealthPermissionsStep = await HealthAuthorizationManager.shouldPromptForCurrentPermissionsVersion()
            if let missingStep = profile.firstMissingStep {
                self.profile = profile
                state = .profile(missingStep)
                return
            }

            self.profile = profile
            await syncCatalogIfNeededBeforeReady()
            await transitionAfterSetup()
        } catch { state = .error("Failed to load your profile: \(error.localizedDescription)") }
    }

    private func transitionToReady() {
        CloudKitImportMonitor.shared.stop()
        networkRetryTask?.cancel()
        networkRetryTask = nil
        networkMonitor.stop()
        state = .ready
    }

    private func syncCatalogIfNeededBeforeReady() async {
        guard DataManager.catalogNeedsSync() else { return }

        do {
            let didChange = try await DataManager.seedExercisesIfNeeded()
            if didChange { SpotlightIndexer.reindexAll(context: context) }
        } catch { print("Returning-launch exercise sync failed: \(error)") }
    }

    private func routeFromProfile(_ profile: UserProfile) {
        self.profile = profile
        if let missingStep = profile.firstMissingStep {
            state = .profile(missingStep)
        } else {
            Task { await transitionAfterSetup() }
        }
    }

    private func persistProfileAndMaybeFinish(saveFailureMessage: String) async -> Bool {
        do { try context.save() } catch {
            state = .error("\(saveFailureMessage): \(error.localizedDescription)")
            return false
        }

        guard profile?.firstMissingStep == nil else { return true }

        state = .finishing
        await syncCatalogIfNeededBeforeReady()
        await transitionAfterSetup()
        return true
    }

    private func startNetworkMonitoring() {
        networkRetryTask?.cancel()
        networkRetryTask = Task { [weak self] in
            guard let self else { return }
            while case .noWiFi = self.state {
                if Task.isCancelled { return }

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

    private func transitionAfterSetup() async {
        if await HealthAuthorizationManager.shouldPromptForCurrentPermissionsVersion() {
            state = .healthPermissions
        } else {
            transitionToReady()
        }
    }

    func connectAppleHealth() async {
        HealthAuthorizationManager.markCurrentPermissionsVersionHandled()
        _ = await HealthAuthorizationManager.requestAuthorization()
        transitionToReady()
    }

    func skipAppleHealth() {
        HealthAuthorizationManager.markCurrentPermissionsVersionHandled()
        transitionToReady()
    }

}

extension UserGender {
    fileprivate init(healthKitBiologicalSex: HKBiologicalSex) {
        switch healthKitBiologicalSex {
        case .male: self = .male
        case .female: self = .female
        case .other: self = .other
        case .notSet: self = .notSet
        @unknown default: self = .notSet
        }
    }
}
