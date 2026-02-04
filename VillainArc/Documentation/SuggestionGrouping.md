# Suggestion Grouping

## Overview

When displaying suggestions to users, individual `PrescriptionChange` records are grouped for easier review:

- **Set-level**: All changes for the same set grouped together
- **Exercise-level**: Changes grouped by policy category (Rep Range, Rest Time)

---

## Visual Hierarchy

```
Exercise: "Bench Press"
├── [Group] Set 1: weight +5, reps -2
├── [Group] Set 2: weight +5
├── [Group] Rep Range: mode change + bounds changes
└── [Group] Rest Time: mode change + seconds change
```

---

## Grouping Rules

| Change Target | Grouping Key |
|--------------|--------------|
| Set (weight, reps, rest, type) | `setPrescription.id` |
| Rep Range (mode, lower, upper, target) | Policy: `.repRange` |
| Rest Time (mode, seconds) | Policy: `.restTime` |

---

## Policy Categories

```swift
enum ChangePolicy: String {
    case repRange
    case restTime
}

extension ChangeType {
    var policy: ChangePolicy? {
        switch self {
        case .increaseRepRangeLower, .decreaseRepRangeLower,
             .increaseRepRangeUpper, .decreaseRepRangeUpper,
             .increaseRepRangeTarget, .decreaseRepRangeTarget,
             .changeRepRangeMode:
            return .repRange
        case .changeRestTimeMode, .increaseRestTimeSeconds, .decreaseRestTimeSeconds:
            return .restTime
        default:
            return nil  // Set-level changes
        }
    }
}
```

---

## Edge Cases

### Mode + Values Change Together

When mode changes AND values change, they are still individual `PrescriptionChange` records but grouped together:

**Example**: User changes from Target (8 reps) to Range (8-12)
```
[Group] Rep Range:
• Mode: Target → Range
• Upper bound: 6 → 12
[Accept] [Reject]
```

### Mode Change with Default Values

When mode changes to use already-stored values:

**Example**: Switch from Target to Range, and bounds were already 8-12
```
[Group] Rep Range:
• Switch to Range mode (8-12 reps)
[Accept] [Reject]
```

The display reads the current prescription values to show context.

### Reasoning Display

Each `PrescriptionChange` has an optional `changeReasoning: String?` field. If present, display it below the change description:

```
• Weight: 135 → 140 lbs
  "You completed all 12 reps with good form across 3 sessions"
```

For grouped changes, show reasoning for each change that has one:

```
[Group] Set 1:
• Weight: 135 → 140 lbs
  "Hit all reps for 3 consecutive workouts"
• Reps: 12 → 10 (no reasoning)
[Accept] [Reject]
```

---

## Display Logic

For mode changes, show resulting state:

```swift
func descriptionForChange(_ change: PrescriptionChange) -> String {
    switch change.changeType {
    case .changeRepRangeMode:
        let newMode = RepRangeMode(rawValue: Int(change.newValue)) ?? .notSet
        guard let exercise = change.targetExercisePrescription else { return "Mode change" }
        switch newMode {
        case .range:
            return "Switch to Range (\(exercise.repRange.lowerRange)-\(exercise.repRange.upperRange) reps)"
        case .target:
            return "Switch to Target (\(exercise.repRange.targetReps) reps)"
        case .untilFailure:
            return "Switch to Until Failure"
        case .notSet:
            return "Clear rep range"
        }
    case .changeRestTimeMode:
        let newMode = RestTimeMode(rawValue: Int(change.newValue)) ?? .individual
        guard let exercise = change.targetExercisePrescription else { return "Mode change" }
        switch newMode {
        case .allSame:
            return "Switch to All Same (\(exercise.restTimePolicy.allSameSeconds)s)"
        case .individual:
            return "Switch to Individual rest"
        }
    // ... other cases show "X → Y" format
    }
}
```

---

## Data Models

```swift
struct SuggestionGroup: Identifiable {
    let id = UUID()
    let changes: [PrescriptionChange]
    let setPrescription: SetPrescription?
    let policy: ChangePolicy?
    
    var label: String {
        if let set = setPrescription { return "Set \(set.index + 1)" }
        switch policy {
        case .repRange: return "Rep Range"
        case .restTime: return "Rest Time"
        case nil: return "Settings"
        }
    }
}

struct ExerciseSuggestionSection: Identifiable {
    let id = UUID()
    let exercisePrescription: ExercisePrescription
    let groups: [SuggestionGroup]
    var exerciseName: String { exercisePrescription.name }
}
```

---

## UI Actions

| Action | Effect |
|--------|--------|
| Accept Group | Set `decision: .accepted` for all, apply values |
| Reject Group | Set `decision: .rejected` for all |
| Defer Group | Set `decision: .deferred` for all |
| Done (leave page) | Mark remaining as deferred |

---

## Pre-Workout Deferred Check

When starting a workout, check for deferred (or pending) suggestions before beginning.

### Flow

```
User taps "Start Workout"
    ↓
WorkoutSessionContainer created (status: .active)
    ↓
Check: Any deferred/pending PrescriptionChange for this plan's exercises?
    ↓
Yes → Set status: .pending → Show DeferredSuggestionsView
No  → Continue with status: .active → Show workout
    ↓
User reviews deferred suggestions:
  • Accept → apply change
  • Reject → mark rejected
  • Skip → mark rejected (not interested)
    ↓
All reviewed → Set status: .active → Show workout
```

### Implementation

```swift
// In WorkoutSessionContainer or session initialization
func checkForDeferredSuggestions() {
    let planExerciseIDs = Set(workoutPlan.exercises.map { $0.id })
    let planSetIDs = Set(workoutPlan.exercises.flatMap { $0.sets.map { $0.id } })
    
    let deferredChanges = allChanges.filter { change in
        (change.decision == .deferred || change.decision == .pending) &&
        (planExerciseIDs.contains(change.targetExercisePrescription?.id ?? UUID()) ||
         planSetIDs.contains(change.targetSetPrescription?.id ?? UUID()))
    }
    
    if !deferredChanges.isEmpty {
        session.status = .pending
    }
}
```

### SessionStatus Values

| Status | Meaning |
|--------|---------|
| `.pending` | Reviewing deferred suggestions before workout |
| `.active` | Workout in progress |
| `.summary` | Showing summary page after completion |
| `.done` | Finalized |
