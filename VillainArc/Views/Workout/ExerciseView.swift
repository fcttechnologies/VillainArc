import SwiftUI
import SwiftData

struct ExerciseView: View {
    @Query private var previousExercise: [WorkoutExercise]
    @Environment(\.modelContext) private var context
    @Bindable var exercise: WorkoutExercise
    @Binding var showRestTimerSheet: Bool
    let isEditing: Bool
    
    @State private var isNotesExpanded = false
    @State private var showRepRangeEditor = false
    @State private var showRestTimeEditor = false
    
    init(exercise: WorkoutExercise, showRestTimerSheet: Binding<Bool>, isEditing: Bool = false) {
        self.exercise = exercise
        _showRestTimerSheet = showRestTimerSheet
        self.isEditing = isEditing

        _previousExercise = Query(WorkoutExercise.lastCompleted(for: exercise))
    }
    
    private var previousSets: [ExerciseSet] {
        previousExercise.first?.sortedSets ?? []
    }
    
    private func previousSetSnapshot(for index: Int) -> PreviousSetSnapshot? {
        guard index < previousSets.count else { return nil }
        let set = previousSets[index]
        return PreviousSetSnapshot(reps: set.reps, weight: set.weight)
    }
    
    var body: some View {
        GeometryReader { geometry in
            let fieldWidth = geometry.size.width / (isEditing ? 3 : 5)
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
                        if !isEditing {
                            Text("Previous")
                            Text(" ")
                        }
                    }
                    .font(.title3)
                    .bold()
                    .accessibilityHidden(true)
                    
                    ForEach(exercise.sortedSets) { set in
                        GridRow {
                            ExerciseSetRowView(set: set, exercise: exercise, showRestTimerSheet: $showRestTimerSheet, previousSetSnapshot: previousSetSnapshot(for: set.index), fieldWidth: fieldWidth, isEditing: isEditing)
                        }
                        .font(.title3)
                        .fontWeight(.semibold)
                    }
                }
                .padding(.vertical)
                .padding(.leading, isEditing ? 15 : 0)
                
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
        }
    }
    
    private func addSet() {
        Haptics.selection()
        exercise.addSet(complete: isEditing)
        saveContext(context: context)
    }

}

#Preview {
    @Previewable @State var showRestTimerSheet = false
    ExerciseView(exercise: sampleIncompleteWorkout().sortedExercises.first!, showRestTimerSheet: $showRestTimerSheet, isEditing: true)
        .sampleDataContainerIncomplete()
        .environment(RestTimerState())
}
