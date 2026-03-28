# Onboarding Flow

This document explains VillainArc's startup and readiness path: how first bootstrap differs from a returning launch, why the app waits for CloudKit import before seeding the exercise catalog, how profile setup works, and why App Intents use `SetupGuard`.

## Main Files

- `Root/VillainArcApp.swift`
- `Root/RootView.swift`
- `Views/Onboarding/OnboardingView.swift`
- `Data/Services/App/OnboardingManager.swift`
- `Data/Services/App/CloudKitImportMonitor.swift`
- `Data/Services/App/DataManager.swift`
- `Data/Services/App/SystemState.swift`
- `Data/Services/App/SetupGuard.swift`
- `Data/Services/HealthKit/Authorization/HealthAuthorizationManager.swift`
- `Data/Services/HealthKit/Sync/HealthStoreUpdateCoordinator.swift`
- `Data/SharedModelContainer.swift`

## Startup Entry

Startup is split across `VillainArcApp`, `RootView`, and `OnboardingManager`.

### `VillainArcApp`

- installs the shared model container
- forwards Spotlight and Siri handoffs into `AppRouter.shared`
- does not start onboarding itself

### `RootView`

- owns `OnboardingManager`
- deletes abandoned plan-editing copies before resume logic runs
- refreshes shortcut parameters
- starts onboarding in `.task`
- waits for `.ready` before calling `AppRouter.checkForUnfinishedData()`
- starts Health observers and runs the first post-ready Health sync pass
- presents `OnboardingView` as a non-dismissable sheet whenever onboarding is not yet complete

That ordering is deliberate. Resume logic for unfinished workouts or new-plan drafts only runs after bootstrap and profile setup are valid.

## The Bootstrap Marker

VillainArc stores a bootstrap marker in shared defaults:

- `DataManager.exerciseCatalogVersionKey`

If that key is missing, the app treats the launch as first bootstrap.
If it exists, the app treats the launch as a returning launch and only syncs the bundled catalog when its version changed.

## First Bootstrap

`OnboardingManager.startOnboarding()` takes the full bootstrap path when the bootstrap marker does not exist.

The order is:

1. check connectivity
2. check iCloud sign-in state
3. check CloudKit availability
4. start `CloudKitImportMonitor` and wait for import completion
5. seed the bundled exercise catalog through `DataManager.seedExercisesForOnboarding()`
6. reindex Spotlight
7. ensure `AppSettings`
8. ensure `UserProfile`
9. route into profile onboarding

If the profile finishes during this first-run path, onboarding then:

- moves to `.finishing`
- runs a bundled-catalog sync only if still needed
- completes the profile flow, which for new users includes the in-navigation Apple Health step after name
- transitions either to the standalone `.healthPermissions` screen or to `.ready`, depending on whether the current Health type set has crossed the request boundary

## Why the App Waits Before Seeding

This is the most important onboarding rule.

If the user already has VillainArc data in CloudKit, import may bring down:

- built-in `Exercise` rows from an older install
- `UserProfile`
- `AppSettings`
- plans, workouts, suggestions, splits, and related records

If the app seeded the bundled catalog before that import completed, it could create local built-in exercises and then import older copies of the same catalog exercises afterward.

The app therefore waits for CloudKit import completion first, then runs catalog seeding/sync against the imported store.

## Continue Without iCloud

If iCloud is disabled, onboarding moves into `.noiCloud`.

That path still allows setup to continue:

- seed the bundled catalog locally
- ensure `AppSettings`
- ensure `UserProfile`
- route into profile onboarding

The app becomes usable, but cloud sync and recovery across devices are unavailable.

## Returning Launch

Once the bootstrap marker exists, onboarding uses `handleReturningLaunch()`.

That path:

- ensures `AppSettings`
- ensures `UserProfile`
- routes into missing profile steps if the profile is incomplete
- otherwise syncs the bundled exercise catalog only when needed
- then decides whether to offer Apple Health or go straight to `.ready`

If the bundled catalog changed, Spotlight is reindexed after the sync finishes.

## Profile Onboarding

Profile onboarding starts only after the exercise catalog and singleton records exist.

The required profile fields are:

- name
- birthday
- gender
- height

### Navigation Model

`OnboardingView` uses a `NavigationStack` for the profile portion of onboarding.

The root screen is always the name step.
After that, navigation is driven by step views pushing onto the local path.
`OnboardingManager.state` is used to choose the initial route into the flow, not to drive every later navigation step.

### New User Flow

For a new user, the profile flow is:

`name -> health permissions -> birthday -> gender -> height`

The Health step is inserted immediately after the name step for true first-time onboarding.

### Returning User With Incomplete Profile

For a returning user with missing profile fields:

- if Apple Health has never been requested for the current type set, onboarding treats the user like a new user and starts with the Health step after name
- otherwise it jumps directly to the first missing required profile field

That lets VillainArc distinguish between:

- a user who quit during original onboarding before the Health step
- a user who already crossed the Health request boundary but still has an incomplete profile

### Profile Completion

Saving birthday, gender, or height persists the change immediately.
When the last missing field is filled, onboarding moves into `.finishing`, runs any needed catalog sync, and then either offers Apple Health or becomes ready.

## Apple Health Step

Apple Health is optional from a product standpoint, but the current launch flow treats the standalone Health-permission prompt as part of readiness whenever the current type set still has not crossed the request boundary.

### In-Nav Step for New Users

The new-user Health step lives inside the onboarding `NavigationStack`.

When the user taps Connect:

- `HealthAuthorizationManager.requestAuthorization()` runs
- VillainArc attempts to prefill birthday, gender, and height from HealthKit
- prefetched values are staged in manager state
- the user still confirms and saves each field before it becomes part of `UserProfile`

If the user force-quits before confirming the prefetched fields, the profile remains incomplete and the Health step can appear again on next launch.

If the user taps `Not Now`, the profile flow keeps moving without requesting Health authorization at that moment. But because the current type set still has not crossed the Health request boundary, onboarding can still transition into the standalone `.healthPermissions` screen after the required profile fields are complete.

### Standalone Sheet After Profile Completion

After the profile flow is otherwise complete, onboarding can transition into `.healthPermissions`.

That sheet:

- appears only when `authorizationAction()` says the current type set still needs a request
- shows a connect button only
- calls `requestAuthorization()` and then immediately transitions to `.ready`

This means the standalone Health sheet is currently blocking for that launch until the user taps Connect once. After that request call returns, VillainArc transitions to ready whether access was granted or denied.

VillainArc relies on HealthKit's request-status API rather than storing its own "prompted already" flag.

## Post-Ready Health Pass

When onboarding reaches `.ready`, `RootView` runs the post-ready Health pass:

- `HealthStoreUpdateCoordinator.start()`
- `HealthStoreUpdateCoordinator.refreshBackgroundDeliveryRegistration()`
- `HealthStoreUpdateCoordinator.syncNow()`

`syncNow()` performs:

1. Health data sync through `HealthSyncCoordinator`
2. export/relink reconciliation through `HealthExportCoordinator`

This is how VillainArc backfills Health mirrors, daily Health aggregate caches, and repairs older workouts or weight entries that still need links/exports.

## What Catalog Sync Actually Does

`DataManager` does not rebuild the whole store.

It:

- compares built-in exercises in persistence against `ExerciseCatalog.all`
- updates existing built-in rows when metadata changed
- inserts missing built-in rows
- propagates changed built-in metadata into stored `ExercisePrescription` and `ExercisePerformance` snapshots
- writes the current bundled catalog version into shared defaults

The bootstrap marker therefore means two things:

- the app has completed at least one catalog sync
- future launches can compare the stored version to the bundled version

## Singleton Records

After catalog sync, onboarding ensures the singleton-style records exist:

- `SystemState.ensureAppSettings(context:)`
- `SystemState.ensureHealthSyncState(context:)`
- `SystemState.ensureUserProfile(context:)`

These helpers fetch the existing record or create and save one if it does not exist.

## Failure, Retry, and Slow-Network States

Onboarding can enter these blocking states before the app is ready:

- no network
- iCloud disabled
- iCloud account issue
- CloudKit unavailable
- syncing
- syncing slow network
- generic bootstrap error

Details:

- the slow-network state appears if CloudKit import takes longer than 15 seconds
- the first-bootstrap import wait fails after 60 seconds
- the no-network state starts a retry loop that restarts onboarding when connectivity returns
- `OnboardingView` also retries when the app becomes active again for iCloud / CloudKit related blocking states

## Reinstall Behavior

On reinstall, the local app-group store and defaults are gone, but the user's CloudKit data may still exist.

That means:

- the bootstrap marker is gone
- onboarding takes the first-bootstrap path again
- the app waits for CloudKit import before seeding the bundled catalog

Reinstall is therefore treated as:

`import first -> reconcile with current bundled catalog -> continue setup`

## Why `SetupGuard` Exists

App Intents can run before the foreground app has completed the current launch's onboarding path.

That creates real risks:

- bootstrap may not have completed
- `AppSettings` may not exist yet
- `HealthSyncState` may not exist yet
- `UserProfile` may not exist yet
- profile onboarding may still be incomplete
- an unfinished workout or plan may already exist

`SetupGuard` is the shared defensive boundary for those cases.

### `requireReady`

Checks:

- bootstrap marker exists
- `AppSettings` exists
- `HealthSyncState` exists
- `UserProfile` exists
- `UserProfile.firstMissingStep == nil`

If any of those fail, the intent throws `SetupGuardError.onboardingNotComplete`.

### `requireNoActiveFlow`

Checks for persisted incomplete work:

- `WorkoutPlan.incomplete`
- `WorkoutSession.incomplete`

It does not inspect in-memory presentation state. It is purely a persistence-side guard.

### `requireReadyAndNoActiveFlow`

Composes both checks and is used by intents that should only run when setup is complete and no other workflow is already active.
