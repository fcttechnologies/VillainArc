# App Store Review Notes — Villain Arc 1.3

Paste this into App Store Connect → version → App Review Information → Notes.

---

## Summary

Villain Arc is a strength-training and cardio tracker with on-device AI plan generation and exercise replacement (Foundation Models), Apple Health integration, optional iCloud sync, Live Activities, widgets, and App Intents. No account is required and no third-party services are used.

This is release **1.3.0**. Major additions over 1.2.3:

- A new Cardio tab with app-owned outdoor route recording and manual treadmill intervals.
- On-device AI workout plan generation and exercise replacement (Apple Intelligence).
- Six pre-built program templates (PPL, Upper/Lower, Full Body, 5×5, 5/3/1 BBB, Bro Split).
- Hydration tracking with Apple Health two-way sync.
- New Health surfaces: heart-rate vitals, respiratory rate, sleeping wrist temperature, Health Trends dashboard, Sleep Timing Insights, and Correlation Insights.

---

## Demo account

Not required. No login flow, no server backend. The app is fully usable on a clean install once onboarding (name, birthday, gender, height, fitness level, training goal) is complete.

## Sign in

Not applicable.

## Required permissions and why they appear

| Permission | Required for | When triggered |
|---|---|---|
| **HealthKit** (Share + Read) | Workout import/export, weight, sleep, steps, distance, energy, heart rate vitals, respiratory rate, wrist temperature, dietary water. Permissions catalog is versioned (`HealthKitCatalog.permissionsCatalogVersion`); a returning user is re-prompted only when the version changes. | First launch (onboarding) and again after a new permissions version ships. The standalone Health prompt is dismissible with "Not Now." |
| **Location When In Use** | Outdoor cardio route recording (run, walk). When-In-Use only — never always-on. Used during an active outdoor cardio session to record `CardioRoutePoint`s for the route map. Distance filter is 8 meters; low-accuracy GPS points are discarded. | The moment a user taps Start on an outdoor cardio session. Treadmill sessions never trigger location. |
| **User Notifications** | Local notifications for: rest timer completion, steps goal milestones, sleep goal completion, hydration goal completion, and weekly health coaching recaps. No remote/push notifications, no APNs. | After the user reaches `.ready` post-onboarding. Permission is requested once, and re-asked only if status returns to `.notDetermined`. |
| **Camera / Photo Library** | Optional profile photo. Only requested when the user taps to change their profile photo. | Inside Profile → Photo. Never on launch. |

No advertising identifiers, tracking permissions, or App Tracking Transparency prompts. Privacy nutrition label declares zero data collection by the developer.

## How to exercise the new 1.3 features

A clean install + onboarding gives the reviewer access to everything immediately. The fastest path to evaluate each major addition:

1. **AI plan generation.** Home → expanded plus → "Create Plan" → "Generate with AI" → enter a short prompt ("3-day full body plan for hypertrophy") → tap Generate. Foundation Models runs on-device; requires Apple Intelligence-capable hardware. Falls back gracefully on unsupported devices (the entry is hidden).
2. **Plan templates.** Same "Create Plan" sheet → Templates section → pick any template → "Build Full Program" to materialize a complete split.
3. **AI exercise replacement.** Inside any plan → tap any exercise → Replace → an "AI Suggestions" row appears above the deterministic list (Apple Intelligence devices only).
4. **Cardio tab.** Cardio tab → tap Outdoor Run / Walk → grant Location → start. Treadmill modes do not require Location.
5. **Health Trends.** Health tab → Trends card → 7D/30D/90D/1Y picker → tap any sparkline for detail.
6. **Sleep Timing Insights.** Health tab → Trends → "Sleep Timing Insights."
7. **Correlation Insights.** Health tab → Trends → "Performance Correlations." Empty state until 8 rated sessions exist.
8. **Hydration.** Quick-action plus on Home → Add Water. Goal history lives under Health tab → Hydration → Goal History.

## App Intents / Siri Shortcuts

10 active App Shortcuts ship in `VillainArcShortcuts.swift`:

- Start Workout
- Start Today's Workout
- Start Cardio (run/walk/treadmill)
- View Last Workout
- Show Workout History
- Add Weight Entry
- Show Health Trends
- Show Sleep Insights
- Show Correlation Insights
- Open Active Workout

All intents that accept user input use typed `AppEnum` parameters. None accept free-text strings that reach storage or the on-device language model.

## Foundation Models / Apple Intelligence

Two features use `SystemLanguageModel.default`:

- **`AIWorkoutPlanGenerator`** — `LanguageModelSession.respond(to:generating:)` with a structured `@Generable AIGeneratedPlan` schema. User prompts are capped at 500 characters and sanitized (control chars stripped, default-ignorable code points removed, truncation at word boundary) before the model sees them. The catalog resolver rejects exercise names that can't fuzzy-match against our local catalog, so the model cannot synthesize arbitrary exercise content.
- **`AIExerciseReplacementSuggester`** — same shape, smaller schema (`AIReplacementSuggestionList`). Catalog resolver again rejects names that don't map to local catalog items.

Both features are gated on `SystemLanguageModel.default.availability == .available` and hide their UI entries when unavailable.

## Data, storage, and sync

- All user data is stored in SwiftData (App Group container `group.com.fcttechnologies.VillainArcCont`).
- iCloud sync uses `cloudKitDatabase: .private("iCloud.com.fcttechnologies.VillainArcCont")` — Apple-managed CloudKit private DB only. No custom server.
- HealthKit interactions are conventional `HKHealthStore` reads + writes, anchored queries, and `HKLiveWorkoutBuilder` for the live workout path.
- App Group entitlement is shared by the main app, widget extension, and intents extension. HealthKit entitlement lives on the main app only.

## Known reviewer considerations

- **Apple Intelligence requirement.** AI features are gated to Apple Intelligence-capable hardware and Apple Intelligence being enabled. On unsupported devices or when Apple Intelligence is off, the AI entries are hidden — never broken. The deterministic plan builder and exercise replacement ranker remain available.
- **Live cardio Health workout.** When the user has HealthKit workout write permission and starts an outdoor or treadmill cardio session, an `HKWorkoutSession` is started in parallel to collect live heart rate and active energy. Without permission, the local cardio flow still works.
- **iCloud is optional.** Users can choose "Continue Without iCloud" during onboarding; the app seeds locally and continues without sync. CloudKit blocking states (no account, restricted) surface retry-able onboarding states.

## Contact

Email: villain-arc@fct-technologies.com
