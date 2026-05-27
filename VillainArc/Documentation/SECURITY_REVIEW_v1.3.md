# Security Review — v1.3

Pre-submission security pass over commits `fb11b2f..HEAD` (15 commits, cardio sessions, plan templates, AI plan/replacement generation, health trends/insights/correlations, outcome rating, What's New, onboarding slideshow, review prompt, TipKit, rest timer redesign).

Window: 2026-05-27

## Scope

- HealthKit data flow: read/write permissions, storage, log redaction
- App Intents accepting user input: validation, injection
- SwiftData store at-rest in the App Group
- Notification deep-link routing
- Widget + Live Activity App Group entitlements
- Spotlight indexing privacy
- Foundation Models prompt construction (user input sanitization before passing to the on-device LM)
- StoreKit / subscription surface (not yet shipped, but verify nothing leaks)

## Summary

| Severity | Count | Status |
|---|---|---|
| Critical | 0 | — |
| High | 0 | — |
| Medium | 1 | Fixed (M1) |
| Low | 3 | Documented (L1, L2, L3) |

No critical or high findings. One medium issue around unbounded AI prompt length is fixed. Remaining low items are pre-existing patterns documented here for tracking; they are not v1.3 regressions.

---

## Findings

### M1 — Unbounded user free text reached the on-device language model — FIXED

**Location:** `Views/WorkoutPlan/GeneratePlanAIPromptView.swift`, `Data/Services/AI/Plans/AIWorkoutPlanGenerator.swift`

**Issue:** The `TextEditor` bound to `userPrompt` had no length cap. The string was trimmed for whitespace but passed verbatim into the `Prompt` block that calls `LanguageModelSession.respond(to:generating:)`. Unbounded inputs:

- inflate prompt size for no information gain
- enlarge the surface for off-topic content (instructions, repeated patterns, control characters) reaching the on-device model
- slow generation when nothing useful is added past ~one paragraph

**Risk:** Low real-world impact because the model returns a constrained `@Generable` schema and never makes network calls — even if the user pastes jailbreak text, the worst case is unhelpful plan content the catalog resolver can mostly reject. Still worth fixing for robustness and to keep the prompt surface small ahead of any future managed-model swap.

**Fix:**

- New `AIWorkoutPlanGenerator.maxUserPromptLength = 500` constant.
- New `sanitize(userPrompt:)` helper trims whitespace, strips control characters and default-ignorable code points, and truncates at a word boundary.
- `GeneratePlanAIPromptView` clamps the `TextEditor` binding in `onChange(of: userPrompt)` so the cap is also visible to the user (not silently dropped at submit).

### L1 — `print()` calls in `HealthLiveWorkoutSessionCoordinator` log workout UUIDs to stdout — pre-existing

**Location:** `Data/Services/HealthKit/Live/HealthLiveWorkoutSessionCoordinator.swift` (lines 69, 95, 101, 103, 106, 136, 249)

**Issue:** Mixed `print(...)` and `AppLog` usage. `print()` goes to the standard console without OSLog's privacy controls. Messages include workout UUIDs and HealthKit sample UUIDs — not PII, but still data that should flow through the unified logger so it can be audited consistently.

**Status:** Pre-existing (predates `fb11b2f`). Not a v1.3 regression. Replace with `AppLog.info` / `AppLog.error` in a follow-up cleanup pass.

### L2 — `AppLog` privacy is `.public` for all interpolated values — pre-existing

**Location:** `Data/Services/App/AppLog.swift`

**Issue:** Every `\(message, privacy: .public)` makes interpolated session IDs, plan IDs, and error descriptions show up unredacted in device logs. For an installed user this is local-only and not exposed externally, but the convention should be `.private` for identifiers and reserve `.public` for fixed messages and category strings.

**Status:** Pre-existing. Tracked as a follow-up cleanup; not changing in v1.3 because the logger interface is used across the codebase and a broad refactor is out of scope for the submission window.

### L3 — `DEBUG`-only suppression of notification permission prompt is still present — intentional, scheduled for removal

**Location:** `Data/Services/App/NotificationCoordinator.swift` (`requestAuthorizationIfNeededAfterOnboarding`)

**Issue:** The body has a `#if DEBUG return #endif` guard with a comment that says "Remove this guard before shipping." Release builds are unaffected (compile-time exclusion), but the comment promises a follow-up that has not happened.

**Status:** Already gated to DEBUG and learnings (`projects/villain-arc/learnings.md`, 2026-05-26) explain the cached-system-dialog reason. Behavior is correct in Release. Leave the guard; remove the "Remove this guard before shipping" comment in a follow-up so the TODO doesn't drift.

---

## Verification

- **URL scheme handler (`AppRouter.handleIncomingURL` / `destination(for:)`)**: scheme `villainarc` + host `health` + hardcoded path enum. Anything else returns `nil`. No risk from arbitrary inbound URLs.
- **Spotlight identifier handler (`AppRouter.handleSpotlight`)**: prefix-stripped identifier is parsed as `UUID(uuidString:)` (or catalog ID lookup against the local catalog). Invalid identifiers fail closed.
- **Notification deep-link routing (`NotificationCoordinator.notificationTapDestination`)**: every routing decision flows through a typed `NotificationType` enum. No raw URLs, no arbitrary destinations.
- **App Intents**: every v1.3 intent accepts either no parameter or a typed `AppEnum` (`CardioKindAppEnum`). No free-text parameter that reaches storage or model calls.
- **App Group entitlements**: `group.com.fcttechnologies.VillainArcCont` consistent across main app, widget extension, and intents extension. HealthKit entitlement is on the main app only — widget and intents can't read HealthKit directly.
- **HealthKit usage descriptions**: `INFOPLIST_KEY_NSHealthShareUsageDescription` and `INFOPLIST_KEY_NSHealthUpdateUsageDescription` set in `project.pbxproj` for both Debug and Release configurations.
- **Location**: When-In-Use only (`requestWhenInUseAuthorization`), activity type `.fitness`, distance filter `8m`, low-accuracy GPS points (>60m horizontal accuracy) discarded before insert. No always-on tracking.
- **Foundation Models output**: every model call uses `respond(to:generating: SomeGenerable.self)`. The structured schema constrains the response shape, and the catalog resolver rejects exercise names it can't match against the local catalog — the model cannot synthesize an arbitrary catalog ID.
- **StoreKit**: no StoreKit imports yet in v1.3 except the existing `requestReview` for `SKStoreReviewController`. Subscriptions are scheduled for 2026-05-29 and will be re-reviewed before submission.
- **Cardio route data**: stored only in the local SwiftData store; written through user-owned `CardioRoutePoint` rows attached to a `CardioSession`. Optional Apple Health export goes through `CardioHealthWorkoutCoordinator` with the standard HealthKit metadata keys and the user-controlled write permission.
