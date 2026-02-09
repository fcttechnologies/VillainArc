import SwiftUI
import SwiftData

struct ExerciseView: View {
    @AppStorage("autoStartRestTimer") private var autoStartRestTimer = true
    @Query private var previousExercise: [ExercisePerformance]
    @Environment(\.modelContext) private var context
    @Bindable var exercise: ExercisePerformance
    let onDeleteExercise: (() -> Void)?
    private let restTimer = RestTimerState.shared

    @State private var showRepRangeEditor = false
    @State private var showRestTimeEditor = false
    @State private var showRestTimeUpdateAlert = false
    @State private var showReplaceExerciseSheet = false
    @State private var restTimeUpdateDeltaSeconds = 0
    @State private var restTimeUpdateSeconds = 0

    init(exercise: ExercisePerformance, onDeleteExercise: (() -> Void)? = nil) {
        self.exercise = exercise
        self.onDeleteExercise = onDeleteExercise

        _previousExercise = Query(ExercisePerformance.lastCompleted(for: exercise))
    }

    private var isPlanSession: Bool {
        exercise.workoutSession?.origin == .plan
    }

    private var previousSets: [SetPerformance] {
        return previousExercise.first?.sortedSets ?? []
    }

    private func referenceData(for set: SetPerformance) -> SetReferenceData? {
        if isPlanSession {
            guard let prescription = set.prescription else { return nil }
            let reps = prescription.targetReps > 0 ? prescription.targetReps : nil
            let weight = prescription.targetWeight > 0 ? prescription.targetWeight : nil
            guard reps != nil || weight != nil else { return nil }
            return SetReferenceData(reps: reps, weight: weight, actionLabel: "Use Target")
        } else {
            guard set.index < previousSets.count else { return nil }
            let prevSet = previousSets[set.index]
            return SetReferenceData(reps: prevSet.reps, weight: prevSet.weight, actionLabel: "Use Previous")
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let fieldWidth = geometry.size.width / 5
            ScrollView {
                headerView
                    .padding(.horizontal)

                Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                    GridRow {
                        Text("Set")
                        Text("Reps")
                            .gridColumnAlignment(.leading)
                        Text("Weight")
                            .gridColumnAlignment(.leading)
                        Text(isPlanSession ? "Target" : "Previous")
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
        }
    }

    var headerView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(exercise.name)
                .font(.title3)
                .bold()
                .lineLimit(1)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(exercise.displayMuscle)
                        .foregroundStyle(.secondary)
                        .fontWeight(.semibold)
                    Button {
                        Haptics.selection()
                        showRepRangeEditor = true
                    } label: {
                        Text(exercise.repRange.displayText)
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Rep range")
                    .accessibilityValue(exercise.repRange.displayText)
                    .accessibilityIdentifier(AccessibilityIdentifiers.exerciseRepRangeButton(exercise))
                    .accessibilityHint("Edits the rep range.")
                }
                Spacer()
                
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
        .sheet(isPresented: $showRepRangeEditor) {
            RepRangeEditorView(repRange: exercise.repRange, catalogID: exercise.catalogID)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showRestTimeEditor) {
            RestTimeEditorView(exercise: exercise)
                .onDisappear {
                    checkForRestTimeUpdate()
                }
        }
        .sheet(isPresented: $showReplaceExerciseSheet) {
            ReplaceExerciseView(exercise: exercise) { newExercise, keepSets in
                exercise.replaceWith(newExercise, keepSets: keepSets)
                ExerciseHistoryUpdater.createIfNeeded(for: newExercise.catalogID, context: context)
                saveContext(context: context)
                WorkoutActivityManager.update()
                Task { await IntentDonations.donateReplaceExercise(newExercise: newExercise) }
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
        guard autoStartRestTimer else { return }
        guard let startedFromSetID = restTimer.startedFromSetID else { return }
        guard let matchingSet = exercise.sortedSets.first(where: { $0.persistentModelID == startedFromSetID }) else { return }

        let newRestSeconds = matchingSet.effectiveRestSeconds
        let originalSeconds = restTimer.startedSeconds
        guard newRestSeconds != originalSeconds else { return }

        restTimeUpdateDeltaSeconds = newRestSeconds - originalSeconds
        restTimeUpdateSeconds = newRestSeconds
        showRestTimeUpdateAlert = true
    }

    private var restTimeUpdateDeltaText: String {
        let delta = restTimeUpdateDeltaSeconds
        let magnitude = secondsToTime(abs(delta))
        return delta < 0 ? "-\(magnitude)" : "+\(magnitude)"
    }

}

#Preview {
    ExerciseView(exercise: sampleIncompleteSession().sortedExercises.first!)
        .sampleDataContainerIncomplete()
}
