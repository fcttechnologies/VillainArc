# Villain Arc 2.0 — App Privacy Labels

The label set App Store Connect must hold for 2.0, derived from `VillainArc/PrivacyInfo.xcprivacy`.
The manifest is authoritative: it is what ships in the binary and what Xcode's privacy report
aggregates, so the listing follows it rather than the reverse.

The three extension manifests (`VillainArcWatchApp`, `VillainArcIntentsExtension`,
`VillainArcWidgetExtension`) each declare `NSPrivacyCollectedDataTypes` as an empty array, so the
app bundle's manifest is the whole declaration.

## Current state on App Store Connect

**Data Not Collected** — "The developer does not collect any data from this app."

That is what the live product page publishes today, accurate for 1.3 ("No accounts, no servers")
and wrong for 2.0. Every row below is therefore an ADD; there is nothing to modify or remove.

## The target set — 12 data types

Tracking: **none**. `NSPrivacyTracking` is `false` and `NSPrivacyTrackingDomains` is empty, so
"Data Used to Track You" stays empty and no ATT prompt is required.

### Data Linked to You — 8 types, all purpose "App Functionality"

| ASC category | ASC data type | Manifest key | What makes it collected |
|---|---|---|---|
| Contact Info | Name | `…TypeName` | `va.user_profile` display name |
| Contact Info | Email Address | `…TypeEmailAddress` | FCT account identity |
| Identifiers | User ID | `…TypeUserID` | FCT account id, scopes every synced row |
| Health & Fitness | Fitness | `…TypeFitness` | `va.workout_session`, `exercise_performance`, `set_performance`, `cardio_session` |
| Health & Fitness | Health | `…TypeHealth` | `va.weight_goal`, `sleep_goal`, `hydration_goal`, `steps_goal` — the goals the user sets over Health metrics |
| Location | Precise Location | `…TypePreciseLocation` | `va.cardio_route_point` — outdoor cardio routes |
| User Content | Photos or Videos | `…TypePhotosorVideos` | Profile photo, uploaded through `FCTBlobSync` |
| Other Data | Other Data Types | `…TypeOtherDataTypes` | The remaining synced tables: `app_settings`, `exercise_preference`, `training_goal`, `training_condition_period`, `suggestion_event`, `suggestion_evaluation`, `prescription_change`, `rep_range_policy`, `pre_workout_context`, `workout_plan`/`split` structure |

### Data Not Linked to You — 4 types

| ASC category | ASC data type | Manifest key | Purpose |
|---|---|---|---|
| Diagnostics | Crash Data | `…TypeCrashData` | App Functionality |
| Diagnostics | Performance Data | `…TypePerformanceData` | App Functionality |
| Diagnostics | Other Diagnostic Data | `…TypeOtherDiagnosticData` | App Functionality |
| Usage Data | Product Interaction | `…TypeProductInteraction` | **Analytics** |

These key on a locally-minted install id and carry no account token, so nothing joins them to an
account. Not-linked is structural here, not a promise.

## Why the split is 8 / 4

Apple does not count a data type as "collected" unless it is transmitted off device and retained.
Every linked row above traces to one of the 25 `va.*` sync tables or to the blob layer, verified
against `VillainArc/Data/Sync/VASyncSchema*.swift`. Apple Health's own samples are *not* declared,
because no Health cache table syncs — Health history is read on device and re-derived per device.
Only the goals the user sets over it ride the wire, which is what "Health" covers.

## Applying it

The web-session commands need an interactive Apple ID password and 2FA, so they are Fernando's:

```bash
asc web privacy pull --app 6759259627 --apple-id fernando@fct-technologies.com --out ./privacy.json
# edit ./privacy.json to the 12 rows above
asc web privacy plan  --app 6759259627 --file ./privacy.json   # read-only diff
asc web privacy apply --app 6759259627 --file ./privacy.json --confirm
asc web privacy publish --app 6759259627 --confirm
```

`pull` first: it emits the canonical shape with the exact category, purpose and data-protection
tokens the file needs, and `asc web privacy catalog` lists them. Hand-writing the JSON without
that pull guesses at token spellings.

Privacy labels are independent of a version — they can be updated without an app update, and they
take effect on publish. Publishing them before 2.0 is live would misdescribe the 1.3 build
customers are running, so this lands with the 2.0 push, not before.
