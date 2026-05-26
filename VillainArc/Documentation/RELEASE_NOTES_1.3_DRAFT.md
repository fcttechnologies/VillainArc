# Villain Arc 1.3 Draft Change List

Working draft for internal review and future App Store "What's New" copy. Keep this developer-facing and detailed enough to preserve what changed; compress later for customer-facing release notes.

## Added

- Added expanded HealthKit permission coverage for heart-rate range, resting heart rate, walking heart rate average, heart-rate variability, respiratory rate, sleeping wrist temperature, and dietary water.
- Added Health tab cards and history screens for heart-rate range, resting heart rate, walking heart rate average, HRV, respiratory-rate range, and sleeping wrist temperature.
- Added matching Health widgets for heart vitals, respiratory rate, wrist temperature, and hydration.
- Added hydration tracking with manual water entries, Apple Health dietary-water import/export, active hydration goals, hydration goal history, hydration charts, and hydration goal completion notifications.
- Added `HydrationDay` as the daily hydration aggregate that stores total volume, goal target, completion timestamp, and linked entries.
- Added an Add Water quick action to the main action bar.
- Added a dedicated Profile tab with profile editing, photo editing, training summary stats, muscle-map distribution, workout streak, and a complete-day heatmap.
- Expanded Settings with app preferences, support/legal links, App Store review entry, and safe-area-aware scroll padding.
- Added Profile complete-day tracking for workout completion, sleep goal completion, steps goal completion, and hydration goal completion over the past two months.
- Added a dedicated Cardio tab with a map-first recent-routes view, start cards for outdoor run, outdoor walk, treadmill run, and treadmill walk, plus recent cardio history and detail views.
- Added `CardioSession`, `CardioRoutePoint`, and `CardioTreadmillInterval` SwiftData models so cardio can be app-owned instead of only mirrored from Apple Health.
- Added a full-screen active cardio flow with minimize/resume behavior, outdoor route recording, treadmill interval entry, live metrics, finish/cancel confirmation, and completed-session detail.
- Added manual treadmill support where users can enter speed in mph, duration, and incline for each interval so Villain Arc can calculate distance without GPS or Apple Health.
- Added outdoor cardio route recording with When In Use location permission for users who do not have Apple Health workout data available.
- Added optional Apple Health live cardio workout support for supported devices and permissions, including Health workout export, live heart rate, active energy, walking/running distance, and linked Health workout mirrors.
- Added a separate Cardio Live Activity and Dynamic Island presentation with elapsed time, distance, pace, heart rate or energy, and route/interval count.
- Added active cardio resume bars so minimized cardio sessions can be reopened from the app shell.
- Added cardio session completion into Profile workout streak and complete-day workout credit.
- Added a MuscleMap local Swift package and used it for exercise/profile muscle diagrams.
- Added richer Exercise Detail content: muscle map, personal records, polished progression charts, how-to steps, recent performances, and a route to full exercise history.
- Added workout plan history and training insight cards to plan details.
- Added the ability to open source workouts from exercise history rows when a performance is tied to a completed workout.
- Added support for standalone/imported completed exercise performances in exercise-history rebuilding.
- Added a sleep weekday chart mode switch for average sleep, average bedtime, and average wake time.
- Added a setting for whether planned workout previous-set references use any matching workout or the last completed session from the same plan.
- Added a temperature unit setting for wrist temperature display.
- Added debug tools for seeding workout data, seeding Health sample scenarios, and touching all model tables.

## Fixed

- Fixed Health workout detail rendering when the original Apple Health workout is no longer available; the screen now avoids showing broken empty heart-rate sections.
- Fixed Health workout summaries to include average and maximum heart rate when cached values are available.
- Fixed profile/settings navigation by moving Profile into a real tab instead of relying on profile buttons in Home and Health headers, while keeping Settings as a routed settings surface.
- Fixed Settings bottom spacing so content is not hidden behind the custom quick-action safe area bar.
- Fixed active-flow protection so regular workouts, workout-plan creation/editing, and cardio sessions cannot be started on top of each other.
- Fixed app resume behavior so unfinished cardio sessions are discovered and restored like unfinished strength workouts and plans.
- Fixed workout history duplication for cardio-linked Apple Health workouts by excluding Health workout mirrors that already belong to a `CardioSession`.
- Fixed hydration goal ownership by removing the old `AppSettings.hydrationDailyGoalML` setting and using `HydrationGoal`/`HydrationDay` as the source of truth.
- Fixed hydration widgets and charts to use the active hydration goal instead of a global app setting.
- Fixed onboarding bootstrap cleanup so incomplete workouts and plans are removed during onboarding setup.
- Fixed exercise detail chart defaults and layout so max weight is the default and charts sit in the same card style as Health views.
- Fixed exercise-history rebuilds so standalone all-sets-complete performances can contribute to cached history.
- Fixed app documentation around the current 1.3 Health/profile/cardio scope, HydrationDay model, Profile tab, Settings surface, Cardio tab, and expanded HealthKit surfaces.
