# App Review Notes

Paste into App Store Connect -> App Review Information -> Notes.

## Summary

Villain Arc is a strength-training and cardio tracker with on-device AI plan generation and exercise replacement, Apple Health integration, cross-device sync through an FCT account, Live Activities, widgets, and App Intents. A free FCT account is required to use the app; sync and account services are hosted by FCT on Supabase.

This is release 1.4.0. Main additions over 1.3.0:

- Share cards for completed workouts, cardio sessions, and workout plans.
- Apple Health heart-rate zones on iOS 27, with the existing estimated zone fallback kept for older OS versions or workouts without zone data.
- Cardio detail routing cleanup: outdoor route sessions open route-first details, while completed indoor Health-backed cardio opens directly in the Health workout detail.
- Finished cardio sessions now appear in Home recent workouts.
- Location permission education flow refined for outdoor cardio: the app explanation step now uses Continue and proceeds directly to the iOS Location permission sheet.

## Demo Account

Required. Villain Arc gates its entire interface behind an FCT account: a clean install shows the onboarding carousel and then the sign-in screen, and there is no app behind it until a session exists. Sign in with Apple, or email.

Reviewer credentials: [FILL IN BEFORE SUBMITTING — email + password for a seeded FCT review account.]

## Required Permissions

| Permission | Required for | When triggered |
|---|---|---|
| HealthKit (Share + Read) | Workout import/export, weight, sleep, steps, distance, energy, heart-rate vitals, respiratory rate, wrist temperature, and dietary water. | First launch onboarding, and again only after a new Health permissions catalog version ships. |
| Location When In Use | Outdoor cardio route recording for run/walk sessions. When-In-Use only. | After the user chooses an outdoor cardio session and taps Continue on the app's location explanation screen, the iOS system permission sheet appears. Treadmill sessions never trigger Location. |
| User Notifications | Local notifications for rest timers, goals, hydration, and weekly health coaching recaps. No remote push or APNs. | After onboarding reaches the ready state. |
| Camera / Photo Library | Optional profile photo. | Only when the user taps to change their profile photo. |

No advertising identifiers, tracking permissions, or App Tracking Transparency prompts, and no third-party analytics or tracking SDKs. The privacy nutrition label and `PrivacyInfo.xcprivacy` declare two separate groups: account-scoped content the user syncs (name, email, user ID, fitness, health, precise location, photos, other user content — all linked to identity, app functionality only), and anonymous diagnostics (crash, performance, other diagnostic, product interaction — not linked to identity, keyed to a random install identifier).

## How To Exercise The New 1.4 Features

1. Share cards: finish any strength workout, cardio session, or open a saved workout plan, then tap Share in the summary/detail surface.
2. Cardio detail routing: complete or import an indoor Health-backed treadmill workout, then open it from Home recent workouts. It should open directly in the Health workout detail without a second "View in Health" navigation step.
3. Outdoor cardio detail: complete an outdoor run or walk, then open it from the Cardio tab. The route map/detail path remains available.
4. Home recent workouts: finish a run, walk, or treadmill session and confirm it appears beside recent strength workouts.
5. Apple Health zones: on iOS 27 with a Health workout that includes heart-rate zone data, open the Health workout detail. The Zones section uses Apple Health zones; older OS versions or workouts without zones keep estimated zones.
6. Location permission fix: fresh install, start an outdoor cardio session, tap Continue on the app explanation step, then grant the iOS system Location permission.

## Existing 1.3 Surfaces Still Available

- AI plan generation: Home -> expanded plus -> Create Plan -> Generate with AI.
- Plan templates: Create Plan -> Templates -> pick one -> Build Full Program.
- AI exercise replacement: any plan -> tap an exercise -> Replace -> AI Suggestions.
- Cardio tab: Outdoor Run, Outdoor Walk, Treadmill Run, Treadmill Walk.
- Health Trends, Sleep Timing Insights, Correlation Insights, and Hydration.

## App Intents / Siri Shortcuts

App Shortcuts ship in `VillainArcShortcuts.swift` for starting workouts/cardio, viewing recent workout history, adding weight, showing Health trends, and opening active workout flows. Intents that accept input use typed `AppEnum` parameters; none accept free-text strings that reach storage or the on-device language model.

## Foundation Models / Apple Intelligence

AI workout plan generation and AI exercise replacement use `SystemLanguageModel.default` through structured `@Generable` schemas. User prompts are capped and sanitized; catalog resolution rejects exercise names that do not match the local exercise catalog. Both features gate on Apple Intelligence availability and hide their UI when unavailable.

## Data, Storage, And Sync

- All user data lives locally in SwiftData in the App Group container `group.com.fcttechnologies.VillainArc1`. There is no CloudKit mirror.
- Cross-device sync is the FCT platform: the app's authored rows (25 tables) and the profile photo go to FCT's own backend, hosted on Supabase, scoped to the signed-in account. Apple Health mirror data, weight and hydration entries, and derived caches stay on the device.
- Anonymous diagnostics post to FCT's `diag-ingest` endpoint under a random install identifier that carries no account token.
- HealthKit reads/writes use conventional `HKHealthStore` APIs, anchored queries, and live workout sessions.
- App Group entitlement is shared by the main app, widget extension, and intents extension. HealthKit entitlement is on the main app only.

## In-App Purchase

Villain Arc Pro is an auto-renewing subscription: monthly ($4.99) and yearly ($39.99), each with a 7-day free trial and Family Sharing enabled. Subscribe via Settings -> Subscription or through premium features. Restore Purchases is available in Settings.

## Contact

villain-arc@fct-technologies.com
