import SwiftUI
import SwiftData
import TipKit

struct ExerciseView: View {
    private enum RestTimerPromptAction {
        case updateExistingTimer
        case startNewTimer(setID: UUID)
    }
    
    @Environment(\.modelContext) private var context
    @Bindable var exercise: ExercisePerformance
    let appSettingsSnapshot: AppSettingsSnapshot
    let onDeleteExercise: (() -> Void)?
    private let restTimer = RestTimerState.shared
    
    @State private var showRepRangeEditor = false
    @State private var showRestTimeEditor = false
    @State private var showReplaceExerciseSheet = false
    @State private var showExerciseHistorySheet = false
    @State private var progressionStepExercise: Exercise?
    @State private var pendingRestTimerPromptAction: RestTimerPromptAction?
    @State private var restTimeUpdateSeconds = 0
    @State private var restTimeSnapshotBySetID: [UUID: Int] = [:]
    @State private var previousReferenceBySetIndex: [Int: SetReferenceData] = [:]
    @State private var showsPreviousInstead: Bool?
    @State private var preferredWeightChangeKg: Double?
    @FocusState private var focusedSetField: SetFieldFocus?
    private let exerciseContextMenuTip = ExerciseContextMenuTip()

    private var weightUnit: WeightUnit { appSettingsSnapshot.weightUnit }

    private var autoStartRestTimerEnabled: Bool {
        appSettingsSnapshot.autoStartRestTimer
    }

    init(exercise: ExercisePerformance, appSettingsSnapshot: AppSettingsSnapshot, onDeleteExercise: (() -> Void)? = nil) {
        self.exercise = exercise
        self.appSettingsSnapshot = appSettingsSnapshot
        self.onDeleteExercise = onDeleteExercise
    }

    private var hasPrescription: Bool {
        exercise.prescription != nil
    }

    private var shouldUseTargetReference: Bool {
        guard hasPrescription else { return false }
        if let showsPreviousInstead { return !showsPreviousInstead }
        return appSettingsSnapshot.prefersTargetReferenceWhenPlanned
    }

    private var canToggleReference: Bool {
        hasPrescription
    }

    private func targetReferenceData(for set: SetPerformance) -> SetReferenceData? {
        guard let prescription = set.prescription else { return nil }
        let reps = prescription.targetReps > 0 ? prescription.targetReps : nil
        let weight = prescription.targetWeight > 0 ? prescription.targetWeight : nil
        let targetRPE = prescription.visibleTargetRPE
        guard reps != nil || weight != nil || targetRPE != nil else { return nil }
        return SetReferenceData(reps: reps, weight: weight, rpe: targetRPE, setType: prescription.type, rpeStyle: .target, actionLabel: "Use Target")
    }

    private func previousReferenceData(for set: SetPerformance) -> SetReferenceData? {
        previousReferenceBySetIndex[set.index]
    }

    private func referenceData(for set: SetPerformance) -> SetReferenceData? {
        if shouldUseTargetReference {
            return targetReferenceData(for: set)
        }
        return previousReferenceData(for: set)
    }

    private func toggleReferenceColumn() {
        guard canToggleReference else { return }
        Haptics.selection()
        showsPreviousInstead = shouldUseTargetReference
        if showsPreviousInstead == true {
            loadPreviousReferenceDataIfNeeded()
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let fieldWidth = geometry.size.width / 5
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(exercise.name)
                        .font(.title3)
                        .bold()
                        .lineLimit(1)
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(exercise.equipmentType.displayName)
                                .foregroundStyle(.secondary)
                                .fontWeight(.semibold)
                            if let repRange = exercise.repRange {
                                RepRangeButton(repRange: repRange, accessibilityIdentifier: AccessibilityIdentifiers.exerciseRepRangeButton(exercise)) { showRepRangeEditor = true }
                            }
                        }
                        Spacer()
                        HStack(spacing: 16) {
                            Button("History", systemImage: "clock.arrow.circlepath") {
                                Haptics.selection()
                                showExerciseHistorySheet = true
                            }
                            .accessibilityIdentifier(AccessibilityIdentifiers.exerciseHistoryButton(exercise))
                            .accessibilityHint(AccessibilityText.workoutPlanExerciseHistoryHint)
                            .labelStyle(.iconOnly)
                            .font(.title)
                            .tint(.primary)
                            
                            Button("Rest Times", systemImage: "timer") {
                                Haptics.selection()
                                captureRestTimeSnapshot()
                                showRestTimeEditor = true
                            }
                            .accessibilityIdentifier(AccessibilityIdentifiers.exerciseRestTimesButton(exercise))
                            .accessibilityHint(AccessibilityText.workoutPlanExerciseRestTimesHint)
                            .labelStyle(.iconOnly)
                            .font(.title)
                            .tint(.primary)
                        }
                    }
                    
                    TextField("Notes", text: $exercise.notes)
                        .padding(.top, 10)
                        .onChange(of: exercise.notes) {
                            scheduleSave(context: context)
                        }
                        .accessibilityIdentifier(AccessibilityIdentifiers.exerciseNotesField(exercise))
                }
                .padding()
                .appCardStyle()
                .popoverTip(exerciseContextMenuTip)
                .contextMenu {
                    Button {
                        openProgressionStepEditor()
                    } label: {
                        Label("Suggestion Settings", systemImage: "slider.horizontal.3")
                    }
                    Button {
                        Haptics.selection()
                        showReplaceExerciseSheet = true
                    } label: {
                        Label("Replace Exercise", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.exerciseReplaceButton(exercise))
                    .accessibilityHint(AccessibilityText.workoutPlanExerciseReplaceHint)
                    if let onDeleteExercise {
                        Button(role: .destructive) {
                            Haptics.selection()
                            onDeleteExercise()
                        } label: {
                            Label("Delete Exercise", systemImage: "trash")
                        }
                        .accessibilityIdentifier(AccessibilityIdentifiers.exerciseDeleteButton(exercise))
                        .accessibilityHint(AccessibilityText.workoutPlanExerciseDeleteHint)
                    }
                }
                .padding(.horizontal)

                setsGrid(fieldWidth: fieldWidth)

                Button {
                    addSet()
                } label: {
                    Label("Add Set", systemImage: "plus")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .padding(.vertical, 5)
                }
                .tint(.blue)
                .buttonStyle(.glass)
                .buttonSizing(.flexible)
                .padding(.horizontal)
                .accessibilityIdentifier(AccessibilityIdentifiers.exerciseAddSetButton(exercise))
                .accessibilityHint(AccessibilityText.workoutPlanExerciseAddSetHint)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.immediately)
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
            .simultaneousGesture(
                TapGesture().onEnded {
                    dismissKeyboard()
                }
            )
            .toolbar { keyboardToolbarItems }
            .onChange(of: focusedSetField) { _, field in
                guard field != nil else { return }
                selectAllFocusedText()
            }
            .alert(restTimerPromptTitle, isPresented: restTimePromptBinding) {
                Button(restTimerPromptConfirmLabel) {
                    applyRestTimerPrompt()
                }
                Button("Keep Current", role: .cancel) {
                    Haptics.selection()
                }
            } message: {
                Text(restTimerPromptMessage)
            }
            .sheet(isPresented: $showRepRangeEditor) {
                RepRangeEditorView(repRange: exercise.repRange ?? RepRangePolicy(), catalogID: exercise.catalogID)
                    .presentationDetents([.medium])
                    .presentationBackground(Color.sheetBg)
            }
            .sheet(isPresented: $showRestTimeEditor) {
                RestTimeEditorView(exercise: exercise)
                    .presentationDetents([.medium, .large])
                    .presentationBackground(Color.sheetBg)
                    .onDisappear {
                        checkForRestTimeUpdate()
                    }
            }
            .sheet(isPresented: $showReplaceExerciseSheet) {
                ReplaceExerciseView(currentCatalogID: exercise.catalogID, sourceMuscles: Set(exercise.musclesTargeted), sourceEquipmentType: exercise.equipmentType) { newExercise, keepSets in
                    exercise.replaceWith(newExercise, keepSets: keepSets, context: context)
                    saveContext(context: context)
                    WorkoutActivityManager.update()
                    Task { await IntentDonations.donateReplaceExercise(newExercise: newExercise) }
                }
                .presentationBackground(Color.sheetBg)
            }
            .sheet(isPresented: $showExerciseHistorySheet) {
                NavigationStack {
                    ExerciseHistoryView(exercise: exercise, showSheetBackground: true)
                }
                .presentationDetents([.medium, .large])
                .presentationBackground(Color.sheetBg)
            }
            .sheet(item: $progressionStepExercise) { progressionStepExercise in
                ExerciseSuggestionSettingsSheet(exercise: progressionStepExercise)
                    .presentationBackground(Color.sheetBg)
            }
            .task(id: exercise.catalogID) {
                loadPreviousReferenceDataIfNeeded()
                loadPreferredWeightChange()
            }
            .onChange(of: appSettingsSnapshot.previousSetReferenceSource) {
                previousReferenceBySetIndex = [:]
                loadPreviousReferenceDataIfNeeded()
            }
        }
    }
    
    private func addSet() {
        Haptics.selection()
        exercise.addSet(unit: weightUnit)
        saveContext(context: context)
        WorkoutActivityManager.update()
    }
    
    private func checkForRestTimeUpdate() {
        defer { restTimeSnapshotBySetID = [:] }
        guard autoStartRestTimerEnabled else { return }
        if let startedFromSetID = restTimer.startedFromSetID,
           let matchingSet = exercise.sortedSets.first(where: { $0.id == startedFromSetID }) {
            let newRestSeconds = matchingSet.effectiveRestSeconds
            guard newRestSeconds != restTimer.startedSeconds else { return }
            restTimeUpdateSeconds = newRestSeconds
            pendingRestTimerPromptAction = .updateExistingTimer
            return
        }
        
        guard !restTimer.isActive else { return }
        guard let workout = exercise.workoutSession,
              let latestCompletedSet = workout.latestCompletedSet(),
              latestCompletedSet.exercise?.id == exercise.id,
              let previousRestSeconds = restTimeSnapshotBySetID[latestCompletedSet.id]
        else { return }
        
        let newRestSeconds = latestCompletedSet.effectiveRestSeconds
        guard previousRestSeconds == 0, newRestSeconds > 0 else { return }
        
        restTimeUpdateSeconds = newRestSeconds
        pendingRestTimerPromptAction = .startNewTimer(setID: latestCompletedSet.id)
    }
    
    private func loadPreviousReferenceDataIfNeeded() {
        guard previousReferenceBySetIndex.isEmpty else { return }
        let descriptor: FetchDescriptor<ExercisePerformance>
        switch appSettingsSnapshot.previousSetReferenceSource {
        case .anyWorkout:
            descriptor = ExercisePerformance.lastCompleted(for: exercise)
        case .lastPlanUse:
            descriptor = ExercisePerformance.lastCompletedInSamePlan(for: exercise)
        }
        let previousSets = (try? context.fetch(descriptor).first?.sortedSets) ?? []
        previousReferenceBySetIndex = Dictionary(uniqueKeysWithValues: previousSets.map { previousSet in
            (previousSet.index, SetReferenceData(reps: previousSet.reps, weight: previousSet.weight, rpe: previousSet.visibleRPE, setType: previousSet.type, rpeStyle: .actual, actionLabel: "Use Previous"))
        })
    }
    
    private func openProgressionStepEditor() {
        guard let sourceExercise = try? context.fetch(Exercise.withCatalogID(exercise.catalogID)).first else { return }
        progressionStepExercise = sourceExercise
        Haptics.selection()
    }

    private func loadPreferredWeightChange() {
        preferredWeightChangeKg = (try? context.fetch(Exercise.withCatalogID(exercise.catalogID)).first)?.preferredWeightChange
    }

    /// The sets table (header row + a row per set). Extracted from `body` so the view's main
    /// expression stays inside the Swift type-checker's budget.
    @ViewBuilder
    private func setsGrid(fieldWidth: CGFloat) -> some View {
        Grid(verticalSpacing: 12) {
            GridRow {
                Spacer()
                Text("Set")
                Spacer()
                Text("Reps")
                    .gridColumnAlignment(.leading)
                Spacer()
                Text(exercise.equipmentType.loadDisplayName)
                    .gridColumnAlignment(.leading)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .frame(alignment: .leading)
                Spacer()
                if canToggleReference {
                    Button(shouldUseTargetReference ? "Target" : "Previous") {
                        toggleReferenceColumn()
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(shouldUseTargetReference ? "Target" : "Previous")
                }
                Spacer()
                Text(verbatim: " ")
                Spacer()
            }
            .font(.title3)
            .bold()
            .accessibilityHidden(true)

            ForEach(exercise.sortedSets) { set in
                GridRow {
                    ExerciseSetRowView(set: set, exercise: exercise, appSettingsSnapshot: appSettingsSnapshot, referenceData: referenceData(for: set), fieldWidth: fieldWidth, focusedField: $focusedSetField)
                }
                .font(.title3)
                .fontWeight(.semibold)
            }
        }
        .padding(.vertical)
    }

    /// The single keyboard accessory for every set field in this exercise — kept as its own
    /// `ToolbarContent` so the large `body` stays inside the Swift type-checker's budget.
    @ToolbarContentBuilder
    private var keyboardToolbarItems: some ToolbarContent {
        if let focusedSetField {
            ToolbarItem(placement: .keyboard) {
                keyboardToolbar(for: focusedSetField)
            }
        }
    }

    /// Rendered once for the focused field (a single full-width HStack: adaptive +/- control(s) on
    /// the left, dismiss on the right), so the accessory never stacks across set rows.
    @ViewBuilder
    private func keyboardToolbar(for focus: SetFieldFocus) -> some View {
        HStack(spacing: 12) {
            switch focus {
            case .weight:
                if let step = weightStepDisplay {
                    Button("−\(weightStepLabel)") { adjustFocusedWeight(by: -step) }
                    Button("+\(weightStepLabel)") { adjustFocusedWeight(by: step) }
                }
            case .reps:
                Button("−1") { adjustFocusedReps(by: -1) }
                Button("+1") { adjustFocusedReps(by: 1) }
            }

            Spacer()

            Button {
                dismissKeyboard()
                focusedSetField = nil
            } label: {
                Image(systemName: "keyboard.chevron.compact.down")
            }
            .accessibilityLabel("Dismiss Keyboard")
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }

    /// The exercise's preferred progression step, in the user's display unit.
    /// `nil` when no preferred step is set, which hides the weight +/- controls.
    private var weightStepDisplay: Double? {
        guard let preferredWeightChangeKg, preferredWeightChangeKg > 0 else { return nil }
        let value = roundedDisplayValue(weightUnit.fromKg(preferredWeightChangeKg), fractionDigits: 2)
        return value > 0 ? value : nil
    }

    private var weightStepLabel: String {
        (weightStepDisplay ?? 0).formatted(.number.precision(.fractionLength(0...2)))
    }

    private func focusedSet() -> SetPerformance? {
        guard let focusedSetField else { return nil }
        let setID: UUID
        switch focusedSetField {
        case .reps(let id), .weight(let id):
            setID = id
        }
        return exercise.sortedSets.first { $0.id == setID }
    }

    private func adjustFocusedReps(by delta: Int) {
        guard let set = focusedSet() else { return }
        Haptics.selection()
        set.reps = max(0, set.reps + delta)
    }

    private func adjustFocusedWeight(by delta: Double) {
        guard let set = focusedSet() else { return }
        Haptics.selection()
        // The step already reflects each equipment type's weight semantics (per-side,
        // assistance, or added bodyweight load), so bump the entered value directly and
        // clamp at 0 to keep assisted/bodyweight loads from going negative.
        set.weight = max(0, roundedDisplayValue(set.weight + delta, fractionDigits: 2))
    }
    
    private func captureRestTimeSnapshot() {
        restTimeSnapshotBySetID = Dictionary(uniqueKeysWithValues: exercise.sortedSets.map { ($0.id, $0.effectiveRestSeconds) })
    }
    
    private func applyRestTimerPrompt() {
        guard let pendingRestTimerPromptAction else { return }
        Haptics.selection()
        
        switch pendingRestTimerPromptAction {
        case .updateExistingTimer:
            restTimer.syncStartedDuration(to: restTimeUpdateSeconds)
        case .startNewTimer(let setID):
            restTimer.start(seconds: restTimeUpdateSeconds, startedFromSetID: setID)
            RestTimeHistory.record(seconds: restTimeUpdateSeconds, context: context)
            saveContext(context: context)
            Task { await IntentDonations.donateStartRestTimer(seconds: restTimeUpdateSeconds) }
        }
        
        self.pendingRestTimerPromptAction = nil
    }
    
    private var restTimePromptBinding: Binding<Bool> {
        Binding(
            get: { pendingRestTimerPromptAction != nil },
            set: { isPresented in
                if !isPresented {
                    pendingRestTimerPromptAction = nil
                }
            }
        )
    }
    
    private var restTimerPromptTitle: String {
        switch pendingRestTimerPromptAction {
        case .updateExistingTimer:
            return String(localized: "Update Rest Timer?")
        case .startNewTimer:
            return String(localized: "Start Rest Timer?")
        case .none:
            return ""
        }
    }
    
    private var restTimerPromptConfirmLabel: String {
        switch pendingRestTimerPromptAction {
        case .updateExistingTimer:
            return String(localized: "Update")
        case .startNewTimer:
            return String(localized: "Start")
        case .none:
            return String(localized: "OK")
        }
    }
    
    private var restTimerPromptMessage: String {
        switch pendingRestTimerPromptAction {
        case .updateExistingTimer:
            return String(localized: "Want to update rest timer to reflect the new set rest time?")
        case .startNewTimer:
            return String(localized: "Want to start a rest timer for \(secondsToTime(restTimeUpdateSeconds)) to reflect the new set rest time?")
        case .none:
            return ""
        }
    }
}

#Preview(traits: .sampleDataIncomplete) {
    ExerciseView(
        exercise: sampleIncompleteSession().sortedExercises.first!,
        appSettingsSnapshot: AppSettingsSnapshot(settings: nil)
    )
}
