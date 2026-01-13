import SwiftUI
import SwiftData

struct ExerciseSetRowView: View {
    @Bindable var set: ExerciseSet
    @Bindable var exercise: WorkoutExercise
    @Environment(\.modelContext) private var context
    
    let previousSetDisplay: String
    let fieldWidth: CGFloat
    
    var body: some View {
        Menu {
            Picker("", selection: $set.type) {
                ForEach(ExerciseSetType.allCases, id: \.self) { type in
                    Text(type.rawValue)
                        .tag(type)
                }
            }
            Divider()
            Button("Delete Set", systemImage: "trash", role: .destructive) {
                deleteSet()
            }
        } label: {
            Text(set.type == .regular ? String(set.index + 1) : set.type.shortLabel)
                .foregroundStyle(set.type.tintColor)
                .frame(width: 40, height: 40)
                .glassEffect(.regular, in: .circle)
        }
        
        TextField("Reps", value: $set.reps, format: .number)
            .keyboardType(.numberPad)
            .frame(width: fieldWidth)
        TextField("Weight", value: $set.weight, format: .number)
            .keyboardType(.decimalPad)
            .frame(width: fieldWidth)
        Text(previousSetDisplay)
            .lineLimit(1)
            .frame(width: fieldWidth)
        
        if set.complete {
            Button {
                set.complete = false
            } label: {
                Image(systemName: "checkmark")
                    .padding(2)
            }
            .buttonBorderShape(.circle)
            .buttonStyle(.glassProminent)
            .tint(.green)
        } else {
            Button {
                set.complete = true
            } label: {
                Image(systemName: "checkmark")
                    .padding(2)
            }
            .buttonBorderShape(.circle)
            .buttonStyle(.glass)
            .tint(.primary)
        }
    }
    
    private func deleteSet() {
        exercise.removeSet(set)
        context.delete(set)
    }
}

#Preview {
    ExerciseView(exercise: Workout.sampleData.first!.exercises.first!)
}
