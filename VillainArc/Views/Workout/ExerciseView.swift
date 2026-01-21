import SwiftUI
import SwiftData

struct ExerciseView: View {
    @Query private var exercises: [WorkoutExercise]
    @Environment(\.modelContext) private var context
    @Bindable var exercise: WorkoutExercise
    let isEditing: Bool
    
    @State private var isNotesExpanded = false
    @State private var showRepRangeEditor = false
    @State private var showRestTimeEditor = false
    
    init(exercise: WorkoutExercise, isEditing: Bool = false) {
        self.exercise = exercise
        self.isEditing = isEditing
        
        let name = exercise.name
        let predicate = #Predicate<WorkoutExercise> { exercise in
            exercise.name == name && exercise.workout.completed
        }
        _exercises = Query(filter: predicate, sort: \.date, order: .reverse)
    }
    
    private var previousSets: [ExerciseSet] {
        exercises.first?.sortedSets ?? []
    }
    
    private func previousSetDisplay(for index: Int) -> String {
        guard index < previousSets.count else { return "-" }
        let set = previousSets[index]
        return "\(set.reps)x\(Int(set.weight))"
    }
    
    var body: some View {
        GeometryReader { geometry in
            let fieldWidth = geometry.size.width / (isEditing ? 3 : 5)
            ScrollView {
                headerView
                    .padding(.horizontal)
                
                Grid(horizontalSpacing: 10, verticalSpacing: 12) {
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
                    
                    ForEach(exercise.sortedSets) { set in
                        GridRow {
                            ExerciseSetRowView(set: set, exercise: exercise, previousSetDisplay: previousSetDisplay(for: set.index), fieldWidth: fieldWidth, isEditing: isEditing)
                        }
                        .font(.title3)
                        .fontWeight(.semibold)
                        .animation(.bouncy, value: set.complete)
                    }
                }
                .padding(.vertical)
                .padding(.leading, isEditing ? 10 : 0)
                
                Button {
                    Haptics.impact(.light)
                    addSet()
                } label: {
                    Label("Add Set", systemImage: "plus")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .padding(.vertical, 5)
                }
                .buttonStyle(.glassProminent)
                .buttonSizing(.flexible)
                .padding(.horizontal)
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
                }
                Spacer()
                HStack(spacing: 12) {
                    Button("Notes", systemImage: isNotesExpanded ? "note.text" : "note.text.badge.plus") {
                        Haptics.selection()
                        withAnimation {
                            isNotesExpanded.toggle()
                        }
                    }
                    
                    Button("Rest Times", systemImage: "timer") {
                        Haptics.selection()
                        showRestTimeEditor = true
                    }
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
                        saveContext(context: context)
                    }
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
        exercise.addSet(complete: isEditing)
        saveContext(context: context)
    }

}

#Preview {
    ExerciseView(exercise: sampleWorkout().sortedExercises.first!, isEditing: false)
        .sampleDataConainer()
        .environment(RestTimerState())
}
