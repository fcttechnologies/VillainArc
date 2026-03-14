import SwiftUI
import SwiftData

struct SetReferenceData {
    let reps: Int?
    let weight: Double?
    let targetRPE: Int?
    let actionLabel: String

    var hasActionableValues: Bool {
        reps != nil || weight != nil
    }

    func displayText(unit: WeightUnit) -> String {
        if let reps, reps > 0, (weight ?? 0) == 0 {
            return "\(reps) reps"
        }
        guard let reps, let weight else { return "-" }
        return "\(reps)x\(unit.fromKg(weight).formatted(.number.precision(.fractionLength(0...2))))"
    }
}

struct ExerciseSetRowView: View {
    private enum Field {
        case reps
        case weight
    }
    
    @Bindable var set: SetPerformance
    @Bindable var exercise: ExercisePerformance
    @Environment(\.modelContext) private var context
    @Query(AppSettings.single) private var appSettings: [AppSettings]
    private let restTimer = RestTimerState.shared
    @State private var showOverrideTimerAlert = false
    @FocusState private var focusedField: Field?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let referenceData: SetReferenceData?
    let fieldWidth: CGFloat

    private var weightUnit: WeightUnit { appSettings.first?.weightUnit ?? .lbs }

    private var autoStartRestTimerEnabled: Bool {
        appSettings.first?.autoStartRestTimer ?? true
    }

    private var autoCompleteSetAfterRPEEnabled: Bool {
        appSettings.first?.autoCompleteSetAfterRPE ?? false
    }

    var body: some View {
        Group {
            Menu {
                Picker("", selection: Binding(get: { set.type }, set: { newValue in
                    let oldValue = set.type
                    set.type = newValue
                    if newValue != oldValue {
                        Haptics.selection()
                        saveContext(context: context)
                        WorkoutActivityManager.update()
                        if newValue == .warmup {
                            set.rpe = 0
                        }
                    }
                })) {
                    ForEach(ExerciseSetType.allCases, id: \.self) { type in
                        Text(type.displayName)
                            .tag(type)
                    }
                }
                Divider()
                if set.type != .warmup {
                    Menu {
                        Picker("RPE", selection: Binding(
                            get: { set.rpe },
                            set: { newValue in
                                updateRPE(to: set.rpe == newValue ? 0 : newValue)
                            }
                        )) {
                            ForEach(RPEValue.selectableValues, id: \.self) { value in
                                Label(RPEValue.pickerDescription(for: value, style: .actual), systemImage: "\(value).circle")
                                    .tag(value)
                            }
                        }
                    } label: {
                        Label(actualRPELabel, systemImage: "flame.fill")
                        Text(RPEValue.menuSubtitle(for: set.visibleRPE, style: .actual))
                    }
                }
                if (exercise.sets?.count ?? 0) > 1 {
                    Button("Delete Set", systemImage: "trash", role: .destructive) {
                        deleteSet()
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.exerciseSetDeleteButton(exercise, set: set))
                }
            } label: {
                setIndicator
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.exerciseSetMenu(exercise, set: set))
            .accessibilityLabel(AccessibilityText.exerciseSetMenuLabel(for: set))
            .accessibilityValue(AccessibilityText.exerciseSetMenuValue(for: set))
            .accessibilityHint(AccessibilityText.exerciseSetMenuHint)

            TextField("Reps", value: $set.reps, format: .number)
                .keyboardType(.numberPad)
                .focused($focusedField, equals: .reps)
                .frame(maxWidth: fieldWidth)
                .opacity(set.complete ? 0.4 : 1)
                .accessibilityIdentifier(AccessibilityIdentifiers.exerciseSetRepsField(exercise, set: set))
                .accessibilityLabel(AccessibilityText.exerciseSetRepsLabel)
            TextField("Weight", value: $set.weight, format: .number)
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: .weight)
                .frame(maxWidth: fieldWidth)
                .opacity(set.complete ? 0.4 : 1)
                .accessibilityIdentifier(AccessibilityIdentifiers.exerciseSetWeightField(exercise, set: set))
                .accessibilityLabel(AccessibilityText.exerciseSetWeightLabel)

            Text(referenceData?.displayText(unit: weightUnit) ?? "-")
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .overlay(alignment: .topTrailing) {
                    if let targetRPE = referenceData?.targetRPE {
                        RPEBadge(value: targetRPE, style: .target)
                            .offset(x: targetRPE == 10 ? 14 : 7, y: -4)
                    }
                }
            .frame(maxWidth: fieldWidth)
            .opacity(set.complete ? 0.4 : 1)
            .contextMenu {
                if let referenceData, referenceData.hasActionableValues {
                    Button(referenceData.actionLabel) {
                        Haptics.selection()
                        if let reps = referenceData.reps {
                            set.reps = reps
                        }
                        if let weight = referenceData.weight {
                            set.weight = weightUnit.fromKg(weight)
                        }
                        saveContext(context: context)
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.exerciseSetUsePreviousButton(exercise, set: set))
                }
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.exerciseSetPreviousValue(exercise, set: set))
            .accessibilityLabel(referenceData?.hasActionableValues == true ? (referenceData?.actionLabel ?? "Reference") : "Target")
            .accessibilityValue(referenceValueText)
            .accessibilityHint(referenceData?.hasActionableValues == true ? "Long-press for options." : "No quick-fill options.")

            if set.complete {
                Button {
                    Haptics.selection()
                    set.complete = false
                    set.completedAt = nil
                    saveContext(context: context)
                    WorkoutActivityManager.update()
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
                    completeSet()
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
        .animation(reduceMotion ? .none : .bouncy, value: set.complete)
        .onChange(of: focusedField) { _, field in
            guard field != nil else { return }
            selectAllFocusedText()
        }
        .onChange(of: set.reps) {
            scheduleSave(context: context)
            WorkoutActivityManager.update()
        }
        .onChange(of: set.weight) {
            scheduleSave(context: context)
            WorkoutActivityManager.update()
        }
        .alert("Replace Rest Timer?", isPresented: $showOverrideTimerAlert) {
            Button("Replace", role: .destructive) {
                let restSeconds = set.effectiveRestSeconds
                if restSeconds > 0 {
                    restTimer.start(seconds: restSeconds, startedFromSetID: set.id)
                    RestTimeHistory.record(seconds: restSeconds, context: context)
                    saveContext(context: context)
                    Task { await IntentDonations.donateStartRestTimer(seconds: restSeconds) }
                }
            }
            .accessibilityIdentifier(AccessibilityIdentifiers.exerciseSetReplaceTimerButton(exercise, set: set))
            Button("Keep Current", role: .cancel) {}
                .accessibilityIdentifier(AccessibilityIdentifiers.exerciseSetCancelReplaceTimerButton(exercise, set: set))
        } message: {
            Text(replaceTimerPrompt)
        }
    }

    private func deleteSet() {
        Haptics.selection()
        exercise.deleteSet(set)
        saveContext(context: context)
        WorkoutActivityManager.update()
    }

    private func updateRPE(to value: Int) {
        guard set.rpe != value else { return }
        Haptics.selection()
        set.rpe = value
        if autoCompleteSetAfterRPEEnabled, !set.complete, value > 0 {
            completeSet(playHaptics: false)
            return
        }
        saveContext(context: context)
        WorkoutActivityManager.update()
    }

    private func completeSet(playHaptics: Bool = true) {
        let shouldPrewarmSuggestions = shouldPrewarmSuggestionModelsOnCompletion
        if playHaptics {
            Haptics.selection()
        }
        set.complete = true
        set.completedAt = Date()
        handleAutoStartTimer()
        saveContext(context: context)
        WorkoutActivityManager.update()
        if shouldPrewarmSuggestions {
            FoundationModelPrewarmer.warmup()
        }
        Task { await IntentDonations.donateCompleteActiveSet() }
    }

    private func handleAutoStartTimer() {
        guard autoStartRestTimerEnabled else { return }
        let restSeconds = set.effectiveRestSeconds
        guard restSeconds > 0 else { return }

        if restTimer.isActive {
            showOverrideTimerAlert = true
        } else {
            restTimer.start(seconds: restSeconds, startedFromSetID: set.id)
            RestTimeHistory.record(seconds: restSeconds, context: context)
            saveContext(context: context)
            Task { await IntentDonations.donateStartRestTimer(seconds: restSeconds) }
        }
    }

    private var referenceValueText: String {
        guard let referenceData else { return "None" }
        let text = referenceData.displayText(unit: weightUnit)
        if let targetRPE = referenceData.targetRPE {
            return "\(text), target RPE \(targetRPE)"
        }
        return text
    }

    private var shouldPrewarmSuggestionModelsOnCompletion: Bool {
        guard let workout = exercise.workoutSession, workout.workoutPlan != nil else { return false }
        return workout.isFinalIncompleteSet(set)
    }

    private var actualRPELabel: String {
        if set.rpe == 0 {
            return String(localized: "RPE")
        }
        return String(localized: "RPE: \(set.rpe)")
    }

    private var replaceTimerPrompt: String {
        String(localized: "Start a new timer for \(secondsToTime(set.effectiveRestSeconds))?")
    }

    private var setIndicator: some View {
        Text(set.type == .working ? String(set.index + 1) : set.type.shortLabel)
            .foregroundStyle(set.type.tintColor)
            .frame(width: 40, height: 40)
            .glassEffect(.regular, in: .circle)
            .opacity(set.complete ? 0.4 : 1)
            .overlay(alignment: .topTrailing) {
                if let visibleRPE = set.visibleRPE {
                    RPEBadge(value: visibleRPE)
                        .offset(x: visibleRPE == 10 ? -2 : -8)
                }
            }
    }

}

#Preview {
    ExerciseView(exercise: sampleIncompleteSession().sortedExercises.first!)
        .sampleDataContainerIncomplete()
}
