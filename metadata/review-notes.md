# App Review Notes

Paste into App Store Connect -> App Review Information -> Notes.

## Summary

Villain Arc is a strength-training and cardio tracker with on-device AI plan generation and exercise replacement, Apple Health integration, cross-device sync through an FCT account, Live Activities, widgets, and App Intents. A free FCT account is required to use the app; sync and account services are hosted by FCT on Supabase.

This is release 2.0, a full rewrite of the app that shipped as 1.3. What changed at the level a reviewer will notice:

- Minimum iOS raised to 27.0. The watchOS companion requires watchOS 26.0.
- Sign-in is now mandatory and is the first thing after the intro carousel. 1.x was usable signed-out; 2.0 has no interface behind the front door until an FCT account session exists.
- iCloud/CloudKit is gone. Cross-device sync is FCT's own backend under the signed-in account.
- The local data store was replaced, so data saved in 1.x does not carry into 2.0. This is stated in the release notes. A 1.x install's old store lives in a different App Group container that 2.0 does not have access to, so the update does not read or migrate it.
- An Apple Watch companion app is embedded in the iOS app: rest timer, live session mirror, and heart-rate stats.
- The app ships fully localized in ten languages: en, de, es, fr, it, ja, ko, pt-BR, ru, zh-Hans.

## Demo Account

Required. Villain Arc gates its entire interface behind an FCT account: a clean install shows the onboarding carousel and then the sign-in screen, and there is no app behind it until a session exists. Sign in with Apple, or email.

Reviewer credentials:

- Email: `villain-arc+appreview@fct-technologies.com`
- Password: `VillainArc-Review-2026`

This is a dedicated review account, not a shared internal one. Sign-in is email + password on the sign-in screen; Sign in with Apple is not needed.

The account is seeded with training history — three completed "Push Pull Legs" sessions across three weeks (bench press, squat, pull-ups, with a progression across sessions) and the plan behind them. They sync down after sign-in, so Home, Workouts, the exercise histories, and the Profile tab's muscle distribution and streak all have real data in them.

## Required Permissions

| Permission | Required for | When triggered |
|---|---|---|
| HealthKit (Share + Read) | Workout import/export, weight, sleep, steps, distance, energy, heart-rate vitals, respiratory rate, wrist temperature, and dietary water. | First launch onboarding, and again only after a new Health permissions catalog version ships. |
| Location When In Use | Outdoor cardio route recording for run/walk sessions. When-In-Use only. | After the user chooses an outdoor cardio session and taps Continue on the app's location explanation screen, the iOS system permission sheet appears. Treadmill sessions never trigger Location. |
| User Notifications | Local notifications for rest timers, goals, hydration, and weekly health coaching recaps. No remote push or APNs. | After onboarding reaches the ready state. |
| Photo Library | The optional FCT account avatar, chosen through the system photo picker. | Only when the user taps to change their account photo in Settings. The picker runs out of process, so no photo-library permission prompt appears and the app sees only the one image chosen. |

No advertising identifiers, tracking permissions, or App Tracking Transparency prompts, and no third-party analytics or tracking SDKs. The privacy nutrition label and `PrivacyInfo.xcprivacy` declare two separate groups: account-scoped content the user syncs (name, email address, user ID, fitness, health, precise location, photos or videos, other data types — all linked to identity, app functionality only), and anonymous diagnostics (crash, performance, other diagnostic, product interaction — not linked to identity, keyed to a random install identifier).

## How To Reach The Main Surfaces

1. Sign in: launch a clean install, page through the intro carousel, then sign in with the reviewer credentials above. Onboarding then collects the profile — name, Apple Health, Location, birthday, gender, height, fitness level, and training goal. Answers already stored on the account sync down at sign-in and their steps are skipped, so the flow resumes at the first question the account has no answer for.
2. AI plan generation: Home -> expanded plus -> Create Plan -> Generate with AI.
3. Plan templates: Create Plan -> Templates -> pick one -> Build Full Program.
4. AI exercise replacement: any plan -> tap an exercise -> Replace -> AI Suggestions.
5. Strength logging: Home -> Start Today's Workout, log sets, finish, and review the summary and its progression suggestions.
6. Cardio: Cardio tab -> Outdoor Run, Outdoor Walk, Treadmill Run, or Treadmill Walk.
7. Share cards: finish any strength workout or cardio session, or open a saved plan, then tap Share.
8. Health: Trends, Sleep Timing Insights, Correlation Insights, and Hydration all live in the Health tab.
9. Apple Watch: with a paired watch, start a rest timer or a workout on the phone and confirm the watch app mirrors it.

## App Intents / Siri Shortcuts

Ten App Shortcuts ship in `VillainArcShortcuts.swift` — Apple's promoted-shortcut cap, so the set is exactly full: Start Today's Workout, Training Summary, Complete Set, Add Exercise, Start Timer, Stop Timer, Today's Summary, Last Night's Sleep, Today's Steps, and Today's Calories. Their spoken phrases are localized in `AppShortcuts.xcstrings` across all ten shipping languages. Intents that accept input use typed `AppEnum` parameters; none accept free-text strings that reach storage or the on-device language model.

A separate SiriKit intents extension handles the system's own `INStartWorkoutIntent`, `INEndWorkoutIntent`, and `INCancelWorkoutIntent` so "start a workout" reaches the app through Apple's workout domain as well.

## Foundation Models / Apple Intelligence

AI workout plan generation and AI exercise replacement use `SystemLanguageModel.default` through structured `@Generable` schemas. User prompts are capped and sanitized; catalog resolution rejects exercise names that do not match the local exercise catalog. Both features gate on Apple Intelligence availability and hide their UI when unavailable.

## Data, Storage, And Sync

- All user data lives locally in SwiftData in the App Group container `group.com.fcttechnologies.VillainArc1`. There is no CloudKit mirror.
- Cross-device sync is the FCT platform: the app's authored rows (26 tables) go to FCT's own backend, hosted on Supabase, scoped to the signed-in account. The app stores no photos or files of its own; the one picture is the FCT account's avatar, which the account carries for every FCT app. Apple Health mirror data, weight and hydration entries, and derived caches stay on the device.
- Anonymous diagnostics post to FCT's `diag-ingest` endpoint under a random install identifier that carries no account token.
- HealthKit reads/writes use conventional `HKHealthStore` APIs, anchored queries, and live workout sessions.
- App Group entitlement is shared by the main app, widget extension, and intents extension. HealthKit entitlement is on the main app only.

## In-App Purchase

Villain Arc Pro is an auto-renewing subscription: monthly ($4.99) and yearly ($39.99), each with a 7-day free trial and Family Sharing enabled. Subscribe via Settings -> Subscription or through premium features. Restore Purchases is available in Settings.

## Contact

villain-arc@fct-technologies.com
