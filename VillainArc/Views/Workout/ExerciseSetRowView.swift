import SwiftUI
import SwiftData

struct ExerciseSetRowView: View {
    @Bindable var set: ExerciseSet
    @Bindable var exercise: WorkoutExercise
    @Environment(\.modelContext) private var context
    @Environment(RestTimerState.self) private var restTimer
    @AppStorage("autoStartRestTimer") private var autoStartRestTimer = true
    @State private var showOverrideTimerAlert = false
    
    let previousSetDisplay: String
    let fieldWidth: CGFloat
    
    var body: some View {
        Group {
            Menu {
                Picker("", selection: Binding(get: { set.type }, set: { newValue in
                    let oldValue = set.type
                    set.type = newValue
                    if newValue != oldValue {
                        Haptics.selection()
                        saveContext(context: context)
                    }
                })) {
                    ForEach(ExerciseSetType.allCases, id: \.self) { type in
                        Text(type.rawValue)
                            .tag(type)
                    }
                }
                Divider()
                if exercise.sets.count > 1 {
                    Button("Delete Set", systemImage: "trash", role: .destructive) {
                        deleteSet()
                    }
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
                    saveContext(context: context)
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
                    handleAutoStartTimer()
                    saveContext(context: context)
                } label: {
                    Image(systemName: "checkmark")
                        .padding(2)
                }
                .buttonBorderShape(.circle)
                .buttonStyle(.glass)
                .tint(.primary)
            }
        }
        .alert("Replace Rest Timer?", isPresented: $showOverrideTimerAlert) {
            Button("Replace", role: .destructive) {
                let restSeconds = set.effectiveRestSeconds
                if restSeconds > 0 {
                    restTimer.start(seconds: restSeconds)
                    RestTimeHistory.record(seconds: restSeconds, context: context)
                    saveContext(context: context)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Start a new timer for \(secondsToTime(set.effectiveRestSeconds))?")
        }
    }
    
    private func deleteSet() {
        Haptics.warning()
        exercise.removeSet(set)
        context.delete(set)
        saveContext(context: context)
    }
    
    private func handleAutoStartTimer() {
        guard autoStartRestTimer else { return }
        let restSeconds = set.effectiveRestSeconds
        guard restSeconds > 0 else { return }
        
        if restTimer.isActive {
            showOverrideTimerAlert = true
        } else {
            restTimer.start(seconds: restSeconds)
            RestTimeHistory.record(seconds: restSeconds, context: context)
            saveContext(context: context)
        }
    }

}

#Preview {
    ExerciseView(exercise: sampleWorkout().sortedExercises.first!)
        .sampleDataConainer()
        .environment(RestTimerState())
}
