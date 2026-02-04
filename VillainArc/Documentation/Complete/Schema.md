# VillainArc: Final Schema Design

## Vision

Transform from "record what happened" to **"plan → execute → learn → adapt"**:
- Plans prescribe targets (weights, reps, rest) not just structure
- AI suggests progressive overload based on performance
- System learns from suggestion outcomes to improve future recommendations
- Mood/effort tracking provides context for personalized adjustments
- One-time overrides allow flexibility without changing the base plan

---

# Part 1: Current → New Schema Mapping

## What We're Keeping (Unchanged)

| Model | Purpose |
|-------|---------|
| `Exercise` | Master catalog of exercises (seeded + custom). Referenced by catalogID. |
| `RepRangePolicy` | Defines rep targets: notSet, target(8), range(8-12), untilFailure |
| `RestTimePolicy` | Defines rest rules: allSame, byType, individual |
| `ExerciseSetType` | Enum: warmup, regular, superSet, dropSet, failure |
| `Muscle` | Enum: chest, back, shoulders, biceps, etc. |

## What We're Replacing

| Current Model | New Model | Key Changes |
|---------------|-----------|-------------|
| `Workout` | `WorkoutSession` | Immutable record of what happened. Links to snapshot used. Adds mood/effort. |
| `WorkoutExercise` | `ExercisePerformance` | Actual performance. Logically required link to prescription (targets). |
| `ExerciseSet` | `SetPerformance` | Actual set data. Logically required link to prescription. Adds `completedAt`. |
| `WorkoutTemplate` | `WorkoutPlan` | Container for versioned plans. No notes (moved to snapshots). |
| `TemplateExercise` | `ExercisePrescription` | Prescribed exercise with targets. Has UUID for suggestion targeting. |
| `TemplateSet` | `SetPrescription` | Prescribed set with `targetWeight`, `targetReps`. Has UUID. |

## What's New

| New Model | Purpose |
|-----------|---------|
| `PlanSnapshot` | A version of a plan at a point in time. Enables plan evolution tracking. |
| `PlanSuggestion` | Bundle of suggested changes after a workout. |
| `SuggestedChange` | One atomic change with flattened decision + outcome. |
| `PreWorkoutMood` | How user feels before workout (for context-aware suggestions). |
| `PostWorkoutEffort` | RPE after workout (for calibrating difficulty). |
| `SessionOverride` | One-time adjustments (sick day = -10% weight). |

---

# Part 2: Complete Model Reference

## Layer 1: Exercise Catalog

### Exercise
**Purpose:** Master catalog of all exercises. Source of truth for exercise metadata.

**How it's used:**
- Seeded from `ExerciseCatalog` on first launch
- Users can create custom exercises (generates unique catalogID)
- Prescriptions and performances reference via `catalogID`
- Enables exercise progression tracking across all workouts

**Properties:**
```
- catalogID: String      // Unique identifier (custom = generated UUID)
- name: String
- musclesTargeted: [Muscle]
- aliases: [String]      // Alternative names for search
- lastUsed: Date?
- favorite: Bool
- isCustom: Bool
- searchIndex: String
- searchTokens: [String]
```

**Connections:**
- Referenced by `ExercisePrescription.catalogID`
- Referenced by `ExercisePerformance.catalogID`

**Why this way:** Separating the catalog from workout data allows exercises to evolve (name changes, muscle corrections) without breaking historical records.

---

## Layer 2: Plans (Versioned Prescriptions)

### WorkoutPlan
**Purpose:** Container for a named workout plan. Holds all versions of that plan.

**How it's used:**
- User creates a plan (e.g., "Push Day")
- Plan accumulates versions as AI suggestions are accepted
- `currentVersion` points to the active snapshot
- Can be favorited, tracks last used date

**Properties:**
```
- id: UUID
- name: String
- favorite: Bool
- complete: Bool                  // Whether plan is fully set up (draft vs finished)
- lastUsed: Date?
- currentVersion: PlanSnapshot?   // Active version (optional for CloudKit)
- versions: [PlanSnapshot]        // All versions (cascade delete)
```

**Connections:**
- Has many `PlanSnapshot` (versions)
- Referenced by `WorkoutSplitDay.plan`

**Why this way:** Separating the plan container from versions allows us to track plan evolution while maintaining a stable identity. Notes moved to snapshots so each version can have its own notes.

---

### PlanSnapshot
**Purpose:** A specific version of a plan at a point in time. Immutable once created.

**How it's used:**
- v1 created when user makes plan or saves freeform as plan
- New versions created when suggestions are accepted
- Freeform workouts create "orphan" snapshots (no workoutPlan)
- Sessions always link to a specific snapshot

**Properties:**
```
- id: UUID
- versionNumber: Int              // 1, 2, 3...
- createdAt: Date
- createdBy: PlanCreator          // .user | .rules | .ai
- notes: String                   // Version-specific notes
- sourceVersion: PlanSnapshot?    // What this was derived from (lineage)
- workoutPlan: WorkoutPlan?       // nil for freeform-created snapshots
- exercisePrescriptions: [ExercisePrescription]  // cascade delete
```

**Connections:**
- Belongs to `WorkoutPlan` (optional - nil for freeform)
- Has many `ExercisePrescription`
- Referenced by `WorkoutSession.planSnapshotUsed`
- Referenced by `PlanSuggestion.planSnapshotFrom`
- Referenced by `SuggestedChange.appliedInSnapshot`

**Why this way:** Snapshots are the key to versioning. Each workout uses exactly one snapshot, so we always know what targets were in effect. Orphan snapshots enable freeform → plan conversion.

---

### ExercisePrescription
**Purpose:** Prescribes an exercise within a plan version, including targets.

**How it's used:**
- Defines what exercise to do and default policies
- Contains set prescriptions with specific targets
- UUID enables AI to target specific exercises in suggestions

**Properties:**
```
- id: UUID                        // For suggestion targeting
- index: Int                      // Order in workout
- catalogID: String               // References Exercise
- name: String                    // Snapshot at creation time
- notes: String
- musclesTargeted: [Muscle]
- repRange: RepRangePolicy        // Default rep policy (cascade)
- restTimePolicy: RestTimePolicy  // Default rest policy (cascade)
- planSnapshot: PlanSnapshot?     // Parent (optional for CloudKit)
- setPrescriptions: [SetPrescription]  // cascade delete
```

**Connections:**
- Belongs to `PlanSnapshot`
- Has many `SetPrescription`
- Referenced by `ExercisePerformance.exercisePrescriptionUsed`
- Targeted by `SuggestedChange.targetExercisePrescriptionID`

**Why this way:** Snapshotting name/muscles at creation time preserves history even if Exercise catalog changes. UUID enables precise suggestion targeting.

---

### SetPrescription
**Purpose:** Prescribes a specific set with target weight, reps, and rest.

**How it's used:**
- Defines exactly what user should aim for
- `targetWeight` is the key addition vs old TemplateSet
- UUID enables AI to suggest changes to specific sets

**Properties:**
```
- id: UUID                        // For suggestion targeting
- index: Int                      // Set number (0, 1, 2...)
- type: ExerciseSetType           // warmup, regular, dropSet, etc.
- targetWeight: Double?           // What to aim for (nil = user decides)
- targetReps: Int?                // Single target (policy handles ranges)
- targetRest: Int                 // Rest seconds after this set
- exercisePrescription: ExercisePrescription?  // Parent (optional for CloudKit)
```

**Connections:**
- Belongs to `ExercisePrescription`
- Referenced by `SetPerformance.setPrescriptionUsed`
- Targeted by `SuggestedChange.targetSetPrescriptionID`

**Why this way:** Target weight is the major addition - plans now prescribe what to lift, not just structure. This enables AI to suggest progressive overload.

---

## Layer 3: Sessions (Immutable Actuals)

### WorkoutSession
**Purpose:** Immutable record of an actual workout. What the user did.

**How it's used:**
- Created when user starts workout (from plan or freeform)
- Records actual performance, timing, mood, effort
- Always links to a snapshot (freeform creates one on-the-fly)
- Never modified after completion (immutable history)

**Properties:**
```
- id: UUID
- title: String
- notes: String
- completed: Bool
- startedAt: Date
- endedAt: Date?
- origin: SessionOrigin           // .plan | .freeform
- preMood: PreWorkoutMood?        // How user felt before
- postEffort: PostWorkoutEffort?  // RPE after
- planSnapshotUsed: PlanSnapshot? // Logically required - what targets were used (optional for CloudKit)
- exercisePerformances: [ExercisePerformance]  // cascade delete
```

**Connections:**
- Links to `PlanSnapshot` (logically required, optional for CloudKit)
- Has many `ExercisePerformance`
- Has one `PreWorkoutMood` (optional)
- Has one `PostWorkoutEffort` (optional)
- Has one `SessionOverride` (optional)
- Referenced by `PlanSuggestion.workoutSessionFrom`
- Referenced by `SuggestedChange.evaluatedInSession`

**Why this way:** Sessions are immutable records - we never change history. Always requiring a snapshot (even for freeform) ensures we always know what the targets were.

---

### PreWorkoutMood
**Purpose:** Captures how user feels before workout for context-aware AI.

**How it's used:**
- User logs mood when starting workout
- AI considers mood when evaluating performance
- Enables suggestions like "you hit targets despite feeling tired"
- Future: correlate with sleep/health data

**Properties:**
```
- id: UUID
- feeling: MoodLevel              // .great | .good | .okay | .tired | .sick
- notes: String?
- workoutSession: WorkoutSession? // Parent (optional for CloudKit)
```

**Connections:**
- Belongs to `WorkoutSession`

**Why this way:** Separate model allows optional capture and easy querying of mood patterns.

---

### PostWorkoutEffort
**Purpose:** Captures perceived exertion after workout.

**How it's used:**
- User logs RPE (1-10) after completing workout
- AI uses this to calibrate suggestion aggressiveness
- High RPE + hit targets = don't increase yet
- Low RPE + hit targets = can push harder

**Properties:**
```
- id: UUID
- rpe: Int                        // 1-10 rate of perceived exertion
- notes: String?
- workoutSession: WorkoutSession? // Parent (optional for CloudKit)
```

**Connections:**
- Belongs to `WorkoutSession`

**Why this way:** RPE is industry-standard for tracking effort. Combined with actual performance, gives AI complete picture.

---

### ExercisePerformance
**Purpose:** Records actual performance of an exercise in a session.

**How it's used:**
- Created for each exercise in workout
- Links to prescription to know what targets were
- Snapshots name/muscles in case catalog changes

**Properties:**
```
- id: UUID                        // For suggestion analysis
- index: Int                      // Order performed
- catalogID: String               // References Exercise
- nameSnapshot: String            // Name at time of workout
- musclesTargetedSnapshot: [Muscle]
- workoutSession: WorkoutSession? // Parent (optional for CloudKit)
- exercisePrescriptionUsed: ExercisePrescription?  // Logically required - targets (optional for CloudKit)
- setPerformances: [SetPerformance]  // cascade delete
```

**Connections:**
- Belongs to `WorkoutSession`
- Links to `ExercisePrescription` (logically required, optional for CloudKit)
- Has many `SetPerformance`

**Why this way:** Required prescription link ensures we always know targets vs actuals. This is key for AI analysis.

---

### SetPerformance
**Purpose:** Records actual performance of a single set.

**How it's used:**
- Records what user actually did (weight, reps)
- `completedAt` enables rest time analysis
- Links to prescription to compare target vs actual

**Properties:**
```
- id: UUID                        // For suggestion analysis
- index: Int                      // Set number
- type: ExerciseSetType
- weight: Double                  // Actual weight lifted
- reps: Int                       // Actual reps performed
- complete: Bool
- completedAt: Date?              // When marked complete (for rest analysis)
- exercisePerformance: ExercisePerformance?  // Parent (optional for CloudKit)
- setPrescriptionUsed: SetPrescription?  // Logically required - targets (optional for CloudKit)
```

**Connections:**
- Belongs to `ExercisePerformance`
- Links to `SetPrescription` (logically required, optional for CloudKit)

**Why this way:** `completedAt` enables calculating actual rest time (time between sets). Even if noisy, patterns emerge for AI analysis.

---

## Layer 4: Suggestions (AI Learning Loop)

### PlanSuggestion
**Purpose:** Bundle of suggested changes generated after a workout.

**How it's used:**
- Created after workout completes
- Contains multiple atomic `SuggestedChange` items (one per set/exercise change)
- Tracks which session triggered it and baseline snapshot
- AI provides reasoning for the overall bundle
- User reviews and decides on each change independently

**Properties:**
```
- id: UUID
- createdAt: Date
- source: SuggestionSource        // .rules | .ai | .user
- reasoning: String?              // AI explanation for bundle
- workoutSessionFrom: WorkoutSession?  // Which workout triggered this (optional for CloudKit)
- planSnapshotFrom: PlanSnapshot?  // Baseline for suggested changes (optional for CloudKit)
- suggestedChanges: [SuggestedChange]  // cascade delete
```

**Connections:**
- Links to `WorkoutSession` (logically required trigger, optional for CloudKit)
- Links to `PlanSnapshot` (logically required baseline, optional for CloudKit)
- Has many `SuggestedChange`

**Why bundling matters:**
- One workout can trigger multiple suggestions (e.g., increase weight on sets 3 & 4)
- Each `SuggestedChange` is atomic and decidable independently
- User can accept some, reject others, defer the rest
- Only accepted changes create new plan version
- Enables fine-grained control: "Yes to bench increase, no to extra set"

**Example Bundle:**
```
PlanSuggestion {
  reasoning: "Strong performance across multiple exercises"
  suggestedChanges: [
    Change 1: Bench Set 3 → +5 lbs (accept)
    Change 2: Bench Set 4 → +5 lbs (accept)
    Change 3: Incline Set 2 → +5 lbs (defer)
    Change 4: Add 4th set to Triceps (reject)
  ]
}
→ New snapshot created with only changes 1 & 2 applied
```

---

### SuggestedChange
**Purpose:** One atomic suggested change with full lifecycle (decision + outcome).

**How it's used:**
- Represents single change (e.g., "increase bench press weight by 5 lbs")
- Tracks both the evidence (source performance) and target (prescription to modify)
- User decides: accept, reject, or defer
- Outcome evaluated after next workout by comparing new performance vs new prescription
- Flattened structure makes AI context building simple

**Properties:**
```
- id: UUID

// What triggered this suggestion (the evidence)
- sourceExercisePerformanceID: UUID?   // Performance that triggered suggestion
- sourceSetPerformanceID: UUID?        // Set performance (e.g., "you did 135×12")

// What to change (in the plan)
- targetExercisePrescriptionID: UUID?  // Which exercise prescription to modify
- targetSetPrescriptionID: UUID?       // Which set prescription (if set-level change)

- changeType: ChangeType               // What kind of change
- delta: Double?                       // Relative change (+5)
- value: Double?                       // Absolute value (set to 135)
- changeReasoning: String?             // AI explanation for this change
- planSuggestion: PlanSuggestion?  // Parent (optional for CloudKit)

// Decision (flattened)
- decision: Decision?                  // .accepted | .rejected | .deferred
- decisionReason: String?              // User's reason if provided
- decidedAt: Date?
- appliedInSnapshot: PlanSnapshot?     // Which version this was applied to

// Outcome (flattened)
- outcome: Outcome?                    // .good | .tooAggressive | .tooEasy | .ignored
- evaluatedAt: Date?
- evaluatedInSession: WorkoutSession?  // Which session evaluated this
```

**Connections:**
- Belongs to `PlanSuggestion`
- References source `ExercisePerformance` / `SetPerformance` (evidence)
- References target `ExercisePrescription` / `SetPrescription` (what to change)
- References `PlanSnapshot` if accepted (where change was applied)
- References `WorkoutSession` when evaluated (where outcome was determined)

**Why this structure:**
- **Source performance**: Shows WHY we suggested (user did 135×12, exceeded target)
- **Target prescription**: Shows WHAT to change (increase to 140×10)
- **Outcome**: Determined by comparing NEXT workout's performance vs the new prescription
- **Flattened**: One query gets complete change lifecycle for AI context

**Outcome Evaluation Flow:**
```
1. SuggestedChange accepted → new snapshot v2 with targetWeight: 140
2. User does next workout using v2
3. SetPerformance records: 140×8 (linked to SetPrescription: 140×10)
4. Compare: actual 8 reps vs target 10 reps
5. Outcome: .tooAggressive (couldn't hit target)
```

---

## Layer 5: Session Overrides

### SessionOverride
**Purpose:** One-time adjustments for a specific session without changing the plan.

**How it's used:**
- User feels sick → apply -10% weight for this session only
- Plan targets remain unchanged
- AI evaluates performance against adjusted expectations

**Properties:**
```
- id: UUID
- reason: String                  // "Feeling sick", "Bad sleep"
- adjustments: [OverrideAdjustment]  // What to adjust (cascade delete)
- workoutSession: WorkoutSession? // Parent (optional for CloudKit)
```

**Connections:**
- Belongs to `WorkoutSession`
- Has many `OverrideAdjustment`

---

### OverrideAdjustment
**Purpose:** Single adjustment within an override. Separate model for independent querying and CloudKit sync.

**Properties:**
```
- id: UUID
- type: AdjustmentType            // .percentWeight | .percentVolume | .skipExercise
- value: Double?                  // e.g., -10 for -10%
- targetExercisePrescriptionID: UUID?  // If exercise-specific
- sessionOverride: SessionOverride?  // Parent (optional for CloudKit)
```

**Connections:**
- Belongs to `SessionOverride`

**Why this way:** Overrides are temporary - they don't create new plan versions. AI can still learn from the session while accounting for the override.

---

## Enums Summary

```swift
enum PlanCreator: String, Codable {
    case user       // User created/edited manually
    case rules      // Rule-based suggestion system
    case ai         // AI model suggestion
}

enum SessionOrigin: String, Codable {
    case plan       // Started from a WorkoutPlan
    case freeform   // Started without a plan
}

enum MoodLevel: String, Codable {
    case great      // Feeling excellent
    case good       // Normal/good
    case okay       // Slightly off
    case tired      // Low energy
    case sick       // Unwell
}

enum SuggestionSource: String, Codable {
    case rules      // Simple rule-based (e.g., "hit all reps → +5 lbs")
    case ai         // Foundation model / ML suggestion
    case user       // User manually suggested change
}

enum ChangeType: String, Codable {
    case increaseWeight, decreaseWeight
    case increaseReps, decreaseReps
    case increaseRest, decreaseRest
    case addSet, removeSet
    case changeSetType
}

enum Decision: String, Codable {
    case accepted   // Apply change to new plan version
    case rejected   // Don't apply, but track if user did it anyway
    case deferred   // Ask again before next workout
}

enum Outcome: String, Codable {
    case good           // User hit or appropriately exceeded targets
    case tooAggressive  // User struggled, couldn't hit targets
    case tooEasy        // User exceeded targets with ease
    case ignored        // User didn't follow the suggestion
}

enum AdjustmentType: String, Codable {
    case percentWeight  // Reduce/increase all weights by %
    case percentVolume  // Reduce/increase sets by %
    case skipExercise   // Skip specific exercise entirely
}
```

---

# Part 3: Detailed Scenarios

## Scenario 1: New User - Fresh Workout (No Plan)

### Setup
- Alex just downloaded VillainArc
- No plans exist yet
- Wants to just start working out

### Flow

**Step 1: Start Freeform Workout**
```
Alex taps "Start Workout" → "Freeform"

System creates:
├── PlanSnapshot (orphan, no WorkoutPlan)
│   ├── versionNumber: 1
│   ├── createdBy: .user
│   ├── workoutPlan: nil  // orphan
│   └── exercisePrescriptions: []  // empty initially
│
└── WorkoutSession
    ├── origin: .freeform
    ├── planSnapshotUsed: → orphan snapshot
    └── exercisePerformances: []
```

**Step 2: Add Exercise**
```
Alex searches "Bench Press", adds it with rep range 8-12

System creates:
├── ExercisePrescription (in orphan snapshot)
│   ├── catalogID: "bench-press"
│   ├── repRange: RepRangePolicy(mode: .range, lower: 8, upper: 12)
│   └── setPrescriptions: []
│
└── ExercisePerformance (in session)
    ├── catalogID: "bench-press"
    ├── exercisePrescriptionUsed: → the prescription above
    └── setPerformances: []
```

**Step 3: Perform Sets**
```
Alex does: Set 1: 135 lbs × 10 reps

System creates (mirroring actuals to prescription):
├── SetPrescription (in ExercisePrescription)
│   ├── targetWeight: 135  // mirrors what Alex did
│   ├── targetReps: 10     // mirrors what Alex did
│   └── targetRest: 90     // from rest policy default
│
└── SetPerformance (in ExercisePerformance)
    ├── weight: 135
    ├── reps: 10
    ├── completedAt: [timestamp]
    └── setPrescriptionUsed: → the prescription above

Alex does: Set 2: 135 lbs × 9 reps
[Same pattern - creates SetPrescription + SetPerformance]

Alex does: Set 3: 135 lbs × 8 reps
[Same pattern]
```

**Step 4: Complete Workout**
```
Alex finishes, logs postEffort: RPE 7

System:
├── Sets endedAt on WorkoutSession
├── Creates PostWorkoutEffort (rpe: 7)
└── Generates PlanSuggestion (if applicable)
    ├── source: .rules
    ├── reasoning: "Completed all sets in rep range"
    └── suggestedChanges:
        └── SuggestedChange
            ├── changeType: .increaseWeight
            ├── delta: +5
            └── targetSetPrescriptionID: set Id
            (we would technically have one for every set)
```

**Step 5: Save as Plan (Optional)**
```
Alex taps "Save as Plan" → names it "Push Day"

System creates:
└── WorkoutPlan
    ├── name: "Push Day"
    ├── currentVersion: → orphan snapshot (now adopted)
    └── versions: [orphan snapshot]

Orphan snapshot.workoutPlan = Push Day (no longer orphan)
```

**Result:**
- Alex has a plan "Push Day" at v1
- Next time Alex does Push Day, targets will be 135 lbs × 10/9/8
- AI suggested +5 lbs for next time (pending decision)

---

## Scenario 2: User Starts Workout with Plan v1

### Setup
- Alex saved "Push Day" from Scenario 1
- Plan v1 has: Bench Press 3×10 @ 135 lbs
- AI suggested +5 lbs for each set (still pending from last time)

### Flow

**Step 1: Check for Deferred Suggestions**
```
Alex taps "Start Push Day"

System checks: Any deferred SuggestedChanges for Push Day?
- Found: +5 lbs suggestions from last workout (was never decided)

UI prompts: "You have a pending suggestion: Increase bench press to 140 lbs for each set. Apply now?"

Option A: Alex taps "Apply"
├── Create new PlanSnapshot v2:
│   ├── sourceVersion: v1
│   ├── createdBy: .ai
│   └── SetPrescription.targetWeight: 140 (every set prescription)
├── Set WorkoutPlan.currentVersion = v2
├── Update SuggestedChange:
│   ├── decision: .accepted
│   ├── decidedAt: now
│   └── appliedInSnapshot: v2
└── Start workout using v2

Option B: Alex taps "Skip for now"
├── Leave plan at v1
├── SuggestedChange.decision remains nil (still pending)
└── Start workout using v1
```

**Step 2: Start Workout (assuming applied v2)**
```
System creates:
└── WorkoutSession
    ├── origin: .plan
    ├── planSnapshotUsed: → v2 (with 140 lb targets)
    └── preMood: (Alex logs .good)
```

**Step 3: Perform Workout**
```
Alex does Bench Press:
- Set 1: 140 lbs × 10 reps ✓ (hit target)
- Set 2: 140 lbs × 9 reps (1 below target)
- Set 3: 140 lbs × 7 reps (3 below target)

Each set creates SetPerformance linked to SetPrescription
```

**Step 4: Complete Workout**
```
Alex finishes, logs postEffort: RPE 8 (felt hard)

System evaluates outcomes for accepted suggestions:
└── The +5 lbs suggestion that created v2:
    ├── Compare: targets were 10/10/10, actuals were 10/9/7
    ├── User struggled on later sets
    ├── RPE was 8 (hard)
    └── outcome: .tooAggressive

System generates new suggestions:
└── PlanSuggestion
    ├── source: .ai
    ├── reasoning: "Previous +5 lbs was too aggressive. Suggest staying at 140 lbs
    │              or trying 137.5 lbs to build consistency."
    └── suggestedChanges:
        └── SuggestedChange
            ├── changeType: .decreaseWeight  // or stay same
            ├── delta: -2.5  // or 0
            └── changeReasoning: "Build rep consistency before increasing"
```

**Step 5: Review Suggestions**
```
UI shows: "How did the +5 lbs increase feel?"
- Shows outcome: tooAggressive

UI shows new suggestion: "Stay at 140 lbs or drop to 137.5?"

Alex decides:
- Accepts "stay at 140" → no new version needed (or creates v3 with same weights)
- Or defers → ask again next time
```

**Result:**
- AI learned that +5 lbs was too aggressive for Alex
- Future suggestions will be more conservative
- Outcome tracking enables personalized progression

---

## Scenario 3: User Several Versions In + Mixed Decisions + Sick Day Override

### Setup
- Alex has been using "Push Day" for weeks
- Current version: v5
- History:
  - v1: Initial (135 lbs)
  - v2: +5 lbs accepted → outcome: good
  - v3: +5 lbs accepted → outcome: good
  - v4: +5 lbs accepted → outcome: tooAggressive
  - v5: stayed at 150 lbs → outcome: good (rebuilt consistency)

### Flow Part A: Normal Workout with Mixed Decisions

**Step 1: Start Workout**
```
Alex starts Push Day (v5: Bench @ 150 lbs)

System creates WorkoutSession linked to v5
Alex logs preMood: .good
```

**Step 2: Complete Workout**
```
Alex crushes it:
- Bench: 150 × 12, 150 × 11, 150 × 10 (exceeded all targets of 10)
- Incline: 115 × 10, 115 × 10, 115 × 8 (mostly hit targets)

postEffort: RPE 6 (felt easier than usual)
```

**Step 3: Suggestion Generation**
```
System generates PlanSuggestion:
├── source: .ai
├── reasoning: "Strong performance, low RPE. Multiple exercises ready for progression."
└── suggestedChanges:
    ├── Change 1: Bench → +5 lbs (to 155)
    │   └── changeReasoning: "Exceeded target reps on all sets, low RPE"
    ├── Change 2: Incline → +5 lbs (to 120)
    │   └── changeReasoning: "Hit targets, but last set dropped. Moderate confidence."
    └── Change 3: Add 4th set to Bench
        └── changeReasoning: "Volume increase may support continued gains"
```

**Step 4: User Reviews (Mixed Decisions)**
```
Alex reviews each:

Change 1 (Bench +5): ACCEPT
├── decision: .accepted
├── decidedAt: now
└── Will be applied to v6

Change 2 (Incline +5): DEFER
├── decision: .deferred
├── decisionReason: "Want to see one more good workout first"
└── Will ask again next workout

Change 3 (Add 4th set): REJECT
├── decision: .rejected
├── decisionReason: "Don't have time for extra sets"
└── Won't be applied, but tracked
```

**Step 5: Create New Version**
```
System creates PlanSnapshot v6:
├── sourceVersion: v5
├── createdBy: .ai
├── Changes applied:
│   └── Bench targetWeight: 150 → 155
├── Incline: unchanged (deferred)
└── Sets: unchanged (rejected)

Update SuggestedChange for Bench:
└── appliedInSnapshot: v6

WorkoutPlan.currentVersion = v6
```

### Flow Part B: Next Workout - User Feels Sick

**Step 1: Start Workout with Deferred Check**
```
Alex starts Push Day

System checks deferred suggestions:
└── Found: Incline +5 lbs (deferred last time)

UI: "Apply Incline +5 lbs now?"
Alex: "Skip" (not feeling great)
```

**Step 2: Log Pre-Workout Mood**
```
Alex logs preMood: .sick

UI: "Would you like to adjust today's targets?"

Alex: "Yes, reduce weights by 10%"

System creates SessionOverride:
├── reason: "Feeling sick"
└── adjustments:
    └── OverrideAdjustment
        ├── type: .percentWeight
        └── value: -10
```

**Step 3: Adjusted Workout**
```
Original targets (v6):
- Bench: 155 lbs × 10
- Incline: 115 lbs × 10

Adjusted targets (for this session only):
- Bench: ~140 lbs × 10
- Incline: ~103 lbs × 10

Alex performs:
- Bench: 140 × 10, 140 × 9, 140 × 8
- Incline: 105 × 10, 105 × 9, 105 × 8

postEffort: RPE 7 (moderate, considering sick)
```

**Step 4: Outcome Evaluation (Adjusted)**
```
System evaluates with override in mind:

For Bench +5 (the change from v5→v6):
├── Original target: 155 lbs
├── Override: -10% = 140 lbs
├── Actual: 140 × 10/9/8
├── Against adjusted target: acceptable performance
└── outcome: .good (considering circumstances)

AI notes:
- User was sick but still performed at adjusted targets
- Don't penalize the v5→v6 suggestion
- May suggest same weights next time to confirm
```

**Step 5: New Suggestions**
```
System generates PlanSuggestion:
├── source: .ai
├── reasoning: "Good performance despite illness. Recommend confirming current
│              targets when feeling better before progressing."
└── suggestedChanges:
    └── Change 1: No weight change, stay at 155
        └── changeReasoning: "Confirm v6 targets when healthy before further increase"
```

**Step 6: Next Healthy Workout**
```
Alex feels great, starts Push Day

Deferred Incline +5 prompts again:
- Alex accepts this time
- Creates v7 with Incline → 120 lbs

Alex crushes workout at full v7 targets
- Bench 155: 11, 10, 10 ✓
- Incline 120: 10, 9, 9 ✓

Outcomes:
- Bench (from v6): outcome = .good
- Incline (from v7): outcome = .good

AI learns:
- Bench +5 was appropriate (confirmed after recovery)
- Incline +5 was appropriate (deferred was good instinct, paid off)
- Rejected 4th set: tracked that user never added it, won't suggest again soon
```

---

## Summary: How the System Learns

### Per-Change Learning
```
SuggestedChange tracks:
├── What was suggested (changeType, delta)
├── What user decided (accept/reject/defer)
├── What happened (outcome: good/tooAggressive/tooEasy/ignored)
└── Context (mood, effort, override)
```

### Pattern Recognition (AI Context)
```
When generating new suggestions, AI receives:
├── Recent changes for this exercise across all users' plans
├── This user's specific outcome history
├── Mood/effort patterns
├── Deferred suggestions that were later accepted/rejected
└── Rejected suggestions user did anyway (→ increase confidence)
```

### Calibration Examples
```
Pattern: User consistently marks suggestions as tooAggressive
→ AI suggests smaller deltas (2.5 lbs instead of 5)

Pattern: User always defers then accepts
→ AI learns user prefers to "sleep on it"

Pattern: User rejects added sets but accepts weight increases
→ AI stops suggesting volume, focuses on intensity

Pattern: User performs well when tired (mood: .tired, outcome: .good)
→ AI learns user's self-assessment is conservative
```

---

## Training Modes & Set-Specific Suggestions

The schema supports various training styles through set-specific prescriptions and suggestions.

### Supported Training Modes

**Ramp-Up / Pyramid Up:**
```
Set 1 (warmup): 95 lbs × 12
Set 2 (warmup): 115 lbs × 10
Set 3 (warmup): 135 lbs × 8
Set 4 (top set): 155 lbs × 6
Set 5 (top set): 155 lbs × 6

Each SetPrescription has its own targetWeight/targetReps.
AI can suggest: "Increase top sets only" → targets sets 4 & 5
```

**Heavy First / Reverse Pyramid:**
```
Set 1 (top set): 165 lbs × 5
Set 2: 155 lbs × 6
Set 3: 145 lbs × 8
Set 4: 135 lbs × 10

AI can suggest: "Increase set 1 weight" → targets only set 1
```

**Straight Sets:**
```
Set 1-4: All 145 lbs × 8

AI can suggest: "Increase all sets to 150 lbs"
→ Creates 4 SuggestedChanges, one per set, in same PlanSuggestion bundle
```

### How Set-Specific Targeting Works

```
SuggestedChange {
  targetSetPrescriptionID: UUID  // Points to specific set
  sourceSetPerformanceID: UUID   // What user did on that set
  changeType: .increaseWeight
  delta: +5
}

One PlanSuggestion can contain multiple SuggestedChanges:
├── Change 1: Set 4 (top set) → +5 lbs
├── Change 2: Set 5 (top set) → +5 lbs
└── Warmup sets: No changes suggested
```

---

## Progressive Overload Patterns

### Rep/Weight Trade-Off (Within Rep Range)

The most common progressive overload pattern:

```
Scenario:
- Exercise has rep range: 8-12
- User's top sets: 145 lbs × 12 (hit top of range)
- User has done this for 2+ weeks consistently

AI Suggestion:
├── PlanSuggestion
│   ├── reasoning: "User consistently hitting 12 reps at 145 lbs.
│   │              Ready to increase weight and reset reps to bottom of range."
│   └── suggestedChanges:
│       ├── Change 1 (Set 3 - top set):
│       │   ├── sourceSetPerformanceID: [the 145×12 performance]
│       │   ├── targetSetPrescriptionID: [set 3 prescription]
│       │   ├── changeType: .increaseWeight
│       │   ├── delta: +5
│       │   └── changeReasoning: "Increase to 150 lbs, target 8 reps"
│       │
│       └── Change 2 (Set 4 - top set):
│           ├── sourceSetPerformanceID: [the 145×12 performance]
│           ├── targetSetPrescriptionID: [set 4 prescription]
│           ├── changeType: .increaseWeight
│           ├── delta: +5
│           └── changeReasoning: "Increase to 150 lbs, target 8 reps"
(Note logic will be slightly different, we would technically have 4 suggestedChanges, 2 which increase weight, 2 which decrease reps since changetype handles only one at a time.)

Result if accepted:
- Old plan: 145 lbs × 12 (top of range)
- New plan: 150 lbs × 8 (bottom of range, weight increased)
- User works back up to 12 reps at new weight
```

### Double Progression Model

```
Week 1: 145 lbs × 8, 8, 8 (bottom of range)
Week 2: 145 lbs × 9, 9, 8
Week 3: 145 lbs × 10, 10, 9
Week 4: 145 lbs × 11, 11, 10
Week 5: 145 lbs × 12, 12, 11 (approaching top)
Week 6: 145 lbs × 12, 12, 12 (hit top of range on all sets)
        ↓
AI suggests: +5 lbs, reset to 8 reps
        ↓
Week 7: 150 lbs × 8, 8, 8 (cycle restarts)
```

### Partial Progression

Sometimes only some sets are ready:
```
Performance: 145 × 12, 145 × 12, 145 × 10, 145 × 8

AI can suggest:
├── Change 1: Set 1 → +5 lbs (hit 12)
├── Change 2: Set 2 → +5 lbs (hit 12)
└── Sets 3-4: No change (didn't hit top of range)

User can accept/reject each independently.
```

---

## Grouping & Combining Suggestions

### How Multiple Changes Work Together

```
PlanSuggestion (bundle) {
  suggestedChanges: [
    Change A: Bench Set 3 → +5 lbs
    Change B: Bench Set 4 → +5 lbs
    Change C: Incline Set 2 → +5 lbs
    Change D: Add 4th set to Triceps
  ]
}

User reviews each change independently:
- Accept A & B (both bench top sets)
- Defer C (want to see one more workout)
- Reject D (no time for extra sets)

System creates new snapshot with only A & B applied.
C remains deferred, D is tracked as rejected.
```

### Grouping by Source Performance

Since each SuggestedChange tracks `sourceSetPerformanceID`, AI can:
1. Group suggestions by which performance triggered them
2. Show user: "Based on your bench press performance..."
3. Evaluate outcomes per-source for learning

```
AI Context for generating suggestions:
├── Exercise: Bench Press
├── Source performances:
│   ├── Set 3: 145 × 12 (exceeded target of 10)
│   └── Set 4: 145 × 12 (exceeded target of 10)
├── Historical outcomes for this exercise:
│   ├── Last +5 lbs suggestion: outcome = good
│   └── Previous +5 lbs suggestion: outcome = good
└── Conclusion: User responds well to +5 lbs increases
```

---

## Goals Integration (Future)

### How Goals Will Feed Into Suggestions

```
User Goal: "Increase bench press 1RM to 225 lbs"
Current estimated 1RM: 195 lbs

AI Context includes:
├── Current performance data
├── Historical progression rate
├── Goal: 225 lbs 1RM
└── Time frame (if specified)

AI Suggestion adjustments:
├── Prioritize strength over hypertrophy
│   → Suggest lower rep ranges (3-5 vs 8-12)
│   → Suggest longer rest periods (3-5 min vs 60-90 sec)
├── More aggressive weight increases on compound lifts
├── Periodization suggestions (deload weeks, peak weeks)
└── "To reach 225 lbs, you need ~15% strength gain.
     At current rate, estimated 12 weeks."
```

### Goal-Aware Suggestion Examples

```
Goal: Muscle gain / Hypertrophy
→ AI suggests: Higher volume (more sets), moderate weight, 8-12 rep range
→ AI suggests: Shorter rest periods to maximize metabolic stress

Goal: Strength / 1RM
→ AI suggests: Lower reps (3-6), heavier weight, longer rest
→ AI suggests: Fewer exercises, more focus on compounds

Goal: Endurance
→ AI suggests: Higher reps (15-20), lighter weight, minimal rest
→ AI prioritizes consistency over weight increases

Goal: Fat loss (with muscle retention)
→ AI suggests: Maintain current weights (don't increase)
→ AI focuses on: "Don't lose strength during cut"
```

### Schema Support for Goals

The current schema already supports goals integration:
1. `SuggestedChange.changeReasoning` can reference goals
2. `PlanSuggestion.reasoning` can explain goal-alignment
3. AI context building will include goals when available
4. No schema changes needed - just add Goals model and feed to AI

---

# Part 4: AI Integration Architecture

## Apple Foundation Models (iOS 26+)

Primary AI integration using Apple's on-device Foundation Models with guided generation.

**Why Apple Foundation Models:**
- **Privacy**: All processing on-device, workout data never leaves
- **Speed**: No network latency, instant suggestions post-workout
- **Guided generation**: Ensures valid structured output (not free-form text)
- **iOS native**: Swift support, optimized for Apple Silicon

**Capabilities:**
- Guided generation for structured model outputs
- On-device processing (privacy-first)
- Context-aware reasoning based on workout history
- Natural language explanations for suggestions

**Guided Generation Approach:**
```swift
// Foundation Model outputs structured suggestions
struct AISuggestionOutput: Codable {
    let reasoning: String
    let changes: [AIChangeOutput]
}

struct AIChangeOutput: Codable {
    let exerciseID: String
    let targetSetIndex: Int
    let changeType: ChangeType
    let delta: Double?
    let value: Double?
    let changeReasoning: String
}

// Guided generation ensures output matches schema
// No parsing errors, no hallucinated fields
```

## Core ML (Supplementary)
- Rule-based heuristics as fallback
- Quick pattern matching for common progressions
- Offline capability when Foundation Models unavailable

## Data Flow for AI
```
1. Workout completes
2. Gather context:
   ├── Current session performances (all sets with timestamps)
   ├── Plan snapshot targets
   ├── Historical outcomes for this exercise
   ├── User's mood/effort patterns
   ├── Previous suggestion decisions & outcomes
   └── User goals (when available)
3. Build prompt for Foundation Model
4. Use guided generation → structured AISuggestionOutput
5. Map to PlanSuggestion + SuggestedChanges
6. Present to user for review (accept/reject/defer each)
7. After next workout, evaluate outcomes
8. Outcomes feed back into future context
```

---

# Part 5: Future Considerations

## Gym Support (V2+)
```
Gym model: id, name, location
SetPrescription gains: gymSpecificWeights: [GymWeight]
Session tracks: gym: Gym?

Enables: "At Gold's Gym use 50 lb dumbbells, at home use 45 lbs"
```

## Goals Integration
```
User sets goals: "Increase bench 1RM to 225 lbs"
AI factors goals into suggestions: longer rest, strength-focused rep ranges
```

## Health Metrics
```
Sleep data from HealthKit
AI adjusts suggestions: "Poor sleep → conservative targets today"
```

## Nutrition
```
Calorie/protein tracking
AI correlates: "Hitting protein goals → faster progression"
```

---

# Part 6: Quick Reference Summary

## All Models at a Glance

```
EXERCISE CATALOG (unchanged)
└── Exercise                    // Master catalog, referenced by catalogID

PLANS (versioned prescriptions)
├── WorkoutPlan                 // Container with name, favorite, complete, lastUsed
│   └── versions: [PlanSnapshot]
│       └── currentVersion: PlanSnapshot? (optional for CloudKit)
│
├── PlanSnapshot                // Immutable version (v1, v2, v3...)
│   ├── versionNumber, createdAt, createdBy
│   ├── notes (version-specific)
│   ├── sourceVersion (lineage)
│   ├── workoutPlan (optional - nil for freeform)
│   └── exercisePrescriptions: [ExercisePrescription]
│
├── ExercisePrescription        // What exercise to do
│   ├── id (UUID for targeting)
│   ├── index, catalogID, name, notes
│   ├── repRange, restTimePolicy
│   └── setPrescriptions: [SetPrescription]
│
└── SetPrescription             // Target for specific set
    ├── id (UUID for targeting)
    ├── index, type
    └── targetWeight, targetReps, targetRest

SESSIONS (immutable actuals)
├── WorkoutSession              // What user actually did
│   ├── title, notes, completed
│   ├── startedAt, endedAt
│   ├── origin (.plan | .freeform)
│   ├── planSnapshotUsed (logically required, optional for CloudKit)
│   ├── preMood, postEffort (optional)
│   └── exercisePerformances: [ExercisePerformance]
│
├── PreWorkoutMood              // How user felt before
│   └── feeling: .great | .good | .okay | .tired | .sick
│
├── PostWorkoutEffort           // RPE after workout
│   └── rpe: 1-10
│
├── ExercisePerformance         // Actual exercise data
│   ├── id, index, catalogID, nameSnapshot
│   ├── exercisePrescriptionUsed (logically required, optional for CloudKit)
│   └── setPerformances: [SetPerformance]
│
└── SetPerformance              // Actual set data
    ├── id, index, type
    ├── weight, reps, complete
    ├── completedAt (for rest time analysis)
    └── setPrescriptionUsed (logically required, optional for CloudKit)

SUGGESTIONS (AI learning loop)
├── PlanSuggestion              // Bundle per workout
│   ├── source: .rules | .ai | .user
│   ├── reasoning
│   ├── workoutSessionFrom, planSnapshotFrom
│   └── suggestedChanges: [SuggestedChange]
│
└── SuggestedChange             // One atomic change (flattened)
    ├── SOURCE (evidence):
    │   ├── sourceExercisePerformanceID
    │   └── sourceSetPerformanceID
    │
    ├── TARGET (what to change):
    │   ├── targetExercisePrescriptionID
    │   └── targetSetPrescriptionID
    │
    ├── CHANGE:
    │   ├── changeType, delta, value
    │   └── changeReasoning
    │
    ├── DECISION (flattened):
    │   ├── decision: .accepted | .rejected | .deferred
    │   ├── decisionReason, decidedAt
    │   └── appliedInSnapshot
    │
    └── OUTCOME (flattened):
        ├── outcome: .good | .tooAggressive | .tooEasy | .ignored
        ├── evaluatedAt
        └── evaluatedInSession

OVERRIDES (one-time adjustments)
├── SessionOverride             // Temporary adjustment
│   ├── reason
│   └── adjustments: [OverrideAdjustment] (cascade delete)
│
└── OverrideAdjustment          // Separate model for CloudKit sync
    ├── id
    ├── type: .percentWeight | .percentVolume | .skipExercise
    └── value, targetExercisePrescriptionID
```

## Key Relationships

```
All relationships are optional at the Swift type level for CloudKit compatibility.
"Logically required" means app code always sets these — nil indicates sync-in-progress.

WorkoutPlan ──1:N──> PlanSnapshot ──1:N──> ExercisePrescription ──1:N──> SetPrescription
                           │
                           ▼
WorkoutSession ──────> planSnapshotUsed (logically required)
      │
      └──1:N──> ExercisePerformance ──────> exercisePrescriptionUsed (logically required)
                       │
                       └──1:N──> SetPerformance ──────> setPrescriptionUsed (logically required)

PlanSuggestion ──────> workoutSessionFrom (logically required)
      │          └──> planSnapshotFrom (logically required)
      │
      └──1:N──> SuggestedChange ──────> sourceSetPerformanceID (evidence)
                                  └──> targetSetPrescriptionID (what to change)
                                  └──> appliedInSnapshot (if accepted)
                                  └──> evaluatedInSession (outcome evaluation)

SessionOverride ──1:N──> OverrideAdjustment
```

## Core Flows

```
FREEFORM WORKOUT:
1. Start freeform → create orphan PlanSnapshot + WorkoutSession
2. Add exercises → create prescriptions + performances (mirror actuals)
3. Complete → generate suggestions
4. Optional: "Save as Plan" → create WorkoutPlan, attach snapshot as v1

PLAN WORKOUT:
1. Check deferred suggestions → prompt to apply
2. Start from plan → create WorkoutSession linked to currentVersion
3. Perform → create performances linked to prescriptions
4. Complete → evaluate previous outcomes, generate new suggestions
5. User decides: accept/reject/defer each change
6. Accepted changes → create new snapshot version

SUGGESTION LIFECYCLE:
1. Generated after workout (with reasoning)
2. User decides: accept, reject, or defer
3. Accepted → applied in new snapshot version
4. Next workout → outcome evaluated (good/tooAggressive/tooEasy/ignored)
5. Outcomes feed back to improve future suggestions
```

## Design Principles

1. **Prescriptions are targets, Performances are actuals** - Always compare
2. **Snapshots are immutable** - New version for any change
3. **Sessions always link to a snapshot** - Even freeform (enables "Save as Plan")
4. **Prescriptions are logically required on performances** - Always know target vs actual. App code always sets these; nil values indicate CloudKit sync-in-progress, not a valid data state
5. **Suggestions track source AND target** - Evidence + what to change
6. **Flattened SuggestedChange** - One query for complete lifecycle
7. **Goals feed AI context** - No schema change, just more context
8. **Overrides are temporary** - Don't create new versions
9. **CloudKit-ready relationships** - All relationships are optional (`?`) at the Swift type level to support asynchronous CloudKit sync. App logic still treats parent-child and prescription-performance links as logically required
