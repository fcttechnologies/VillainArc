# Onboarding Flow

This document explains VillainArc's startup and onboarding bootstrap path: how first launch differs from a normal launch, why the app waits for CloudKit import before seeding the exercise catalog, how singleton models are created, how catalog updates are applied over time, and why many intents use `SetupGuard`.

## Main Files

- `Views/ContentView.swift`
- `Views/Onboarding/OnboardingView.swift`
- `Data/Services/OnboardingManager.swift`
- `Data/Services/DataManager.swift`
- `Data/Services/SystemState.swift`
- `Data/Services/SetupGuard.swift`
- `Data/SharedModelContainer.swift`
- `Root/VillainArcApp.swift`
- `Data/Models/Exercise/Exercise.swift`
- `Data/Models/Exercise/ExerciseCatalog.swift`
- `Data/Models/UserProfile.swift`
- `Data/Models/AppSettings.swift`

## Startup Entry

The startup path is split across `VillainArcApp`, `RootView`, and `ContentView`.

`VillainArcApp`:
- creates the shared SwiftData container from the app-group store
- starts `CloudKitImportMonitor` before the onboarding flow begins
- attaches CloudKit-backed persistence through `SharedModelContainer`

`RootView`:
- creates `OnboardingManager`
- deletes abandoned editing workout-plan copies from the main context
- refreshes app shortcut parameters
- calls `await onboardingManager.startOnboarding()` in `.task`
- waits for onboarding to reach `.ready`
- only then calls `AppRouter.checkForUnfinishedData()`
- presents `OnboardingView` whenever the onboarding state says a sheet should be shown

That last part matters: resume logic for unfinished workouts or unfinished new-plan creation only runs after onboarding/bootstrap is complete.

## Shared Storage and Bootstrap Marker

VillainArc stores two important things in the app group:
- the shared SwiftData store (`VillainArc.store`)
- shared defaults, including the exercise catalog bootstrap marker

The bootstrap marker is:
- `DataManager.exerciseCatalogVersionKey`

Its stored value is the last catalog version the app synced. If there is no stored value yet, `DataManager.hasCompletedInitialBootstrap()` returns `false`, and the app treats the launch as first-time bootstrap.

## First Launch

On first launch, `OnboardingManager.startOnboarding()` takes the full bootstrap path because the catalog version has not been stored yet.

The order is:
1. check connectivity
2. check iCloud account status
3. check CloudKit availability
4. wait for CloudKit import completion
5. seed or sync the exercise catalog
6. ensure singleton models exist
7. route into profile onboarding or mark the app ready

### Why the App Waits Before Seeding

This is the key first-launch rule.

`OnboardingManager` waits for CloudKit import completion before calling `DataManager.seedExercisesForOnboarding()`.

The import observer starts at app launch through `CloudKitImportMonitor`, so onboarding is not relying on `OnboardingManager` being created first in order to see the completion event.

The reason is to avoid duplicate catalog exercise objects.

If the user already has VillainArc data in CloudKit, the import may bring down:
- previously synced catalog `Exercise` rows
- `UserProfile`
- `AppSettings`
- historical workouts, plans, suggestions, and related models

If the app seeded the catalog before that import finished, it could create local catalog exercises first and then import old copies of those same catalog exercises afterward.

Instead, the app waits until the import finishes, then runs catalog sync against the imported store.

### First Launch Without iCloud

If iCloud is disabled, the user can choose to continue without iCloud.

That path skips the CloudKit wait and still:
- seeds the catalog locally
- ensures `AppSettings`
- ensures `UserProfile`
- routes into profile onboarding or ready

## What Seeding Actually Does

`DataManager.seedExercisesForOnboarding()` just calls the shared sync path.

The actual behavior lives in `syncExercisesAndPersist()` and `syncExercises(context:)`.

For each item in `ExerciseCatalog.all`, the app:
- fetches existing non-custom catalog exercises
- matches them by `catalogID`
- updates existing rows if metadata changed
- inserts missing catalog rows

If exercise metadata changed, the app also propagates those updates into stored snapshots:
- `ExercisePrescription`
- `ExercisePerformance`

That propagation keeps existing plans and workout history aligned with the current catalog metadata for name, muscles, and equipment type.

At the end of sync:
- the context is saved if anything changed
- the current `ExerciseCatalog.catalogVersion` is written into shared defaults

So the bootstrap marker means both:
- the app has completed at least one catalog sync
- future launches can compare stored version against the current bundled catalog version

## Singleton Models

After catalog sync, onboarding ensures the singleton-style models exist:
- `SystemState.ensureAppSettings(context:)`
- `SystemState.ensureUserProfile(context:)`

Those helpers:
- fetch the first existing `AppSettings` or `UserProfile`
- create and save one if none exists

This is why the app can safely assume those records should exist once onboarding is done, even on a brand-new install.

## Profile Onboarding vs Ready

After the catalog and singleton models are ready, `OnboardingManager.routeFromProfile(_:)` decides the next state.

If the profile is missing required fields, the app routes into the appropriate onboarding step:
- name
- birthday
- height

If nothing is missing, onboarding transitions directly to `.ready`.

So there are really two phases:
- system bootstrap
- user profile completion

`SetupGuard` later treats both as part of being "ready."

## What Happens If the User Deletes and Reinstalls the App

For a reinstall, the important detail is that the local app-group store and defaults are gone, but the user's CloudKit private database may still contain their old VillainArc data.

That means on reinstall:
- the stored catalog version is gone
- `hasCompletedInitialBootstrap()` returns `false`
- onboarding takes the first-launch path again
- the app waits for CloudKit import before seeding

After import finishes, catalog sync runs against whatever came down from CloudKit.

That handles two cases at once:
- old synced catalog exercises are reused instead of duplicated
- any catalog changes shipped since the user last had the app are applied now

So reinstall is not just "seed from scratch." It is "import first, then reconcile the imported store with the current bundled catalog."

## Regular Launch After Bootstrap

Once a catalog version has been stored, `OnboardingManager.startOnboarding()` takes the returning-user path through `handleReturningLaunch()`.

That path is intentionally faster:
- it does not block on CloudKit import
- it immediately ensures `AppSettings` and `UserProfile`
- it routes into missing profile steps or `.ready`

Then, if the bundled exercise catalog version has changed, it starts a background task:
- `DataManager.seedExercisesIfNeeded()`

If that sync changes anything, the app reindexes Spotlight.

So returning launches prioritize getting the user into the app quickly, while catalog updates happen opportunistically in the background.

## How Catalog Updates Are Applied Later

`DataManager.catalogNeedsSync()` compares:
- stored catalog version in shared defaults
- current `ExerciseCatalog.catalogVersion`

If the versions differ, the sync path runs again.

The update behavior is:
- new bundled catalog exercises are inserted
- existing catalog exercises with the same `catalogID` are updated in place
- changed metadata is pushed into `ExercisePrescription` and `ExercisePerformance`
- custom exercises are ignored by this sync path because it only fetches non-custom catalog exercises

This means catalog updates are additive and metadata-correcting, not destructive.

The app is not rebuilding the whole database. It is reconciling live data with the latest bundled catalog by `catalogID`.

## Spotlight During Bootstrap

On first bootstrap and on explicit onboarding paths, the app reindexes all Spotlight data after seeding:
- `SpotlightIndexer.reindexAll(context: context)`

On returning launch, Spotlight is only fully reindexed if the background catalog sync actually changed anything.

That keeps search surfaces aligned with the latest exercise metadata without making every launch expensive.

## Why `SetupGuard` Exists

Many App Intents can be triggered before the foreground app has gone through the current launch's onboarding/bootstrap path.

That creates a real risk:
- the catalog bootstrap marker might not exist yet
- `AppSettings` might not exist yet
- `UserProfile` might not exist yet
- the profile might still be incomplete
- there might already be an active workout or active plan flow

`SetupGuard` is the defensive boundary for those entrypoints.

### `requireReady`

`SetupGuard.requireReady(context:)` checks:
- the initial catalog bootstrap marker exists
- `AppSettings` exists
- `UserProfile` exists
- the profile has no missing onboarding step

If any of those fail, the intent throws `SetupGuardError.onboardingNotComplete`.

The user-facing meaning is:
- launch the app and finish setup first

### `requireNoActiveFlow`

`SetupGuard.requireNoActiveFlow(context:)` checks for:
- incomplete workout plans
- incomplete workout sessions

If one exists, it throws the same active-flow errors the app uses elsewhere.

### `requireReadyAndNoActiveFlow`

This is just the composition of both checks.

It is used by intents that open or navigate to a feature and should not interrupt another active flow.

Examples:
- open a workout
- open a workout plan
- open exercise history
- show workout history

### Why Some Intents Only Use `requireReady`

Some "start" intents use `requireReady` first and then perform more specific flow checks themselves instead of using the combined helper.

Examples:
- `StartWorkoutIntent`
- `CreateWorkoutPlanIntent`
- `StartTodaysWorkoutIntent`

They do that so they can return more precise domain-specific errors after readiness is confirmed, like:
- workout already active
- workout plan already active
- no active split
- today is a rest day

So `SetupGuard` is not trying to replace all validation. It handles the shared bootstrap/readiness boundary, and individual intents still add feature-specific checks afterward.

## Failure and Retry States

`OnboardingManager` can also route into blocking states before the app is ready:
- no Wi-Fi
- no iCloud
- iCloud account issue
- CloudKit unavailable
- syncing slow network
- generic bootstrap error

Those states live in `OnboardingView` and are part of why onboarding is represented as a state machine instead of a single one-shot task.
