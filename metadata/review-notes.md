## App Review notes (paste into ASC → App Review Information → Notes)

### Summary

Villain Arc is a strength-training and cardio tracker with on-device AI plan generation and exercise replacement (Foundation Models), Apple Health integration, optional iCloud sync, Live Activities, widgets, and App Intents. No account is required and no third-party services are used.

This is release **1.3.0**. Major additions over 1.2.3:

- A new Cardio tab with app-owned outdoor route recording and manual treadmill intervals.
- On-device AI workout plan generation and exercise replacement (Apple Intelligence).
- Six pre-built program templates (PPL, Upper/Lower, Full Body, 5×5, 5/3/1 BBB, Bro Split).
- Hydration tracking with Apple Health two-way sync.
- New Health surfaces: heart-rate vitals, respiratory rate, sleeping wrist temperature, Health Trends dashboard, Sleep Timing Insights, and Correlation Insights.

### Demo account

Not required. No login flow, no server backend. The app is fully usable on a clean install once onboarding (name, birthday, gender, height, fitness level, training goal) is complete. **Sign in:** not applicable.

### Required permissions and why they appear

| Permission | Required for | When triggered |
|---|---|---|
| **HealthKit** (Share + Read) | Workout import/export, weight, sleep, steps, distance, energy, heart-rate vitals, respiratory rate, wrist temperature, dietary water. Permissions catalog is versioned (`HealthKitCatalog.permissionsCatalogVersion`); a returning user is re-prompted only when the version changes. | First launch (onboarding) and again after a new permissions version ships. The standalone Health prompt is dismissible with "Not Now." |
| **Location When In Use** | Outdoor cardio route recording (run, walk). When-In-Use only — never always-on. Records `CardioRoutePoint`s during an active outdoor cardio session for the route map. Distance filter 8 m; low-accuracy points discarded. | The moment a user taps Start on an outdoor cardio session. Treadmill sessions never trigger location. |
| **User Notifications** | Local notifications: rest-timer completion, steps-goal milestones, sleep-goal completion, hydration-goal completion, weekly health coaching recaps. No remote/push, no APNs. | After the user reaches `.ready` post-onboarding. Requested once; re-asked only if status returns to `.notDetermined`. |
| **Camera / Photo Library** | Optional profile photo. Only when the user taps to change their profile photo. | Inside Profile → Photo. Never on launch. |

No advertising identifiers, tracking permissions, or App Tracking Transparency prompts. Privacy nutrition label declares zero data collection by the developer.

### How to exercise the new 1.3 features

A clean install + onboarding gives the reviewer access to everything immediately.

1. **AI plan generation.** Home → expanded plus → "Create Plan" → "Generate with AI" → short prompt → Generate. Foundation Models runs on-device; needs Apple Intelligence-capable hardware (entry hidden on unsupported devices).
2. **Plan templates.** "Create Plan" sheet → Templates → pick one → "Build Full Program."
3. **AI exercise replacement.** Any plan → tap an exercise → Replace → "AI Suggestions" row (Apple Intelligence devices only).
4. **Cardio tab.** Cardio → Outdoor Run/Walk → grant Location → start (treadmill modes need no Location).
5. **Health Trends.** Health → Trends card → 7D/30D/90D/1Y → tap a sparkline.
6. **Sleep Timing Insights.** Health → Trends → "Sleep Timing Insights."
7. **Correlation Insights.** Health → Trends → "Performance Correlations" (empty until 8 rated sessions).
8. **Hydration.** Home quick-action plus → Add Water; history under Health → Hydration → Goal History.

### App Intents / Siri Shortcuts

10 App Shortcuts ship in `VillainArcShortcuts.swift` (Start Workout, Start Today's Workout, Start Cardio, View Last Workout, Show Workout History, Add Weight Entry, Show Health Trends, Show Sleep Insights, Show Correlation Insights, Open Active Workout). All intents that accept input use typed `AppEnum` parameters; none accept free-text strings that reach storage or the on-device language model.

### Foundation Models / Apple Intelligence

Two features use `SystemLanguageModel.default`: **`AIWorkoutPlanGenerator`** and **`AIExerciseReplacementSuggester`**, both via `LanguageModelSession.respond(to:generating:)` with a structured `@Generable` schema. User prompts are capped at 500 chars and sanitized; a catalog resolver rejects exercise names that don't fuzzy-match the local catalog, so the model can't synthesize arbitrary exercise content. Both gate on `SystemLanguageModel.default.availability == .available` and hide their UI when unavailable.

### Data, storage, and sync

- All user data in SwiftData (App Group container `group.com.fcttechnologies.VillainArcCont`).
- iCloud sync uses `cloudKitDatabase: .private("iCloud.com.fcttechnologies.VillainArcCont")` — Apple-managed CloudKit private DB only, no custom server.
- HealthKit via conventional `HKHealthStore` reads/writes, anchored queries, and `HKLiveWorkoutBuilder`.
- App Group entitlement shared by main app, widget extension, intents extension; HealthKit entitlement on the main app only.

### Known reviewer considerations

- **Apple Intelligence requirement.** AI features gate to AI-capable hardware with Apple Intelligence enabled; entries hidden (never broken) otherwise. Deterministic plan builder + replacement ranker remain available.
- **Live cardio Health workout.** With HealthKit workout-write permission, an `HKWorkoutSession` runs in parallel for live HR + active energy; without permission the local cardio flow still works.
- **iCloud is optional.** "Continue Without iCloud" during onboarding seeds locally; CloudKit blocking states surface retry-able onboarding states.

### In-App Purchase

Villain Arc Pro — auto-renewing subscription, monthly ($4.99) / yearly ($39.99), each with a 7-day free trial, Family Sharing enabled. Subscribe via Settings → Subscription or any of the 5 premium features (AI Plan Generation, AI Exercise Replacement, Health Trends, Sleep Timing Insights, Correlation Insights). Restore Purchases in Settings. All other features free.

### Contact

villain-arc@fct-technologies.com
