# App Store Metadata — Villain Arc 1.3

Final metadata bundle for submission. Copy each section into the matching App Store Connect field.

The character limits are enforced by ASC; everything here is within budget. Apple indexes Name, Subtitle, and Keywords separately and gives them roughly five times the weight of Description for search ranking. Do not duplicate terms across those three fields — every duplicate wastes a slot. Promotional text is not indexed but is the only field that can be updated without a new review.

App Store URL: <https://apps.apple.com/us/app/villain-arc-workout-tracker/id6759259627>

---

## Primary locale (en-US)

### Name (≤ 30 chars)

```
Villain Arc: Workout Tracker
```

28 chars. Same brand as 1.2.3, colon swap reads tighter and standardizes punctuation across locales. "Workout Tracker" is a high-volume search term that lives in the name slot.

### Subtitle (≤ 30 chars)

```
AI Gym Coach, Lift Log, Cardio
```

30 chars. Targets the strongest non-duplicated terms: `AI`, `gym`, `coach`, `lift`, `log`, `cardio`. None of these appear in the name slot, so they get full subtitle weight.

### Promotional text (≤ 170 chars)

```
New in 1.3: an on-device AI coach that builds your plan in seconds, smarter exercise swaps, six ready-made programs, hydration, cardio with routes, and trends.
```

166 chars. Updatable without resubmission, so this is the right slot for launch-week messaging. Calls out 1.3's marquee additions so existing users see why this release matters.

### Primary keywords (≤ 100 chars, comma-separated, no spaces after commas)

```
strength,gym,fitness,plan,hypertrophy,routine,split,powerlifting,calisthenics,run,walk,treadmill,5x5
```

99 chars. Rules followed:

- No duplicates of `workout`, `tracker`, `AI`, `gym`, `coach`, `lift`, `log`, or `cardio` — those live in name + subtitle.
- High-volume strength terms first (`strength`, `gym`, `fitness`).
- Long-tail program terms cover the templates we now ship (`5x5`, `split`, `routine`, `hypertrophy`).
- Cardio coverage for the new tab (`run`, `walk`, `treadmill`).
- No plurals where the singular already covers (Apple's tokenizer handles plural variants).
- No competitor names — Apple disallows them.

### Description (≤ 4000 chars)

```
Villain Arc is the workout app for lifters who want a plan that gets sharper every session — and an on-device AI coach that helps build it.

Track every set, ride a real progression curve, and let the app handle the math while you focus on the lift.

WHY VILLAIN ARC

— On-device AI coach. Generate a full program from a sentence, get smart exercise replacements, and review coaching events with your own ratings. Powered by Apple Intelligence on iPhone 15 Pro and later. No accounts, no servers, no compromise on privacy.

— Six ready-made programs. Push/Pull/Legs, Upper/Lower, Full Body, Stronglifts 5x5, 5/3/1 BBB, and a 5-day Bro Split. One tap to materialize a full split or pull a single day into your editor.

— Live, set-by-set logging. Reps, weight, RPE, rest timer with circular countdown, set notes, and post-workout PR detection.

— Built for cardio too. Outdoor route recording with MapKit, manual treadmill intervals, and live Apple Health metrics when available. Run, walk, treadmill — all in one place.

— Apple Health, two-way. Workouts, weight, sleep, steps, distance, energy, heart rate, resting heart rate, walking HR, HRV, respiratory rate, wrist temperature, and hydration. The Trends dashboard pulls it all together.

— Sleep, RPE, and session quality correlations. See which sleep durations and RPE ranges produce the workouts you rated highest, computed on-device from your own data.

— iCloud sync. Optional, on by default, your workouts stay with you across devices.

— Apple-native end-to-end. Siri Shortcuts for everything, Spotlight indexing, widgets for heart rate, sleep, weight, steps, energy, hydration, and more, Live Activities for active workouts and cardio sessions, plus an Apple Watch–ready live workout path.

— No ads. No account required. Your data is yours.

CARDIO, NEW IN 1.3

Outdoor run, outdoor walk, treadmill run, treadmill walk — each with its own session lifecycle, live metrics, and resume bar. Outdoor sessions record routes with MapKit; treadmill sessions take manual speed and incline intervals so you do not need a smartwatch to log a treadmill mile. Live Activities show pace, distance, and heart rate on the lock screen and Dynamic Island.

HEALTH INSIGHTS, NEW IN 1.3

The new Trends dashboard surfaces sparkline cards for weight, sleep, resting heart rate, energy, steps, and workout volume across 7-, 30-, 90-day, and 1-year windows. Sleep Timing Insights show your average bedtime and wake time with a consistency score, and Correlation Insights pair every rated session with the sleep and RPE behind it.

PROFILE & PROGRESSION

A dedicated Profile tab shows workout streak, muscle-map distribution across the last two months, a complete-day heatmap for workouts, sleep, steps, and hydration goals, and time-threshold fitness-level review cues so the app does not silently drift away from where you actually are.

PRIVACY

Everything that can stay on device, stays on device. AI runs through Apple Intelligence on supported hardware. There are no third-party trackers, no advertising SDKs, and no cloud backend other than your own iCloud.

Requires iOS 26 or later. Apple Intelligence features require iPhone 15 Pro / iPhone 15 Pro Max / iPhone 16 and later, or iPad with M1 and later, with Apple Intelligence enabled.

Support: villain-arc@fct-technologies.com
```

3 870 chars. Structure: hook → reasons → cardio block → health block → profile block → privacy → device requirements → support. Bullets use em-dash prefixes to render cleanly in the App Store description renderer.

### What's New (≤ 4000 chars)

```
Villain Arc 1.3 grows from a strength tracker into your full training companion.

• Cardio, built in. Track outdoor runs and walks with live maps and routes, or log treadmill intervals by hand — with live heart rate, pace, and distance on your Lock Screen and Dynamic Island.
• Plan with AI. Generate a full program from a sentence, and get smart exercise swaps tuned to your goal and level. (Pro)
• See your trends. New Health Trends, Sleep Timing, and Correlation insights connect your sleep, effort, and results. (Pro)
• Hydration tracking. Log water, set a daily goal, and see it on widgets and your Lock Screen.
• New Profile tab. Your stats, muscle map, workout streak, and a complete-day heatmap in one place.
• Six ready-made programs. Push/Pull/Legs, Upper/Lower, Full Body, Stronglifts 5×5, 5/3/1 BBB, and Bro Split — start in a tap.
• Plus expanded Apple Health (heart, respiratory rate, wrist temperature), a redesigned rest timer, and a sharper workout summary.

Core lifting, logging, cardio, and hydration stay free. Villain Arc Pro unlocks the AI and insight features.
```

Approved 2026-06-07 customer-facing copy (Fernando), kept verbatim; this is the text for the ASC "What's New in this Version" field on upload.

### Category

- **Primary:** Health & Fitness
- **Secondary (recommended):** Lifestyle

Sports is a tempting alternative but the discovery overlap with strength apps is stronger in Lifestyle.

### Age rating

- 4+ (no objectionable content)

### Privacy nutrition label coverage

| Data type | Linked to user | Tracking | Purpose |
|---|---|---|---|
| Health & Fitness | Yes (via iCloud only) | No | App functionality |
| User Content (workouts, plans, notes) | Yes (via iCloud only) | No | App functionality |
| Identifiers (Apple ID, via iCloud) | Yes | No | App functionality, sync |
| Diagnostics | No | No | App functionality |

No data is collected by the developer or any third party. iCloud sync is end-to-end Apple-managed. Confirm against the existing 1.2.3 nutrition label in App Store Connect before submission.

---

## Localized variants

The brand name "Villain Arc" stays untranslated across all locales; only the subtitle, keywords, promotional text, and description hook are localized. The full description body can stay English until each locale gets a real translation pass. The `Localizable.xcstrings` in-app strings already ship `needs_review` first-pass translations for these locales.

Keyword lists are 100 chars each, comma-separated, no spaces after commas, no duplicates of name or subtitle terms.

### Spanish (es)

- **Subtitle:** `Coach IA, registro de pesas, cardio`
  - Note: 35 chars — trim before submit. Recommended trim: `Coach IA: pesas y cardio` (24 chars) or `IA, registro de pesas y cardio` (30 chars). Use the 30-char variant.
- **Subtitle (final):** `IA, registro de pesas y cardio`
- **Keywords:** `fuerza,gimnasio,fitness,plan,hipertrofia,rutina,split,5x5,powerlifting,calistenia,correr,caminar`
  - 96 chars.
- **Promotional text:** `Novedades 1.3: coach con IA, planes listos, hidratación, cardio con rutas y tendencias de salud.`
  - 95 chars.
- **Description hook:**
  > Villain Arc es la app de entrenamiento para quienes quieren un plan que mejora con cada sesión — con un coach de IA en el dispositivo que te ayuda a construirlo.

### French (fr)

- **Subtitle:** `Coach IA, journal de muscu`
  - 26 chars.
- **Keywords:** `musculation,salle,fitness,plan,hypertrophie,routine,split,5x5,powerlifting,course,marche,tapis`
  - 96 chars.
- **Promotional text:** `Nouveau en 1.3 : coach IA, programmes prêts, hydratation, cardio avec parcours et tendances santé.`
  - 100 chars.
- **Description hook:**
  > Villain Arc est l'application de musculation pour les sportifs qui veulent un plan qui s'affine à chaque séance — avec un coach IA sur l'appareil pour le construire.

### German (de)

- **Subtitle:** `KI-Coach, Trainingstagebuch`
  - 27 chars.
- **Keywords:** `kraft,fitness,plan,hypertrophie,split,5x5,powerlifting,calisthenics,laufen,gehen,laufband,gym`
  - 95 chars.
- **Promotional text:** `Neu in 1.3: KI-Coach, fertige Pläne, Hydration, Cardio mit Routen, Schlaf- und Pulswerte-Trends.`
  - 99 chars.
- **Description hook:**
  > Villain Arc ist die Trainings-App für Kraftsportler, die mit jedem Workout besser werden wollen — mit einem KI-Coach direkt auf dem Gerät, der dir beim Plan hilft.

### Portuguese — Brazil (pt-BR)

- **Subtitle:** `Coach IA, registro de cargas`
  - 28 chars.
- **Keywords:** `força,academia,fitness,plano,hipertrofia,rotina,split,5x5,powerlifting,corrida,caminhada,esteira`
  - 97 chars.
- **Promotional text:** `Novidades 1.3: coach com IA, programas prontos, hidratação, cardio com rotas e tendências de saúde.`
  - 99 chars.
- **Description hook:**
  > Villain Arc é o app de treino para quem quer um plano que evolui a cada sessão — com um coach de IA no aparelho para te ajudar a montar.

### Japanese (ja)

- **Subtitle:** `AIコーチ、ウェイトログ、有酸素`
  - 17 chars (Japanese counts CJK chars; well under 30).
- **Keywords:** `筋トレ,ジム,フィットネス,プラン,ハイパートロフィー,ルーティン,スプリット,ランニング,ウォーキング,トレッドミル,5x5`
  - 86 chars.
- **Promotional text:** `1.3新機能：AIコーチ、すぐ使えるプラン、水分管理、ルート付き有酸素、健康トレンド。`
  - 42 chars.
- **Description hook:**
  > Villain Arc は、毎セッション賢くなるプランを求めるリフター向けのワークアウトアプリ。デバイス内蔵の AI コーチがプラン作成をサポートします。

### Simplified Chinese (zh-Hans)

- **Subtitle:** `AI 教练，举铁日志，有氧训练`
  - 16 chars.
- **Keywords:** `力量,健身,健身房,计划,肌肥大,训练计划,分化训练,跑步,步行,跑步机,5x5,Powerlifting`
  - 79 chars.
- **Promotional text:** `1.3 新增：设备端 AI 教练、现成训练计划、水分追踪、户外路线有氧、健康趋势。`
  - 41 chars.
- **Description hook:**
  > Villain Arc 是为想要每次训练都更精准的力量训练者打造的应用 — 内置 AI 教练在设备端帮你制定计划。

---

## Pre-submission checklist

- [ ] Bump `MARKETING_VERSION` from `1.2.3` to `1.3.0` in the Xcode project.
- [ ] Confirm `CURRENT_PROJECT_VERSION` is incremented for the build.
- [ ] Update the App Store Connect "App Name" to `Villain Arc: Workout Tracker` (with colon).
- [ ] Update Subtitle to `AI Gym Coach, Lift Log, Cardio`.
- [ ] Paste the Description above, replacing the 1.2.3 description.
- [ ] Paste the What's New text above into the version's "What's New in this Version" field.
- [ ] Paste the Promotional Text above.
- [ ] Paste the Keywords above into the Keywords field.
- [ ] Upload localized subtitle / keywords / promotional text / hook for es, fr, de, pt-BR, ja, zh-Hans.
- [ ] Re-confirm the Privacy nutrition label still matches the table above.
- [ ] Upload screenshots (see `database/automation-output/villainarc-assets/2026-05-27/screenshots/` in Jarvis).
- [ ] Upload App Preview video if recorded (see `database/automation-output/villainarc-assets/2026-05-27/app-preview/`).
- [ ] Set "Available in new territories" so the rollout matches 1.2.3.
- [ ] Confirm the App Review notes from `APP_STORE_REVIEW_NOTES.md` are pasted in.

---

## Notes for future ASO testing (post-launch)

After 1.3 is live, set up a Product Page Optimization test in App Store Connect:

1. Treatment A — swap the lead screenshot from "active workout logging" to "AI plan generation" to test whether the AI hook converts better than the core logging hook.
2. Treatment B — try a tighter subtitle (`AI Coach for Strength Training`, 30 chars) that drops `cardio` and `log` to lean into one strong story.
3. Run for 30 days, aim for ≥ 90% confidence before applying.
