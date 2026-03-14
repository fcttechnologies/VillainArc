import SwiftUI
import SwiftData

struct SuggestionReviewView: View {
    let sections: [ExerciseSuggestionSection]
    let onAcceptGroup: (SuggestionGroup) -> Void
    let onRejectGroup: (SuggestionGroup) -> Void
    let onDeferGroup: ((SuggestionGroup) -> Void)?
    var showDecisionState: Bool = false
    var actionableDecisions: Set<Decision> = [.pending]
    var emptyState: SuggestionEmptyState?
    
    var body: some View {
        if sections.isEmpty {
            // If a custom empty state is provided, show it; otherwise render nothing.
            if let emptyState {
                emptyState.view
            } else {
                EmptyView()
            }
        } else {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(section.exerciseName)
                            .font(.title3)
                            .bold()
                            .lineLimit(1)
                            .fontDesign(.rounded)
                        
                        ForEach(section.groups, id: \.id) { group in
                            SuggestionGroupRow(group: group, onAccept: { onAcceptGroup(group) }, onReject: { onRejectGroup(group) }, onDefer: onDeferGroup != nil ? { onDeferGroup?(group) } : nil, showDecisionState: showDecisionState, actionableDecisions: actionableDecisions)
                        }
                    }
                    .id(section.id)
                }
            }
        }
    }
}

struct SuggestionGroupRow: View {
    let group: SuggestionGroup
    let onAccept: () -> Void
    let onReject: () -> Void
    let onDefer: (() -> Void)?
    var showDecisionState: Bool = false
    let actionableDecisions: Set<Decision>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(group.label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fontWeight(.semibold)

                Spacer()

                // Show decision status inline with the group label.
                if showDecisionState, let visibleDecisionState {
                    Text(visibleDecisionState.label)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(visibleDecisionState.tint)
                }
            }

            // Group-level reasoning appears only when all changes share one reason.
            if let groupReasoning {
                Text(groupReasoning)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(group.changes, id: \.id) { change in
                    ChangeDescriptionRow(change: change)
                }
            }
            
            if visibleDecisionState == nil {
                HStack(spacing: 8) {
                    
                    Button {
                        Haptics.selection()
                        onReject()
                    } label: {
                        Text("Reject")
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.red)
                    .accessibilityHint(AccessibilityText.suggestionRejectHint)

                    Button {
                        Haptics.selection()
                        onAccept()
                    } label: {
                        Text("Accept")
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.green)
                    .accessibilityHint(AccessibilityText.suggestionAcceptHint)

                    if let onDefer {
                        Button {
                            Haptics.selection()
                            onDefer()
                        } label: {
                            Text(AccessibilityText.suggestionDeferLabel)
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.glass)
                        .accessibilityHint(AccessibilityText.suggestionDeferHint)
                    }
                }
                .buttonSizing(.flexible)
            }
        }
        .fontDesign(.rounded)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
    }

    private var visibleDecisionState: DecisionState? {
        let decision = group.event.decision
        if actionableDecisions.contains(decision) {
            return nil
        }
        switch decision {
        case .pending:
            return nil
        case .accepted:
            return .accepted
        case .rejected:
            return .rejected
        case .deferred:
            return .deferred
        }
    }

    private var groupReasoning: String? {
        let trimmed = group.event.changeReasoning?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct DecisionState {
    let label: String
    let tint: Color

    static let accepted = DecisionState(label: "Accepted", tint: .green)
    static let rejected = DecisionState(label: "Rejected", tint: .red)
    static let deferred = DecisionState(label: "Deferred", tint: .orange)
}

struct SuggestionEmptyState {
    let title: String
    let message: String

    var view: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .fontDesign(.rounded)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
    }
}


struct ChangeDescriptionRow: View {
    let change: PrescriptionChange
    @Query(AppSettings.single) private var appSettings: [AppSettings]

    private var weightUnit: WeightUnit { appSettings.first?.weightUnit ?? .lbs }

    var body: some View {
        Text(changeDescription)
            .font(.subheadline)
        .fontWeight(.semibold)
    }

    private var changeDescription: String {
        let previous = change.previousValue
        let new = change.newValue

        switch change.changeType {
        // Set-level
        case .increaseWeight, .decreaseWeight:
            return "Weight: \(weightUnit.display(previous)) → \(weightUnit.display(new))"
        case .increaseReps, .decreaseReps:
            return "Reps: \(Int(previous)) → \(Int(new))"
        case .increaseRest, .decreaseRest:
            return "Rest: \(Int(previous))s → \(Int(new))s"
        case .changeSetType:
            let prevType = ExerciseSetType(rawValue: Int(previous))?.displayName ?? "Unknown"
            let newType = ExerciseSetType(rawValue: Int(new))?.displayName ?? "Unknown"
            return "Set Type: \(prevType) → \(newType)"
            
        // Rep Range
        case .increaseRepRangeLower, .decreaseRepRangeLower:
            return "Lower bound: \(Int(previous)) → \(Int(new))"
        case .increaseRepRangeUpper, .decreaseRepRangeUpper:
            return "Upper bound: \(Int(previous)) → \(Int(new))"
        case .increaseRepRangeTarget, .decreaseRepRangeTarget:
            return "Target reps: \(Int(previous)) → \(Int(new))"
        case .changeRepRangeMode:
            return repRangeModeDescription(newModeRaw: Int(new))
            
        }
    }
    
    private func repRangeModeDescription(newModeRaw: Int) -> String {
        guard let newMode = RepRangeMode(rawValue: newModeRaw) else {
            return "Change rep range mode"
        }
        switch newMode {
        case .range:
            return "Switch to Range"
        case .target:
            return "Switch to Target"
        case .notSet:
            return "Clear rep range"
        }
    }
}



@MainActor
func applyChange(_ change: PrescriptionChange, in event: SuggestionEvent, context: ModelContext) {
    switch change.changeType {
    case .increaseWeight, .decreaseWeight:
        event.targetSetPrescription?.targetWeight = change.newValue
    case .increaseReps, .decreaseReps:
        event.targetSetPrescription?.targetReps = Int(change.newValue)
    case .increaseRest, .decreaseRest:
        event.targetSetPrescription?.targetRest = Int(change.newValue)
    case .changeSetType:
        event.targetSetPrescription?.type = ExerciseSetType(rawValue: Int(change.newValue)) ?? .working
    case .increaseRepRangeLower, .decreaseRepRangeLower:
        event.targetExercisePrescription?.repRange?.lowerRange = Int(change.newValue)
    case .increaseRepRangeUpper, .decreaseRepRangeUpper:
        event.targetExercisePrescription?.repRange?.upperRange = Int(change.newValue)
    case .increaseRepRangeTarget, .decreaseRepRangeTarget:
        event.targetExercisePrescription?.repRange?.targetReps = Int(change.newValue)
    case .changeRepRangeMode:
        event.targetExercisePrescription?.repRange?.activeMode = RepRangeMode(rawValue: Int(change.newValue)) ?? .notSet
    }
}

@MainActor
func acceptGroup(_ group: SuggestionGroup, context: ModelContext) {
    group.event.decision = .accepted
    for change in group.changes {
        applyChange(change, in: group.event, context: context)
    }
    saveContext(context: context)
}

@MainActor
func rejectGroup(_ group: SuggestionGroup, context: ModelContext) {
    group.event.decision = .rejected
    saveContext(context: context)
}

@MainActor
func deferGroup(_ group: SuggestionGroup, context: ModelContext) {
    group.event.decision = .deferred
    saveContext(context: context)
}
