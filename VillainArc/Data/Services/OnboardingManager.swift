import SwiftUI
import SwiftData
import CoreData

enum OnboardingState: Equatable {
    case launching
    case checking
    case noWiFi
    case noiCloud
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
@MainActor
class OnboardingManager {
    var state: OnboardingState = .launching
    var profile: UserProfile?
    private var context: ModelContext { SharedModelContainer.container.mainContext }
    private let networkMonitor = NetworkMonitor()
    private var cloudKitObservationTask: Task<Void, Never>?
    private var cloudKitWaiters: [CheckedContinuation<Void, Never>] = []
    private var hasObservedCloudKitImportCompletion = false
    private var networkRetryTask: Task<Void, Never>?

    init() {
        startCloudKitImportObservation()
    }

    func startOnboarding() async {
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

        await waitForCloudKitImportCompletion()
        slowNetworkTask.cancel()

        // Step 5: Seed exercises
        state = .seeding
        do {
            _ = try await DataManager.seedExercisesForOnboarding()
            SpotlightIndexer.reindexAll(context: context)
        } catch {
            state = .error("Failed to set up exercises: \(error.localizedDescription)")
            return
        }

        do {
            _ = try SystemState.ensureAppSettings(context: context)
            let profile = try SystemState.ensureUserProfile(context: context)
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
        do {
            try await Task.sleep(for: .seconds(1.5))
        } catch {
            // Cancelled — proceed immediately
        }
        transitionToReady()
    }

    func profileStepPath() -> [UserProfileOnboardingStep] {
        guard case .profile(let step) = state else {
            return []
        }
        return UserProfileOnboardingStep.navigationPath(to: step)
    }

    private func handleReturningLaunch() async {
        if DataManager.catalogNeedsSync() {
            Task { @MainActor in
                do {
                    let didChange = try await DataManager.seedExercisesIfNeeded()
                    if didChange {
                        SpotlightIndexer.reindexAll(context: context)
                    }
                } catch {
                    print("Background exercise sync failed: \(error)")
                }
            }
        }

        do {
            _ = try SystemState.ensureAppSettings(context: context)
            let profile = try SystemState.ensureUserProfile(context: context)
            routeFromProfile(profile)
        } catch {
            state = .error("Failed to load your profile: \(error.localizedDescription)")
        }
    }

    private func transitionToReady() {
        cloudKitObservationTask?.cancel()
        cloudKitObservationTask = nil
        networkRetryTask?.cancel()
        networkRetryTask = nil
        networkMonitor.stop()
        state = .ready
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
            while case .noWiFi = self.state, !Task.isCancelled {
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    withObservationTracking {
                        _ = self.networkMonitor.isConnected
                    } onChange: {
                        continuation.resume()
                    }
                }
                guard !Task.isCancelled, case .noWiFi = self.state else { break }
                if self.networkMonitor.isConnected {
                    await self.startOnboarding()
                    break
                }
            }
        }
    }

    private func startCloudKitImportObservation() {
        guard cloudKitObservationTask == nil else { return }

        cloudKitObservationTask = Task { @MainActor [weak self] in
            guard let self else { return }

            for await notification in NotificationCenter.default.notifications(named: NSPersistentCloudKitContainer.eventChangedNotification) {
                guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event else { continue }
                guard event.type == .import, event.endDate != nil else { continue }

                if let error = event.error {
                    print("⚠️ CloudKit import completed with error: \(error)")
                } else {
                    print("✅ CloudKit import complete - safe to seed exercises")
                }

                hasObservedCloudKitImportCompletion = true
                resumeCloudKitWaiters()
            }
        }
    }

    private func waitForCloudKitImportCompletion() async {
        if hasObservedCloudKitImportCompletion {
            return
        }

        await withCheckedContinuation { continuation in
            cloudKitWaiters.append(continuation)
        }
    }

    private func resumeCloudKitWaiters() {
        let pendingWaiters = cloudKitWaiters
        cloudKitWaiters.removeAll()
        for waiter in pendingWaiters {
            waiter.resume()
        }
    }
}
