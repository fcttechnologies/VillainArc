import SwiftUI
import SwiftData

struct ExerciseView: View {
    @Environment(\.modelContext) private var context
    @Query(AppSettings.single) private var appSettings: [AppSettings]
    @Bindable var exercise: ExercisePerformance
    let onDeleteExercise: (() -> Void)?
    private let restTimer = RestTimerState.shared

    @State private var showRepRangeEditor = false
    @State private var showRestTimeEditor = false
    @State private var showRestTimeUpdateAlert = false
    @State private var showReplaceExerciseSheet = false
    @State private var showExerciseHistorySheet = false
    @State private var restTimeUpdateDeltaSeconds = 0
    @State private var restTimeUpdateSeconds = 0

    private var autoStartRestTimerEnabled: Bool {
        appSettings.first?.autoStartRestTimer ?? true
    }

    init(exercise: ExercisePerformance, onDeleteExercise: (() -> Void)? = nil) {
        self.exercise = exercise
        self.onDeleteExercise = onDeleteExercise
    }

    private var previousSets: [SetPerformance] {
        (try? context.fetch(ExercisePerformance.lastCompleted(for: exercise)).first?.sortedSets) ?? []
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
        return SetReferenceData(reps: reps, weight: weight, targetRPE: targetRPE, actionLabel: "Use Target")
    }

    private func previousReferenceData(for set: SetPerformance) -> SetReferenceData? {
        guard set.index < previousSets.count else { return nil }
        let prevSet = previousSets[set.index]
        return SetReferenceData(reps: prevSet.reps, weight: prevSet.weight, targetRPE: nil, actionLabel: "Use Previous")
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
                            Text(exercise.equipmentType.rawValue)
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
                            .accessibilityIdentifier("exerciseHistoryButton-\(exercise.catalogID)-\(exercise.index)")
                            .accessibilityHint("Shows prior performances for this exercise.")
                            .labelStyle(.iconOnly)
                            .font(.title)
                            .tint(.primary)

                            Button("Rest Times", systemImage: "timer") {
                                Haptics.selection()
                                showRestTimeEditor = true
                            }
                            .accessibilityIdentifier(AccessibilityIdentifiers.exerciseRestTimesButton(exercise))
                            .accessibilityHint("Edits rest times.")
                            .labelStyle(.iconOnly)
                            .font(.title)
                            .tint(.primary)
                        }
                    }

                    TextField("Notes", text: $exercise.notes)
                        .padding(.top, 8)
                        .onChange(of: exercise.notes) {
                            scheduleSave(context: context)
                        }
                        .accessibilityIdentifier(AccessibilityIdentifiers.exerciseNotesField(exercise))
                }
                .padding()
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
                .contextMenu {
                    Button {
                        Haptics.selection()
                        showReplaceExerciseSheet = true
                    } label: {
                        Label("Replace Exercise", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.exerciseReplaceButton(exercise))
                    .accessibilityHint("Replaces this exercise with another.")
                    if let onDeleteExercise {
                        Button(role: .destructive) {
                            Haptics.selection()
                            onDeleteExercise()
                        } label: {
                            Label("Delete Exercise", systemImage: "trash")
                        }
                        .accessibilityIdentifier(AccessibilityIdentifiers.exerciseDeleteButton(exercise))
                        .accessibilityHint("Deletes this exercise.")
                    }
                }
                .padding(.horizontal)

                Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                    GridRow {
                        Text("Set")
                        Text("Reps")
                            .gridColumnAlignment(.leading)
                        Text("Weight")
                            .gridColumnAlignment(.leading)
                        Text(shouldUseTargetReference ? "Target" : "Previous")
                        Text(" ")
                    }
                    .font(.title3)
                    .bold()
                    .accessibilityHidden(true)

                    ForEach(exercise.sortedSets) { set in
                        GridRow {
                            ExerciseSetRowView(set: set, exercise: exercise, referenceData: referenceData(for: set), fieldWidth: fieldWidth)
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
                .accessibilityHint("Adds a new set.")
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.immediately)
            .dynamicTypeSize(...DynamicTypeSize.large)
            .simultaneousGesture(
                TapGesture().onEnded {
                    dismissKeyboard()
                }
            )
            .alert("Update Rest Timer?", isPresented: $showRestTimeUpdateAlert) {
                Button("Update") {
                    Haptics.selection()
                    restTimer.adjust(by: restTimeUpdateDeltaSeconds)
                    if restTimer.isActive {
                        restTimer.startedSeconds = restTimeUpdateSeconds
                    }
                }
                Button("Keep Current", role: .cancel) {}
            } message: {
                Text("Want to update rest timer to reflect the new set rest time?")
            }
            .sheet(isPresented: $showRepRangeEditor) {
                RepRangeEditorView(repRange: exercise.repRange ?? RepRangePolicy(), catalogID: exercise.catalogID)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showRestTimeEditor) {
                RestTimeEditorView(exercise: exercise)
                    .presentationDetents([.medium, .large])
                    .onDisappear {
                        checkForRestTimeUpdate()
                    }
            }
            .sheet(isPresented: $showReplaceExerciseSheet) {
                ReplaceExerciseView(currentCatalogID: exercise.catalogID) { newExercise, keepSets in
                    exercise.replaceWith(newExercise, keepSets: keepSets)
                    saveContext(context: context)
                    WorkoutActivityManager.update()
                    Task { await IntentDonations.donateReplaceExercise(newExercise: newExercise) }
                }
            }
            .sheet(isPresented: $showExerciseHistorySheet) {
                NavigationStack {
                    ExerciseHistoryView(exercise: exercise)
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    private func addSet() {
        Haptics.selection()
        exercise.addSet()
        saveContext(context: context)
        WorkoutActivityManager.update()
    }

    private func checkForRestTimeUpdate() {
        guard autoStartRestTimerEnabled else { return }
        guard let startedFromSetID = restTimer.startedFromSetID else { return }
        guard let matchingSet = exercise.sortedSets.first(where: { $0.id == startedFromSetID }) else { return }

        let newRestSeconds = matchingSet.effectiveRestSeconds
        let originalSeconds = restTimer.startedSeconds
        guard newRestSeconds != originalSeconds else { return }

        restTimeUpdateDeltaSeconds = newRestSeconds - originalSeconds
        restTimeUpdateSeconds = newRestSeconds
        showRestTimeUpdateAlert = true
    }
}

#Preview {
    ExerciseView(exercise: sampleIncompleteSession().sortedExercises.first!)
        .sampleDataContainerIncomplete()
}
