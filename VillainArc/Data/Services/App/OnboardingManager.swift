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

private struct BootstrapSyncProgressSnapshot: Equatable {
    let userProfiles: Int
    let appSettings: Int
    let healthSyncStates: Int
    let exercises: Int
    let exerciseHistories: Int
    let workoutSessions: Int
    let exercisePerformances: Int
    let setPerformances: Int
    let workoutPlans: Int
    let exercisePrescriptions: Int
    let setPrescriptions: Int
    let workoutSplits: Int
    let workoutSplitDays: Int
    let trainingGoals: Int
    let trainingConditionPeriods: Int
    let weightEntries: Int
    let weightGoals: Int
    let stepsGoals: Int
    let sleepGoals: Int
    let healthWorkouts: Int
    let healthSleepNights: Int
    let healthSleepBlocks: Int
    let healthStepsDistances: Int
    let healthEnergyRecords: Int
    let suggestionEvents: Int
    let restTimeHistories: Int
}

@Observable class OnboardingManager {
    private static let networkRetryPollInterval: Duration = .milliseconds(500)
    private static let bootstrapSyncPollInterval: Duration = .seconds(15)
    private static let bootstrapSyncMinimumWait: TimeInterval = 120
    private static let bootstrapSyncIdleGracePeriod: TimeInterval = 90
    private static let bootstrapSyncMaximumWait: TimeInterval = 480
    private static let bootstrapSyncTimeoutMessage = "Villain Arc couldn't confirm that your iCloud data finished syncing. Please try again."

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

    var nextRequiredStep: UserProfileOnboardingStep? {
        if let profile, let missingStep = profile.firstMissingStep {
            return missingStep
        }

        if (try? context.fetch(TrainingGoal.active).first) == nil {
            return .trainingGoal
        }

        return nil
    }

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

        let stalledSyncTask = startBootstrapSyncStallWatcher(attemptID: attemptID)

        let importStatus = await CloudKitImportMonitor.shared.waitForImportCompletion()
        stalledSyncTask.cancel()
        guard attemptID == onboardingAttemptID else { return }

        switch importStatus {
        case .completed: break
        case .failed(let message):
            state = .error(message == Self.bootstrapSyncTimeoutMessage ? message : "Unable to finish syncing your iCloud data: \(message)")
            return
        case .idle, .waiting, .importing:
            state = .error(Self.bootstrapSyncTimeoutMessage)
            return
        }

        guard state == .syncing else { return }

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

    func saveHeight(cm: Double) async -> Bool {
        guard let profile else { return false }
        profile.heightCm = cm

        return await persistProfileAndMaybeFinish(saveFailureMessage: "Failed to save your height")
    }

    func saveFitnessLevel(_ fitnessLevel: FitnessLevel) async -> Bool {
        guard let profile else { return false }
        profile.fitnessLevel = fitnessLevel
        profile.fitnessLevelSetAt = .now
        return await persistProfileAndMaybeFinish(saveFailureMessage: "Failed to save your fitness level")
    }

    func saveTrainingGoal(_ kind: TrainingGoalKind) async -> Bool {
        do {
            _ = try TrainingGoal.replaceActiveGoal(with: kind, context: context)
            return await persistProfileAndMaybeFinish(saveFailureMessage: "Failed to save your training goal")
        } catch {
            state = .error("Failed to save your training goal: \(error.localizedDescription)")
            return false
        }
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
            self.profile = profile
            if let missingStep = nextRequiredStep {
                state = .profile(missingStep)
                return
            }

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
        if let missingStep = nextRequiredStep {
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

        guard nextRequiredStep == nil else { return true }

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

    private func startBootstrapSyncStallWatcher(attemptID: UUID) -> Task<Void, Never> {
        Task { [weak self] in
            guard let self else { return }

            let startedAt = Date()
            var lastProgressAt = startedAt
            var lastSnapshot = bootstrapSyncProgressSnapshot()

            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: Self.bootstrapSyncPollInterval)
                } catch {
                    return
                }

                guard attemptID == onboardingAttemptID else { return }
                guard state == .syncing else { return }

                let now = Date()
                let snapshot = bootstrapSyncProgressSnapshot()
                if let snapshot, snapshot != lastSnapshot {
                    lastSnapshot = snapshot
                    lastProgressAt = now
                }

                let elapsed = now.timeIntervalSince(startedAt)
                guard elapsed >= Self.bootstrapSyncMinimumWait else { continue }

                if elapsed >= Self.bootstrapSyncMaximumWait {
                    CloudKitImportMonitor.shared.failCurrentWait(message: Self.bootstrapSyncTimeoutMessage)
                    return
                }

                let importStatus = CloudKitImportMonitor.shared.status
                guard importStatus != .importing else { continue }

                if now.timeIntervalSince(lastProgressAt) >= Self.bootstrapSyncIdleGracePeriod {
                    CloudKitImportMonitor.shared.failCurrentWait(message: Self.bootstrapSyncTimeoutMessage)
                    return
                }
            }
        }
    }

    private func bootstrapSyncProgressSnapshot() -> BootstrapSyncProgressSnapshot? {
        do {
            return BootstrapSyncProgressSnapshot(
                userProfiles: try context.fetchCount(FetchDescriptor<UserProfile>()),
                appSettings: try context.fetchCount(FetchDescriptor<AppSettings>()),
                healthSyncStates: try context.fetchCount(FetchDescriptor<HealthSyncState>()),
                exercises: try context.fetchCount(FetchDescriptor<Exercise>()),
                exerciseHistories: try context.fetchCount(FetchDescriptor<ExerciseHistory>()),
                workoutSessions: try context.fetchCount(FetchDescriptor<WorkoutSession>()),
                exercisePerformances: try context.fetchCount(FetchDescriptor<ExercisePerformance>()),
                setPerformances: try context.fetchCount(FetchDescriptor<SetPerformance>()),
                workoutPlans: try context.fetchCount(FetchDescriptor<WorkoutPlan>()),
                exercisePrescriptions: try context.fetchCount(FetchDescriptor<ExercisePrescription>()),
                setPrescriptions: try context.fetchCount(FetchDescriptor<SetPrescription>()),
                workoutSplits: try context.fetchCount(FetchDescriptor<WorkoutSplit>()),
                workoutSplitDays: try context.fetchCount(FetchDescriptor<WorkoutSplitDay>()),
                trainingGoals: try context.fetchCount(FetchDescriptor<TrainingGoal>()),
                trainingConditionPeriods: try context.fetchCount(FetchDescriptor<TrainingConditionPeriod>()),
                weightEntries: try context.fetchCount(FetchDescriptor<WeightEntry>()),
                weightGoals: try context.fetchCount(FetchDescriptor<WeightGoal>()),
                stepsGoals: try context.fetchCount(FetchDescriptor<StepsGoal>()),
                sleepGoals: try context.fetchCount(FetchDescriptor<SleepGoal>()),
                healthWorkouts: try context.fetchCount(FetchDescriptor<HealthWorkout>()),
                healthSleepNights: try context.fetchCount(FetchDescriptor<HealthSleepNight>()),
                healthSleepBlocks: try context.fetchCount(FetchDescriptor<HealthSleepBlock>()),
                healthStepsDistances: try context.fetchCount(FetchDescriptor<HealthStepsDistance>()),
                healthEnergyRecords: try context.fetchCount(FetchDescriptor<HealthEnergy>()),
                suggestionEvents: try context.fetchCount(FetchDescriptor<SuggestionEvent>()),
                restTimeHistories: try context.fetchCount(FetchDescriptor<RestTimeHistory>())
            )
        } catch {
            print("Unable to inspect bootstrap sync progress: \(error)")
            return nil
        }
    }

    private func transitionAfterSetup() async {
        if let missingStep = nextRequiredStep {
            state = .profile(missingStep)
        } else if await HealthAuthorizationManager.shouldPromptForCurrentPermissionsVersion() {
            state = .healthPermissions
        } else {
            transitionToReady()
        }
    }

    func connectAppleHealth() async {
        HealthAuthorizationManager.markCurrentPermissionsVersionHandled()
        _ = await HealthAuthorizationManager.requestAuthorization()
        if let missingStep = nextRequiredStep {
            state = .profile(missingStep)
        } else {
            transitionToReady()
        }
    }

    func skipAppleHealth() {
        HealthAuthorizationManager.markCurrentPermissionsVersionHandled()
        if let missingStep = nextRequiredStep {
            state = .profile(missingStep)
        } else {
            transitionToReady()
        }
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
