import SwiftUI
import SwiftData

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
    
    private var weightUnit: WeightUnit { appSettingsSnapshot.weightUnit }
    
    private var autoStartRestTimerEnabled: Bool {
        appSettingsSnapshot.autoStartRestTimer
    }
    
    init(exercise: ExercisePerformance, appSettingsSnapshot: AppSettingsSnapshot, onDeleteExercise: (() -> Void)? = nil) {
        self.exercise = exercise
        self.appSettingsSnapshot = appSettingsSnapshot
        self.onDeleteExercise = onDeleteExercise
    }
    
    private var shouldUseTargetReference: Bool {
        exercise.prescription != nil
    }
    
    private func targetReferenceData(for set: SetPerformance) -> SetReferenceData? {
        guard let prescription = set.prescription else { return nil }
        let reps = prescription.targetReps > 0 ? prescription.targetReps : nil
        let weight = prescription.targetWeight > 0 ? prescription.targetWeight : nil
        let targetRPE = prescription.visibleTargetRPE
        guard reps != nil || weight != nil || targetRPE != nil else { return nil }
        return SetReferenceData(reps: reps, weight: weight, rpe: targetRPE, rpeStyle: .target, actionLabel: "Use Target")
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
                        Text(shouldUseTargetReference ? "Target" : "Previous")
                        Spacer()
                        Text(verbatim: " ")
                        Spacer()
                    }
                    .font(.title3)
                    .bold()
                    .accessibilityHidden(true)
                    
                    ForEach(exercise.sortedSets) { set in
                        GridRow {
                            ExerciseSetRowView(set: set, exercise: exercise, appSettingsSnapshot: appSettingsSnapshot, referenceData: referenceData(for: set), fieldWidth: fieldWidth)
                        }
                        .font(.title3)
                        .fontWeight(.semibold)
                    }
                }
                .padding(.vertical)
                
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
                ReplaceExerciseView(currentCatalogID: exercise.catalogID) { newExercise, keepSets in
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
                loadPreviousReferenceData()
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
    
    private func loadPreviousReferenceData() {
        guard !shouldUseTargetReference else {
            previousReferenceBySetIndex = [:]
            return
        }
        
        let previousSets = (try? context.fetch(ExercisePerformance.lastCompleted(for: exercise)).first?.sortedSets) ?? []
        previousReferenceBySetIndex = Dictionary(uniqueKeysWithValues: previousSets.map { previousSet in
            (previousSet.index, SetReferenceData(reps: previousSet.reps, weight: previousSet.weight, rpe: previousSet.visibleRPE, rpeStyle: .actual, actionLabel: "Use Previous"))
        })
    }
    
    private func openProgressionStepEditor() {
        guard let sourceExercise = try? context.fetch(Exercise.withCatalogID(exercise.catalogID)).first else { return }
        progressionStepExercise = sourceExercise
        Haptics.selection()
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
