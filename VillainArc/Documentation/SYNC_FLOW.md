# Sync Flow — the FCT Account and Platform Sync

How Villain Arc's data reaches the FCT platform and comes back: the account lifecycle, the sync
engine, what rides the wire and what deliberately never does, and what a sign-out or deletion
means locally. The store itself (App Group, clean V1, no CloudKit) is covered in
`PROJECT_GUIDE.md`.

## Main Files

- `Data/Sync/VASyncSchema.swift` (+ `+Plans`, `+Sessions`, `+Suggestions`) — the wire: 25
  `SyncedModel` conformances, table names, columns, link roles
- `Data/Sync/VASyncIdentity.swift` — the converging identities (singleton fixed ids, catalog
  deterministic ids)
- `Data/Sync/VASync.swift` — the bootstrap: account events → engine lifecycle, triggers, the
  staging sweep, the status surface, the clears
- `Data/Services/Platform/VAAccount.swift` — the one `AccountController`
- `Views/Settings/AccountSection.swift` — identity, sync status row, sign-out, the deletion doors
- `Root/RootView.swift` — the account gate: the sign-in surface as the whole window, never a layer
  over the app
- Server half: the `va.*` tables in the FCTPlatform repo's migrations

## What Syncs

The app's own authored rows, in every lifecycle state (drafts included — a per-state filter would
strand a completed session's children, whose history entries fire at their save, not at their
parent's completion):

- workouts as authored: `WorkoutSession`, `PreWorkoutContext`, `ExercisePerformance`,
  `SetPerformance`
- cardio as authored: `CardioSession`, `CardioRoutePoint`, `CardioMachineInterval`
- plans and splits: `WorkoutPlan`, `ExercisePrescription`, `SetPrescription`, `WorkoutSplit`,
  `WorkoutSplitDay`, `RepRangePolicy`
- the coaching record: `SuggestionEvent`, `SuggestionEvaluation`, `PrescriptionChange`
- goals and identity: the five goal models, `TrainingConditionPeriod`, `UserProfile` (singleton),
  `AppSettings` (singleton)
- what the user has done to a catalog exercise: `ExercisePreference`, sparse — a row exists only
  for an exercise they actually touched (favorited, added, or tuned)
- one byte surface: the profile photo, through `FCTBlobSync` (`va.user_profile.photo`; bytes in
  the object store, preview riding the row, `profileImageData` as the local render cache)

## What Never Syncs, and Why

- the Apple Health mirror family (`Health*`) — Apple Health is its canon; each device's anchored
  Health sync refills it
- `WeightEntry`, `HydrationDay`, `HydrationEntry` — authored in-app but exported to Apple Health
  at write time, which makes Health their canon (Apple's own Health sync carries the samples);
  named cost: weight/hydration continuity rides Apple Health, not the FCT account
- `ExerciseHistory` / `ProgressionPoint` — derived caches, rebuilt in full after any pull that
  lands rows (`ExerciseHistoryUpdater.rebuildAllHistories`)
- `HealthSyncState` (per-device anchors), `RestTimeHistory` (a per-device last-used stamp)
- `Exercise` — reference data, not the user's. The catalog ships in the app binary
  (`ExerciseCatalog`) and is seeded locally on every install, so syncing it made every account
  store an identical copy of a catalog nobody had personalised. Only `ExercisePreference` rides
  the wire. Because the catalog is unsynced the engine's `clearSyncedData` no longer reaches it,
  so a departing account's exercise rows are cleared by `VASync.locallyClearedModels` instead —
  the two lists partition the schema, and a model in neither outlives the account that made it
- live-session pointers (`activeExercise`, `activeInSession`, `activePerformance`) and the
  device-local `healthWorkout` mirror links

## Identity Conventions

- `AppSettings` and `UserProfile` are singletons under fixed uuids (`VASyncIdentity`), so two
  devices that each create one converge as one row under LWW
- `ExercisePreference` rows derive their uuid deterministically from the catalog id they name
  (under their own namespace, distinct from the local catalog's), so two devices that each
  favorite the same exercise converge as one row; safe because a preference is never deleted, so
  a deterministic id never meets its own tombstone
- everything else mints `UUID()` once, on the authoring device
- every synced model's `id` carries `@Attribute(.preserveValueOnDeletion)` — without it a deletion
  cannot ride the history feed

## Lifecycle

`RootView` starts `VASync` with the one `AccountController` and resumes the session; the engine
exists only while an account does:

- `.enrolled` / `.resumed` → build the engine (state file + blob store beside the store in the App
  Group), enroll marks-all-dirty on first sign-in, then cycle
- `.needsReauthentication` → engine idles, nothing cleared; the sign-in gate takes the window back
  over intact data
- `.signedOut` → barrier-gated clear: one last push while a token exists (`signOutPreflight`),
  then the engine's own non-discarding clear (refuses while anything is unpushed), then the local
  caches and bootstrap markers go and onboarding restarts
- `.switched` / `.deleted` → unconditional discard (account A's rows must not become account B's;
  5.1.1(v) respectively), then onboarding restarts

What asks for a cycle, and which kind. A local write is a reason to send and never a reason to
ask, so the trigger rungs — `SyncScheduler.engineTriggers`: in-process saves debounced 250 ms with
the engine's own applier excluded, plus `RemoteHistoryChangeTrigger` for widget/intents-extension
writes — spend a **push**; a settled blob upload asks for one too. Foregrounding, the network-path
monitor's return-to-signal, and every Realtime nudge spend a **full** cycle, because a pull is the
only thing any of them can act on. A request landing mid-cycle folds into the running one at the
stronger of the two kinds.

The nudge rung is `SyncNudgeChannel`, foreground-only: one socket on the account's private
`sync:<account>` topic, started with the engine and on each `foregrounded()`, released on
`backgrounded()`. Nothing rides it — losing it degrades to pull-on-foreground and post-push, which
is what correctness rides on.

Rows the engine applies bypass every app-side write seam, so `didApplyRemoteChanges` refreshes the
derived surfaces directly: Spotlight reindex, widget reload, the exercise-analytics rebuild, and
profile-photo hydration (cache or lazy digest-verified fetch — never through `setPhoto`, which
would re-stage bytes the account already holds).

## The Deletion Doors

`AccountSection` assembles `FCTAccount`'s settings section with Villain Arc's truths: the narrow
door erases `va.*` server-side and calls `VASync.eraseAppDataLocally()` (signed-in-empty at cursor
0); the account door runs the platform's full deletion and lands in the `.deleted` wipe. Both are
barrier-gated by the outbox census, split retrying/stuck, and "could not count" throws rather than
reading as zero.

## Testing

`VillainArcTests/Sync/VASyncContractTests.swift` instantiates the fleet's adopter contract suites:
all record scenarios over VA's schema (with VA's seven declared joins driven through every arrival
order) and all blob scenarios over the profile-photo adapter. The suites assert on the user's
data, never the engine's bookkeeping. Run them with the full suite, or focused:
`-only-testing:VillainArcTests/VASyncContractTests`.
