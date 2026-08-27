# Onboarding Flow

This document explains how VillainArc gets from process launch to a ready app state. It covers first bootstrap, returning launch, profile onboarding, the required fitness-level and training-goal steps, the Apple Health permission prompt, and the terminal FCT account sign-in step.

This file is only about launch readiness. Ongoing profile editing after setup lives in the dedicated Profile surface (`Views/Profile/ProfileSheetView.swift`) rather than in onboarding.

## Main Files

- `Root/VillainArcApp.swift`
- `Root/RootView.swift`
- `Views/Onboarding/OnboardingView.swift`
- `Data/Services/App/OnboardingManager.swift`
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
- route into the training-goal step if profile fields (including fitness level) are complete but no active training goal exists
- sync the bundled exercise catalog only if its version changed
- decide whether the current Health permissions version still needs a prompt
- otherwise transition directly to `.ready`

## Profile Onboarding

The required profile fields are:

- name
- birthday
- gender
- height
- fitness level

Fitness-level completeness requires both:

- `fitnessLevel`
- `fitnessLevelSetAt`

VillainArc also requires one active `TrainingGoal` before setup is considered complete.

`OnboardingView` uses a `NavigationStack` for the profile portion of onboarding. `OnboardingManager.state` chooses the initial entry point, but the per-step screens drive the forward navigation once the flow is active.

### New User Flow

For a true first-time user, the profile flow is:

`name -> health permissions -> birthday -> gender -> height -> fitness level -> training goal -> account sign-in`

The in-flow Apple Health step comes immediately after the name step.

### Returning User With Missing Profile Data

For a returning user with an incomplete profile:

- if the current Health permissions version still needs a prompt, onboarding starts with the Health step after name
- otherwise onboarding jumps directly to the first missing required profile field

For a returning user whose profile fields are complete but who has no active training goal:

- onboarding jumps directly to the training-goal step
- if the current Health permissions version still needs a prompt, the Health step appears before the training-goal step

## Apple Health Permission Prompt

VillainArc treats Health as optional from a product perspective, but the launch flow still treats the standalone Health-permission screen as part of readiness when the current Health permissions version still needs a request.

The prompt rule is versioned:

- `HealthKitCatalog.permissionsCatalogVersion` represents the current read/write type set. Version `1.3` requests the added heart vitals, respiratory rate, sleeping wrist temperature, and dietary water permissions.
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
- `WeeklyHealthCoachingCoordinator.refreshSchedule()`

This does five jobs:

- recreate missing Health observers after the launch path
- backfill Health mirrors, sleep nights and sleep blocks, and daily caches
- reconcile older workout and weight exports
- refresh all Health widgets after the manual sync pass
- schedule or cancel the weekly Health coaching background refresh based on the current notification settings and system permissions

The observer reinstall matters because observer queries are also created earlier at process launch. If an earlier observer failed due to Health authorization state, the ready-time path can recreate it cleanly.

## Failure and Retry States

Before the app is ready, onboarding can enter a generic bootstrap error (seeding or singleton
setup failed) with a Retry button that restarts the attempt. Sign-in failures are handled inside
the account surface itself and never abandon the flow.

## Reinstall Behavior

On reinstall, the local store and defaults are gone; the account's data lives on the FCT platform.
The app takes the first-bootstrap path again (seed, profile, health, sign-in), and enrollment after
sign-in restores the account's rows in the background. The profile typed during setup pushes as the
current truth; the account's workout history, plans, splits, and settings pull down and settle by
LWW.

## Post-Ready Education Surface

After the post-ready Health pass, `RootView` asks `WhatsNewPreferences.presentationOnLaunch()` what (if anything) to present as a one-time sheet. There is a single surface — the `WhatsNewSheet` — rendered in one of two modes:

- **Welcome** — a brand-new install (no stored version and no legacy pre-1.4 marker). Shows the app's main pillars (`WhatsNewCatalog.welcomeHighlights`) under a "Welcome to Villain Arc" header with a Get Started button.
- **What's New** — a returning/updated user. Shows the aggregated highlights of every release the user hasn't seen yet (`WhatsNewCatalog.featuresIntroduced(after:throughIncluding:)`), so a user who skips versions (e.g. 1.3 → 1.5) still sees every missed release's highlights in one sheet.

The decision logic (`WhatsNewPreferences`):

- the last shown marketing version is stored in App Group `UserDefaults` (`whats_new_last_shown_version`)
- already on the current version → present nothing, and advance the stored pointer immediately
- no stored version **and** no legacy marker (`has_seen_onboarding_slideshow`, written by the removed pre-1.4 onboarding slideshow) → Welcome
- otherwise → What's New for the unseen releases (nothing if those releases contribute no highlights, e.g. a minor bug-fix build)

The version it was shown for is marked seen on **any** dismissal (Continue/Get Started button or a swipe-away), via the sheet's `onDismiss`, so it never reappears on the next launch.

The per-version changelog and the Welcome highlights live in `WhatsNewCatalog`. To announce a release's features, append a `WhatsNewRelease` with its marketing version. The releases list starts at 1.4 — the 1.3 pillars are the Welcome content, so a user updating from 1.3 sees only what's new in 1.4.

This surface is a gating decision, not a state machine state. It does not block `.ready`; it layers on top via a SwiftUI sheet.

## Why `SetupGuard` Exists

App Intents can run before the foreground app has completed the current launch’s onboarding path.

`SetupGuard` exists to block intent work until:

- bootstrap has completed
- singleton records exist
- the profile is complete (including fitness level and fitness-level timestamp)
- an active training goal exists
- any additional no-active-flow requirement is satisfied

That keeps shortcut/intents behavior aligned with the app’s actual readiness rules.
