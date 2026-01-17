import SwiftUI
import SwiftData

struct ExerciseView: View {
    @Query private var exercises: [WorkoutExercise]
    @Environment(\.modelContext) private var context
    @Bindable var exercise: WorkoutExercise
    @State private var isNotesExpanded = false
    @State private var showRepRangeEditor = false
    @State private var showRestTimeEditor = false
    
    init(exercise: WorkoutExercise) {
        self.exercise = exercise
        
        let name = exercise.name
        let predicate = #Predicate<WorkoutExercise> { exercise in
            exercise.name == name && exercise.workout?.completed == true
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
            ScrollView {
                headerView
                    .padding(.horizontal)
                
                if !exercise.sets.isEmpty {
                    Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                        GridRow {
                            Text("Set")
                            Text("Reps")
                                .gridColumnAlignment(.leading)
                            Text("Weight")
                                .gridColumnAlignment(.leading)
                            Text("Previous")
                            Text(" ")
                        }
                        .font(.title3)
                        .bold()
                        
                        ForEach(exercise.sortedSets) { set in
                            GridRow {
                                ExerciseSetRowView(set: set, exercise: exercise, previousSetDisplay: previousSetDisplay(for: set.index), fieldWidth: geometry.size.width / 5)
                            }
                            .font(.title3)
                            .fontWeight(.semibold)
                            .animation(.bouncy, value: set.complete)
                        }
                    }
                    .padding(.vertical)
                }
                
                Button {
                    Haptics.impact(.light)
                    addSet()
                } label: {
                    Label("Add Set", systemImage: "plus")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .padding(.vertical, 5)
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.glassProminent)
                .buttonSizing(.flexible)
                .padding(.horizontal)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.immediately)
            .dynamicTypeSize(...DynamicTypeSize.large)
        }
    }
    
    var headerView: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(exercise.name)
                        .font(.title3)
                        .bold()
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
                    Button("Rest Times", systemImage: "timer") {
                        Haptics.selection()
                        showRestTimeEditor = true
                    }
                    .labelStyle(.iconOnly)
                    .font(.title2)
                    .tint(.primary)
                    
                    Button("Notes", systemImage: isNotesExpanded ? "note.text" : "note.text.badge.plus") {
                        Haptics.selection()
                        withAnimation {
                            isNotesExpanded.toggle()
                        }
                    }
                    .labelStyle(.iconOnly)
                    .font(.title)
                    .tint(.primary)
                }
            }
            
            if isNotesExpanded {
                TextField("Notes", text: $exercise.notes, axis: .vertical)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .sheet(isPresented: $showRepRangeEditor) {
            RepRangeEditorView(repRange: exercise.repRange)
                .interactiveDismissDisabled()
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showRestTimeEditor) {
            RestTimeEditorView(exercise: exercise)
                .interactiveDismissDisabled()
                .presentationDetents([.fraction(0.75), .large])
        }
    }
    
    private func addSet() {
        exercise.addSet()
        saveContext(context: context)
    }
}

#Preview {
    ExerciseView(exercise: Workout.sampleData.first!.exercises.first!)
}
