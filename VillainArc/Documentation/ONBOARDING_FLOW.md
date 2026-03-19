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
- `Data/Services/HealthKit/HealthStoreUpdateCoordinator.swift`
- `Data/Services/HealthKit/HealthWorkoutSyncCoordinator.swift`
- `Data/Services/HealthKit/HealthPreferences.swift`
- `Data/Services/HealthKit/HealthExportCoordinator.swift`
- `Data/SharedModelContainer.swift`
- `Helpers/CloudKitStatusChecker.swift`
- `Helpers/NetworkMonitor.swift`

## Startup Entry

The startup path is split across `VillainArcApp`, `RootView`, and `OnboardingManager`.

### `VillainArcApp`

- installs `SharedModelContainer.container` via `.modelContainer`
- forwards Spotlight and Siri activities into `AppRouter.shared`

### `RootView`

- owns `OnboardingManager`
- deletes abandoned plan editing copies before anything resumes
- refreshes shortcut parameters
- starts onboarding in `.task`
- when state reaches `.ready`, calls `AppRouter.checkForUnfinishedData()`, then kicks off `HealthStoreUpdateCoordinator.shared.refreshBackgroundDeliveryRegistration()` and `HealthStoreUpdateCoordinator.shared.syncNow()`
- presents `OnboardingView` as a non-dismissable sheet at half-height whenever `state.shouldPresentSheet` is true

That ordering is deliberate. Resume logic for unfinished workouts or incomplete plan creation only runs after bootstrap and profile setup are valid.

## The Bootstrap Marker

VillainArc stores the shared SwiftData store and shared defaults in the app group. The bootstrap marker is:

- `DataManager.exerciseCatalogVersionKey`

If this key does not exist, the app treats the launch as first-time bootstrap. If it exists, the app treats the launch as a returning launch and skips the full CloudKit wait.

## First Bootstrap

`OnboardingManager.startOnboarding()` takes the full bootstrap path when the catalog version marker does not exist.

The order is:

1. check network connectivity
2. check iCloud sign-in status
3. check CloudKit availability
4. start `CloudKitImportMonitor` on demand and wait for it to confirm import completion
5. seed the exercise catalog via `DataManager.seedExercisesForOnboarding()`
6. reindex Spotlight
7. ensure `AppSettings` exists
8. ensure `UserProfile` exists
9. set `isNewUser = true`, then route into profile onboarding

After profile steps complete, `saveHeight` sets state to `.finishing`, runs `syncCatalogIfNeededBeforeReady()`, then calls `transitionAfterSetup()` which either offers the Health permissions sheet or transitions to `.ready`.

## Why the App Waits Before Seeding

This is the most important first-launch rule.

If the user already has VillainArc data in CloudKit, the import may bring down:
- catalog `Exercise` rows from an older install
- `UserProfile`
- `AppSettings`
- workout sessions, plans, suggestions, splits, and related records

If the app seeded the bundled exercise catalog before that import completed, it could create local catalog exercises and then import older copies of the same catalog exercises afterward.

The app waits for import completion first, then runs `DataManager.seedExercisesForOnboarding()`, which reconciles the imported store against the bundled catalog by `catalogID`.

## Continue Without iCloud

If iCloud is disabled, onboarding routes into `.noiCloud`. The user can continue without iCloud.

That path:
- seeds the bundled exercise catalog locally
- ensures `AppSettings`
- ensures `UserProfile`
- sets `isNewUser = true`, then routes into profile setup

## Returning Launch

Once the bootstrap marker exists, onboarding uses `handleReturningLaunch()`.

That path:
- ensures `AppSettings`
- ensures `UserProfile`
- if the profile has missing fields, checks `authorizationAction()` to set `isNewUser` appropriately, then routes into the profile flow
- if the profile is complete, runs `syncCatalogIfNeededBeforeReady()` then `transitionAfterSetup()`

If the catalog sync changes anything, Spotlight is reindexed after the sync completes.

## Profile Onboarding

After the exercise catalog and singleton records exist, onboarding routes from the profile state.

### Navigation Model

The profile flow uses a `NavigationStack` with a private `OnboardingStep` enum (`healthPermissions`, `birthday`, `height`). The root of the stack is always `ProfileNameStepView`. Step views push onto `path` directly — the manager state is used only for the initial path setup when first entering the profile flow, not to drive subsequent navigation.

`OnboardingManager` exposes `isNewUser`, `prefetchedBirthday`, and `prefetchedHeightCm` for views to read.

`OnboardingView` sets the initial path once via `setInitialProfilePath()` when state first enters `.profile(...)`. After that, `didSetInitialPath` prevents the path from being reset by further state changes within the profile flow.

### New User Flow

For new users (`isNewUser == true`), the full sequence is:

**name → health permissions → birthday → height**

The name step saves and pushes `.healthPermissions`. The health permissions step connects or skips, then pushes `.birthday`. Birthday saves and pushes `.height`. Height saving triggers `saveHeight`, which transitions to `.finishing` and then `.ready`.

### Returning User With Incomplete Profile

If a returning user's profile has missing fields, `handleReturningLaunch` checks `authorizationAction()`:
- if `.requestAccess` → `isNewUser = true` → initial path starts at `.healthPermissions`
- otherwise → `isNewUser = false` → initial path starts at the first missing field directly

This covers force-quit during original onboarding (health was never requested) vs a user who connected health but quit before finishing birthday or height.

### Profile Completion

`saveName` and `saveBirthday` just save to the context and return — views drive navigation. Only `saveHeight` triggers the finishing transition. If the profile is already complete when onboarding first routes from it, `transitionAfterSetup()` runs immediately without showing any profile steps.

## Apple Health Step

### In-Nav Step (New Users)

The health step is embedded in the `NavigationStack` profile flow immediately after name. `OnboardingHealthPermissionStepView` shows two buttons:

- **Connect to Apple Health** — calls `connectAppleHealthDuringOnboarding()`, which requests authorization then reads date of birth and most recent height sample from HealthKit and stores them in `prefetchedBirthday` and `prefetchedHeightCm`. After the async work completes, the view pushes `.birthday`.

Prefetched values are held in manager state and are not written to `UserProfile` until the user taps Continue on each step. If the user force-quits before confirming birthday, the profile remains incomplete and the health step reappears on the next launch.

If the user navigates back to the health step after already connecting, `hasAuthorized` is true and the view shows a "Continue" button instead, skipping the authorization request.

### Standalone Sheet (Returning Users)

For returning users with a complete profile, `transitionAfterSetup()` checks `shouldOfferHealthPermissions()`, which calls `authorizationAction()`:
- `.requestAccess` → state transitions to `.healthPermissions` → standalone sheet appears
- anything else → transitions directly to `.ready`

The standalone sheet shows only "Connect to Apple Health". There is no skip option. The user goes through the HealthKit system dialog and either allows or denies, but `requestAuthorization` is called either way. This prevents the sheet from reappearing on the next launch for the same type set. No version flag or stored marker is needed — HealthKit's `statusForAuthorizationRequest` tracks which types have been presented.

### Post-Ready Health Pass

When state reaches `.ready`, `RootView` calls:
- `HealthStoreUpdateCoordinator.shared.start()` — registers the HealthKit workout and body-mass observer queries
- `HealthStoreUpdateCoordinator.shared.refreshBackgroundDeliveryRegistration()` — enables background delivery if authorization exists
- `HealthStoreUpdateCoordinator.shared.syncNow()` — syncs HealthKit workouts into the local mirror and reconciles completed app sessions that have no Health link

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

The bootstrap marker means both:
- the app has completed at least one catalog sync
- future launches can compare that stored version to the bundled version

## Singleton Records

After catalog sync, onboarding ensures the singleton-style app records exist:
- `SystemState.ensureAppSettings(context:)`
- `SystemState.ensureUserProfile(context:)`

Those helpers either fetch the existing record or create and save one if it does not exist yet.

## Failure, Retry, and Slow-Network States

`OnboardingManager` can enter these blocking states before the app is ready:
- no network
- no iCloud
- iCloud account issue
- CloudKit unavailable
- syncing
- syncing slow network
- generic bootstrap error

Details:
- slow-network UI appears if CloudKit import has not completed after 15 seconds
- import wait fails hard after 60 seconds
- the no-network state starts a polling `NetworkMonitor` task that retries onboarding automatically when connectivity returns
- `OnboardingView` also retries when the app becomes active again for `.noiCloud`, `.cloudKitAccountIssue`, and `.cloudKitUnavailable`

## Reinstall Behavior

On reinstall, the local app-group store and defaults are gone, but the user's CloudKit data may still exist.

That means:
- the catalog version marker is gone
- onboarding takes the first-bootstrap path
- the app waits for CloudKit import before seeding

Reinstall is handled as "import first, then reconcile with the current bundled catalog."

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
