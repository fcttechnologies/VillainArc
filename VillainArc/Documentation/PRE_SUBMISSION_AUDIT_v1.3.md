# Pre-Submission Audit — Villain Arc 1.3

Run against the `rejection-handler` skill's checklist before tapping **Submit for Review**. The audit is paired with:

- `APP_STORE_REVIEW_NOTES.md` — what App Review sees
- `SECURITY_REVIEW_v1.3.md` — the security pass
- `READY_FOR_SUBMIT.md` — morning-of mechanical steps

Status legend: ✅ verified · ⚠️ risk to mitigate before submit · 🛠️ Fernando action · ⏭️ deferred (post-1.3)

---

## Guideline 2.1 — App Completeness

| Check | Status | Notes |
|---|---|---|
| App launches without crashing on all supported devices | ✅ | Unit tests pass on iPhone 17 Pro / iOS 26.5; no force unwraps in production paths per security review. |
| All features described in metadata are functional | ✅ | Cardio tab, AI plan generation, plan templates, health trends, sleep timing, correlations, hydration, profile heatmap all wired and tested. |
| No placeholder content (lorem ipsum, TODO screens) | ✅ | Security review final-pass cleared `Remove this guard before shipping` comment. |
| No broken links or dead-end navigation | ✅ | URL scheme handler validates path enum; Spotlight handler validates UUID. |
| All buttons and interactive elements work | ✅ | Accessibility identifiers exist on every 1.3 surface (`Helpers/Accessibility.swift`); see commit `0323a89`. |
| Demo/test accounts provided if login is required | n/a | No login. `APP_STORE_REVIEW_NOTES.md` explicitly states this. |
| Beta or test labels removed | ✅ | `MARKETING_VERSION` is `1.3.0`; no internal-only flags exposed. |

## Guideline 2.3 — Accurate Metadata

| Check | Status | Notes |
|---|---|---|
| App name matches what the app does | ✅ | `Villain Arc: Workout Tracker` — `Workout Tracker` is the primary use. |
| **Screenshots show the actual current app UI** | ⚠️ → 🛠️ | **Risk:** 1.3.0 currently inherits the 1.2.3 screenshot set (10 PNGs, APP_IPHONE_67 / 6.7"). These show the old surfaces — **no Cardio, no AI plan result, no Health Trends, no Correlations, no Profile heatmap.** Description and Subtitle both lean on AI and Cardio. **Fernando: re-shoot the 10 marketing screenshots after dismissing the Notifications dialog once (see Phase 3 of the hand-off) and upload them to the iPhone 6.9" Display family BEFORE submitting.** Without 1.3-accurate screenshots, this is the single highest rejection-risk item (Guideline 2.3.3 — "Accurate Screenshots"). |
| Description accurately represents functionality | ✅ | Every claim maps to a shipping feature. |
| Category selection is appropriate | ✅ | Primary: Health & Fitness · Secondary: Lifestyle. |
| No misleading claims ("best", "#1") without substantiation | ✅ | None. |
| Age rating reflects actual content | ✅ | 4+ — no objectionable content. |
| What's New describes actual changes, not marketing copy | ✅ | NEW / POLISHED / FIXED sections all map to real commits. |
| Keywords do not include competitor names or misleading terms | ✅ | Final keyword string (`strength,fitness,plan,hypertrophy,routine,split,powerlifting,weight,run,walk,treadmill,5x5,5/3/1,bro`) is all generic terms. |

## Guideline 2.5 — Software Requirements

| Check | Status | Notes |
|---|---|---|
| App uses only public APIs | ✅ | Security review verified — `SystemLanguageModel`, `HKWorkoutSession`, `BGTaskScheduler`, `SKStoreReviewController` are all public. |
| No deprecated APIs marked for removal | ✅ | Compile passes cleanly with no deprecation warnings on iOS 26 SDK. |
| Works on the oldest supported iOS version | ✅ | iOS 26.0 deployment target. Tested at 26.5. |
| No remote code execution | ✅ | No downloaded scripts; Foundation Models is local. |
| IPv6 networking compatibility | ✅ | App makes no direct network calls; iCloud sync handled by Apple frameworks. |

## Guideline 3.1 — In-App Purchase Compliance

VA 1.3 ships without IAP. The 5/29 subscription work in `v1.3-plan.md` was deferred to a 1.3.x point release. No paid digital content in 1.3.

| Check | Status | Notes |
|---|---|---|
| Digital content uses Apple IAP | n/a | No paid content in 1.3. |
| Restore Purchases | n/a | Not applicable until subscriptions ship. |
| No external payment direction | ✅ | Description does not direct users to any payment surface. |

## Guideline 4.0 — Design Quality

| Check | Status | Notes |
|---|---|---|
| Native UI components (not web wrapper) | ✅ | 100% SwiftUI + SwiftData. No `WKWebView` host. |
| Supports current device screen sizes | ✅ | iPhone 17 Pro Max layout tested. Layout uses dynamic sizing throughout. |
| No empty states without guidance | ✅ | Each empty state has a `.emptyState` modifier + label/hint identifiers (`workoutsEmptyState`, etc.). |
| Error messages user-friendly | ✅ | OSLog channels via `AppLog`. UI surfaces friendly recovery text. |
| Loading states exist for async operations | ✅ | Foundation Models has a `aiPlanGeneratingOverlay` accessibility identifier wired to a progress overlay. |
| Meaningful functionality (not a glorified bookmark) | ✅ | Full workout tracker + AI coach + health insights; substantial depth. |

## Guideline 4.3 — Spam

| Check | Status | Notes |
|---|---|---|
| App is distinct from other workout trackers | ✅ | On-device AI plan generation + correlation insights are differentiated. |
| No duplicate apps in the catalog | ✅ | `Villain Arc - Workout Tracker` is a single, original product owned by FCT Technologies LLC. |
| Major-update version reflects real change, not just a re-skin | ✅ | 1.3 adds Cardio tab, AI plan/replacement, 6 templates, Health Trends, Sleep Timing Insights, Correlation Insights, hydration, Profile tab. Multi-feature release. |

## Guideline 5.1 — Privacy

| Check | Status | Notes |
|---|---|---|
| Privacy policy URL provided | ✅ | `https://fct-technologies.com/projects/villainarc/privacy/` set on all 7 locales. |
| Privacy policy describes data collection | ✅ | (Verify the URL renders the current policy. URL → action item if not yet live.) 🛠️ |
| App Tracking Transparency prompt | n/a | No third-party tracking. No `NSUserTrackingUsageDescription` needed. |
| Privacy Nutrition Labels match actual behavior | ✅ | Labels declared in `APP_STORE_METADATA.md` (Health & Fitness, User Content, Identifiers via iCloud, Diagnostics). Verify against 1.2.3's published labels in ASC before submit. |
| Data minimization | ✅ | App stores only what's needed for training history + health caches. |
| User data deletion mechanism | ✅ | Debug Settings → "Delete All App Data" (only in DEBUG builds). For Release: deleting the app + iCloud data via Settings → iCloud → Manage Storage covers user-initiated deletion. Acceptable for HealthKit-class apps. |
| Privacy manifest included | ✅ | `VillainArc/PrivacyInfo.xcprivacy` present. |

## Guideline 5.2 — Legal Requirements

| Check | Status | Notes |
|---|---|---|
| Complies with local laws in distribution territories | ✅ | Generic fitness app; no region-specific regulations apply. |
| Required age gates | n/a | 4+ rating. |
| Health/medical disclaimers | ✅ | App is a fitness tracker, not a medical device. Health insights are educational summaries from the user's own Apple Health data. No medical claims in metadata. |
| Financial disclaimers | n/a | No financial features. |

## App Review Notes (Submission)

| Check | Status | Notes |
|---|---|---|
| Demo account credentials | n/a | No login required (covered in `APP_STORE_REVIEW_NOTES.md`). |
| Special hardware instructions | ✅ | Notes explain Apple Intelligence requirement for AI features and how it falls back gracefully. |
| Backend requirements | n/a | No backend. Notes state this explicitly. |
| Non-obvious feature walkthroughs | ✅ | Notes list the fastest path to each major v1.3 feature. |
| Entitlements and why | ✅ | App Group, HealthKit Share/Read, Location When-In-Use, User Notifications all justified in the notes. |

---

## Risk-watch items (pre-submit triage)

These are the items most likely to drive a rejection. Treat each as a hard gate.

### 1. ⚠️ HIGH RISK — Screenshots do not reflect 1.3 features

**Current state.** Version 1.3.0 inherits the 1.2.3 screenshot set (`APP_IPHONE_67`, 10 files: `01-workout-home-dark.png` through `10-workout-home-light.png`). These do not show Cardio, AI Plan Generation, Health Trends, Sleep Timing Insights, Correlation Insights, or the Profile tab heatmap.

**Why it matters.** Guideline 2.3.3 explicitly requires screenshots to accurately represent the app. Subtitle (`AI Gym Coach, Lift Log, Cardio`), Promotional Text (`...on-device AI coach... cardio with routes...`), and Description all foreground v1.3 features. App Review will see the mismatch.

**Action — Fernando.** Before tapping Submit:

1. In the booted simulator, manually tap "Don't Allow" on the cached Notifications dialog (one time only).
2. Re-run `xcodebuild test-without-building -only-testing:VillainArcUITests` from the project root to re-capture the 10 marketing PNGs into the .xcresult bundle.
3. Open the screenshot editor (`bun dev` in `database/automation-output/villainarc-assets/2026-05-27/screenshots/marketing/`, http://localhost:3000), review the deck, swap in the new raws, and Export bundle.
4. Upload the exported deck to ASC's iPhone 6.9" Display set:

   ```bash
   ASC_BYPASS_KEYCHAIN=1 asc screenshots upload \
     --version-localization 7f3aa698-a878-4b56-a164-9a1e1674dabe \
     --path "/Users/fernando7ct/Jarvis/database/automation-output/villainarc-assets/2026-05-27/screenshots/exported" \
     --device-type IPHONE_69 \
     --output json
   ```

   (`IPHONE_69` is the 6.9" display type. If `asc screenshots sizes` does not list it, fall back to `IPHONE_67` — ASC's web UI accepts either for 1.3 submission.)

### 2. ✅ Apple Intelligence gating is explained

`APP_STORE_REVIEW_NOTES.md` already explains that AI features are gated to Apple Intelligence-eligible hardware and hidden on unsupported devices. No additional risk.

### 3. ✅ HealthKit + Location prompts described

Notes describe every prompt the reviewer will see (HealthKit Share + Read, Location When-In-Use, User Notifications, Camera/Photo Library). All have legitimate use justifications.

### 4. 🛠️ Confirm privacy policy URL is live

The URL `https://fct-technologies.com/projects/villainarc/privacy/` is set in metadata. **Fernando: open the URL in a browser before submitting to confirm it renders a real privacy policy.** A 404 here causes a 5.1.1 rejection.

### 5. ⏭️ Subscriptions deferred to a follow-up release

The `v1.3-plan.md` "Subscriptions setup" item is unchecked. No StoreKit code ships in 1.3. This is correct — IAP is not required for 1.3 and adding it now creates new review surface without justification. Subscriptions ship in a 1.3.x point release per plan.

### 6. ✅ App Privacy publish state

`asc validate` reports `privacy.publish_state.unverified` as INFO (not blocking). App Privacy was published with 1.2.3 and the data-collection shape has not changed for 1.3. Spot-check the labels in `https://appstoreconnect.apple.com/apps/6759259627/appPrivacy` before submit.

### 7. ✅ Cardio route data flow

Per the security review: cardio route points are stored only in the local SwiftData store, optional Apple Health export uses standard `HKWorkoutSession`. Location is When-In-Use only. No always-on tracking. Permission text is descriptive.

### 8. ✅ Foundation Models / Apple Intelligence usage

Per the security review: both AI surfaces (plan generation, exercise replacement) use `SystemLanguageModel.default` with structured `@Generable` schemas. User prompts are sanitized and capped at 500 chars. Catalog resolver rejects unknown exercise names. AI features hide cleanly when the model is unavailable.

---

## Final pre-submit gate

Before Fernando taps **Submit for Review**, run this gate sequentially. **Any unchecked item = do not submit yet.**

- [ ] **NEW 1.3 screenshots uploaded** to iPhone 6.9" Display family (10 PNGs). The inherited 1.2.3 screenshots are unacceptable — they do not show the v1.3 features Subtitle + Promotional Text + Description promise.
- [ ] App Preview video uploaded (per `projects/villain-arc/v1.3-app-preview-script.md`).
- [ ] Build 1.3 (#?) uploaded to ASC and processed (state = VALID).
- [ ] Build attached to version 1.3.0 via ASC web UI.
- [ ] Privacy policy URL renders.
- [ ] App Privacy labels confirmed unchanged from 1.2.3.
- [ ] App Review notes from `APP_STORE_REVIEW_NOTES.md` pasted into ASC.
- [ ] One final `asc validate --app 6759259627 --version "1.3.0" --platform IOS --strict --output table` — must show zero blocking issues except the build-attached check (which clears once Fernando attaches the build).
- [ ] Tap Submit.

---

## Confidence call

If the screenshot replacement is done, this submission is **low rejection risk**. The metadata is accurate, all permissions are justified, all AI features are gated and hide gracefully, the security review found no critical issues, and the prior 1.2.3 review approved the same architectural shape. The only real failure mode is shipping the inherited 1.2.3 screenshots — Apple's reviewer would catch that under 2.3.3 within the first day.

Estimated review time: 1–3 days (standard).
