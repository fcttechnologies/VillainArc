import FCTMetrics
import FCTAccount
import HealthKit
import SwiftData
import SwiftUI

/// Where a launch routes before any of Villain Arc's own setup runs.
///
/// The rule this type holds: **no part of the app exists without a session.** Every FCT app
/// requires the FCT account, so a launch without one goes to the front door and nothing else —
/// the whole intro on a device that has never been set up, the sign-in gate alone on one that
/// has (a session that expired, or a sign-out whose local clear was refused).
nonisolated enum OnboardingEntry: Equatable {
    /// The carousel, then the required sign-in step.
    case welcome
    /// The sign-in gate on its own.
    case account
    /// Signed in, nothing set up: seed the catalog, then Villain Arc's own setup steps.
    case firstRunSetup
    /// Signed in and set up: the short path to `.ready`.
    case returningLaunch

    static func forLaunch(hasSession: Bool, hasCompletedBootstrap: Bool) -> OnboardingEntry {
        guard hasSession else { return hasCompletedBootstrap ? .account : .welcome }
        return hasCompletedBootstrap ? .returningLaunch : .firstRunSetup
    }
}

enum OnboardingState: Equatable {
    case launching
    /// The front door: the intro carousel ending in the required sign-in step. Held whole by the
    /// root view — no app surface renders behind or before it.
    case welcome
    /// The sign-in gate without the carousel, for a device that is already set up.
    case account
    case seeding
    case profile(UserProfileOnboardingStep)
    case finishing
    case healthPermissions
    case ready
    case error(String)

    /// Whether this state is one of Villain Arc's own setup steps, which the root view presents as
    /// a sheet over the launch backdrop. The account states are full-screen gates, not sheets.
    var presentsSetupSheet: Bool {
        switch self {
        case .launching, .welcome, .account, .ready: return false
        case .seeding, .profile, .finishing, .healthPermissions, .error: return true
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

        switch OnboardingEntry.forLaunch(
            hasSession: account?.state.isSignedIn == true,
            hasCompletedBootstrap: DataManager.hasCompletedInitialBootstrap()
        ) {
        case .welcome:
            // The front door opens the funnel: everything after it, sign-in included, is a step a
            // user can abandon.
            Diag.funnel(VAFunnel.onboarding, .started)
            state = .welcome
        case .account:
            state = .account
        case .firstRunSetup:
            await runFirstBootstrap(attemptID: attemptID)
        case .returningLaunch:
            await handleReturningLaunch()
        }
    }

    /// The session is in hand and this device has never been set up: seed the bundled catalog,
    /// ensure the singletons, and route into profile setup. The store is local-first with no cloud
    /// mirror, so seeding waits on nothing — restoring the account's existing rows is the sync
    /// engine's job, already running in the background from the sign-in that just happened.
    private func runFirstBootstrap(attemptID: UUID) async {
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
        } else {
            transitionToReady()
        }
    }

    /// Called by the front door once a session exists — the carousel's sign-in step, or the
    /// sign-in gate on an already-set-up device. Routing again from the top is what picks up the
    /// setup this launch still owes; the sync engine's enrollment (and any restore of the
    /// account's existing rows) proceeds in the background, and readiness never waits on a pull.
    func accountGateCompleted() {
        guard state == .welcome || state == .account else { return }
        Task { await startOnboarding() }
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
