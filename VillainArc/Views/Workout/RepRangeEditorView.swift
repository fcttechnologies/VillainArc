import SwiftUI

struct RepRangeEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var repRange: RepRange

    @State private var mode: RepRangeMode = .notSet
    @State private var exact: Int = 8
    @State private var lower: Int = 8
    @State private var upper: Int = 12
    @State private var showCancelConfirmation = false
    @State private var initialSnapshot = RepRangeSnapshot(mode: .notSet, exact: 8, lower: 8, upper: 12)

    var body: some View {
        NavigationStack {
            Form {
                Section("Type") {
                    Picker("Rep Range", selection: $mode) {
                        ForEach(RepRangeMode.allCases) { mode in
                            Text(mode.displayName)
                                .tag(mode)
                        }
                    }
                }

                if mode == .exact {
                    Section("Values") {
                        Stepper("Reps: \(exact)", value: $exact, in: 1...200)
                    }
                } else if mode == .range {
                    Section("Values") {
                        Stepper("Lower: \(lower)", value: $lower, in: 1...200)
                        Stepper("Upper: \(upper)", value: $upper, in: lower...200)
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
        RepRangeSnapshot(mode: mode, exact: exact, lower: lower, upper: upper)
    }

    private var hasChanges: Bool {
        currentSnapshot != initialSnapshot
    }

    private func loadFromRepRange() {
        switch repRange {
        case .notSet:
            mode = .notSet
        case .untilFailure:
            mode = .untilFailure
        case .exact(let reps):
            mode = .exact
            exact = reps
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
        case .exact:
            return .exact(exact)
        case .range:
            return .range(lower: lower, upper: max(upper, lower))
        }
    }
}

private enum RepRangeMode: String, CaseIterable, Identifiable {
    case notSet
    case exact
    case range
    case untilFailure

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .notSet:
            return "Not Set"
        case .exact:
            return "Exact"
        case .range:
            return "Range"
        case .untilFailure:
            return "Until Failure"
        }
    }
}

private struct RepRangeSnapshot: Equatable {
    let mode: RepRangeMode
    let exact: Int
    let lower: Int
    let upper: Int
}

#Preview {
    ExerciseView(exercise: Workout.sampleData.first!.exercises.first!)
}
