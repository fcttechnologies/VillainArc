import SwiftUI
import SwiftData

struct PreviousSetSnapshot {
    let reps: Int
    let weight: Double

    var displayText: String {
        "\(reps)x\(Self.formattedWeight(weight))"
    }

    static func formattedWeight(_ weight: Double) -> String {
        weight.formatted(.number.precision(.fractionLength(0...2)))
    }
}

struct ExerciseSetRowView: View {
    @Bindable var set: ExerciseSet
    @Bindable var exercise: WorkoutExercise
    @Binding var showRestTimerSheet: Bool
    @Environment(\.modelContext) private var context
    @Environment(RestTimerState.self) private var restTimer
    @AppStorage("autoStartRestTimer") private var autoStartRestTimer = true
    @State private var showOverrideTimerAlert = false
    
    let previousSetSnapshot: PreviousSetSnapshot?
    let fieldWidth: CGFloat
    let isEditing: Bool
    
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
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.exerciseSetMenu(exercise, set: set))
            .accessibilityLabel(AccessibilityText.exerciseSetMenuLabel(for: set))
            .accessibilityValue(AccessibilityText.exerciseSetMenuValue(for: set))
            .accessibilityHint("Opens set options.")
            
            TextField("Reps", value: $set.reps, format: .number)
                .keyboardType(.numberPad)
                .frame(maxWidth: fieldWidth)
                .accessibilityIdentifier(AccessibilityIdentifiers.exerciseSetRepsField(exercise, set: set))
                .accessibilityLabel("Reps")
            TextField("Weight", value: $set.weight, format: .number)
                .keyboardType(.decimalPad)
                .frame(maxWidth: fieldWidth)
                .accessibilityIdentifier(AccessibilityIdentifiers.exerciseSetWeightField(exercise, set: set))
                .accessibilityLabel("Weight")

            if !isEditing {
                Text(previousSetSnapshot?.displayText ?? "-")
                    .lineLimit(1)
                    .frame(maxWidth: fieldWidth)
                    .contextMenu {
                        if let previousSetSnapshot {
                            Button("Use Previous Set") {
                                Haptics.selection()
                                set.reps = previousSetSnapshot.reps
                                set.weight = previousSetSnapshot.weight
                                saveContext(context: context)
                            }
                            .accessibilityIdentifier(AccessibilityIdentifiers.exerciseSetUsePreviousButton(exercise, set: set))
                        }
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.exerciseSetPreviousValue(exercise, set: set))
                    .accessibilityLabel("Previous")
                    .accessibilityValue(previousSetSnapshot?.displayText ?? "None")
                    .accessibilityHint(previousSetSnapshot == nil ? "No previous set data." : "Long-press for options.")

                if set.complete {
                    Button {
                        Haptics.selection()
                        set.complete = false
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
            } else {
                Spacer()
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
                    restTimer.start(seconds: restSeconds)
                    RestTimeHistory.record(seconds: restSeconds, context: context)
                    saveContext(context: context)
                    Task { await IntentDonations.donateStartRestTimer(seconds: restSeconds) }
                    showRestTimerSheet = true
                }
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.exerciseSetReplaceTimerButton(exercise, set: set))
            Button("Cancel", role: .cancel) {}
                .accessibilityIdentifier(AccessibilityIdentifiers.exerciseSetCancelReplaceTimerButton(exercise, set: set))
        } message: {
            Text("Start a new timer for \(secondsToTime(set.effectiveRestSeconds))?")
        }
    }
    
    private func deleteSet() {
        Haptics.selection()
        exercise.removeSet(set)
        context.delete(set)
        saveContext(context: context)
    }
    
    private func handleAutoStartTimer() {
        guard autoStartRestTimer else { return }
        let restSeconds = set.effectiveRestSeconds
        guard restSeconds > 0 else { return }
        
        if restTimer.isActive {
            showOverrideTimerAlert = true
        } else {
            restTimer.start(seconds: restSeconds)
            RestTimeHistory.record(seconds: restSeconds, context: context)
            saveContext(context: context)
            Task { await IntentDonations.donateStartRestTimer(seconds: restSeconds) }
            showRestTimerSheet = true
        }
    }

}

#Preview {
    @Previewable @State var showRestTimerSheet = false
    ExerciseView(exercise: sampleIncompleteWorkout().sortedExercises.first!, showRestTimerSheet: $showRestTimerSheet)
        .sampleDataContainerIncomplete()
        .environment(RestTimerState())
}
