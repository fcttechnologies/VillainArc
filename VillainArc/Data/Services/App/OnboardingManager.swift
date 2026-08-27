import FCTMetrics
import FCTAccount
import HealthKit
import SwiftData
import SwiftUI

enum OnboardingState: Equatable {
    case launching
    case seeding
    case profile(UserProfileOnboardingStep)
    case finishing
    case healthPermissions
    /// The terminal step: every FCT app requires the FCT account, and onboarding ends in the
    /// sign-in surface. Reached only once profile + health setup are complete; `.ready` follows
    /// the account controller reporting `.signedIn`.
    case account
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
    var state: OnboardingState = .launching
    var profile: UserProfile?
    /// Measured natural height of the onboarding step currently on screen. The sheet's
    /// presentation detent follows this so each step is sized from its real content
    /// (Dynamic Type + localization aware) instead of a hardcoded fraction.
    var sheetHeight: CGFloat = 480
    private(set) var shouldInsertHealthPermissionsStep = false
    private(set) var prefetchedBirthday: Date?
    private(set) var prefetchedGender: UserGender?
    private(set) var prefetchedHeightCm: Double?
    private var context: ModelContext { SharedModelContainer.container.mainContext }
    private var onboardingAttemptID = UUID()
    /// The account layer the terminal step drives. Set once by `RootView` before
    /// `startOnboarding()`; the manager only reads its state and never owns its lifecycle.
    private(set) weak var account: AccountController?

    func attachAccount(_ controller: AccountController) {
        account = controller
    }

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
        let attemptID = UUID()
        onboardingAttemptID = attemptID

        if DataManager.hasCompletedInitialBootstrap() {
            await handleReturningLaunch()
            return
        }

        // First bootstrap. The store is local-first with no cloud mirror, so there is nothing to
        // wait for before seeding: seed the bundled catalog, ensure the singletons, and route
        // into profile setup. Restoring an existing account's data is the sync engine's job and
        // begins at the terminal sign-in step.
        Diag.funnel(VAFunnel.onboarding, .started)
        state = .seeding
        do {
            _ = try await DataManager.seedExercisesForOnboarding()
            SpotlightIndexer.reindexAll(context: context)
            cleanupIncompleteAuthoringWork()
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
        await startOnboarding()
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

#if DEBUG
    func completeOnboardingWithDebugData() async {
        do {
            state = .finishing
            HealthAuthorizationManager.markCurrentPermissionsVersionHandled()
            _ = try SystemState.ensureAppSettings(context: context)
            _ = try SystemState.ensureHealthSyncState(context: context)

            let profile = try SystemState.ensureUserProfile(context: context)
            profile.name = profile.trimmedName.isEmpty ? "Debug User" : profile.trimmedName
            profile.birthday = profile.birthday ?? Calendar.autoupdatingCurrent.date(from: DateComponents(year: 1995, month: 1, day: 1))
            if profile.gender == .notSet {
                profile.gender = .other
            }
            profile.heightCm = profile.heightCm ?? 175
            profile.fitnessLevel = profile.fitnessLevel ?? .intermediate
            profile.fitnessLevelSetAt = profile.fitnessLevelSetAt ?? .now
            self.profile = profile

            if try context.fetch(TrainingGoal.active).first == nil {
                context.insert(TrainingGoal(kind: .generalTraining))
            }

            try context.save()
            await syncCatalogIfNeededBeforeReady()
            transitionToReady()
        } catch {
            state = .error("Failed to complete debug onboarding: \(error.localizedDescription)")
        }
    }
#endif

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
        // Terminal for the first-run funnel; a phase for a funnel that isn't running is ignored,
        // so returning launches pass through here for free.
        Diag.funnel(VAFunnel.onboarding, .completed)
        state = .ready
    }

    private func syncCatalogIfNeededBeforeReady() async {
        guard DataManager.catalogNeedsSync() else { return }

        do {
            let didChange = try await DataManager.seedExercisesIfNeeded()
            if didChange { SpotlightIndexer.reindexAll(context: context) }
        } catch { AppLog.error("Returning-launch exercise sync failed", error: error) }
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

    private func transitionAfterSetup() async {
        if let missingStep = nextRequiredStep {
            state = .profile(missingStep)
        } else if await HealthAuthorizationManager.shouldPromptForCurrentPermissionsVersion() {
            state = .healthPermissions
        } else if accountStepIsRequired {
            state = .account
        } else {
            transitionToReady()
        }
    }

    /// Whether the terminal sign-in step still stands between here and `.ready`. Signed in means
    /// done; `needsReauthentication` and `signedOut` both route through the same surface, since
    /// the app requires an account to run.
    private var accountStepIsRequired: Bool {
        guard let account else { return false }
        if case .signedIn = account.state { return false }
        return true
    }

    /// Called by the account step when the controller reports `.signedIn`. The sync engine's
    /// enrollment (and any prior data restore) proceeds in the background; readiness never waits
    /// on a pull.
    func accountStepCompleted() {
        guard state == .account else { return }
        transitionToReady()
    }

    func connectAppleHealth() async {
        HealthAuthorizationManager.markCurrentPermissionsVersionHandled()
        _ = await HealthAuthorizationManager.requestAuthorization()
        await transitionAfterSetup()
    }

    func skipAppleHealth() {
        HealthAuthorizationManager.markCurrentPermissionsVersionHandled()
        Task { await transitionAfterSetup() }
    }

    private func cleanupIncompleteAuthoringWork() {
        do {
            let done = SessionStatus.done.rawValue
            let incompleteWorkoutPredicate = #Predicate<WorkoutSession> { $0.status != done }
            let incompleteWorkouts = try context.fetch(FetchDescriptor<WorkoutSession>(predicate: incompleteWorkoutPredicate))
            let incompletePlanPredicate = #Predicate<WorkoutPlan> { !$0.completed || $0.isEditing }
            let incompletePlans = try context.fetch(FetchDescriptor<WorkoutPlan>(predicate: incompletePlanPredicate))

            guard !incompleteWorkouts.isEmpty || !incompletePlans.isEmpty else { return }

            incompleteWorkouts.forEach(context.delete)
            incompletePlans.forEach(context.delete)
            try context.save()
            AppLog.info("Onboarding cleanup removed \(incompleteWorkouts.count) incomplete workouts and \(incompletePlans.count) incomplete plans.")
        } catch {
            AppLog.error("Onboarding cleanup failed for incomplete authoring work", error: error)
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
