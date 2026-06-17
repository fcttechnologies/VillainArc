# Villain Arc 1.4 Device Test Checklist

Run this on the GM-Xcode MacBook before archiving/uploading 1.4 build 22.

## Fresh Install / Permissions

- Fresh install, complete onboarding, and confirm the app reaches Home.
- Start an outdoor cardio session from Cardio.
- On the app's Location explanation screen, tap Continue.
- Confirm the iOS Location permission sheet appears immediately.
- Grant When In Use and confirm outdoor cardio starts recording.
- Start a treadmill session and confirm it does not ask for Location.

## Cardio Detail Routing

- Finish an indoor Health-backed treadmill session.
- Open the finished session from Home recent workouts.
- Confirm it opens directly in the Health workout detail.
- Confirm there is no "View in Health" button/path on that indoor cardio detail.
- Open a finished outdoor run/walk from the Cardio tab.
- Confirm the route map/detail path still works.
- If the outdoor session has a Health workout mirror, confirm View in Health still opens the Health workout detail.

## Sharing

- Finish a strength workout and share its summary card.
- Finish a cardio session and share its summary card.
- Open a saved workout plan and share its plan card.
- Confirm the share sheet previews the intended image/content and does not show placeholder values.

## Health Workout Zones

- On an iOS 27 device with a Health workout that has heart-rate zone data, open the workout detail.
- Confirm the Zones section labels the source as Apple Health.
- Confirm zone ranges and durations look consistent with Apple Health.
- Open a workout without native zone data and confirm estimated zones still appear when heart-rate samples are available.

## Regression Sweep

- Home recent workouts includes the latest strength and cardio sessions.
- Cardio tab history only shows route sessions in the route-history map/list path.
- Completed indoor cardio no longer double-navigates into Health workout detail.
- Settings -> Subscription still opens purchase/restore surfaces.
- AI plan generation and AI exercise replacement remain hidden on unsupported devices and available on Apple Intelligence devices.
