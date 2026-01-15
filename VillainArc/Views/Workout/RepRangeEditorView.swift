import SwiftUI

struct RepRangeEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Binding var repRange: RepRange
    
    @State private var mode: RepRangeMode = .notSet
    @State private var target: Int = 8
    @State private var lower: Int = 8
    @State private var upper: Int = 12
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $mode) {
                        ForEach(RepRangeMode.allCases) { mode in
                            Text(mode.displayName)
                                .tag(mode)
                        }
                    }
                } footer: {
                    Text(modeFooterText)
                }
                
                Section {
                    if mode == .target {
                        Stepper("Target: \(target)", value: $target, in: 1...200)
                    } else if mode == .range {
                        Stepper("Lower: \(lower)", value: $lower, in: 1...200)
                        Stepper("Upper: \(upper)", value: $upper, in: lower...200)
                    }
                } footer: {
                    if mode == .target || mode == .range {
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
                        applyChanges()
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadFromRepRange()
            }
            .onChange(of: mode) { _, _ in
                Haptics.selection()
            }
            .onChange(of: lower) { _, newValue in
                if newValue > upper {
                    upper = newValue
                }
            }
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
    
    private func loadFromRepRange() {
        switch repRange {
        case .notSet:
            mode = .notSet
        case .untilFailure:
            mode = .untilFailure
        case .target(let reps):
            mode = .target
            target = reps
        case .range(let lower, let upper):
            mode = .range
            self.lower = lower
            self.upper = max(upper, lower)
        }
    }
    
    private func buildRepRange() -> RepRange {
        switch mode {
        case .notSet:
            return .notSet
        case .untilFailure:
            return .untilFailure
        case .target:
            return .target(target)
        case .range:
            return .range(lower: lower, upper: max(upper, lower))
        }
    }
    
    private func applyChanges() {
        repRange = buildRepRange()
        saveContext(context: context)
    }
}

private enum RepRangeMode: String, CaseIterable, Identifiable {
    case notSet
    case target
    case range
    case untilFailure
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .notSet:
            return "Not Set"
        case .target:
            return "Target"
        case .range:
            return "Range"
        case .untilFailure:
            return "Until Failure"
        }
    }
}

#Preview {
    ExerciseView(exercise: Workout.sampleData.first!.exercises.first!)
}
