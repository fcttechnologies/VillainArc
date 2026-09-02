# VillainArc Project Guide

This is the product-level overview for VillainArc. Read this first to understand what the app is, how the main areas fit together, and which conventions show up everywhere else in the codebase. Then read the specific flow docs for the area you want to work on.

Use these docs in this order:

1. `Documentation/PROJECT_GUIDE.md`
2. the specific flow docs for the feature you want to change

## What VillainArc Is

VillainArc is a SwiftUI + SwiftData strength-training app built around:

- resumable workout logging
- reusable workout plans
- weekly or rotating workout splits
- plan suggestions and later outcome evaluation
- cached exercise analytics
- Apple Health integration for workouts, weight, sleep, daily steps, daily distance, and daily energy
- app-owned cardio sessions with outdoor routes, treadmill intervals, and optional Apple Health metrics
- Shortcuts, home-screen quick actions, Spotlight, widgets, and Live Activities that reuse the same app state

The main product areas are:

- onboarding and readiness
- profile hub and app settings
- home navigation and active-flow routing
- workout sessions
- cardio sessions
- workout plans and plan editing
- workout splits
- training condition status and history
- suggestions and outcomes
- exercise analytics
- health history, goals, and notifications

## Platforms

| Platform | Target | Build setting |
|---|---|---|
| iOS | `VillainArc`, plus the widget and intents extensions | `TARGETED_DEVICE_FAMILY = 1`, `IPHONEOS_DEPLOYMENT_TARGET = 27.0` |
| watchOS | `VillainArcWatchApp`, embedded companion | `TARGETED_DEVICE_FAMILY = 4`, `WATCHOS_DEPLOYMENT_TARGET = 26.0` |
| macOS | none | `SUPPORTS_MACCATALYST = NO`, `SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = NO` |

**Villain Arc ships no Mac target, and it is the one FCT app that doesn't.** The fleet default is
Mac-by-default; Villain Arc is its stated exception because training happens away from a desk. A
lifter logs a set between rests with a phone in one hand or a watch on the wrist, so the surfaces
that matter are the ones that travel. A Mac build would carry the whole app's weight to reach a
context the product is never used in. This is a product decision, not an oversight or a backlog
item — do not "fix" it by adding a Mac target.

## App Shell

After onboarding is ready, `Views/AppShell/ContentView.swift` owns:

- the root `TabView` (`Home`, `Cardio`, `Health`, `Profile`)
- global profile/settings sheets
- full-screen workout flow
- full-screen cardio flow
- full-screen workout-plan flow
- active workout/cardio/plan resume bars when those flows are minimized
- full-screen weight-goal-completion flow

## App-Wide Conventions

These rules are important because they shape most of the codebase.

### One Active Authoring Flow

VillainArc allows only one active workout, cardio, or plan flow at a time.

Starting a new workout, cardio session, or plan is blocked when any of these exist:

- a presented workout session
- a presented cardio session
- a presented plan flow
- a persisted incomplete `WorkoutSession`
- a persisted incomplete `CardioSession`
- a persisted incomplete `WorkoutPlan`

This keeps UI flows, intents, Spotlight entry points, and resume behavior aligned.

Important nuance:

- active flow lifecycle is separate from full-screen presentation
- users can temporarily dismiss workout/cardio/plan full-screen covers, access the rest of the app, and reopen from the active-flow resume bar
- while minimized, the workout/cardio/plan still counts as active work and still blocks creating a second active flow

Quick actions follow the same rule too:

- `Start Today's Workout` only runs when no workout, cardio, or plan flow is already active
- `Add Weight Entry` routes into the Health tab and presents the same sheet the foreground UI uses

For routing intents and deep links:

- foreground navigation intents and widget deep links can temporarily collapse active workout/plan covers so navigation can proceed
- workout/cardio/plan lifecycle state remains active underneath that temporary presentation collapse

Top-level tab chrome separates profile identity from app configuration:

- `Profile` is a dedicated tab and still supports the legacy profile sheet presentation path for deep links and sheets
- `Profile` owns profile fields, fitness-level editing/review, training goal editing, profile photo actions, training summary, muscle-map distribution, and the complete-day heatmap
- `Settings` is a dedicated tab and still supports sheet presentation from legacy routes
- `Settings` owns app settings, support/legal links, App Store review entry, and uses the shared quick-action bottom inset when shown as a tab

### Persist Real Drafts, Not Temporary State

Incomplete workouts and new-plan drafts are persisted SwiftData records, not temporary view-only state.

That is why:

- unfinished workout sessions can resume
- unfinished new-plan creation can resume
- edit copies of existing plans can be cleaned up safely on launch

### Store Canonical Values, Present User Units

Persisted load values are stored canonically in kilograms.

The app converts to the user’s preferred display unit when editing or presenting data and converts back to canonical values before save. This keeps calculations and merges stable even when the user changes unit preferences later.

If the user changes weight units while an incomplete workout or plan is in progress, the app migrates those in-progress display values from the old unit to the new unit so finish/save conversion remains correct.

The same general rule applies to Health caches:

- distance is stored canonically in meters
- energy and step values are stored as raw numeric totals for the day

### Goals Are Date-Ranged and Historical

Health goals are historical records, not mutable singleton flags.

Current goal patterns are:

- `WeightGoal` uses start/end timestamps and allows only one active goal at a time through app logic
- `StepsGoal` uses start/end calendar days and also keeps one active goal at a time through app logic
- `TrainingGoal` uses start/end calendar days and also keeps one active goal at a time through app logic

Replacing a goal does not mutate the old goal into the new goal. The app ends or deletes the old active record and inserts a new one. That preserves history and keeps charts and summaries date-correct.

### Training Condition Is Historical Context

Training condition is also stored as historical truth, not as a mutable singleton flag.

The current pattern is:

- `TrainingConditionPeriod` uses `startDate` and optional `endDate`
- only one active non-normal condition exists at a time through app logic
- ending a condition returns the user to the default "training normally" state without inserting a fake `normal` row
- replacing a condition ends the previous active period and creates a new one only when the kind actually changes

This keeps later split resolution, session adjustment, and suggestion reasoning grounded in real timestamps instead of whichever condition happens to be active today.

### Singletons Are Explicit Models

VillainArc keeps true singleton-style records in SwiftData:

- `AppSettings`
- `UserProfile`
- `HealthSyncState`

Startup code ensures they exist before the app treats launch as ready.

`UserProfile` holds what is **VillainArc's own** about the person:

- the required onboarding fields (gender, height)
- the user fitness level and last confirmed timestamp
- externally stored profile photo data

The name, the birthday, the country and the avatar are **not** here: they are the FCT account's,
one home for the whole fleet. The name comes off `account.profile`'s rows
(`AccountProfileField.displayName(from:)`) and the birthday off the account's trusted row, read
once per launch by `AccountBirthday` — which is what every age-based calculation is built on.

### One Store, Two Layers: SwiftData Local, the FCT Platform Canonical

VillainArc's store is local-first SwiftData in the App Group with **no CloudKit mirror**. What the
app authors syncs through the FCT platform (`FCTServerSync` + `FCTBlobSync` against the shared
backend, under the mandatory FCT account); what Apple Health canonically holds re-derives from
Apple Health per device. `Documentation/SYNC_FLOW.md` owns the whole split, the wire, and the
lifecycle.

The schema is `VillainArcSchemaV1` — the clean platform-era V1, currently unpublished:

- the live `@Model` classes ARE the schema; editing one edits V1 in place
- while V1 is unpublished, shape changes clear the store on dev devices (delete the app AND the
  App-Group store file — the store survives an app delete on its own)
- the first public release freezes V1; any later shape change then adds a real V2 with a migration
- every `@Model` must be in `VillainArcSchemaV1.models` (pinned by `SchemaContractTests`)
- a synced model's `id` carries `@Attribute(.preserveValueOnDeletion)`, or its deletions cannot
  ride the history feed
- a stored attribute must never be a Codable struct that contains an array: SwiftData reflects the
  struct into composite sub-attributes and traps materializing the nested keypath the first time
  persistent history over that model is read (which sync does on every drain); store encoded
  `Data` with a typed computed face instead (`ExercisePerformance.originalTargetSnapshot` is the
  in-repo example)

### Apple Health Is an Integration Layer

Apple Health is not the app’s primary source of truth.

The split is:

- `WorkoutSession` remains the app-owned training record
- `HealthWorkout` is a local Apple Health mirror/cache
- `WeightEntry` is the app’s local weight history model, which can also link to Apple Health samples
- `HealthSleepNight` is a per-wake-day Apple Health sleep rollup cache
- `HealthSleepBlock` is the persisted per-block sleep detail layer for naps and same-day secondary sleep blocks
- `HealthStepsDistance` and `HealthEnergy` are per-day Health caches
- `HealthHeart` is the grouped per-day heart cache for heart-rate range, resting heart rate, walking heart rate average, and HRV
- `HealthRespiratoryRate` and `HealthWristTemperature` are per-day Health caches for respiratory range and sleeping wrist temperature
- `HydrationEntry` is the app’s local water-intake model, which can also link to Apple Health dietary water samples
- `HydrationDay` is the per-day hydration aggregate that owns the day total, goal target, completion timestamp, and linked entries
- `HydrationGoal` is the historical local goal model for water-intake targets
- `CardioSession` is the app-owned cardio record, with `CardioRoutePoint` for app-tracked outdoor routes, `CardioMachineInterval` for manual machine distance, and HealthKit-only capture for sessions whose detail comes from Apple Health
- `AppSettings.temperatureUnit` controls whether wrist temperature displays in F or C while HealthKit values stay stored in Celsius
- Health widgets mirror the Health tab summary cards for weight, sleep, steps, energy, hydration, heart vitals, respiratory rate, and wrist temperature
- `WeightGoal`, `StepsGoal`, `SleepGoal`, `HydrationGoal`, and `TrainingGoal` are local app models

This keeps the app’s own domain logic independent from HealthKit while still letting Health data enrich the app.

### Background Sync Is Opportunistic

VillainArc installs Health observers and enables Health background delivery where available, but background updates are still best-effort. The app always needs a good foreground recovery path.

That is why the ready/settings flow also:

- reinstalls any missing observers
- refreshes Health background delivery registration
- runs a full Health sync and export reconciliation pass
- refreshes the weekly Health coaching background refresh schedule when notification settings allow it

## Launch and Readiness

The high-level launch path is:

1. `VillainArcApp` installs the shared model container and forwards Spotlight/Siri handoffs.
2. The app delegate registers the weekly Health coaching background refresh task and reinstalls Health observers on process launch.
3. `RootView` resumes the FCT account, starts `VASync`, then starts `OnboardingManager`; it also cleans up abandoned plan-edit copies and refreshes shortcut parameters.
4. `OnboardingManager` routes on the session first (`OnboardingEntry`): without one the window holds the front door — the intro carousel ending in the required sign-in step, or the sign-in gate alone on a device that is already set up. `ContentView` does not exist until `.ready`.
5. With a session, it decides whether this is first bootstrap or a returning launch.
6. Only after onboarding reaches `.ready` does `RootView`:
   - ask `AppRouter` to resume unfinished work
   - reinstall any missing Health observers
   - refresh Health background delivery registration
   - run the full Health sync plus export-reconciliation pass
   - request local-notification permission if it has not been requested yet
   - schedule or cancel the weekly Health coaching background refresh

That ordering matters. VillainArc does not resume unfinished work before setup is valid.

Setup is only considered valid once:

- required profile fields are complete
- fitness level and `fitnessLevelSetAt` are set
- one active training goal exists

## First Bootstrap

The first launch opens on the front door — the intro carousel, then sign-in — and only behind the
session does VillainArc take the local-first setup path:

- seed the bundled exercise catalog
- reindex Spotlight
- ensure singleton records exist
- route into profile onboarding

The store has no cloud mirror, so seeding waits on nothing. Cross-device convergence is an
identity property instead of a wait: catalog exercises carry deterministic ids and the singletons
fixed ids (`VASyncIdentity`), so an existing account's rows settle against the fresh seed under
LWW once the sync engine enrolls at sign-in. Restoring account data runs in the background from
that sign-in; readiness never waits on a pull.

## Returning Launch

Once the exercise-catalog bootstrap marker exists, launch is faster:

- ensure singleton records exist
- route into missing profile steps if needed
- route into training-goal setup if the profile fields are complete but no active goal exists
- sync the bundled exercise catalog only if its version changed
- decide whether the current Health permissions version still needs a one-time prompt
- otherwise transition directly to `.ready`

## Profile Hub and Settings

VillainArc uses a dedicated top-level Profile tab. Settings remains an `AppSettingsView` surface reached from Profile, app intents, and legacy settings routes; Home and Health no longer need profile buttons in their headers.

The profile surface owns:

- avatar and profile photo management
- gender and height editing
- fitness-level editing
- a fitness-level review cue when the current level has exceeded its time threshold (`beginner: 1 year`, `novice: 2 years`, `intermediate: 2 years`, `advanced: no cue`)
- active training-goal editing
- training summary stats, muscle-map distribution, workout streak, and complete-day heatmap

`AppSettingsView` remains the settings surface for:

- workout-history retention behavior
- workout logging preferences such as plan-target auto-fill
- Apple Health access and removed-data retention
- notifications
- display units
- support/legal links
- the feature-request row, which presents the app's feedback board (`FCTFeedback`'s
  `FeedbackBoardSheet` over `fct-technologies.com/villainarc/feedback/`, opened already signed in
  with the account controller's credentials). The sheet hangs off the Form: `appGroupedListRow`
  chrome cannot present one.
- manual App Store review entry point

## Main Product Areas

### Workout Sessions

Workout sessions are the live logging flow. They move through:

`pending -> active -> summary -> done`

- `pending` is the pre-workout suggestion gate for plan-backed sessions
- `active` is live logging
- `summary` is the finished-but-not-finalized stage
- `done` is the stable completed record

See:

- `Documentation/SESSION_LIFECYCLE_FLOW.md`
- `Documentation/SUGGESTION_AND_OUTCOME_FLOW.md`

### Cardio Sessions

Cardio sessions are app-owned records separate from strength workout logging. Each session is modeled as:

- an activity (`run`, `walk`, `hike`, `cycle`, `row`, `elliptical`, `stairStepper`, `swim`, or `other`)
- an environment (`outdoor` or `indoor`)
- a capture mode (`gpsRoute`, `machineIntervals`, or `healthKitOnly`)

The start UI currently surfaces the four primary presets: outdoor run, outdoor walk, treadmill run, and treadmill walk. The underlying model supports broader cardio activity types without replacing the schema again.

App-tracked outdoor sessions use foreground When In Use location access to record `CardioRoutePoint`s and render routes with MapKit. Machine-interval sessions use manual speed, duration, incline, resistance, cadence, or power intervals to calculate distance without GPS. HealthKit-only sessions keep app detail empty and rely on the linked Health workout for route, distance, heart rate, energy, splits, and effort detail.

When Apple Health workout write access is available, cardio sessions start an `HKWorkoutSession` to collect live heart rate, active energy, and walking/running distance, then save a linked Health workout mirror on finish. Without Apple Health access, the app-tracked route and machine-interval flows still work locally.

Cardio has its own Live Activity and resume bar. It participates in the same one-active-flow rule as strength workouts and plan creation.

### Workout Plans

Workout plans are reusable prescriptions. New plans are persisted drafts. Existing completed plans are never edited in place; the app uses copy-merge editing.

See:

- `Documentation/PLAN_EDITING_FLOW.md`

### Workout Splits

Splits answer “what should I do today?” and can point to plans. The app supports weekly and rotation scheduling. Home surfaces use split state to show today’s plan or rest status.

See:

- `Documentation/WORKOUT_SPLIT_FLOW.md`

### Suggestions and Outcomes

Suggestions are persisted coaching events attached to plan structure. Users review them in summary, at the deferred pre-workout gate, or from the plan suggestions sheet. Outcomes are resolved later from future workouts.

Exercise-level catalog settings can globally disable suggestion generation for a specific exercise. When that happens, VillainArc:

- stops generating new suggestions for that exercise everywhere
- hides progression-step tuning in the exercise suggestion settings sheet
- deletes unresolved suggestion state for that exercise when the user saves the setting

See:

- `Documentation/SUGGESTION_AND_OUTCOME_FLOW.md`

### Exercise Analytics

Exercise analytics are cache-backed. `ExerciseHistory` stores derived per-exercise aggregates and progression points, while raw completed performances still back the detailed history drill-down.

See:

- `Documentation/EXERCISE_HISTORY_FLOW.md`

### Health History and Goals

The Health tab combines:

- a top training condition status row with an editor sheet and condition history
- a latest sleep summary card backed by cached nightly sleep
- a dedicated sleep history screen with a day stage view, cached week/month block charts, grouped broader-range charts, weekday averages, and sleep highlights
- weight history with intraday day view plus weight goals
- daily steps and distance history with intraday day view plus steps goals
- daily energy history with intraday day view

That surface is also reused by App Intents and quick actions:

- read-only health intents answer from the same local caches and app-owned records the Health tab uses
- foreground health intents route into the same navigation destinations and sheets as the Health tab UI
- the home-screen `Add Weight Entry` quick action opens the Health add-weight sheet once the app is ready
- intent donations are triggered from foreground app UI actions; widget and Live Activity intent paths do not donate

Notification behavior is part of that surface:

- rest timer completions
- steps goal and coaching events, including double goal, triple goal, and new-best milestones when the app can observe the Health update in time

Health settings route through `AppSettingsView`, where Apple Health has its own detail screen alongside notifications and units.

Home-tab navigation also includes workout-centric history/detail routes such as:

- completed workout history (`WorkoutsListView`)
- Apple Health workout detail (`HealthWorkoutDetailView`)
- completed cardio history and detail routes in the Cardio tab

See:

- `Documentation/HEALTHKIT_INTEGRATION.md`

## Where To Read Next

If you are changing:

- launch, bootstrap, or readiness behavior:
  - `Documentation/ONBOARDING_FLOW.md`
- the FCT account, platform sync, or what does and does not ride the wire:
  - `Documentation/SYNC_FLOW.md`
- Health syncing, observers, or Health-backed UI:
  - `Documentation/HEALTHKIT_INTEGRATION.md`
- workout logging, finish flow, or resume behavior:
  - `Documentation/SESSION_LIFECYCLE_FLOW.md`
- plan authoring or edit-copy behavior:
  - `Documentation/PLAN_EDITING_FLOW.md`
- workout splits, today's workout, or split scheduling:
  - `Documentation/WORKOUT_SPLIT_FLOW.md`
- suggestions or outcome evaluation:
  - `Documentation/SUGGESTION_AND_OUTCOME_FLOW.md`
- cached exercise analytics:
  - `Documentation/EXERCISE_HISTORY_FLOW.md`
- plan templates and AI plan generation:
  - `Documentation/TEMPLATES_FLOW.md`
- the Apple Watch companion app or phone↔watch sync:
  - `Documentation/WATCH_COMPANION.md`
