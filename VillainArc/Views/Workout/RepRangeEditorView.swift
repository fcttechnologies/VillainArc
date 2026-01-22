import SwiftUI

struct RepRangeEditorView: View {
    @Environment(\.modelContext) private var context
    @Bindable var repRange: RepRangePolicy
    
    private var mode: RepRangeMode {
        repRange.activeMode
    }
    
    var body: some View {
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
                    if mode == .target {
                        Stepper("Target: \(repRange.targetReps)", value: $repRange.targetReps, in: 1...200)
                    } else if mode == .range {
                        Stepper("Lower: \(repRange.lowerRange)", value: $repRange.lowerRange, in: 1...200)
                        Stepper("Upper: \(repRange.upperRange)", value: $repRange.upperRange, in: (repRange.lowerRange + 1)...200)
                    }
                } footer: {
                    if mode == .target || mode == .range {
                        Text(repGuidanceFooterText)
                    }
                }
            }
            .navBar(title: "Rep Range") {
                CloseButton()
            }
            .onChange(of: mode) {
                Haptics.selection()
                saveContext(context: context)
            }
            .onChange(of: repRange.lowerRange) { _, newValue in
                if newValue > repRange.upperRange {
                    repRange.upperRange = newValue
                }
                Haptics.selection()
                scheduleSave(context: context)
            }
            .onChange(of: repRange.upperRange) {
                Haptics.selection()
                scheduleSave(context: context)
            }
            .onChange(of: repRange.targetReps) {
                Haptics.selection()
                scheduleSave(context: context)
            }
            .onDisappear {
                saveContext(context: context)
            }
    }
    
    private var modeFooterText: String {
        switch mode {
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
    ExerciseView(exercise: sampleIncompleteWorkout().sortedExercises.first!)
        .sampleDataContainerIncomplete()
        .environment(RestTimerState())
}
