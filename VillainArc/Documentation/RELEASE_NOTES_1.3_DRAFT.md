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
- Added a dedicated Settings tab with app preferences, support/legal links, App Store review entry, and safe-area-aware scroll padding.
- Added Profile complete-day tracking for workout completion, sleep goal completion, steps goal completion, and hydration goal completion over the past two months.
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
- Fixed profile/settings navigation by moving Profile and Settings into real tabs instead of relying on profile buttons in Home and Health headers.
- Fixed Settings tab bottom spacing so content is not hidden behind the custom quick-action safe area bar.
- Fixed hydration goal ownership by removing the old `AppSettings.hydrationDailyGoalML` setting and using `HydrationGoal`/`HydrationDay` as the source of truth.
- Fixed hydration widgets and charts to use the active hydration goal instead of a global app setting.
- Fixed onboarding bootstrap cleanup so incomplete workouts and plans are removed during onboarding setup.
- Fixed exercise detail chart defaults and layout so max weight is the default and charts sit in the same card style as Health views.
- Fixed exercise-history rebuilds so standalone all-sets-complete performances can contribute to cached history.
- Fixed app documentation around the current 1.3 Health/profile scope, HydrationDay model, Profile tab, Settings tab, and expanded HealthKit surfaces.
