import SwiftUI
import SwiftData

struct SuggestionReviewView: View {
    let sections: [ExerciseSuggestionSection]
    let onAcceptGroup: ([PrescriptionChange]) -> Void
    let onRejectGroup: ([PrescriptionChange]) -> Void
    let onDeferGroup: (([PrescriptionChange]) -> Void)?
    var showDecisionState: Bool = false
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
                ForEach(sections, id: \.exerciseName) { section in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(section.exerciseName)
                            .font(.title3)
                            .bold()
                            .lineLimit(1)
                            .fontDesign(.rounded)
                        
                        ForEach(section.groups, id: \.id) { group in
                            SuggestionGroupRow(group: group, onAccept: { onAcceptGroup(group.changes) }, onReject: { onRejectGroup(group.changes) }, onDefer: onDeferGroup != nil ? { onDeferGroup?(group.changes) } : nil, showDecisionState: showDecisionState)
                        }
                    }
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(group.label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fontWeight(.semibold)

                Spacer()

                // Show decision status inline with the group label.
                if showDecisionState, let decisionState {
                    Text(decisionState.label)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(decisionState.tint)
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
                    ChangeDescriptionRow(change: change, showReasoning: shouldShowChangeReasoning(for: change))
                }
            }
            
            if decisionState == nil {
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
                    
                    Button {
                        Haptics.selection()
                        onAccept()
                    } label: {
                        Text("Accept")
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.green)
                    
                    if let onDefer {
                        Button {
                            Haptics.selection()
                            onDefer()
                        } label: {
                            Text("Later")
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.glass)
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

    private var decisionState: DecisionState? {
        // If all changes share one decision, show it; otherwise show mixed or pending.
        let decisions = Set(group.changes.map { $0.decision })
        if decisions.count == 1, let only = decisions.first {
            switch only {
            case .pending:
                return nil
            case .accepted:
                return .accepted
            case .rejected:
                return .rejected
            case .deferred:
                return .deferred
            case .userOverride:
                return .overridden
            }
        }
        if decisions.contains(.pending) {
            return nil
        }
        return .mixed
    }

    private var groupReasoning: String? {
        // Only show a single reason at group level when all reasons match.
        uniqueReasonings.count == 1 ? uniqueReasonings.first : nil
    }

    private func shouldShowChangeReasoning(for change: PrescriptionChange) -> Bool {
        // If multiple unique reasons exist, show them once per unique reason.
        guard uniqueReasonings.count > 1 else { return false }
        let reasoningMap = reasoningVisibilityMap
        return reasoningMap[change.id] ?? false
    }

    private var uniqueReasonings: [String] {
        var seen: Set<String> = []
        var result: [String] = []

        for change in group.changes {
            let trimmed = change.changeReasoning?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !trimmed.isEmpty else { continue }
            if seen.insert(trimmed).inserted {
                result.append(trimmed)
            }
        }

        return result
    }

    private var reasoningVisibilityMap: [UUID: Bool] {
        // First occurrence of each unique reason shows; duplicates are hidden.
        var seen: Set<String> = []
        var map: [UUID: Bool] = [:]

        for change in group.changes {
            let trimmed = change.changeReasoning?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !trimmed.isEmpty else {
                map[change.id] = false
                continue
            }
            if seen.contains(trimmed) {
                map[change.id] = false
            } else {
                seen.insert(trimmed)
                map[change.id] = true
            }
        }

        return map
    }
}

private struct DecisionState {
    let label: String
    let tint: Color

    static let accepted = DecisionState(label: "Accepted", tint: .green)
    static let rejected = DecisionState(label: "Rejected", tint: .red)
    static let deferred = DecisionState(label: "Deferred", tint: .orange)
    static let overridden = DecisionState(label: "Overridden", tint: .secondary)
    static let mixed = DecisionState(label: "Mixed", tint: .secondary)
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
    let showReasoning: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(changeDescription)
                .font(.subheadline)
            
            if showReasoning, let reasoning = change.changeReasoning, !reasoning.isEmpty {
                Text(reasoning)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .fontWeight(.semibold)
    }
    
    private var changeDescription: String {
        let previous = change.previousValue ?? 0
        let new = change.newValue ?? 0
        
        switch change.changeType {
        // Set-level
        case .increaseWeight, .decreaseWeight:
            return "Weight: \(formatValue(previous)) → \(formatValue(new)) lbs"
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
            
        // Rest Time
        case .changeRestTimeMode:
            return restTimeModeDescription(newModeRaw: Int(new))
        case .increaseRestTimeSeconds, .decreaseRestTimeSeconds:
            return "Rest time: \(Int(previous))s → \(Int(new))s"
            
        // Structure
        case .removeSet:
            return "Working sets: \(Int(previous)) → \(Int(new))"
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
    
    private func restTimeModeDescription(newModeRaw: Int) -> String {
        guard let newMode = RestTimeMode(rawValue: newModeRaw),
              let exercise = change.targetExercisePrescription else {
            return "Change rest time mode"
        }
        switch newMode {
        case .allSame:
            return "Switch to All Same (\(exercise.restTimePolicy?.allSameSeconds ?? 0)s)"
        case .individual:
            return "Switch to Individual rest"
        case .byType:
            return "Switch to By Type"
        }
    }
    
    private func formatValue(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }
}


@MainActor
func applyChange(_ change: PrescriptionChange) {
    switch change.changeType {
    case .increaseWeight, .decreaseWeight:
        change.targetSetPrescription?.targetWeight = change.newValue ?? 0
    case .increaseReps, .decreaseReps:
        change.targetSetPrescription?.targetReps = Int(change.newValue ?? 0)
    case .increaseRest, .decreaseRest:
        change.targetSetPrescription?.targetRest = Int(change.newValue ?? 0)
    case .changeSetType:
        change.targetSetPrescription?.type = ExerciseSetType(rawValue: Int(change.newValue ?? 0)) ?? .working
    case .increaseRepRangeLower, .decreaseRepRangeLower:
        change.targetExercisePrescription?.repRange?.lowerRange = Int(change.newValue ?? 0)
    case .increaseRepRangeUpper, .decreaseRepRangeUpper:
        change.targetExercisePrescription?.repRange?.upperRange = Int(change.newValue ?? 0)
    case .increaseRepRangeTarget, .decreaseRepRangeTarget:
        change.targetExercisePrescription?.repRange?.targetReps = Int(change.newValue ?? 0)
    case .changeRepRangeMode:
        change.targetExercisePrescription?.repRange?.activeMode = RepRangeMode(rawValue: Int(change.newValue ?? 0)) ?? .notSet
    case .changeRestTimeMode:
        change.targetExercisePrescription?.restTimePolicy?.activeMode = RestTimeMode(rawValue: Int(change.newValue ?? 0)) ?? .individual
    case .increaseRestTimeSeconds, .decreaseRestTimeSeconds:
        change.targetExercisePrescription?.restTimePolicy?.allSameSeconds = Int(change.newValue ?? 0)
    case .removeSet:
        // Remove the last working set from the prescription.
        if let prescription = change.targetExercisePrescription,
           let lastWorkingSet = prescription.sortedSets.last(where: { $0.type == .working }) {
            prescription.deleteSet(lastWorkingSet)
        }
    }
}

@MainActor
func acceptGroup(_ changes: [PrescriptionChange], context: ModelContext) {
    for change in changes {
        change.decision = .accepted
        applyChange(change)
    }
    saveContext(context: context)
}

@MainActor
func rejectGroup(_ changes: [PrescriptionChange], context: ModelContext) {
    for change in changes {
        change.decision = .rejected
    }
    saveContext(context: context)
}

@MainActor
func deferGroup(_ changes: [PrescriptionChange], context: ModelContext) {
    for change in changes {
        change.decision = .deferred
    }
    saveContext(context: context)
}
