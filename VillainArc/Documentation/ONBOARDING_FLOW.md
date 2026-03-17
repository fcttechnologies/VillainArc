# Onboarding Flow

This document explains VillainArc's startup and readiness path: how bootstrap works, why the app waits for CloudKit import before seeding the exercise catalog, how profile setup fits into launch, and why many intents use `SetupGuard`.

## Main Files

- `Root/VillainArcApp.swift`
- `Root/RootView.swift`
- `Views/Onboarding/OnboardingView.swift`
- `Data/Services/OnboardingManager.swift`
- `Data/Services/CloudKitImportMonitor.swift`
- `Data/Services/DataManager.swift`
- `Data/Services/SystemState.swift`
- `Data/Services/SetupGuard.swift`
- `Data/Services/HealthKit/HealthAuthorizationManager.swift`
- `Data/Services/HealthKit/HealthOnboardingPreferences.swift`
- `Data/Services/HealthKit/HealthExportCoordinator.swift`
- `Data/SharedModelContainer.swift`
- `Helpers/CloudKitStatusChecker.swift`
- `Helpers/NetworkMonitor.swift`

## Startup Entry

The startup path is split across `VillainArcApp`, `RootView`, and `OnboardingManager`.

### `VillainArcApp`

- starts `CloudKitImportMonitor.shared` in `init()`
- installs `SharedModelContainer.container`
- forwards Spotlight and Siri activities into `AppRouter.shared`

### `RootView`

- owns `OnboardingManager`
- deletes abandoned plan editing copies before anything resumes
- refreshes shortcut parameters
- starts onboarding in `.task`
- waits for onboarding to reach `.ready`
- only then calls `AppRouter.checkForUnfinishedData()`
- after `.ready`, also asks `HealthExportCoordinator` to reconcile completed workouts that still have no Apple Health export link
- presents `OnboardingView` as a blocking sheet whenever onboarding is not ready

That ordering is deliberate. Resume logic for unfinished workouts or incomplete plan creation only runs after bootstrap and profile setup are valid.

## The Bootstrap Marker

VillainArc stores the shared SwiftData store and shared defaults in the app group. The onboarding/bootstrap marker is:

- `DataManager.exerciseCatalogVersionKey`

If this key does not exist, the app treats the launch as first-time bootstrap. If it exists, the app treats the launch as a returning launch and can skip the full CloudKit wait.

## First Bootstrap

`OnboardingManager.startOnboarding()` takes the full bootstrap path when the catalog version marker does not exist.

The order is:

1. check network connectivity
2. check iCloud sign-in status
3. check CloudKit availability
4. wait for `CloudKitImportMonitor` to confirm import completion
5. seed or sync the exercise catalog
6. reindex Spotlight
7. ensure `AppSettings` exists
8. ensure `UserProfile` exists
9. route into profile onboarding
10. after profile completion, either offer the optional Apple Health step or transition to `.ready`

## Why the App Waits Before Seeding

This is the most important first-launch rule.

If the user already has VillainArc data in CloudKit, the import may bring down:
- catalog `Exercise` rows from an older install
- `UserProfile`
- `AppSettings`
- workout sessions, plans, suggestions, splits, and related records

If the app seeded the bundled exercise catalog before that import completed, it could create local catalog exercises and then import older copies of the same catalog exercises afterward.

Instead, the app waits for import completion first, then runs `DataManager.seedExercisesForOnboarding()`, which reconciles the imported store against the bundled catalog by `catalogID`.

## Continue Without iCloud

If iCloud is disabled, onboarding can route into `.noiCloud`. The user may choose to continue without iCloud.

That path still:
- seeds the bundled exercise catalog locally
- reindexes Spotlight
- ensures `AppSettings`
- ensures `UserProfile`
- routes into profile setup or `.ready`

It simply skips the CloudKit wait.

## Returning Launch

Once the bootstrap marker exists, onboarding uses `handleReturningLaunch()`.

That path:
- immediately ensures `AppSettings`
- immediately ensures `UserProfile`
- routes into missing profile setup steps
- if the profile is already complete, runs any needed catalog sync on the main actor before transitioning to `.ready`

If the returning-launch catalog sync changes anything, Spotlight is reindexed after the sync completes.

This keeps the returning-launch path on the main actor and guarantees the bundled exercise metadata is reconciled before the app becomes ready.

## Optional Apple Health Step

Apple Health is not part of bootstrap readiness. VillainArc only offers it after:
- the exercise catalog exists
- singleton records exist
- profile onboarding is complete

That step is optional:
- `connectAppleHealth()` requests workout read/write permission
- `skipAppleHealth()` marks the prompt complete locally and continues to `.ready`

If the user connects Apple Health during onboarding, VillainArc immediately asks `HealthExportCoordinator` to reconcile already-completed workouts that still have no export link.

## Why the Prompt Is Device-Local

The app remembers whether it already showed the optional Apple Health step through `HealthOnboardingPreferences`, which stores a flag in shared defaults.

That flag is not treated as HealthKit truth:
- HealthKit authorization still comes from `HKHealthStore`
- users can change Health permissions outside the app
- reinstall or a second device may still need a fresh HealthKit permission request even if profile and app data restore from CloudKit

## What Catalog Sync Actually Does

`DataManager` does not rebuild the whole database. It reconciles the current store against `ExerciseCatalog.all`.

For each built-in catalog item it:
- fetches existing non-custom catalog exercises
- matches by `catalogID`
- updates existing rows if metadata changed
- inserts missing rows

If catalog metadata changes, it also propagates those updates into stored snapshots:
- `ExercisePrescription`
- `ExercisePerformance`

At the end of sync:
- the context is saved if anything changed
- the current `ExerciseCatalog.catalogVersion` is written to shared defaults

So the bootstrap marker means both:
- the app has completed at least one catalog sync
- future launches can compare that stored version to the bundled version

## Singleton Records

After catalog sync, onboarding ensures the singleton-style app records exist:
- `SystemState.ensureAppSettings(context:)`
- `SystemState.ensureUserProfile(context:)`

Those helpers either fetch the existing record or create and save one if it does not exist yet.

## Profile Onboarding

After the exercise catalog and singleton records exist, onboarding routes from the profile state.

If required fields are missing, the user is taken through:
- name
- birthday
- height

If nothing is missing, onboarding transitions directly to `.ready`.

So VillainArc has two startup phases:
- system bootstrap
- user profile completion

`SetupGuard` treats both as part of being ready.

## Failure, Retry, and Slow-Network States

`OnboardingManager` can enter these blocking states before the app is ready:
- no network
- no iCloud
- iCloud account issue
- CloudKit unavailable
- syncing
- syncing slow network
- generic bootstrap error

A few details matter here:
- slow-network UI appears if CloudKit import still has not completed after 15 seconds
- import wait fails hard after 60 seconds
- the no-network state starts network monitoring so onboarding can retry when connectivity returns
- `OnboardingView` also retries when the app becomes active again for `.noiCloud`, `.cloudKitAccountIssue`, and `.cloudKitUnavailable`

## Reinstall Behavior

On reinstall, the local app-group store and defaults are gone, but the user's CloudKit data may still exist.

That means:
- the catalog version marker is gone
- onboarding takes the first-bootstrap path again
- the app waits for CloudKit import before seeding

This is correct. Reinstall is handled as "import first, then reconcile with the current bundled catalog," not "blindly seed from scratch."

## Why `SetupGuard` Exists

App Intents can run before the foreground app has completed the current launch's onboarding flow. That creates real risks:
- the bootstrap marker might not exist yet
- `AppSettings` might not exist yet
- `UserProfile` might not exist yet
- profile onboarding might still be incomplete
- there might already be an unfinished workout or plan

`SetupGuard` is the shared defensive boundary for those cases.

### `requireReady`

Checks:
- initial bootstrap marker exists
- `AppSettings` exists
- `UserProfile` exists
- `UserProfile.firstMissingStep == nil`

If any of those fail, the intent throws `SetupGuardError.onboardingNotComplete`.

### `requireNoActiveFlow`

Checks for persisted incomplete work:
- `WorkoutPlan.incomplete`
- `WorkoutSession.incomplete`

It does not inspect in-memory presentation state. It is purely a persistence-side guard.

### `requireReadyAndNoActiveFlow`

Composes both checks and is used by intents that should only run when setup is complete and no other active workflow is already in progress.
