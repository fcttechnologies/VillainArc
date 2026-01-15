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
            Picker("", selection: Binding(get: { set.type }, set: { newValue in
                let oldValue = set.type
                set.type = newValue
                if newValue != oldValue {
                    Haptics.selection()
                }
            })) {
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
                Haptics.selection()
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
                Haptics.success()
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
        Haptics.warning()
        exercise.removeSet(set)
        context.delete(set)
    }
}

#Preview {
    ExerciseView(exercise: Workout.sampleData.first!.exercises.first!)
}
