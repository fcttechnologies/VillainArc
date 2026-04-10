# Onboarding Flow

This document explains how VillainArc gets from process launch to a ready app state. It covers first bootstrap, returning launch, profile onboarding, the Apple Health permission prompt, and why the app waits for CloudKit import before seeding the exercise catalog.

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

## Startup Entry

Startup is split across three pieces:

- `VillainArcApp`
  - installs the shared model container
  - forwards Spotlight and Siri handoffs
  - reinstalls Health observers on process launch through the app delegate
- `RootView`
  - starts onboarding
  - performs launch cleanup
  - waits for `.ready` before resuming unfinished work
- `OnboardingManager`
  - owns the readiness state machine

That split is deliberate. Onboarding owns readiness decisions; `RootView` owns when the foreground app may actually resume persisted work.

## First Bootstrap vs Returning Launch

The bootstrap marker is `DataManager.exerciseCatalogVersionKey`.

- if it is missing, launch is treated as first bootstrap
- if it exists, launch is treated as a returning launch

## First Bootstrap

First bootstrap does the slow path:

1. check connectivity
2. check iCloud sign-in state
3. check CloudKit availability
4. wait for CloudKit import completion
5. seed the bundled exercise catalog
6. reindex Spotlight
7. ensure singleton records
8. route into profile onboarding

The critical rule is:

- wait for CloudKit import before seeding the bundled exercise catalog

That prevents duplicate built-in exercises when older cloud data is still arriving.

Important implementation detail:

- `CloudKitImportMonitor` starts at onboarding start on first bootstrap (before the explicit wait step) so the app does not miss an early import-complete event

## Continue Without iCloud

If iCloud is disabled, VillainArc can continue without cloud sync.

That path still:

- seeds the bundled exercise catalog locally
- ensures singleton records
- continues into profile onboarding
- skips the first-bootstrap Spotlight reindex pass used by the iCloud-enabled bootstrap path

The app becomes usable, but cloud recovery and cross-device sync are unavailable.

## Returning Launch

Returning launch does the short path:

- ensure singleton records exist
- route into missing profile steps if the profile is incomplete
- sync the bundled exercise catalog only if its version changed
- decide whether the current Health permissions version still needs a prompt
- otherwise transition directly to `.ready`

## Profile Onboarding

The required profile fields are:

- name
- birthday
- gender
- height

`OnboardingView` uses a `NavigationStack` for the profile portion of onboarding. `OnboardingManager.state` chooses the initial entry point, but the per-step screens drive the forward navigation once the flow is active.

### New User Flow

For a true first-time user, the profile flow is:

`name -> health permissions -> birthday -> gender -> height`

The in-flow Apple Health step comes immediately after the name step.

### Returning User With Missing Profile Data

For a returning user with an incomplete profile:

- if the current Health permissions version still needs a prompt, onboarding starts with the Health step after name
- otherwise onboarding jumps directly to the first missing required profile field

## Apple Health Permission Prompt

VillainArc treats Health as optional from a product perspective, but the launch flow still treats the standalone Health-permission screen as part of readiness when the current Health permissions version still needs a request.

The prompt rule is versioned:

- `HealthKitCatalog.permissionsCatalogVersion` represents the current read/write type set
- the app stores the last handled Health permissions version in shared defaults
- onboarding and the standalone launch gate prompt only when:
  - the current permissions version differs from the stored handled version
  - and HealthKit still reports that the current type set should be requested
- the handled version updates only when the user taps `Connect to Apple Health` or `Not Now`
- if the user leaves the blocking screen without tapping either button, the prompt appears again on the next launch

### In-Flow Prompt for New Users

For new users:

- the Health step lives inside profile onboarding
- tapping Connect requests authorization
- the app tries to prefill birthday, gender, and height for confirmation
- tapping `Not Now` marks the current Health permissions version as handled and skips the request for that version

### Standalone Prompt After Profile Completion

If the current Health permissions version still needs a request after the profile is otherwise complete, onboarding enters `.healthPermissions`.

That screen:

- explains that VillainArc needs additional Health permissions for newly added or upcoming features
- shows `Connect to Apple Health` and `Not Now`
- marks the current Health permissions version as handled only when the user taps one of those buttons
- requests authorization only when the user taps `Connect to Apple Health`
- then transitions to `.ready` whether access was granted or denied

So the standalone Health prompt is effectively a launch gate that requires the user to explicitly handle the current permissions version once.

## Post-Ready Health Pass

When onboarding reaches `.ready`, `RootView` runs the post-ready Health pass:

- `HealthStoreUpdateCoordinator.installObserversIfNeeded()`
- `HealthStoreUpdateCoordinator.refreshBackgroundDeliveryRegistration()`
- `HealthStoreUpdateCoordinator.syncNow()`
- `HealthMetricWidgetReloader.reloadAllHealthMetrics()`
- `NotificationCoordinator.requestAuthorizationIfNeededAfterOnboarding()`

This does four jobs:

- recreate missing Health observers after the launch path
- backfill Health mirrors, sleep nights and sleep blocks, and daily caches
- reconcile older workout and weight exports
- refresh all Health widgets after the manual sync pass

The observer reinstall matters because observer queries are also created earlier at process launch. If an earlier observer failed due to Health authorization state, the ready-time path can recreate it cleanly.

## Failure and Retry States

Before the app is ready, onboarding can enter:

- no network
- iCloud disabled
- iCloud account issue
- CloudKit unavailable
- syncing
- syncing slow network
- generic bootstrap error

Important timing rules:

- slow network appears after about 15 seconds of CloudKit import waiting
- the first-bootstrap import wait fails after about 60 seconds
- no-network uses a retry loop that restarts onboarding when connectivity returns
- iCloud/CloudKit blocking states also retry when the app becomes active again

## Reinstall Behavior

On reinstall, the local store and defaults are gone but CloudKit data may still exist.

That means reinstall behaves like:

`import first -> reconcile bundled catalog -> continue setup`

The app takes the first-bootstrap path again, waits for cloud import, then seeds/syncs against the imported store.

## Why `SetupGuard` Exists

App Intents can run before the foreground app has completed the current launch’s onboarding path.

`SetupGuard` exists to block intent work until:

- bootstrap has completed
- singleton records exist
- the profile is complete
- any additional no-active-flow requirement is satisfied

That keeps shortcut/intents behavior aligned with the app’s actual readiness rules.

## Apple Watch Companion Readiness

The Apple Watch companion does not reuse the iPhone `SetupGuard`.

Instead, the watch derives readiness only from its own synced SwiftData store:

- `AppSettings.single` must exist
- `UserProfile.single` must exist
- `UserProfile.firstMissingStep` must be `nil`
- at least one catalog exercise must be present

Important distinctions:

- watch readiness is local-store driven, not App Group driven
- the watch never performs iPhone bootstrap or onboarding repair work
- watch-side Health authorization is checked at workout runtime start, not as part of readiness

See:

- `Documentation/WATCH_COMPANION_FLOW.md`
