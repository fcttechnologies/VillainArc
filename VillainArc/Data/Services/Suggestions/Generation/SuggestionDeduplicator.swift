import Foundation

struct SuggestionDeduplicator {
    static func process(suggestions: [SuggestionEventDraft]) -> [SuggestionEventDraft] {
        guard !suggestions.isEmpty else { return [] }

        let grouped = Dictionary(grouping: suggestions, by: \.idScope)

        return grouped.values.flatMap { scopedSuggestions in
            selectCompatibleSuggestions(from: scopedSuggestions)
        }
    }

    static func isCompatible(_ lhs: SuggestionCategory, _ rhs: SuggestionCategory, isSetScoped: Bool) -> Bool {
        if lhs == rhs {
            return false
        }

        guard isSetScoped else {
            return false
        }

        switch (lhs, rhs) {
        case (.performance, .recovery), (.recovery, .performance):
            return true
        default:
            return false
        }
    }

    private static func selectCompatibleSuggestions(from scopedSuggestions: [SuggestionEventDraft]) -> [SuggestionEventDraft] {
        guard !scopedSuggestions.isEmpty else { return [] }

        let sorted = scopedSuggestions.sorted(by: isPreferred(_:over:))
        let isSetScoped = sorted.first?.idScope.setID != nil

        guard isSetScoped else {
            return sorted.prefix(1).map { $0 }
        }

        var selected: [SuggestionEventDraft] = []
        for candidate in sorted {
            let conflicts = selected.contains { existing in
                !canCoexistInSamePass(existing, candidate)
            }

            if !conflicts {
                selected.append(candidate)
            }
        }

        return selected
    }

    private static func canCoexistInSamePass(_ lhs: SuggestionEventDraft, _ rhs: SuggestionEventDraft) -> Bool {
        if isCompatible(lhs.category, rhs.category, isSetScoped: true) {
            return true
        }

        return allowsWorkingSetReclassificationPair(lhs, rhs)
    }

    private static func allowsWorkingSetReclassificationPair(_ lhs: SuggestionEventDraft, _ rhs: SuggestionEventDraft) -> Bool {
        if isWorkingSetReclassification(lhs) {
            return canPairWithWorkingSetReclassification(rhs)
        }

        if isWorkingSetReclassification(rhs) {
            return canPairWithWorkingSetReclassification(lhs)
        }

        return false
    }

    private static func isWorkingSetReclassification(_ draft: SuggestionEventDraft) -> Bool {
        guard draft.category == .structure, draft.changes.count == 1, let change = draft.changes.first, change.changeType == .changeSetType else {
            return false
        }

        return Int(change.newValue.rounded()) == ExerciseSetType.working.rawValue
    }

    private static func canPairWithWorkingSetReclassification(_ draft: SuggestionEventDraft) -> Bool {
        switch draft.category {
        case .performance, .recovery:
            return !draft.contains(.changeSetType)
        default:
            return false
        }
    }

    private static func isPreferred(_ lhs: SuggestionEventDraft, over rhs: SuggestionEventDraft) -> Bool {
        let lhsPriority = priority(for: lhs.category)
        let rhsPriority = priority(for: rhs.category)
        if lhsPriority != rhsPriority {
            return lhsPriority < rhsPriority
        }

        let lhsEvidencePriority = priority(for: lhs.evidenceStrength)
        let rhsEvidencePriority = priority(for: rhs.evidenceStrength)
        if lhsEvidencePriority != rhsEvidencePriority {
            return lhsEvidencePriority > rhsEvidencePriority
        }

        let lhsChangePriority = priority(for: lhs)
        let rhsChangePriority = priority(for: rhs)
        if lhsChangePriority != rhsChangePriority {
            return lhsChangePriority < rhsChangePriority
        }

        if lhs.changes.count != rhs.changes.count {
            return lhs.changes.count > rhs.changes.count
        }

        let lhsMagnitude = totalMagnitude(for: lhs)
        let rhsMagnitude = totalMagnitude(for: rhs)
        if lhsMagnitude != rhsMagnitude {
            return lhsMagnitude > rhsMagnitude
        }

        let lhsRuleID = lhs.ruleID?.rawValue ?? ""
        let rhsRuleID = rhs.ruleID?.rawValue ?? ""
        if lhsRuleID != rhsRuleID {
            return lhsRuleID < rhsRuleID
        }

        let lhsSignature = stableChangeSignature(for: lhs)
        let rhsSignature = stableChangeSignature(for: rhs)
        if lhsSignature != rhsSignature {
            return lhsSignature < rhsSignature
        }

        return lhs.catalogID < rhs.catalogID
    }

    private static func priority(for draft: SuggestionEventDraft) -> Int {
        draft.changes.map { priority(for: $0.changeType) }.min() ?? Int.max
    }

    private static func totalMagnitude(for draft: SuggestionEventDraft) -> Double {
        draft.changes.reduce(0) { partialResult, change in
            partialResult + abs(change.newValue - change.previousValue)
        }
    }

    private static func priority(for category: SuggestionCategory) -> Int {
        switch category {
        case .structure:
            return 1
        case .volume:
            return 2
        case .performance:
            return 3
        case .recovery:
            return 4
        case .warmupCalibration:
            return 5
        case .repRangeConfiguration:
            return 6
        }
    }

    private static func priority(for evidenceStrength: SuggestionEvidenceStrength) -> Int {
        evidenceStrength.rawValue
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
            return 4
        }
    }

    private static func stableChangeSignature(for draft: SuggestionEventDraft) -> String {
        let signature = draft.changes
            .map { change in
                "\(change.changeType.rawValue):\(change.previousValue):\(change.newValue)"
            }
            .sorted()
            .joined(separator: "|")

        return "\(draft.category.rawValue)|\(signature)"
    }
}
