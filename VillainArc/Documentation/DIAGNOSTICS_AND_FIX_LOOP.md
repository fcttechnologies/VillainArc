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

- **The store is named once per foreground, and every time it refuses.** Every user-facing write in
  the app goes through `saveContext(context:)`, which raises `store_saved` through
  `Diag.breadcrumbOncePerForeground` and `store_save_failed` on the catch. A crumb on each of the
  hundreds of saves a session makes would spend the whole ring on itself; a save that *threw* is
  rare, and it is the last thing that happened before whatever comes next.
- **A counter is raised where the feature completes, not where its screen opens** — a plan created
  when the editor's Save commits it, a split created where all three builder paths converge, an
  escalation counted by the router that decided it. `VACounter` has no case that nothing raises: a
  name waiting on an unbuilt feature is deleted with the feature's decision, not parked here.
- **A funnel's three edges live at the three real events**, never at one convenient place: plan
  authoring starts where the router opens a draft, completes where Save commits it, and abandons
  where the draft is discarded; a review pass starts on a surface that has something to review and
  ends on the way out, completed or abandoned by whether anything was left undecided.

**Every App Intent carries a `static let diagCrumb` and hands its body to `Diag.intent(_:_:)`**,
which records that name and then brackets the run with `intent.started` and
`intent.returned`/`.threw`. `IntentCrumbCoverageTests` keeps the names distinct and namespaced, and
sweeps the sources so an intent added without the bracket fails there rather than going quiet.

The body sits in a nested `run()` repeating `perform()`'s signature:

```swift
@MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
    func run() async throws -> some IntentResult & ProvidesDialog {
        …
        return .result(dialog: "…")
    }
    return try await Diag.intent(Self.diagCrumb, run)
}
```

The repeated signature is not ceremony. Every intent here returns an **opaque** type, and an opaque
return type is resolved *from* the return expression — so handing the body straight to the bracket
as a closure makes that resolution circular, and `.result(…)` inside it has no contextual base
(`cannot infer contextual base in reference to member 'result'`). The nested function resolves its
own opaque type first, and `perform()` returns that.

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

## Why there is no sanitizer gate

ThreadSanitizer cannot run this suite. The instrumented host takes a fatal signal
(`ThreadSanitizer:DEADLYSIGNAL`, then "nested bug in the same thread, aborting") with **no race
report, no crash report and no faulting frames** — the sanitizer's own runtime dies inside its
signal handler, so the process is gone before anything can be blamed.

What the measurement found, so nobody re-runs it:

- It is not one test. Across the whole suite in one process it kills the host 12 times at 12
  different tests, and each of those tests passes alone.
- It is not scheduling. Running the suite in 22 chunks of four test classes leaves 20 chunks clean
  and two dying — and `VASyncContractTests` dies **alone in its own process**, so no split avoids
  it. The tests it dies in are the ones that run `ModelContext.delete(model:)` across the schema.
- It is not memory, though it looks like it. Every dying host peaks at 725–940 MB, which reads as a
  ceiling until a single suite peaks at 918 MB and passes; the plain host reaches 736 MB and runs
  all 630 tests green. `TSAN_OPTIONS=flush_memory_ms=1000` changes nothing.
- It never reported a race. Not once, in any run, before dying.

One real defect did come out of the hunt and is fixed: `SyncContractDevice.tearDown()` and this
repo's own `DetachedDebugStoreTests` unlinked SQLite store files while their `ModelContainer` still
held them open (`BUG IN CLIENT OF libsqlite3.dylib: vnode unlinked while in use`). Both now sweep
at process start instead. It was not the cause of the deaths.

**What answers for data races instead is the compiler.** This project builds Swift 6 with warnings
as errors, where a cross-actor race is a build failure rather than something a runtime sample might
happen to catch. That leaves exactly the code that opts out: the `nonisolated(unsafe)` HealthKit
completion handlers in `HealthStoreUpdateCoordinator` and the shared `UserDefaults` behind
`SharedModelContainer.sharedDefaults`. Nothing checks those at runtime; they are read by eye when
they change. AddressSanitizer is not run either — it answers for C/C++/ObjC memory, and every
target here is pure Swift with strict memory safety on.
