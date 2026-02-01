import SwiftUI
import SwiftData

struct SetReferenceData {
    let reps: Int?
    let weight: Double?
    let actionLabel: String

    var displayText: String {
        if let reps, reps > 0, (weight ?? 0) == 0 {
            return "\(reps) reps"
        }
        guard let reps, let weight else { return "-" }
        return "\(reps)x\(Self.formattedWeight(weight))"
    }

    static func formattedWeight(_ weight: Double) -> String {
        weight.formatted(.number.precision(.fractionLength(0...2)))
    }
}

struct ExerciseSetRowView: View {
    @Bindable var set: SetPerformance
    @Bindable var exercise: ExercisePerformance
    @Binding var showRestTimerSheet: Bool
    @Environment(\.modelContext) private var context
    private let restTimer = RestTimerState.shared
    @AppStorage("autoStartRestTimer") private var autoStartRestTimer = true
    @State private var showOverrideTimerAlert = false

    let referenceData: SetReferenceData?
    let fieldWidth: CGFloat

    var body: some View {
        Group {
            Menu {
                Picker("", selection: Binding(get: { set.type }, set: { newValue in
                    let oldValue = set.type
                    set.type = newValue
                    if newValue != oldValue {
                        Haptics.selection()
                        saveContext(context: context)
                    }
                })) {
                    ForEach(ExerciseSetType.allCases, id: \.self) { type in
                        Text(type.rawValue)
                            .tag(type)
                    }
                }
                Divider()
                if exercise.sets.count > 1 {
                    Button("Delete Set", systemImage: "trash", role: .destructive) {
                        deleteSet()
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.exerciseSetDeleteButton(exercise, set: set))
                }
            } label: {
                Text(set.type == .regular ? String(set.index + 1) : set.type.shortLabel)
                    .foregroundStyle(set.type.tintColor)
                    .frame(width: 40, height: 40)
                    .glassEffect(.regular, in: .circle)
                    .opacity(set.complete ? 0.4 : 1)
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.exerciseSetMenu(exercise, set: set))
            .accessibilityLabel(AccessibilityText.exerciseSetMenuLabel(for: set))
            .accessibilityValue(AccessibilityText.exerciseSetMenuValue(for: set))
            .accessibilityHint("Opens set options.")

            TextField("Reps", value: $set.reps, format: .number)
                .keyboardType(.numberPad)
                .frame(maxWidth: fieldWidth)
                .opacity(set.complete ? 0.4 : 1)
                .accessibilityIdentifier(AccessibilityIdentifiers.exerciseSetRepsField(exercise, set: set))
                .accessibilityLabel("Reps")
            TextField("Weight", value: $set.weight, format: .number)
                .keyboardType(.decimalPad)
                .frame(maxWidth: fieldWidth)
                .opacity(set.complete ? 0.4 : 1)
                .accessibilityIdentifier(AccessibilityIdentifiers.exerciseSetWeightField(exercise, set: set))
                .accessibilityLabel("Weight")

            Text(referenceData?.displayText ?? "-")
                .lineLimit(1)
                .frame(maxWidth: fieldWidth)
                .opacity(set.complete ? 0.4 : 1)
                .contextMenu {
                    if let referenceData {
                        Button(referenceData.actionLabel) {
                            Haptics.selection()
                            if let reps = referenceData.reps {
                                set.reps = reps
                            }
                            if let weight = referenceData.weight {
                                set.weight = weight
                            }
                            saveContext(context: context)
                        }
                        .accessibilityIdentifier(AccessibilityIdentifiers.exerciseSetUsePreviousButton(exercise, set: set))
                    }
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.exerciseSetPreviousValue(exercise, set: set))
                .accessibilityLabel(referenceData?.actionLabel ?? "Reference")
                .accessibilityValue(referenceData?.displayText ?? "None")
                .accessibilityHint(referenceData == nil ? "No reference data." : "Long-press for options.")

            if set.complete {
                Button {
                    Haptics.selection()
                    set.complete = false
                    set.completedAt = nil
                    saveContext(context: context)
                } label: {
                    Image(systemName: "checkmark")
                        .padding(2)
                }
                .buttonBorderShape(.circle)
                .buttonStyle(.glassProminent)
                .tint(.blue)
                .accessibilityIdentifier(AccessibilityIdentifiers.exerciseSetCompleteButton(exercise, set: set))
                .accessibilityLabel(AccessibilityText.exerciseSetCompletionLabel(isComplete: set.complete))
            } else {
                Button {
                    Haptics.selection()
                    set.complete = true
                    set.completedAt = Date()
                    handleAutoStartTimer()
                    saveContext(context: context)
                } label: {
                    Image(systemName: "checkmark")
                        .padding(2)
                }
                .buttonBorderShape(.circle)
                .buttonStyle(.glass)
                .accessibilityIdentifier(AccessibilityIdentifiers.exerciseSetCompleteButton(exercise, set: set))
                .accessibilityLabel(AccessibilityText.exerciseSetCompletionLabel(isComplete: set.complete))
            }
        }
        .animation(.bouncy, value: set.complete)
        .onChange(of: set.reps) {
            scheduleSave(context: context)
        }
        .onChange(of: set.weight) {
            scheduleSave(context: context)
        }
        .alert("Replace Rest Timer?", isPresented: $showOverrideTimerAlert) {
            Button("Replace", role: .destructive) {
                let restSeconds = set.effectiveRestSeconds
                if restSeconds > 0 {
                    restTimer.start(seconds: restSeconds, startedFromSetID: set.persistentModelID)
                    RestTimeHistory.record(seconds: restSeconds, context: context)
                    saveContext(context: context)
                    Task { await IntentDonations.donateStartRestTimer(seconds: restSeconds) }
                    showRestTimerSheet = true
                }
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.exerciseSetReplaceTimerButton(exercise, set: set))
            Button("Keep Current", role: .cancel) {}
                .accessibilityIdentifier(AccessibilityIdentifiers.exerciseSetCancelReplaceTimerButton(exercise, set: set))
        } message: {
            Text("Start a new timer for \(secondsToTime(set.effectiveRestSeconds))?")
        }
    }

    private func deleteSet() {
        Haptics.selection()
        exercise.deleteSet(set)
        saveContext(context: context)
    }

    private func handleAutoStartTimer() {
        guard autoStartRestTimer else { return }
        let restSeconds = set.effectiveRestSeconds
        guard restSeconds > 0 else { return }

        if restTimer.isActive {
            showOverrideTimerAlert = true
        } else {
            restTimer.start(seconds: restSeconds, startedFromSetID: set.persistentModelID)
            RestTimeHistory.record(seconds: restSeconds, context: context)
            saveContext(context: context)
            Task { await IntentDonations.donateStartRestTimer(seconds: restSeconds) }
            showRestTimerSheet = true
        }
    }

}

#Preview {
    @Previewable @State var showRestTimerSheet = false
    ExerciseView(exercise: sampleIncompleteSession().sortedExercises.first!, showRestTimerSheet: $showRestTimerSheet)
        .sampleDataContainerIncomplete()
        .environment(RestTimerState())
}
