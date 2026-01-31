import SwiftUI
import SwiftData

struct ExerciseView: View {
    @AppStorage("autoStartRestTimer") private var autoStartRestTimer = true
    @Query private var previousExercise: [ExercisePerformance]
    @Environment(\.modelContext) private var context
    @Bindable var exercise: ExercisePerformance
    @Binding var showRestTimerSheet: Bool
    private let restTimer = RestTimerState.shared

    @State private var isNotesExpanded = false
    @State private var showRepRangeEditor = false
    @State private var showRestTimeEditor = false
    @State private var showRestTimeUpdateAlert = false
    @State private var restTimeUpdateDeltaSeconds = 0
    @State private var restTimeUpdateSeconds = 0

    init(exercise: ExercisePerformance, showRestTimerSheet: Binding<Bool>) {
        self.exercise = exercise
        _showRestTimerSheet = showRestTimerSheet

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
                            ExerciseSetRowView(set: set, exercise: exercise, showRestTimerSheet: $showRestTimerSheet, referenceData: referenceData(for: set), fieldWidth: fieldWidth)
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
                Text("Update the timer by \(restTimeUpdateDeltaText)?")
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
                HStack(spacing: 12) {
                    Button("Notes", systemImage: isNotesExpanded ? "note.text" : "note.text.badge.plus") {
                        Haptics.selection()
                        withAnimation {
                            isNotesExpanded.toggle()
                        }
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.exerciseNotesButton(exercise))
                    .accessibilityHint("Shows notes.")

                    Button("Rest Times", systemImage: "timer") {
                        Haptics.selection()
                        showRestTimeEditor = true
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.exerciseRestTimesButton(exercise))
                    .accessibilityHint("Edits rest times.")
                }
                .labelStyle(.iconOnly)
                .font(.title)
                .tint(.primary)
            }

            if isNotesExpanded {
                TextField("Notes", text: $exercise.notes, axis: .vertical)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .padding(.top, 8)
                    .onChange(of: exercise.notes) {
                        scheduleSave(context: context)
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.exerciseNotesField(exercise))
            }
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .sheet(isPresented: $showRepRangeEditor) {
            RepRangeEditorView(repRange: exercise.repRange)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showRestTimeEditor) {
            RestTimeEditorView(exercise: exercise)
                .onDisappear {
                    checkForRestTimeUpdate()
                }
        }
    }

    private func addSet() {
        Haptics.selection()
        exercise.addSet()
        saveContext(context: context)
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
    @Previewable @State var showRestTimerSheet = false
    ExerciseView(exercise: sampleIncompleteSession().sortedExercises.first!, showRestTimerSheet: $showRestTimerSheet)
        .sampleDataContainerIncomplete()
}
