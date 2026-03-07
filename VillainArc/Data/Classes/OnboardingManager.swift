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
    case syncingSlowNetwork  // Taking longer than expected
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
    private let modelContext: ModelContext
    private var cloudKitObservationTask: Task<Void, Never>?
    private var cloudKitWaiters: [CheckedContinuation<Void, Never>] = []
    private var hasObservedCloudKitImportCompletion = false

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        startCloudKitImportObservation()
    }

    func startOnboarding() async {
        if DataManager.hasCompletedInitialBootstrap() {
            await handleReturningLaunch()
            return
        }

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

        await waitForCloudKitImportCompletion()
        slowNetworkTask.cancel()

        // Step 5: Seed exercises
        state = .seeding
        do {
            let didChange = try await DataManager.seedExercisesForOnboarding(context: modelContext)
            if didChange {
                SpotlightIndexer.reindexAll(context: modelContext)
            }
        } catch {
            state = .error("Failed to set up exercises: \(error.localizedDescription)")
            return
        }

        do {
            let profile = try ensureProfile()
            routeFromProfile(profile)
        } catch {
            state = .error("Failed to set up your profile: \(error.localizedDescription)")
        }
    }

    func retry() async {
        await startOnboarding()
    }

    func continueWithoutiCloud() async {
        // User chose to continue without iCloud
        state = .seeding

        do {
            // Seed exercises locally only
            let didChange = try await DataManager.seedExercisesForOnboarding(context: modelContext)
            if didChange {
                SpotlightIndexer.reindexAll(context: modelContext)
            }
            let profile = try ensureProfile()
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

    func saveHeight(feet: Int, inches: Double) async {
        guard let profile else { return }
        profile.heightFeet = feet
        profile.heightInches = inches

        do {
            try saveContextOrThrow(context: modelContext)
        } catch {
            state = .error("Failed to save your height: \(error.localizedDescription)")
            return
        }

        if let nextStep = profile.firstMissingStep {
            state = .profile(nextStep)
            return
        }

        state = .finishing
        try? await Task.sleep(for: .seconds(1.5))
        state = .ready
    }

    func profileStepPath() -> [UserProfileOnboardingStep] {
        guard case .profile(let step) = state else {
            return []
        }
        return UserProfileOnboardingStep.navigationPath(to: step)
    }

    private func handleReturningLaunch() async {
        if DataManager.catalogNeedsSync() {
            Task { @MainActor [weak self] in
                guard let self else { return }
                do {
                    let didChange = try await DataManager.seedExercisesIfNeeded(context: self.modelContext)
                    if didChange {
                        SpotlightIndexer.reindexAll(context: self.modelContext)
                    }
                } catch {
                    print("Background exercise sync failed: \(error)")
                }
            }
        }

        do {
            let profile = try ensureProfile()
            routeFromProfile(profile)
        } catch {
            state = .error("Failed to load your profile: \(error.localizedDescription)")
        }
    }

    private func ensureProfile() throws -> UserProfile {
        if let existing = try fetchProfiles().first {
            profile = existing
            return existing
        }

        let newProfile = UserProfile()
        modelContext.insert(newProfile)
        try saveContextOrThrow(context: modelContext)
        profile = newProfile
        return newProfile
    }

    private func fetchProfiles() throws -> [UserProfile] {
        var descriptor = UserProfile.all
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor)
    }

    private func routeFromProfile(_ profile: UserProfile) {
        self.profile = profile
        if let missingStep = profile.firstMissingStep {
            state = .profile(missingStep)
        } else {
            state = .ready
        }
    }

    private func persistProfileAndAdvance() async -> Bool {
        do {
            try saveContextOrThrow(context: modelContext)
        } catch {
            state = .error("Failed to save your profile: \(error.localizedDescription)")
            return false
        }

        guard let profile else { return false }
        routeFromProfile(profile)
        return true
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
        startCloudKitImportObservation()

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
