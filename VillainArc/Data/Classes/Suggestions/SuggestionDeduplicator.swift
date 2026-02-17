import Foundation

struct SuggestionDeduplicator {
    static func process(suggestions: [PrescriptionChange]) -> [PrescriptionChange] {
        guard !suggestions.isEmpty else { return [] }

        let filtered = resolveLogicalConflicts(suggestions)
        return resolveConflicts(filtered)
    }

    private static func resolveLogicalConflicts(_ suggestions: [PrescriptionChange]) -> [PrescriptionChange] {
        let grouped = Dictionary(grouping: suggestions) {
            $0.targetExercisePrescription?.id ?? UUID()
        }

        var resolved: [PrescriptionChange] = []

        for (_, exerciseSuggestions) in grouped {
            let filtered = filterConflictingStrategies(exerciseSuggestions)
            resolved.append(contentsOf: filtered)
        }

        return resolved
    }

    private static func filterConflictingStrategies(_ suggestions: [PrescriptionChange]) -> [PrescriptionChange] {
        let hasWeightIncrease = suggestions.contains { $0.changeType == .increaseWeight }
        let hasRestIncrease = suggestions.contains { $0.changeType == .increaseRest }

        if hasWeightIncrease && hasRestIncrease {
            return suggestions.filter { $0.changeType != .increaseRest }
        }

        let hasWeightDecrease = suggestions.contains { $0.changeType == .decreaseWeight }

        if hasWeightIncrease && hasWeightDecrease {
            return suggestions.filter { $0.changeType != .increaseWeight }
        }

        return suggestions
    }

    private static func resolveConflicts(_ suggestions: [PrescriptionChange]) -> [PrescriptionChange] {
        guard suggestions.count > 1 else { return suggestions }

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
                if lhs.source != rhs.source {
                    return lhs.source == .rules
                }
                let lhsMagnitude = abs((lhs.newValue ?? 0) - (lhs.previousValue ?? 0))
                let rhsMagnitude = abs((rhs.newValue ?? 0) - (rhs.previousValue ?? 0))
                if lhsMagnitude != rhsMagnitude {
                    return lhsMagnitude > rhsMagnitude
                }
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
        case .removeSet:
            return .structure
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
        case .removeSet:
            return 4
        case .increaseRest, .decreaseRest:
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
    case structure
}

private struct ConflictKey: Hashable {
    let id: UUID
    let isSet: Bool
    let property: ChangeProperty
}
