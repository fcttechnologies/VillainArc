import Foundation
import SwiftData

struct SuggestionDeduplicator {
    static func process(suggestions: [PrescriptionChange], context: ModelContext) -> [PrescriptionChange] {
        // Filters duplicates + recent rejections, then resolves conflicts by priority.
        guard !suggestions.isEmpty else { return [] }

        // Fetch once to avoid repeated I/O per suggestion.
        let cutoffDate = Date().addingTimeInterval(-14 * 24 * 60 * 60) // 14 days ago
        let descriptor = FetchDescriptor<PrescriptionChange>(
            predicate: #Predicate { $0.createdAt > cutoffDate },
            sortBy: [SortDescriptor(\PrescriptionChange.createdAt, order: .reverse)]
        )
        let existing = (try? context.fetch(descriptor)) ?? []

        // Cooldown windows.
        let oneWeekAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        let threeDaysAgo = Date().addingTimeInterval(-3 * 24 * 60 * 60)

        var filtered: [PrescriptionChange] = []

        for suggestion in suggestions {
            // Skip if a similar suggestion was shown recently.
            if hasSimilarRecentSuggestion(suggestion: suggestion, existing: existing, since: oneWeekAgo, userSince: threeDaysAgo) {
                continue
            }

            // Skip if the user recently rejected this suggestion.
            if wasRecentlyRejected(suggestion: suggestion, existing: existing, since: oneWeekAgo) {
                continue
            }

            filtered.append(suggestion)
        }

        // Resolve logical conflicts between different strategies.
        filtered = resolveLogicalConflicts(filtered)

        // Ensure we don't emit conflicting changes for the same target property.
        return resolveConflicts(filtered)
    }

    private static func resolveLogicalConflicts(_ suggestions: [PrescriptionChange]) -> [PrescriptionChange] {
        // Group by exercise to check for conflicts within each exercise.
        let grouped = Dictionary(grouping: suggestions) {
            $0.targetExercisePrescription?.id ?? UUID()
        }

        var resolved: [PrescriptionChange] = []

        for (_, exerciseSuggestions) in grouped {
            let filtered = filterConflictingStrategies(exerciseSuggestions)
            resolved.append(contentsOf: filterPolicyConflicts(filtered))
        }

        return resolved
    }

    private static func filterConflictingStrategies(_ suggestions: [PrescriptionChange]) -> [PrescriptionChange] {
        // Strategy conflict 1: Weight progression vs Rest increase
        // If user is progressing (increasing weight), they don't need rest optimization
        let hasWeightIncrease = suggestions.contains {
            $0.changeType == .increaseWeight
        }
        let hasRestIncrease = suggestions.contains {
            $0.changeType == .increaseRest || $0.changeType == .increaseRestTimeSeconds
        }

        if hasWeightIncrease && hasRestIncrease {
            // Progression takes priority over optimization
            // Keep weight increases, remove rest increases
            return suggestions.filter {
                $0.changeType != .increaseRest &&
                $0.changeType != .increaseRestTimeSeconds
            }
        }

        // Strategy conflict 2: Weight increase vs Weight decrease (safety vs progression)
        // This should be rare due to rule logic, but handle it defensively
        let hasWeightDecrease = suggestions.contains {
            $0.changeType == .decreaseWeight
        }

        if hasWeightIncrease && hasWeightDecrease {
            // Safety takes priority - keep decrease, remove increase
            return suggestions.filter {
                $0.changeType != .increaseWeight
            }
        }

        // No conflicts, return all
        return suggestions
    }

    private static func filterPolicyConflicts(_ suggestions: [PrescriptionChange]) -> [PrescriptionChange] {
        // Avoid mixing exercise-level rest policy changes with set-level rest adjustments.
        let restPolicyChanges: Set<ChangeType> = [
            .changeRestTimeMode,
            .increaseRestTimeSeconds,
            .decreaseRestTimeSeconds
        ]
        let restSetChanges: Set<ChangeType> = [
            .increaseRest,
            .decreaseRest
        ]

        let hasRestModeChange = suggestions.contains { $0.changeType == .changeRestTimeMode }
        let hasRestTimeSecondsChange = suggestions.contains { restPolicyChanges.contains($0.changeType) }

        var filtered = suggestions

        if hasRestModeChange {
            // Switching rest time mode supersedes any all-same rest seconds change.
            filtered = filtered.filter { $0.changeType != .increaseRestTimeSeconds && $0.changeType != .decreaseRestTimeSeconds }
        }

        if hasRestModeChange || hasRestTimeSecondsChange {
            // If an exercise-level rest policy change exists, drop per-set rest changes.
            filtered = filtered.filter { !restSetChanges.contains($0.changeType) }
        }

        return filtered
    }

    private static func hasSimilarRecentSuggestion(suggestion: PrescriptionChange, existing: [PrescriptionChange], since date: Date, userSince: Date) -> Bool {
        // Cooldown: block recently shown suggestions for the same target/type.
        existing.contains { change in
            change.createdAt > ((change.source == .user && change.decision == .accepted) ? userSince : date) &&
            change.changeType == suggestion.changeType &&
            matchesTarget(suggestion: suggestion, existing: change) &&
            (change.decision == .pending || change.decision == .deferred || change.decision == .accepted)
        }
    }

    private static func wasRecentlyRejected(suggestion: PrescriptionChange, existing: [PrescriptionChange], since date: Date) -> Bool {
        // Avoid resurfacing a suggestion the user explicitly rejected.
        existing.contains { change in
            change.createdAt > date &&
            change.changeType == suggestion.changeType &&
            matchesTarget(suggestion: suggestion, existing: change) &&
            change.decision == .rejected
        }
    }

    private static func matchesTarget(suggestion: PrescriptionChange, existing: PrescriptionChange) -> Bool {
        // Match on set or exercise target identity.
        if let setID = suggestion.targetSetPrescription?.id {
            return existing.targetSetPrescription?.id == setID
        }
        if let exerciseID = suggestion.targetExercisePrescription?.id {
            return existing.targetExercisePrescription?.id == exerciseID
        }
        return false
    }

    private static func resolveConflicts(_ suggestions: [PrescriptionChange]) -> [PrescriptionChange] {
        // If multiple changes target the same property, keep the highest-priority one.
        guard suggestions.count > 1 else { return suggestions }

        // Group by (target id + property).
        var grouped: [ConflictKey: [PrescriptionChange]] = [:]
        for suggestion in suggestions {
            guard let key = conflictKey(for: suggestion) else { continue }
            grouped[key, default: []].append(suggestion)
        }

        var resolved: [PrescriptionChange] = []

        for group in grouped.values {
            if group.count == 1 {
                resolved.append(group[0])
                continue
            }

            let sorted = group.sorted { lhs, rhs in
                let lhsPriority = priority(for: lhs.changeType)
                let rhsPriority = priority(for: rhs.changeType)
                if lhsPriority != rhsPriority {
                    return lhsPriority < rhsPriority
                }
                // Prefer deterministic rule suggestions over AI when priorities match.
                if lhs.source != rhs.source {
                    return lhs.source == .rules
                }
                // If priority ties, keep the larger magnitude change.
                let lhsMagnitude = abs((lhs.newValue ?? 0) - (lhs.previousValue ?? 0))
                let rhsMagnitude = abs((rhs.newValue ?? 0) - (rhs.previousValue ?? 0))
                if lhsMagnitude != rhsMagnitude {
                    return lhsMagnitude > rhsMagnitude
                }
                // Final tie-breaker for deterministic ordering.
                return lhs.createdAt < rhs.createdAt
            }

            if let best = sorted.first {
                resolved.append(best)
            }
        }

        return resolved
    }

    private static func conflictKey(for suggestion: PrescriptionChange) -> ConflictKey? {
        if let setID = suggestion.targetSetPrescription?.id {
            return ConflictKey(id: setID, isSet: true, property: property(for: suggestion.changeType))
        }
        if let exerciseID = suggestion.targetExercisePrescription?.id {
            return ConflictKey(id: exerciseID, isSet: false, property: property(for: suggestion.changeType))
        }
        return nil
    }

    private static func property(for changeType: ChangeType) -> ChangeProperty {
        switch changeType {
        case .increaseWeight, .decreaseWeight:
            return .weight
        case .increaseReps, .decreaseReps:
            return .reps
        case .increaseRest, .decreaseRest:
            return .rest
        case .changeSetType:
            return .setType
        case .increaseRepRangeLower, .decreaseRepRangeLower:
            return .repRangeLower
        case .increaseRepRangeUpper, .decreaseRepRangeUpper:
            return .repRangeUpper
        case .increaseRepRangeTarget, .decreaseRepRangeTarget:
            return .repRangeTarget
        case .changeRepRangeMode:
            return .repRangeMode
        case .changeRestTimeMode:
            return .restTimeMode
        case .increaseRestTimeSeconds, .decreaseRestTimeSeconds:
            return .restTimeSeconds
        }
    }

    private static func priority(for changeType: ChangeType) -> Int {
        switch changeType {
        case .decreaseWeight:
            return 1
        case .increaseWeight:
            return 2
        case .decreaseReps, .increaseReps:
            return 2
        case .changeSetType:
            return 3
        case .changeRepRangeMode,
             .increaseRepRangeLower, .decreaseRepRangeLower,
             .increaseRepRangeUpper, .decreaseRepRangeUpper,
             .increaseRepRangeTarget, .decreaseRepRangeTarget:
            return 3
        case .increaseRest, .decreaseRest:
            return 5
        case .changeRestTimeMode, .increaseRestTimeSeconds, .decreaseRestTimeSeconds:
            return 5
        }
    }
}

private enum ChangeProperty: Hashable {
    case weight
    case reps
    case rest
    case setType
    case repRangeMode
    case repRangeLower
    case repRangeUpper
    case repRangeTarget
    case restTimeMode
    case restTimeSeconds
    case structure
}

private struct ConflictKey: Hashable {
    let id: UUID
    let isSet: Bool
    let property: ChangeProperty
}
