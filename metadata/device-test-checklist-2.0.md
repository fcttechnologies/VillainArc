# Villain Arc 2.0 Device Test Checklist

Run this on a real device before archiving and uploading 2.0. `scripts/install-ios.sh` builds Release
and installs on the paired iPhone.

Not every line here needs hardware. A simulator answers the front door, the permission scope, the
onboarding path, the account restore, cross-device sync and force-quit resume;
`device-test-2.0-simulator-results.md` records what a simulator pass proved and names the eleven
lines that genuinely need a phone, a watch, real GPS, real speech, or a real App Store account.
Read it first and run the short set rather than the whole list.

## First Run — The Front Door

- Delete the app AND the App-Group `VillainArc.store*` files, so this is a genuine first run.
- Launch and confirm the intro carousel appears, ending in the sign-in step.
- Confirm there is no way past the front door without a session.
- Sign in with Apple. Sign out, relaunch, and confirm the gate alone appears (no carousel) on a device already set up.
- Sign in with email and password, and confirm Password AutoFill offers the saved credential (the `webcredentials:fct-technologies.com` association).
- Complete onboarding through to Home: name, Health, Location, birthday, gender, height, fitness level, training goal.
- Watch the onboarding sheet resize between steps and judge whether the movement reads as one beat or two.

## Sync Across Devices

- On a second device signed into the same account, confirm the profile, plans, splits, and completed
  sessions arrive without a manual refresh.
- Author a workout on device A and confirm it reaches device B.
- Delete a plan on device B and confirm the deletion reaches device A (tombstones ride the history feed).
- Confirm Apple Health mirror data, weight, and hydration are re-derived per device rather than synced.

## Permissions

- Grant Apple Health during onboarding and confirm the export/import reconciliation pass runs.
- Deny Apple Health and confirm the app still reaches Home and logs workouts locally.
- Start an outdoor cardio session, tap Continue on the Location explanation step, and confirm the iOS
  permission sheet appears immediately.
- Grant When In Use and confirm the route records.
- Start a treadmill session and confirm it never asks for Location.
- Confirm outdoor route recording with the screen locked — this needs verifying, not assuming: the app
  requests When In Use only.

## Apple Watch

- With a paired watch, start a rest timer on the phone and confirm the watch jumps to the timer page.
- Start a strength workout and confirm the live session page mirrors exercise, set position, and target.
- Complete a set from the wrist and confirm the phone reflects it.
- Confirm the wrist haptic fires when a rest completes with the watch app frontmost.
- Run a treadmill session with the watch on and check for indoor-distance double counting against
  VA's own interval-derived distance.

## Apple Intelligence

- On an Apple Intelligence device: generate a plan from a sentence, and replace an exercise from a plan.
- On a device without Apple Intelligence: confirm both surfaces are hidden rather than failing.

## Live Activities, Widgets, Siri

- Start a workout and a cardio session and confirm each Live Activity renders on the Lock Screen and
  in the Dynamic Island.
- Add each Health widget to the Home Screen and confirm it shows real data rather than placeholders.
- Run each of the ten App Shortcuts by voice, in English and in at least one other shipping locale.

## Subscription

- Settings -> Subscription opens the paywall; monthly and yearly both show the 7-day trial.
- Restore Purchases works on a device that already owns Pro.
- With Family Sharing, confirm a family member's own lapsed entry does not mask the purchaser's active Pro.

## Regression Sweep

- Home recent workouts includes the latest strength and cardio sessions.
- Finish an indoor cardio session and tap through to the Health workout detail — the 1.3 crash path.
- Change weight units mid-workout and confirm in-progress values migrate rather than reinterpret.
- Force-quit mid-workout, relaunch, and confirm the session resumes from the resume bar.
