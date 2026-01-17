import SwiftUI

struct RepRangeEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var repRange: RepRangePolicy
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $repRange.activeMode) {
                        ForEach(RepRangeMode.allCases, id: \.self) { mode in
                            Text(mode.displayName)
                                .tag(mode)
                        }
                    }
                } footer: {
                    Text(modeFooterText)
                }
                
                Section {
                    if repRange.activeMode == .target {
                        Stepper("Target: \(repRange.targetReps)", value: $repRange.targetReps, in: 1...200)
                    } else if repRange.activeMode == .range {
                        Stepper("Lower: \(repRange.lowerRange)", value: $repRange.lowerRange, in: 1...200)
                        Stepper("Upper: \(repRange.upperRange)", value: $repRange.upperRange, in: (repRange.lowerRange + 1)...200)
                    }
                } footer: {
                    if repRange.activeMode == .target || repRange.activeMode == .range {
                        Text(repGuidanceFooterText)
                    }
                }
            }
            .navigationTitle("Rep Range")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        Haptics.success()
                        saveContext(context: context)
                        dismiss()
                    }
                }
            }
            .onChange(of: repRange.activeMode) { _, _ in
                Haptics.selection()
            }
            .onChange(of: repRange.lowerRange) { _, newValue in
                if newValue > repRange.upperRange {
                    repRange.upperRange = newValue
                }
            }
        }
    }
    
    private var modeFooterText: String {
        switch repRange.activeMode {
        case .notSet:
            return "No rep goal is stored for this exercise."
        case .target:
            return "Set a single rep goal, like 8."
        case .range:
            return "Set a rep range, like 8-12."
        case .untilFailure:
            return "Use when every set is taken to failure."
        }
    }
    
    private var repGuidanceFooterText: String {
        """
        Common targets:
        Powerlifting 1-3 reps
        Strength 3-6 reps
        Hypertrophy 6-12 reps
        Endurance 12-20+ reps
        """
    }
}

#Preview {
    ExerciseView(exercise: Workout.sampleData.first!.exercises.first!)
}
