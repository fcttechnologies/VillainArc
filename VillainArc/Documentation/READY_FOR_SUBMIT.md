# Ready for Submit — Villain Arc 1.3

Everything in this folder is final. The remaining work to ship 1.3 is mechanical: capture assets, archive, validate, upload, paste metadata, submit.

This file is the morning-of checklist. Work top-to-bottom.

---

## 1. Bump version + build numbers

In Xcode → VillainArc target → General:

- **Version (Marketing Version):** `1.2.3` → **`1.3.0`**
- **Build (Current Project Version):** increment from `1` to the next integer (probably `2`, but check; build numbers must be monotonically increasing for ASC uploads).

Apply to the main app target, the widget extension target, and the intents extension target so the App Store accepts the upload.

## 2. Clean build

```bash
cd ~/Projects/VillainArc
xcodebuild -project VillainArc.xcodeproj -scheme VillainArc -configuration Release clean
```

Open Xcode and pick the generic "Any iOS Device (arm64)" destination.

## 3. Capture App Store screenshots (mandatory)

See `database/automation-output/villainarc-assets/2026-05-27/screenshots/README.md` for the 10-shot plan and exact `simctl` commands.

Required device size: iPhone 17 Pro Max (1320 × 2868). Optional sizes Apple will scale from the 6.9" set.

Confirm all PNGs exist at the right resolution:

```bash
sips -g pixelWidth -g pixelHeight \
  /Users/fernando7ct/Jarvis/database/automation-output/villainarc-assets/2026-05-27/screenshots/01-*.png \
  /Users/fernando7ct/Jarvis/database/automation-output/villainarc-assets/2026-05-27/screenshots/02-*.png \
  ...
```

## 4. Record App Preview (optional but recommended)

See `database/automation-output/villainarc-assets/2026-05-27/app-preview/storyboard.md` for the 25-second scene plan.

Recommended path: physical iPhone, screen recording from Control Center, mic off. AirDrop to Mac, trim + caption in iMovie, export 1080 × 1920 MP4.

If you skip the preview for the initial 1.3 submission, you can add it post-launch without re-review.

## 5. Archive + upload

In Xcode:

1. Product → Archive.
2. When the Organizer opens, select the new archive → **Distribute App** → **App Store Connect** → **Upload**.
3. Use the automatic signing path you've been using.
4. Wait for processing in App Store Connect (5–30 minutes typically).

## 6. Paste metadata into App Store Connect

Open `https://appstoreconnect.apple.com` → My Apps → Villain Arc → **+ Version** → `1.3.0`.

Copy each field from `APP_STORE_METADATA.md`:

- App Name: `Villain Arc: Workout Tracker`
- Subtitle: `AI Gym Coach, Lift Log, Cardio`
- Promotional Text: paste the en-US block.
- Description: paste the en-US block.
- Keywords: paste the en-US comma-list.
- What's New in this Version: paste the en-US block.

For each localized locale already in the app store listing (es, fr, de, pt-BR, ja, zh-Hans), paste the localized subtitle / keywords / promotional text / description hook from the Localized variants section of the metadata bundle.

## 7. Upload screenshots + App Preview

- Screenshots: Version 1.3.0 → Media → iPhone 6.9" Display → drop in the 10 PNGs from `database/automation-output/villainarc-assets/2026-05-27/screenshots/`.
- App Preview: Same surface, App Preview slot → drop in the final MP4 from `database/automation-output/villainarc-assets/2026-05-27/app-preview/villain-arc-1.3-preview.mp4` (if recorded).

## 8. Paste App Review notes

Version 1.3.0 → App Review Information → Notes → paste the body of `APP_STORE_REVIEW_NOTES.md`.

Confirm contact email: `villain-arc@fct-technologies.com`.

## 9. Confirm the build is attached

Version 1.3.0 → Build section → Select the newly uploaded `1.3 (build N)` build.

## 10. Confirm Privacy nutrition label

Spot-check the existing 1.2.3 nutrition label against `APP_STORE_METADATA.md` → Privacy nutrition label coverage. Nothing has changed in data collection — no edits expected.

## 11. Submit

Version 1.3.0 → top right → **Add for Review** → confirm App Review questions → **Submit for Review**.

---

## Tonight's pre-submission work — done

Everything below this line is already in the repo. The morning checklist above is the only remaining manual work.

- Full codebase review: 25 `print()` calls replaced with `AppLog`, stale `Remove this guard before shipping` comment cleared, unreachable-code warning resolved in `NotificationCoordinator`.
- Performance audit: SwiftData indexing already comprehensive via `#Index` macros, `fetchLimit` consistently applied to singleton queries, no main-thread blocking, no force unwraps in production paths. No regressions to fix.
- Security review (`SECURITY_REVIEW_v1.3.md`) updated: M1 fixed (AI prompt sanitization), L1 fixed (print() → AppLog), L3 reworded with explicit `#else` branch.
- Documentation finalized:
  - `RELEASE_NOTES_1.3_DRAFT.md` promoted to `RELEASE_NOTES_1.3.md`.
  - `PRODUCT_ROADMAP.md` archived under `Documentation/archive/`.
  - `ONBOARDING_FLOW.md` updated to document the slideshow + What's New gating.
  - `PROJECT_GUIDE.md` pointer to PRODUCT_ROADMAP swapped for TEMPLATES_FLOW.
- New docs:
  - `APP_STORE_METADATA.md` — full ASO bundle with primary + 6 localized variants.
  - `APP_STORE_REVIEW_NOTES.md` — paste-ready review notes for App Review.
  - `READY_FOR_SUBMIT.md` — this file.
- Asset pipeline scaffolded at `~/Jarvis/database/automation-output/villainarc-assets/2026-05-27/` with screenshot README + App Preview storyboard.

Tomorrow morning: capture, archive, upload, paste, submit. Twenty minutes if assets go smoothly, an hour with the App Preview recording.
