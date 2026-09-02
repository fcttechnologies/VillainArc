# Onboarding Flow

This document explains how VillainArc gets from process launch to a ready app state. It covers the
front door (the intro carousel ending in the required FCT account sign-in, then the one FCT account
onboarding), first bootstrap, returning launch, profile onboarding, the required fitness-level and
training-goal steps, and the Apple Health permission prompt.

This file is only about launch readiness. Ongoing profile editing after setup lives in the dedicated
Profile surface (`Views/Profile/ProfileSheetView.swift`) rather than in onboarding.

## Main Files

- `Root/VillainArcApp.swift`
- `Root/RootView.swift`
- `Views/Onboarding/VAOnboardingCarousel.swift`
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
  - resumes the account, starts `VASync`, then starts onboarding
  - holds the front door as the whole window, and the app only behind it
  - performs launch cleanup
  - waits for `.ready` before resuming unfinished work
- `OnboardingManager`
  - owns the readiness state machine

That split is deliberate. Onboarding owns readiness decisions; `RootView` owns what the window
holds and when the foreground app may actually resume persisted work.

## The Front Door

**No part of VillainArc exists without an FCT session.** The account is required, so a launch
without one gets the account surface and nothing else: `RootView` renders it *instead of*
`ContentView`, never as a sheet over it.

First launch opens on the intro carousel — `FCTOnboarding.AccountOnboardingFlow` paging
`VAOnboardingCarousel.items` (the app's pillars over its App Store artwork, in
`Assets.xcassets/Onboarding`) and ending in the three-provider sign-in step. The carousel finishing
never finishes onboarding: the flow completes only once a session exists, and the carousel cannot
produce one. The front door is dark whatever the app's appearance setting says — a first launch has
no setting yet.

`OnboardingEntry.forLaunch` is the whole routing rule, and `OnboardingSequenceTests` pins it:

| session | bootstrap marker | entry | what the user sees |
|---|---|---|---|
| no | no | `.welcome` | the carousel, then sign-in |
| no | yes | `.account` | the sign-in gate alone — the device has met the app, it is only missing the session |
| yes | no | `.firstRunSetup` | seeding, then the profile steps |
| yes | yes | `.returningLaunch` | the short path to `.ready` |

Signing in routes from the top again, which is what picks up the setup that launch still owes.

**The one FCT account onboarding sits between the session and everything else** — the fleet's
position for it. `RootView` wraps `FCTAccountProfile.AccountOnboardingGate` around the setup sheet
*and* the app, so the person's name, birthday and storefront country are asked once per account, in
whichever FCT app they met first, and never again on any device. Nothing behind it asks for them:
they are the account's, not this app's (`Data/Models/UserProfile.swift`).

**One more account step comes after all of it**: the engine donation ask
(`FCTAccountProfile.EngineDonationGate`, wrapped around `ContentView` at `.ready`), which asks once
per account whether the content behind a suggestion's outcome may ride with it — off until tapped,
skipped entirely on a launch that has not yet pulled the account's answer, and never asked again in
any FCT app once it is answered here. See
[SUGGESTION_AND_OUTCOME_FLOW.md](./SUGGESTION_AND_OUTCOME_FLOW.md) § the donation ask.

Losing the session closes the app behind the gate again, whatever caused it — an involuntary
expiry, or a sign-out whose local clear was refused because this device still holds unpushed work.
A clean sign-out clears the local store *and* the bootstrap marker, so the next thing the user sees
is the whole front door, carousel included.

## First Bootstrap vs Returning Launch

The bootstrap marker is `DataManager.exerciseCatalogVersionKey`.

- if it is missing, launch is treated as first bootstrap
- if it exists, launch is treated as a returning launch

## First Bootstrap

First bootstrap runs behind the session, and does the slow path:

1. seed the bundled exercise catalog
2. reindex Spotlight
3. clean up incomplete authoring work
4. ensure singleton records
5. route into profile onboarding

The store is local-first with no cloud mirror, so seeding waits on nothing. Restoring the account's
existing rows is the sync engine's job and is already running in the background from the sign-in
that just happened; readiness never waits on a pull.

## Returning Launch

Returning launch does the short path:

- ensure singleton records exist
- route into missing profile steps if the profile is incomplete
- route into the training-goal step if profile fields (including fitness level) are complete but no
  active training goal exists
- sync the bundled exercise catalog only if its version changed
- decide whether the current Health permissions version still needs a prompt
- otherwise transition directly to `.ready`

## Profile Onboarding

The required profile fields are the ones that are **VillainArc's own**:

- gender
- height
- fitness level

The name, the birthday, the country and the avatar are not among them and never will be: they are
the FCT account's, one home for the whole fleet. The account onboarding above this asks for them,
`AccountProfileSection` in App Settings edits them, and VillainArc reads the name off
`account.profile`'s rows (`AccountProfileField.displayName(from:)`) and the birthday off the
account's trusted row (`AccountBirthday`).

Fitness-level completeness requires both:

- `fitnessLevel`
- `fitnessLevelSetAt`

VillainArc also requires one active `TrainingGoal` before setup is considered complete.

These steps present as a sheet over the launch backdrop — the app itself is not behind them.
`OnboardingView` uses a `NavigationStack` for the profile portion; `OnboardingManager.state`
chooses the initial entry point, but the per-step screens drive the forward navigation once the
flow is active. The sheet sizes itself to the step on screen by measuring that step's natural
content height, so it follows Dynamic Type and localization instead of a hardcoded detent.

Measuring beats hardcoded fractions and stays. What it costs is that the resize trails the content
swap by one layout pass, so the movement can read as two beats where the eye expects one. Four
things feed that, the first structural:

1. **The measurement cannot arrive before the step it measures.** `reportsOnboardingHeight`
   (`onGeometryChange`) can only report once the next step has laid out, so the content swaps at the
   *old* detent — clipped, or floating in slack — and the sheet catches up after. Only a
   pre-computed or step-declared height moves both together.
2. **`.animation(_:value:)` does not cleanly drive a detent change.** `UISheetPresentationController`
   runs the resize on its own curve, so a SwiftUI animation layered over it is redundant at best and
   a second competing curve at worst.
3. **`OnboardingChrome.navStep` (100) and `.plain` (56) are guesses added on top of a measured
   height**, so a step whose real chrome differs over- or undershoots and the sheet settles visibly.
4. **The step switch carries no transition**: the `Group { switch manager.state }` and the `path`
   pushes both swap without one.

The shape a fix should take: keep the measurement as the source of truth but cache it per step the
first time each is measured, so a step seen once resizes *with* its content; drop the `.animation`
modifier and let the sheet own its curve; fold the chrome constants into the measured frame rather
than adding them on top. This is design-led and is judged on a device, not from a static read — the
2.0 device checklist carries the line that judges it.

### New User Flow

For a true first-time user, the setup flow after sign-in is:

`health permissions -> location permissions -> gender -> height -> fitness level -> training goal`

The permission steps lead, and the location step follows the Health one.

### Returning User With Missing Profile Data

For a returning user with an incomplete profile:

- if the current Health permissions version still needs a prompt, onboarding starts with the Health
  step, then location, then the first missing field
- otherwise onboarding jumps directly to the first missing required profile field

For a returning user whose profile fields are complete but who has no active training goal:

- onboarding jumps directly to the training-goal step
- if the current Health permissions version still needs a prompt, the Health step appears before the
  training-goal step

## Apple Health Permission Prompt

VillainArc treats Health as optional from a product perspective, but the launch flow still treats
the standalone Health-permission screen as part of readiness when the current Health permissions
version still needs a request.

The prompt rule is versioned:

- `HealthKitCatalog.permissionsCatalogVersion` represents the current read/write type set. Version
  `1.3` requests the added heart vitals, respiratory rate, sleeping wrist temperature, and dietary
  water permissions.
- the app stores the last handled Health permissions version in shared defaults
- onboarding and the standalone launch gate prompt only when:
  - the current permissions version differs from the stored handled version
  - and HealthKit still reports that the current type set should be requested
- the handled version updates only when the user taps `Connect to Apple Health` or `Not Now`
- if the user leaves the blocking screen without tapping either button, the prompt appears again on
  the next launch

### In-Flow Prompt for New Users

For new users:

- the Health step lives inside profile onboarding
- tapping Connect requests authorization
- the app tries to prefill gender and height for confirmation
- tapping `Not Now` marks the current Health permissions version as handled and skips the request
  for that version

### Standalone Prompt After Profile Completion

If the current Health permissions version still needs a request after the profile is otherwise
complete, onboarding enters `.healthPermissions`.

That screen:

- explains that VillainArc needs additional Health permissions for newly added or upcoming features
- shows `Connect to Apple Health` and `Not Now`
- marks the current Health permissions version as handled only when the user taps one of those
  buttons
- requests authorization only when the user taps `Connect to Apple Health`
- then transitions to `.ready` whether access was granted or denied

So the standalone Health prompt is effectively a launch gate that requires the user to explicitly
handle the current permissions version once.

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
- schedule or cancel the weekly Health coaching background refresh based on the current notification
  settings and system permissions

The observer reinstall matters because observer queries are also created earlier at process launch.
If an earlier observer failed due to Health authorization state, the ready-time path can recreate it
cleanly.

## Failure and Retry States

Before the app is ready, onboarding can enter a generic bootstrap error (seeding or singleton setup
failed) with a Retry button that restarts the attempt. Sign-in failures are handled inside the
account surface itself and never abandon the flow.

## Reinstall Behavior

On reinstall, the local store and defaults are gone; the account's data lives on the FCT platform.
The app takes the front door again (carousel, sign-in, seed, profile, health), and enrollment after
sign-in restores the account's rows in the background. The profile typed during setup pushes as the
current truth; the account's workout history, plans, splits, and settings pull down and settle by
LWW.

## Post-Ready Education Surface

After the post-ready Health pass, `RootView` asks `WhatsNewPreferences.presentationOnLaunch()`
whether this launch has a release to announce, and presents the `WhatsNewSheet` if it does: the
aggregated highlights of every release the user hasn't seen yet
(`WhatsNewCatalog.featuresIntroduced(after:throughIncluding:)`), so a user who skips versions (e.g.
1.3 → 1.5) still sees every missed release's highlights in one sheet.

The decision logic (`WhatsNewPreferences`), pinned by `WhatsNewPresentationTests`:

- the last shown marketing version is stored in App Group `UserDefaults`
  (`whats_new_last_shown_version`)
- already on the current version → present nothing, and advance the stored pointer immediately
- no stored version **and** no legacy marker (`has_seen_onboarding_slideshow`, written by the
  removed pre-1.4 onboarding slideshow) → a brand-new install: present nothing, because the
  first-launch carousel is where a new user meets the app
- otherwise → What's New for the unseen releases (nothing if those releases contribute no
  highlights, e.g. a minor bug-fix build)

The version it was shown for is marked seen on **any** dismissal (Continue button or a swipe-away),
via the sheet's `onDismiss`, so it never reappears on the next launch.

The per-version changelog lives in `WhatsNewCatalog`. To announce a release's features, append a
`WhatsNewRelease` with its marketing version. The releases list starts at 1.4 — the 1.3 pillars are
the app's introduction and live in the onboarding carousel, so a user updating from 1.3 sees only
what's new in 1.4.

This surface is a gating decision, not a state machine state. It does not block `.ready`; it layers
on top via a SwiftUI sheet.

## Why `SetupGuard` Exists

App Intents can run before the foreground app has completed the current launch's onboarding path.

`SetupGuard` exists to block intent work until:

- bootstrap has completed
- singleton records exist
- the profile is complete (including fitness level and fitness-level timestamp)
- an active training goal exists
- any additional no-active-flow requirement is satisfied

That keeps shortcut/intents behavior aligned with the app's actual readiness rules.
