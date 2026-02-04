# Context Gathering Architecture

## Overview

Context providers gather rich historical and environmental data for both rule-based suggestions and AI model calls. All context structures are `Codable` for easy serialization to FoundationModels.

---

## Context Provider Categories

### 1. Exercise History Context
**Purpose**: Track progression, trends, and patterns for a specific exercise over time.

### 2. Prescription Context
**Purpose**: Current targets and policies for the exercise.

### 3. Performance Context  
**Purpose**: What the user actually did this session.

### 4. Change History Context
**Purpose**: Past suggestions, decisions, and outcomes for this exercise.

### 5. User Readiness Context
**Purpose**: Recovery state, mood, health signals.

### 6. Session Context
**Purpose**: When, how long, what else was done this session.

### 7. Program Context (Future)
**Purpose**: Broader training context (volume, frequency, split type).

---

## V1 AI Usage (Per Exercise)

- **Exercise history context is complete** (backed by `ExerciseHistory` + `ExerciseHistoryUpdater`).
- For AI V1, we **do not** need separate `PrescriptionContext` or `PerformanceContext` providers.
  - We pass the **prescription + performance snapshots directly** per exercise at generation time.
- Tool calling and richer context remain **post-V1**.

## 1. Exercise History Context

**NEW: Backed by `ExerciseHistory` Model** (VillainArc/Data/Models/Exercise/ExerciseHistory.swift)

**Status**: Implemented via cached history updates (`ExerciseHistoryUpdater`).

Instead of calculating statistics on-the-fly, we now maintain a cached `ExerciseHistory` model per exercise that updates when workouts complete. This dramatically improves performance.

```swift
import Foundation
import SwiftData

/// Historical performance data for a specific exercise across multiple sessions
/// Sourced from cached ExerciseHistory model (updated when workouts complete)
struct ExerciseHistoryContext: Codable, Sendable {
    let catalogID: String
    
    // Progression metrics
    let totalSessions: Int
    let last30DaySessions: Int
    let progressionTrend: ProgressionTrend
    let lastWorkoutDate: Date?
    
    // Historical bests (PRs)
    let bestEstimated1RM: Double
    let bestEstimated1RMDate: Date?
    let bestWeight: Double
    let bestWeightDate: Date?
    let bestVolume: Double
    let bestVolumeDate: Date?
    let bestRepsAtWeight: [WeightRepsRecord]  // All weight/rep PRs
    
    // Recent averages (last 3 sessions)
    let last3AvgWeight: Double
    let last3AvgVolume: Double
    let last3AvgSetCount: Int
    let last3AvgRestSeconds: Int
    
    // Typical patterns (all-time)
    let typicalSetCount: Int
    let typicalRepRangeLower: Int
    let typicalRepRangeUpper: Int
    let typicalRestSeconds: Int
    
    // Weight progression for charting (last 10 sessions)
    let progressionPoints: [ProgressionPoint]
}

// ProgressionTrend is now a proper enum in VillainArc/Data/Models/Enums/Exercise/ProgressionTrend.swift
// ProgressionPoint is now a SwiftData @Model in VillainArc/Data/Models/Exercise/ProgressionPoint.swift

struct WeightRepsRecord: Codable, Sendable {
    let weight: Double
    let reps: Int
}
```

**Provider Implementation (uses cached ExerciseHistory):**
```swift
@MainActor
class ExerciseHistoryProvider {
    static func fetchContext(
        catalogID: String,
        context: ModelContext
    ) -> ExerciseHistoryContext? {
        // Fetch cached history model
        let descriptor = ExerciseHistory.forCatalogID(catalogID)
        guard let history = try? context.fetch(descriptor).first else {
            return nil  // No history exists yet
        }
        
        // Convert to context structure
        let repsRecords = history.bestRepsAtWeight.map { weight, reps in
            WeightRepsRecord(weight: weight, reps: reps)
        }.sorted { $0.weight > $1.weight }  // Descending weight

        
        return ExerciseHistoryContext(
            catalogID: history.catalogID,
            totalSessions: history.totalSessions,
            last30DaySessions: history.last30DaySessions,
            progressionTrend: history.progressionTrend,  // Direct access (computed property)
            lastWorkoutDate: history.lastWorkoutDate,
            bestEstimated1RM: history.bestEstimated1RM,
            bestEstimated1RMDate: history.bestEstimated1RMDate,
            bestWeight: history.bestWeight,
            bestWeightDate: history.bestWeightDate,
            bestVolume: history.bestVolume,
            bestVolumeDate: history.bestVolumeDate,
            bestRepsAtWeight: repsRecords,
            last3AvgWeight: history.last3AvgWeight,
            last3AvgVolume: history.last3AvgVolume,
            last3AvgSetCount: history.last3AvgSetCount,
            last3AvgRestSeconds: history.last3AvgRestSeconds,
            typicalSetCount: history.typicalSetCount,
            typicalRepRangeLower: history.typicalRepRangeLower,
            typicalRepRangeUpper: history.typicalRepRangeUpper,
            typicalRestSeconds: history.typicalRestSeconds,
            progressionPoints: history.sortedProgressionPoints  // Use sorted computed property
        )
    }
}
```

---

## 2. Prescription Context

**V1 Note**: For AI v1, pass prescription snapshots directly per exercise. This provider is optional and can be deferred until tool calling.

```swift
/// Current prescription targets for this exercise
struct PrescriptionContext: Codable, Sendable {
    let exerciseName: String
    let exerciseID: UUID
    
    // Rep range policy
    let repRangeMode: String
    let repRangeLower: Int?
    let repRangeUpper: Int?
    let repRangeTarget: Int?
    
    // Rest time policy
    let restTimeMode: String
    let restTimeAllSameSeconds: Int?
    
    // Sets
    let sets: [SetPrescriptionSnapshot]
    let totalPrescribedVolume: Double  // Sum of target weight * target reps
}

struct SetPrescriptionSnapshot: Codable, Sendable {
    let index: Int
    let setID: UUID
    let type: String
    let targetWeight: Double
    let targetReps: Int
    let targetRest: Int
}
```

**Provider:**
```swift
@MainActor
class PrescriptionContextProvider {
    static func fetchContext(
        prescription: ExercisePrescription
    ) -> PrescriptionContext {
        let sets = prescription.sortedSets.map { set in
            SetPrescriptionSnapshot(
                index: set.index,
                setID: set.id,
                type: set.type.displayName,
                targetWeight: set.targetWeight,
                targetReps: set.targetReps,
                targetRest: set.targetRest
            )
        }
        
        let totalVolume = sets.reduce(0.0) { $0 + ($1.targetWeight * Double($1.targetReps)) }
        
        return PrescriptionContext(
            exerciseName: prescription.name,
            exerciseID: prescription.id,
            repRangeMode: prescription.repRange.activeMode.displayName,
            repRangeLower: prescription.repRange.activeMode == .range ? prescription.repRange.lowerRange : nil,
            repRangeUpper: prescription.repRange.activeMode == .range ? prescription.repRange.upperRange : nil,
            repRangeTarget: prescription.repRange.activeMode == .target ? prescription.repRange.targetReps : nil,
            restTimeMode: prescription.restTimePolicy.activeMode.displayName,
            restTimeAllSameSeconds: prescription.restTimePolicy.activeMode == .allSame ? prescription.restTimePolicy.allSameSeconds : nil,
            sets: sets,
            totalPrescribedVolume: totalVolume
        )
    }
}
```

---

## 3. Performance Context

**V1 Note**: For AI v1, pass performance snapshots directly per exercise. This provider is optional and can be deferred until tool calling.

```swift
/// What the user actually did this session
struct PerformanceContext: Codable, Sendable {
    let exerciseName: String
    let sessionDate: Date
    
    // Actual sets performed
    let sets: [SetPerformanceSnapshot]
    
    // Aggregates
    let totalVolume: Double
    let bestEstimated1RM: Double?
    let topWeight: Double?
    let averageReps: Double
    let averageRestSeconds: Int
    
    // Comparison to prescription
    let setCountDelta: Int  // Performed - prescribed
    let volumeDelta: Double  // Performed - prescribed (%)
}

struct SetPerformanceSnapshot: Codable, Sendable {
    let index: Int
    let type: String
    let weight: Double
    let reps: Int
    let restSeconds: Int
    let effectiveRestSeconds: Int  // Accounts for drop/super sets
    let complete: Bool
    
    // Compared to prescription (if exists)
    let weightDelta: Double?  // Actual - target
    let repsDelta: Int?       // Actual - target
    let restDelta: Int?       // Actual - target
}
```

**Provider:**
```swift
@MainActor
class PerformanceContextProvider {
    static func fetchContext(
        performance: ExercisePerformance,
        prescription: ExercisePrescription?
    ) -> PerformanceContext {
        let sets = performance.sortedSets.enumerated().map { (idx, set) in
            let prescribedSet = prescription?.sortedSets[safe: idx]
            
            return SetPerformanceSnapshot(
                index: set.index,
                type: set.type.displayName,
                weight: set.weight,
                reps: set.reps,
                restSeconds: set.restSeconds,
                effectiveRestSeconds: performance.effectiveRestSeconds(after: set),
                complete: set.complete,
                weightDelta: prescribedSet != nil ? set.weight - (prescribedSet!.targetWeight) : nil,
                repsDelta: prescribedSet != nil ? set.reps - prescribedSet!.targetReps : nil,
                restDelta: prescribedSet != nil ? set.restSeconds - prescribedSet!.targetRest : nil
            )
        }
        
        let avgReps = sets.isEmpty ? 0 : Double(sets.map { $0.reps }.reduce(0, +)) / Double(sets.count)
        let avgRest = sets.isEmpty ? 0 : sets.map { $0.restSeconds }.reduce(0, +) / sets.count
        
        let prescribedVolume = prescription?.sortedSets.reduce(0.0) { $0 + ($1.targetWeight * Double($1.targetReps)) } ?? 0
        let actualVolume = performance.totalVolume
        let volumeDelta = prescribedVolume > 0 ? ((actualVolume - prescribedVolume) / prescribedVolume) : 0
        
        return PerformanceContext(
            exerciseName: performance.name,
            sessionDate: performance.date,
            sets: sets,
            totalVolume: actualVolume,
            bestEstimated1RM: performance.bestEstimated1RM,
            topWeight: performance.bestWeight,
            averageReps: avgReps,
            averageRestSeconds: avgRest,
            setCountDelta: performance.sets.count - (prescription?.sets.count ?? 0),
            volumeDelta: volumeDelta
        )
    }
}
```

---

## 4. Suggestion History Context

**Purpose**: Summarize past prescription changes for this exercise to guide future suggestions.

This context has two layers:
1. **Exercise-wide history** (all change types)
2. **Focused history** for a specific `ChangeType` the rules/AI are considering

```swift
/// Exercise-wide summary of past suggestions and outcomes
struct SuggestionHistoryContext: Codable, Sendable {
    let catalogID: String

    // Recent changes (last N)
    let recentChanges: [ChangeSnapshot]

    // Overall statistics
    let totalSuggestionsReceived: Int
    let acceptanceRate: Double
    let rejectionRate: Double
    let deferralRate: Double

    // Outcome statistics (outcome matters most)
    let goodOutcomeRate: Double
    let tooAggressiveRate: Double
    let tooEasyRate: Double
    let ignoredRate: Double

    // Aggregate scoring by change type (weighted by outcome, lightly by decision)
    let changeTypeScores: [ChangeTypeScore]
}

/// Focused summary for a specific ChangeType being considered
struct ChangeTypeHistoryContext: Codable, Sendable {
    let catalogID: String
    let changeType: String
    let totalCount: Int
    let weightedScore: Double
    let averageMagnitude: Double?
    let goodOutcomeRate: Double
    let tooAggressiveRate: Double
    let tooEasyRate: Double
    let ignoredRate: Double
    let recentChanges: [ChangeSnapshot]
    let topOutcomeReasons: [String]
}

struct ChangeTypeScore: Codable, Sendable {
    let changeType: String
    let totalCount: Int
    let weightedScore: Double
    let averageMagnitude: Double?
    let goodOutcomeRate: Double
    let tooAggressiveRate: Double
    let tooEasyRate: Double
    let ignoredRate: Double
}

struct ChangeSnapshot: Codable, Sendable {
    let changeID: UUID
    let createdAt: Date
    let source: String  // SuggestionSource
    let changeType: String
    let decision: String
    let outcome: String

    // Details
    let previousValue: Double?
    let newValue: Double?
    let magnitude: Double?  // abs(new - previous) for numeric changes only
    let reasoning: String?
    let outcomeReason: String?

    // Target
    let targetSetIndex: Int?  // If set-specific
    let targetExerciseLevel: Bool  // If exercise-level change

    // Evaluation
    let evaluatedAt: Date?
    let evaluatedInSessionDate: Date?
}
```

**Notes on magnitude**
- Only compute `magnitude` for numeric change types (weight, reps, rest, rep range values).
- For categorical changes (mode/type/add/remove/reorder), leave `magnitude` nil and treat magnitude weight as 1.0.

**Scoring guidelines**
- Outcome drives the score; decision only nudges it (accept adds a small boost).
- Apply a recency decay so newer outcomes matter more than old ones.
- Weight by magnitude only when the change is numeric.

**Provider (exercise-wide + focused):**
```swift
@MainActor
class SuggestionHistoryProvider {
    static func fetchContext(
        catalogID: String,
        limit: Int = 10,
        context: ModelContext
    ) -> SuggestionHistoryContext {
        let descriptor = FetchDescriptor<PrescriptionChange>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        guard let allChanges = try? context.fetch(descriptor) else {
            return SuggestionHistoryContext.empty(catalogID: catalogID)
        }

        let exerciseChanges = allChanges.filter { $0.catalogID == catalogID }
        let recent = Array(exerciseChanges.prefix(limit))

        let snapshots = recent.map { change in
            let magnitude = (change.previousValue != nil && change.newValue != nil)
                ? abs((change.newValue ?? 0) - (change.previousValue ?? 0))
                : nil

            return ChangeSnapshot(
                changeID: change.id,
                createdAt: change.createdAt,
                source: change.source.rawValue,
                changeType: change.changeType.rawValue,
                decision: change.decision.rawValue,
                outcome: change.outcome.rawValue,
                previousValue: change.previousValue,
                newValue: change.newValue,
                magnitude: magnitude,
                reasoning: change.changeReasoning,
                outcomeReason: change.outcomeReason,
                targetSetIndex: change.targetSetPrescription?.index,
                targetExerciseLevel: change.targetSetPrescription == nil,
                evaluatedAt: change.evaluatedAt,
                evaluatedInSessionDate: change.evaluatedInSession?.startedAt
            )
        }

        let total = exerciseChanges.count
        let accepted = exerciseChanges.filter { $0.decision == .accepted }.count
        let rejected = exerciseChanges.filter { $0.decision == .rejected }.count
        let deferred = exerciseChanges.filter { $0.decision == .deferred }.count

        let acceptedChanges = exerciseChanges.filter { $0.decision == .accepted }
        let goodOutcomes = acceptedChanges.filter { $0.outcome == .good }.count
        let aggressive = acceptedChanges.filter { $0.outcome == .tooAggressive }.count
        let easy = acceptedChanges.filter { $0.outcome == .tooEasy }.count
        let ignored = acceptedChanges.filter { $0.outcome == .ignored }.count

        let scores = buildChangeTypeScores(from: exerciseChanges)

        return SuggestionHistoryContext(
            catalogID: catalogID,
            recentChanges: snapshots,
            totalSuggestionsReceived: total,
            acceptanceRate: total > 0 ? Double(accepted) / Double(total) : 0,
            rejectionRate: total > 0 ? Double(rejected) / Double(total) : 0,
            deferralRate: total > 0 ? Double(deferred) / Double(total) : 0,
            goodOutcomeRate: acceptedChanges.isEmpty ? 0 : Double(goodOutcomes) / Double(acceptedChanges.count),
            tooAggressiveRate: acceptedChanges.isEmpty ? 0 : Double(aggressive) / Double(acceptedChanges.count),
            tooEasyRate: acceptedChanges.isEmpty ? 0 : Double(easy) / Double(acceptedChanges.count),
            ignoredRate: acceptedChanges.isEmpty ? 0 : Double(ignored) / Double(acceptedChanges.count),
            changeTypeScores: scores
        )
    }

    static func fetchChangeTypeContext(
        catalogID: String,
        changeType: ChangeType,
        limit: Int = 10,
        context: ModelContext
    ) -> ChangeTypeHistoryContext {
        let all = fetchContext(catalogID: catalogID, limit: limit, context: context)
        return buildFocusedContext(from: all, changeType: changeType)
    }
}

extension SuggestionHistoryContext {
    static func empty(catalogID: String) -> SuggestionHistoryContext {
        SuggestionHistoryContext(
            catalogID: catalogID,
            recentChanges: [],
            totalSuggestionsReceived: 0,
            acceptanceRate: 0,
            rejectionRate: 0,
            deferralRate: 0,
            goodOutcomeRate: 0,
            tooAggressiveRate: 0,
            tooEasyRate: 0,
            ignoredRate: 0,
            changeTypeScores: []
        )
    }
}
```

---

## 5. User Readiness Context

```swift
/// User's recovery state and readiness signals
struct UserReadinessContext: Codable, Sendable {
    // Mood
    let preMoodLevel: String  // MoodLevel
    let preMoodNotes: String?
    
    // Recovery indicators
    let daysSinceLastWorkout: Int
    let daysSinceLastTrainedThisMuscle: Int?  // If trackable
    
    // Apple Health data (future)
    let sleepHours: Double?         // Last night's sleep
    let sleepQuality: Double?       // 0-1 score
    let restingHeartRate: Int?      // Morning RHR
    let heartRateVariability: Double?  // HRV in ms
    
    // Computed readiness score
    let readinessScore: Double      // 0-1 composite score
    let readinessLevel: String      // "Low" / "Moderate" / "High"
}
```

**Provider:**
```swift
@MainActor
class UserReadinessProvider {
    static func fetchContext(
        for session: WorkoutSession,
        context: ModelContext
    ) -> UserReadinessContext {
        // Get mood
        let mood = session.preMood.mood
        let notes = session.preMood.notes
        
        // Calculate days since last workout
        let completedDescriptor = WorkoutSession.completedSessions(limit: 2)
        let lastSessions = (try? context.fetch(completedDescriptor)) ?? []
        
        let daysSince: Int
        if lastSessions.count >= 2 {
            let previous = lastSessions[1]
            let days = Calendar.current.dateComponents([.day], from: previous.startedAt, to: session.startedAt).day ?? 0
            daysSince = max(0, days)
        } else {
            daysSince = 0
        }
        
        // TODO: Apple Health integration
        let sleepHours: Double? = nil
        let sleepQuality: Double? = nil
        let rhr: Int? = nil
        let hrv: Double? = nil
        
        // Calculate readiness score
        let score = calculateReadinessScore(
            mood: mood,
            daysSince: daysSince,
            sleepHours: sleepHours,
            hrv: hrv
        )
        
        let level: String
        if score < 0.4 {
            level = "Low"
        } else if score < 0.7 {
            level = "Moderate"
        } else {
            level = "High"
        }
        
        return UserReadinessContext(
            preMoodLevel: mood.rawValue,
            preMoodNotes: notes.isEmpty ? nil : notes,
            daysSinceLastWorkout: daysSince,
            daysSinceLastTrainedThisMuscle: nil,  // TODO: Implement
            sleepHours: sleepHours,
            sleepQuality: sleepQuality,
            restingHeartRate: rhr,
            heartRateVariability: hrv,
            readinessScore: score,
            readinessLevel: level
        )
    }
    
    private static func calculateReadinessScore(
        mood: MoodLevel,
        daysSince: Int,
        sleepHours: Double?,
        hrv: Double?
    ) -> Double {
        var score = 0.5  // Base neutral
        
        // Mood contribution (0-0.3)
        switch mood {
        case .great: score += 0.3
        case .good: score += 0.15
        case .neutral: score += 0.0
        case .low: score -= 0.15
        case .veryLow: score -= 0.3
        case .notSet: score += 0.0
        }
        
        // Recovery contribution (0-0.2)
        if daysSince == 0 { score -= 0.1 }      // Same day (second workout)
        else if daysSince == 1 { score += 0.1 } // 1 day rest
        else if daysSince >= 2 { score += 0.2 } // 2+ days rest
        
        // Sleep contribution (0-0.2) - future
        if let sleep = sleepHours {
            if sleep >= 8 { score += 0.2 }
            else if sleep >= 7 { score += 0.1 }
            else if sleep < 6 { score -= 0.1 }
        }
        
        // HRV contribution (0-0.1) - future
        // Higher HRV = better recovery
        // Implementation depends on baseline
        
        return max(0.0, min(1.0, score))
    }
}
```

---

## 6. Session Context

```swift
/// Context about the current workout session
struct SessionContext: Codable, Sendable {
    let sessionID: UUID
    let startedAt: Date
    let planName: String?
    let sessionOrigin: String  // SessionOrigin
    
    // Session-level data
    let totalExercisesCompleted: Int
    let totalSetsCompleted: Int
    let sessionDurationMinutes: Int?
    
    // Other exercises in this session (for fatigue context)
    let otherExercisesPerformed: [String]  // Exercise names
    let precedingExerciseCount: Int  // How many exercises before this one
}
```

**Provider:**
```swift
@MainActor
class SessionContextProvider {
    static func fetchContext(
        session: WorkoutSession,
        currentExerciseIndex: Int
    ) -> SessionContext {
        let duration: Int?
        if let ended = session.endedAt {
            duration = Int(ended.timeIntervalSince(session.startedAt) / 60)
        } else {
            duration = nil
        }
        
        let completedSets = session.exercises.flatMap { $0.sets.filter { $0.complete } }.count
        
        let otherExercises = session.sortedExercises
            .filter { $0.index != currentExerciseIndex }
            .map { $0.name }
        
        return SessionContext(
            sessionID: session.id,
            startedAt: session.startedAt,
            planName: session.workoutPlan?.title,
            sessionOrigin: session.origin.rawValue,
            totalExercisesCompleted: session.exercises.count,
            totalSetsCompleted: completedSets,
            sessionDurationMinutes: duration,
            otherExercisesPerformed: otherExercises,
            precedingExerciseCount: currentExerciseIndex
        )
    }
}
```

---

## 7. Complete Context Bundle

```swift
/// Complete context bundle for suggestion generation or AI model calls
struct CompleteSuggestionContext: Codable, Sendable {
    // Core context
    let exerciseHistory: ExerciseHistoryContext
    let prescription: PrescriptionContext
    let performance: PerformanceContext
    let changeHistory: ChangeHistoryContext
    
    // Environmental context
    let userReadiness: UserReadinessContext
    let session: SessionContext
    
    // Metadata
    let generatedAt: Date
    let contextVersion: String  // For future schema changes
}
```

**Master Provider:**
```swift
@MainActor
class ContextBundleProvider {
    static func gatherCompleteContext(
        for exercisePerformance: ExercisePerformance,
        prescription: ExercisePrescription,
        session: WorkoutSession,
        context: ModelContext
    ) -> CompleteSuggestionContext {
        let catalogID = exercisePerformance.catalogID
        
        let history = ExerciseHistoryProvider.fetchContext(
            catalogID: catalogID,
            sessionLimit: 5,
            context: context
        )
        
        let prescriptionCtx = PrescriptionContextProvider.fetchContext(
            prescription: prescription
        )
        
        let performanceCtx = PerformanceContextProvider.fetchContext(
            performance: exercisePerformance,
            prescription: prescription
        )
        
        let changeHistory = ChangeHistoryProvider.fetchContext(
            catalogID: catalogID,
            limit: 10,
            context: context
        )
        
        let readiness = UserReadinessProvider.fetchContext(
            for: session,
            context: context
        )
        
        let sessionCtx = SessionContextProvider.fetchContext(
            session: session,
            currentExerciseIndex: exercisePerformance.index
        )
        
        return CompleteSuggestionContext(
            exerciseHistory: history,
            prescription: prescriptionCtx,
            performance: performanceCtx,
            changeHistory: changeHistory,
            userReadiness: readiness,
            session: sessionCtx,
            generatedAt: Date(),
            contextVersion: "1.0"
        )
    }
}
```

---

## Usage Examples

### For Rule-Based Suggestions
```swift
let context = ContextBundleProvider.gatherCompleteContext(
    for: exercisePerformance,
    prescription: prescription,
    session: session,
    context: modelContext
)

// Rules can access specific parts
if context.exerciseHistory.progressionTrend == .plateau {
    // Suggest volume increase
}

if context.changeHistory.recentlyRejectedTypes.contains("increaseWeight") {
    // User doesn't want weight increases right now
}

if context.userReadiness.readinessScore < 0.4 {
    // Be conservative with suggestions
}
```

### For Apple FoundationModels
```swift
// Context is already Codable - can be serialized directly
let context = ContextBundleProvider.gatherCompleteContext(...)

let encoder = JSONEncoder()
let jsonData = try encoder.encode(context)

// Pass to FoundationModel for guided generation
let model = try await FoundationModel.load(named: "workout-suggestion-model")
let suggestions: [AISuggestion] = try await model.generate(
    from: context,
    outputType: [AISuggestion].self
)
```

---

## File Structure

```
VillainArc/Data/Classes/Context/
├── Providers/
│   ├── ExerciseHistoryProvider.swift
│   ├── PrescriptionContextProvider.swift
│   ├── PerformanceContextProvider.swift
│   ├── ChangeHistoryProvider.swift
│   ├── UserReadinessProvider.swift
│   ├── SessionContextProvider.swift
│   └── ContextBundleProvider.swift
└── Models/
    ├── ExerciseHistoryContext.swift
    ├── PrescriptionContext.swift
    ├── PerformanceContext.swift
    ├── ChangeHistoryContext.swift
    ├── UserReadinessContext.swift
    ├── SessionContext.swift
    └── CompleteSuggestionContext.swift
```

---

## Benefits of This Architecture

1. **Reusable**: Same context for rules AND AI
2. **Codable**: Direct serialization to FoundationModels
3. **Comprehensive**: Rich historical + environmental data
4. **Modular**: Can fetch only what you need
5. **Testable**: Easy to mock contexts for unit tests
6. **Versionable**: contextVersion field for schema evolution
7. **Type-Safe**: All data properly typed (not stringly-typed)
8. **Sendable**: Can pass across concurrency boundaries

This context system provides everything needed for both deterministic rules and AI model calls!
