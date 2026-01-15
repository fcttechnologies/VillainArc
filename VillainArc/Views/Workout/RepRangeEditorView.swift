import SwiftUI

struct RepRangeEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var repRange: RepRange
    
    @State private var mode: RepRangeMode = .notSet
    @State private var target: Int = 8
    @State private var lower: Int = 8
    @State private var upper: Int = 12
    @State private var showCancelConfirmation = false
    @State private var initialSnapshot = RepRangeSnapshot(mode: .notSet, target: 8, lower: 8, upper: 12)
    
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
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) {
                        if hasChanges {
                            showCancelConfirmation = true
                        } else {
                            dismiss()
                        }
                    }
                    .confirmationDialog("Discard rep range changes?", isPresented: $showCancelConfirmation) {
                        Button("Discard Changes", role: .destructive) {
                            dismiss()
                        }
                        Button("Cancel") {
                            showCancelConfirmation = false
                        }
                    } message: {
                        Text("Your edits will not be saved.")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        repRange = buildRepRange()
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadFromRepRange()
            }
            .onChange(of: lower) { _, newValue in
                if newValue > upper {
                    upper = newValue
                }
            }
        }
    }
    
    private var currentSnapshot: RepRangeSnapshot {
        RepRangeSnapshot(mode: mode, target: target, lower: lower, upper: upper)
    }
    
    private var hasChanges: Bool {
        currentSnapshot != initialSnapshot
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
        
        initialSnapshot = currentSnapshot
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

private struct RepRangeSnapshot: Equatable {
    let mode: RepRangeMode
    let target: Int
    let lower: Int
    let upper: Int
}

#Preview {
    ExerciseView(exercise: Workout.sampleData.first!.exercises.first!)
}
