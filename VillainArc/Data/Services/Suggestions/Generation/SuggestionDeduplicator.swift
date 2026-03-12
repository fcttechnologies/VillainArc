import Foundation

struct SuggestionDeduplicator {
    static func process(suggestions: [SuggestionEventDraft]) -> [SuggestionEventDraft] {
        guard !suggestions.isEmpty else { return [] }

        let grouped = Dictionary(grouping: suggestions, by: \.idScope)

        return grouped.values.compactMap { scopedSuggestions in
            scopedSuggestions.sorted(by: isPreferred(_:over:)).first
        }
    }

    private static func isPreferred(_ lhs: SuggestionEventDraft, over rhs: SuggestionEventDraft) -> Bool {
        let lhsPriority = priority(for: lhs)
        let rhsPriority = priority(for: rhs)
        if lhsPriority != rhsPriority {
            return lhsPriority < rhsPriority
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
