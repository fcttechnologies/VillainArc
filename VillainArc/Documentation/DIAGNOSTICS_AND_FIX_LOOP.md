# Diagnostics and the fix loop

What Villain Arc reports from the field, and how a report becomes a failing test and then a fix.

The layer itself is FCTFoundation's: `FCTMetrics.Diag` is the always-on anonymous client, and
`FCTMetrics.MetricsService` is the MetricKit collector that feeds it crash and hang payloads.
Neither works alone — the service is the only path that hands a crash payload to `Diag`, and
`Diag.start` is the only thing that opens the upload tier — so `VAMetrics.start()` calls both, and
it is the app's very first line.

## What the app names

The whole vocabulary is `Data/Services/App/VADiagVocabulary.swift`, and it is compile-time
constants by construction: `Diag` has no string-taking overload anywhere, so free text has no way
onto the wire.

| kind | type | what it carries |
|---|---|---|
| screens and actions | `VACrumb` | one case per screen, one per meaningful action, one per App Intent |
| flows | `VAFunnel` | the app's own setup, a workout, a cardio session, plan authoring, a review pass |
| features | `VACounter` | how many installs reach a feature at all |
| engine verdicts | `SuggestionVerdictCounter` | the next-set engine's own verdict, by kind and by rung |
| suggestion outcomes | `AlgorithmOutcome<VillainArcEngine>` | what became of one suggestion |

**`VADiagVocabulary.swift` compiles into the widget extension**, so it depends on `FCTMetrics` and
`Foundation` and nothing else. A counter composed from the app's own domain enums lives beside the
code that raises it (`SuggestionVerdictCounters.swift`), not here.

Two placement rules, and they are the whole of the per-screen wiring:

- **A screen gets `.diagScreen(VACrumb.x)` on its own view** — a struct presented by a
  `navigationDestination`, a sheet, a `fullScreenCover`, or a tab root. Never a row, never a
  section, never derived from what the screen is showing. It rides `onAppear`, so the last screen
  crumb before a crash is the screen the person was looking at.
- **An action gets one `Diag.breadcrumb(VACrumb.x)` at the top of the handler that runs it.** Not a
  modifier beside the control: a button's own action closure is the only place that fires exactly
  when the action does, and a gesture attached beside it fires on taps the button refused and
  misses everything reached by a swipe, a toggle, a menu, or an App Intent.

Where FCTFoundation owns the handler it takes the name instead: `AsyncButton`/`FCTPrimaryButton`
take `crumb:`, and `.diagTask(_:)` replaces `.task`. Each pairs the app's name with
`ui.work_finished` on return, so **a name with no finish after it is work that was still running
when the process died**.

**Every App Intent carries a `static let diagCrumb` and drops it as the first line of `perform()`**,
and `IntentCrumbCoverageTests` is what keeps the names distinct and namespaced. It is written by
hand rather than through `FCTEntities.ReportingAppIntent`: that protocol supplies `perform()` from
an extension and declares `run() -> Self.PerformResult`, and Swift does not infer `PerformResult`
from a `run()` whose return type is opaque — which every intent in this app has, since they all
return `some IntentResult & …`. Adopting it fails the conformance outright.

Foundation reports its own surfaces with no wiring here at all: the store open, the sync push's
history fetch, every model session and request, navigation, sign-in, both onboardings, the deletion
doors, the paywall, sync, blobs, and the device conditions a crash arrives after.

## Reading a report

`~/Jarvis/tools/diag/diag` reads the platform's `diag` schema. A crash payload arrives on the
install's *next* launch, carrying the crumb trail as of the crash's own timestamp — not the ring as
it stands when the payload is finally uploaded.

## How a fix lands

The loop is the same whether the report is a crash trail or a funnel that stops converting, and its
first step is always a test that fails the way the field failed.

1. **Turn the trail into a scenario.** The crumbs name the screen, the action, and what was still
   running: `workout.session` → `set_logged` → no `ui.work_finished` is a hang inside logging a
   set, and the system crumbs beside it say whether a memory warning or a thermal band preceded it.
   A funnel that starts and abandons names the step people leave at.
2. **Write the failing test at the layer the trail points to**, and watch it fail the same way. The
   suites are shaped for this: the domain rules (`OutcomeRuleEngineTests`,
   `SuggestionSystemTests`), the store and its descriptors (`SchemaContractTests`, the `Sync`
   suites over `FakeSyncServer`), and the reporting seams themselves. Every reporting surface takes
   its reporter as a parameter — `SuggestionOutcomeReporting`, `SuggestionVerdictReporting` — so a
   spy can prove what a surface reported, which is the only way to test a layer whose recorder sits
   in a process-wide slot with nothing to read it back.
3. **Iterate on `scripts/gate.sh --fast --only <suite>`.** It keeps its DerivedData between runs,
   so after the first build a single suite is seconds rather than minutes.
4. **Fix the cause, watch the same test go green.**
5. **Run `scripts/gate.sh` with no arguments before calling it done.** `--fast` says the fix
   compiles and the suite agrees; it says nothing about Release, the archive, the built artifacts,
   localization drift, the listing, or the cold launch.

Measured on this repo: a warm `--fast --only` run of one suite is ~14s and the whole suite is
~77s, against ~354s for the full gate.

## The two gates

| | `scripts/gate.sh --fast` | `scripts/gate.sh` |
|---|---|---|
| DerivedData | kept between runs, per simulator | thrown away every run |
| builds | Debug only | Debug, Release, and an archive dry-run |
| suite | all of it, or `--only <spec>` | all of it, against a pinned floor |
| reads the built artifacts | no | shortcuts, icons, privacy manifests, in Debug and Release |
| localization drift, the listing, cold launch | no | yes |
| what a green means | the fix compiles and the suite agrees | this is shippable |
