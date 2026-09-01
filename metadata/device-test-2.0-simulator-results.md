# Villain Arc 2.0 — what a simulator can answer

A pass at `device-test-checklist-2.0.md` driven entirely on simulators, to shrink the set that needs
a phone in hand. Run 2026-09-01 on two iOS 27.0 iPhone 17 Pro simulators, signed into the shared FCT
test account, against a **Release** build except where noted.

**The checklist's header is wrong.** It claims "Everything here is device-gated: it is the set the
simulator and the gate cannot answer." A simulator answers a good part of it. The genuinely
hardware-gated set is at the bottom of this file and it is eleven lines, not the whole list.

No seed, reset, demo-data or delete-account path was run. `ScreenshotStudioSeeder.seedAll()` and
every `DebugOperations` reset were left untouched; the Release build compiles the whole `#if DEBUG`
menu out, which is why most of this ran on Release.

## Proved on simulator

**First run — the front door**

- *Genuine first run.* A simulator erased before install is a stronger version of "delete the app
  and the App-Group store files": no container, no defaults, no store.
- *The intro carousel appears and ends in the sign-in step.* Five pages, then the three-provider
  step (Apple, Google, email+password).
- *No way past the front door without a session.* The sign-in step is the carousel's last page.
  Swiping forward and swiping down both do nothing — it is the window, not a sheet, so there is
  nothing to dismiss. `RootView` renders it instead of `ContentView`.
- *The gate alone appears on a device already set up.* Relaunching with a bootstrap marker but no
  session returns the sign-in step without the carousel, matching `OnboardingEntry.forLaunch`.
- *Sign in with email and password.* Signed in as the test account by typing the credential into the
  real form; the app went to "Restoring Your Account" and then into profile onboarding.
- *Onboarding reaches Home.* **Partial** — name, Location, birthday and gender were completed by
  hand. Height, fitness level and training goal were completed by the Debug build's Skip
  (`completeOnboardingWithDebugData`, which only fills missing fields and deletes nothing), because
  the height step cannot be driven by the simulator automation at all — see Failed/suspicious.
- *The onboarding sheet resize.* Not judged here; that is Fernando's call. The recording is
  `metadata/device-test-2.0-onboarding-resize.mp4`, 9s, two real step transitions at real speed:
  name → Location (0–6s) and birthday → gender (6–9s).

**Permissions**

- *The Location explanation step's Continue raises the iOS sheet immediately.* Reproduced twice, on
  two separate first runs. No delay, no intermediate screen.
- *The app requests When In Use only.* The system sheet offers Allow Once / Allow While Using App /
  Don't Allow and **no "Always"** option, which is the request scope showing through the sheet
  itself.
- *Granting When In Use proceeds.* Onboarding advanced straight to the birthday step.
- *A treadmill session never asks for Location.* Started a Treadmill Run; no permission prompt.
  **Partial** — location had already been granted on this device, so this shows no *prompt* rather
  than proving no *request*. The stronger version, on a device where location is still
  undetermined, was not run.

**Sync across devices** — run on two simulators, A and B, both signed into the account.

- *Plans and completed sessions arrive without a manual refresh.* A freshly installed, freshly
  signed-in device pulled down the "Push Day" plan with its 4 exercises, a completed Outdoor Run
  (Aug 29, 3.5 mi, 8:35/mi) with its **route drawn on the cardio map**, and per-exercise history
  (Bench Press, 14 times, 167.5 lbs). Nothing was tapped to make it happen.
- *Author on device A, confirm it reaches device B.* **Proved.** The Treadmill Run finished on A at
  14:08:22 was read back out of B's own store minutes later — `run` / `indoor`, started
  `2026-09-01 14:08:22`, `59.8 m` — alongside the older Outdoor Run. B was a separate simulator,
  installed and signed in independently.
- *The profile does **not** arrive.* See Failed/suspicious #7. Splits were not tested (the account
  holds none), and the deletion/tombstone line was not run, because it requires deleting a
  sync-enrolled row.

**Regression sweep**

- *Home recent workouts includes the latest cardio session.* The restored Outdoor Run appears in
  Home's recent-workout row. The strength half is covered by the restored plan and exercise history
  rather than by a session finished in this run.
- *Force-quit mid-session, relaunch, resume.* Started a Treadmill Run, force-quit with
  `simctl terminate`, relaunched: the app came back **directly into the active session** with its
  state intact. **Partial** — this was a cardio session, and it restored the full session UI rather
  than the resume bar the line names; the strength-workout resume-bar path was not exercised.
- *Finishing an indoor cardio session does not crash.* Finished the treadmill session (1 interval,
  0:00:27, 0.04 mi, 12:00/mi) through the effort sheet into the session detail. **Partial** — the
  line names the *Health* workout detail, a different surface, which was not reached.

**Apple Intelligence, the negative case** — see Failed/suspicious; this did not come out clean.

## Needs real hardware

Eleven lines. Each costs Fernando time with a phone, so each has its reason.

- **Password AutoFill offers the saved credential on return.** The *save* half already works in a
  simulator: signing in on device B raised iOS's own **"Save Password?"** prompt for the app, which
  only appears when the associated-domain claim resolves. What is left for a device is the offer on
  a later sign-in against a real keychain.
  *Both halves of the association are verified, so a failure on device is not a config problem:* the
  app declares `webcredentials:fct-technologies.com`, and the site serves
  `X26SC78YDG.com.fcttechnologies.VillainArc` under `webcredentials` at
  `/.well-known/apple-app-site-association` (HTTP 200, `application/json`).
- **Sign in with Apple.** Needs a real Apple ID signed into the device.
- **Grant Apple Health and confirm the export/import reconciliation pass runs.** The simulator's
  HealthKit store is empty, so a reconciliation pass over it proves nothing.
- **Deny Apple Health and still reach Home.** Same reason — worth doing on device in the same pass
  as the grant.
- **Outdoor route recording with the screen locked.** Needs real GPS and a real locked screen;
  simulated location does not exercise the background-location path.
- **All five Apple Watch lines** (timer page jump, live session mirroring, completing a set from the
  wrist, the rest-complete haptic, treadmill indoor-distance double counting). No paired watch, and
  haptics do not exist in a simulator.
- **Apple Intelligence, the positive case** (generate a plan from a sentence; replace an exercise).
  On-device inference needs Apple Intelligence hardware.
- **The ten App Shortcuts by voice, in two locales.** Needs real speech to Siri.
- **Restore Purchases on a device that already owns Pro**, and **Family Sharing not masking the
  purchaser's active Pro.** Both need real App Store accounts and a real family group.

The subscription paywall's own content (monthly, yearly, 7-day trial) is *not* on this list only
because it went untested here, not because it needs hardware — a StoreKit configuration would let a
simulator answer it.

## Failed / suspicious

**1. `ONBOARDING_FLOW.md` says the front door is always dark. It is not.**
The doc states "The front door is dark whatever the app's appearance setting says — a first launch
has no setting yet." On a first launch with the simulator in Light appearance the carousel and
sign-in render **light**; switched to Dark, they render dark. It follows the system.
`RootView` applies `.preferredColorScheme(appSettings.first?.appearanceMode.preferredColorScheme)`,
which is `nil` on first launch, and nothing in `FCTOnboarding` or `FCTAccount` forces dark —
`OnboardingFlow` reads the ambient `colorScheme` and even picks per-scheme screenshots with it.
Either the doc or the intent is wrong. Screenshots: light and dark first launches.

**2. The height step cannot be driven by simulator automation at all.**
Every `axe` command — `describe-ui`, `tap` by id, `tap` by coordinate, and even the low-level
`touch` — dies on this one screen with:
`-[__NSCFString translation]: unrecognized selector`, thrown inside
`+[FBSimulatorAccessibilitySerializer nestedRecursiveDescriptionFromElement:token:]`.
Every axe command opens an accessibility session first, so nothing gets through while the screen is
up. The app is fine — it keeps running, and the step works when driven by a human.
The birthday step's picker serializes fine, so the trigger is specific to the height step's two
side-by-side `.wheel` pickers in an `HStack`. **This reads as an FBSimulatorControl bug rather than
an app defect, and I could not prove which**; ruling it out would mean checking whether the metric
branch (a single cm picker) also crashes. It blocks any automated UI coverage past this step, which
is why the Debug Skip was used.

**3. No Live Activity rendered for an active cardio session — unresolved.**
With a Treadmill Run running, the Lock Screen showed no Live Activity. What was checked:
`AppSettings.liveActivitiesEnabled` is **1** in the store (read directly out of the App-Group
SQLite), so the app's own guard passes; `CardioActivityManager.requestActivity` logs on failure and
**no such error was logged**; the device log shows no activity-creation event for the app at all.
That leaves `ActivityAuthorizationInfo().areActivitiesEnabled` returning false on this simulator as
the likely cause, which would be an environment limit and not a bug — but I could not confirm it,
so **this line stays unproven rather than passed, and the Live Activity lines still need a device.**
Worth knowing: `live_activities_enabled` is a **synced** field (`VASyncSchema`), so a device that
pulls the account's settings inherits whatever the last device set.

**4. "Ask AI" is shown unconditionally.**
`ContentView.swift:232` appends the Ask AI action with no availability gate, while
`AskVillainArcAssistant`, `AIWorkoutPlanGenerator` and `AIExerciseReplacementSuggester` all check
`SystemLanguageModel.default.availability`. The checklist's "both surfaces are hidden rather than
failing" line names plan generation and exercise replacement, not Ask AI, so this may be by design
(the sheet can explain unavailability itself). **I could not establish whether this simulator
reports Apple Intelligence as available**, so I cannot say the entry point is wrongly shown — the
premise is unverified either way. Worth one look on a device without Apple Intelligence.

**7. The profile does not reach a second device, though everything else does.**
Device B — separate simulator, own install, signed into the same account — pulled down 1 workout
plan, 14 workout sessions, 2 cardio sessions, 4 exercise histories and the app settings, but its
`ZUSERPROFILE` row came back **empty**: no name, no height, no birthday, gender `notSet`. Onboarding
on B duly asked for the name again, with an empty field, and still did after a force-quit and
relaunch. `UserProfile` *is* sync-enrolled (`va.user_profile`, a singleton on a fixed UUID), so both
devices author the same row id.
**No data was lost:** A's profile was re-read after B signed in and after a full A relaunch and
re-sync, and is intact (`Fernando` / 175 / intermediate). B's empty row did not clobber it.
This may be the documented design rather than a defect — `ONBOARDING_FLOW.md` says "the profile
typed during setup pushes as the current truth" while only "workout history, plans, splits, and
settings pull down" — in which case **the checklist line expecting the profile to arrive is the
thing that is wrong**. Worth settling deliberately, because a singleton on a fixed id where the
newer empty row could win LWW is a shape that bites later.

**5. The finish-effort dial reports an accessibility value of `nan`.**
On the workout finish sheet, `workoutFinishEffortCard-1` exposes `Slider "Workout effort dial" =nan`
before a rating is chosen. VoiceOver would read that. Minor, but it is a real value being published.

**6. The Debug build's test-account sign-in bar renders underneath the carousel's Continue button.**
`DebugTestAccountSignInBar` overlaps `Continue` on the front door, and a tap at its centre reaches
neither control. Debug-only, so it ships to nobody, but it makes the affordance unusable on the
first carousel page.

## What this run left on the shared FCT account

Additive only — nothing was deleted, no reset path was run.

- The profile was completed during onboarding and **pushes as current truth**, read back out of the
  store: name `Fernando`, birthday 2001-09-01, height 175 cm, fitness level intermediate, gender
  `other`, plus one active `generalTraining` `TrainingGoal` if none existed. Height, fitness level
  and gender are the Debug Skip's defaults — *Male* was selected on the gender step but Skip
  bypasses that step's own save, so the stored value is `other` rather than what was tapped.
- One saved password in **simulator B's** keychain, from accepting iOS's "Save Password?" prompt.
  Both simulators were deleted at the end of the run, which takes it with them.
- One completed **Treadmill Run**, Sep 1 2026 2:08 PM, 0:00:27, 0.04 mi, one interval at 5.0 mph.
  It exists because cancelling an in-progress session would have deleted a sync-enrolled row and
  tombstoned it to every device; finishing it was the only close that adds rather than removes.

## Not attempted

Named so the gaps are visible rather than implied: the tombstone/deletion line (it requires deleting
a sync-enrolled row, which this run was barred from), the splits half of the sync line (the account
holds no splits), the Health-mirror re-derivation line, the subscription paywall contents, the
widgets on the Home Screen, and the mid-workout weight-unit migration. All of these look answerable
in a simulator; they ran out of run, not out of capability.
