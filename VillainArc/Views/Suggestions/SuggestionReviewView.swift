import SwiftUI
import SwiftData


struct SuggestionReviewView: View {
    let sections: [ExerciseSuggestionSection]
    let onAcceptGroup: ([PrescriptionChange]) -> Void
    let onRejectGroup: ([PrescriptionChange]) -> Void
    let onDeferGroup: (([PrescriptionChange]) -> Void)?
    
    var body: some View {
        if sections.isEmpty {
            ContentUnavailableView("No Suggestions", systemImage: "checkmark.circle", description: Text("All caught up!"))
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
                            SuggestionGroupRow(
                                group: group,
                                onAccept: { onAcceptGroup(group.changes) },
                                onReject: { onRejectGroup(group.changes) },
                                onDefer: onDeferGroup != nil ? { onDeferGroup?(group.changes) } : nil
                            )
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(group.label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(group.changes, id: \.id) { change in
                    ChangeDescriptionRow(change: change)
                }
            }
            
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
        .fontDesign(.rounded)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
    }
}


struct ChangeDescriptionRow: View {
    let change: PrescriptionChange
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(changeDescription)
                .font(.subheadline)
            
            if let reasoning = change.changeReasoning, !reasoning.isEmpty {
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
            
        // Structural
        case .addSet, .removeSet, .addExercise, .removeExercise, .reorderExercise:
            return change.changeType.rawValue
        }
    }
    
    private func repRangeModeDescription(newModeRaw: Int) -> String {
        guard let newMode = RepRangeMode(rawValue: newModeRaw),
              let exercise = change.targetExercisePrescription else {
            return "Change rep range mode"
        }
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
    }
    
    private func restTimeModeDescription(newModeRaw: Int) -> String {
        guard let newMode = RestTimeMode(rawValue: newModeRaw),
              let exercise = change.targetExercisePrescription else {
            return "Change rest time mode"
        }
        switch newMode {
        case .allSame:
            return "Switch to All Same (\(exercise.restTimePolicy.allSameSeconds)s)"
        case .individual:
            return "Switch to Individual rest"
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
        change.targetSetPrescription?.type = ExerciseSetType(rawValue: Int(change.newValue ?? 0)) ?? .regular
    case .increaseRepRangeLower, .decreaseRepRangeLower:
        change.targetExercisePrescription?.repRange.lowerRange = Int(change.newValue ?? 0)
    case .increaseRepRangeUpper, .decreaseRepRangeUpper:
        change.targetExercisePrescription?.repRange.upperRange = Int(change.newValue ?? 0)
    case .increaseRepRangeTarget, .decreaseRepRangeTarget:
        change.targetExercisePrescription?.repRange.targetReps = Int(change.newValue ?? 0)
    case .changeRepRangeMode:
        change.targetExercisePrescription?.repRange.activeMode = RepRangeMode(rawValue: Int(change.newValue ?? 0)) ?? .notSet
    case .changeRestTimeMode:
        change.targetExercisePrescription?.restTimePolicy.activeMode = RestTimeMode(rawValue: Int(change.newValue ?? 0)) ?? .individual
    case .increaseRestTimeSeconds, .decreaseRestTimeSeconds:
        change.targetExercisePrescription?.restTimePolicy.allSameSeconds = Int(change.newValue ?? 0)
    default:
        break
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
