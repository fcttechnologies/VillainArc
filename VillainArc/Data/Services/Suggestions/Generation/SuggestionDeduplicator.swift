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
        let isSetScoped = sorted.first?.idScope.setIndex != nil

        guard isSetScoped else {
            return sorted.prefix(1).map { $0 }
        }

        var selected: [SuggestionEventDraft] = []
        for candidate in sorted {
            let conflicts = selected.contains { existing in
                !isCompatible(existing.category, candidate.category, isSetScoped: true)
            }

            if !conflicts {
                selected.append(candidate)
            }
        }

        return selected
    }

    private static func isPreferred(_ lhs: SuggestionEventDraft, over rhs: SuggestionEventDraft) -> Bool {
        let lhsPriority = priority(for: lhs.category)
        let rhsPriority = priority(for: rhs.category)
        if lhsPriority != rhsPriority {
            return lhsPriority < rhsPriority
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

        let lhsReasoning = lhs.changeReasoning ?? ""
        let rhsReasoning = rhs.changeReasoning ?? ""
        if lhsReasoning != rhsReasoning {
            return lhsReasoning < rhsReasoning
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
}
