import SwiftUI

struct WorkoutEffortPromptView: View {
    @Binding var selectedEffort: Int
    let onClose: () -> Void
    let onSkip: () -> Void
    let onConfirm: () -> Void

    private let scaleGroups: [(label: String, range: String)] = [
        ("1-2", "Very easy"),
        ("3-4", "Light"),
        ("5-6", "Moderate"),
        ("7-8", "Hard"),
        ("9", "Near max"),
        ("10", "Absolute max")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How hard was this workout?")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text(promptDescription)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier(AccessibilityIdentifiers.workoutFinishEffortSelectionSummary)
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                        ForEach(1...10, id: \.self) { value in
                            effortCard(for: value)
                        }
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                        ForEach(scaleGroups, id: \.label) { group in
                            HStack(alignment: .top, spacing: 10) {
                                Text(group.label)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .frame(width: 32, alignment: .leading)
                                Text(group.range)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .fontDesign(.rounded)
                .padding()
            }
            .navigationTitle("Workout Effort")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", systemImage: "xmark", action: onClose)
                        .labelStyle(.iconOnly)
                        .accessibilityIdentifier(AccessibilityIdentifiers.workoutFinishEffortCloseButton)
                        .accessibilityHint(AccessibilityText.workoutFinishEffortCloseHint)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if (1...10).contains(selectedEffort) {
                        Button("Confirm", action: onConfirm)
                            .fontWeight(.semibold)
                            .accessibilityIdentifier(AccessibilityIdentifiers.workoutFinishEffortConfirmButton)
                            .accessibilityHint(AccessibilityText.workoutFinishEffortConfirmHint)
                    } else {
                        Button("Skip", action: onSkip)
                            .accessibilityIdentifier(AccessibilityIdentifiers.workoutFinishEffortSkipButton)
                            .accessibilityHint(AccessibilityText.workoutFinishEffortSkipHint)
                    }
                }
            }
        }
        .presentationDetents([.fraction(0.52)])
        .presentationBackground(Color(.systemBackground))
        .accessibilityIdentifier(AccessibilityIdentifiers.workoutFinishEffortSheet)
    }

    private var promptDescription: String {
        if (1...10).contains(selectedEffort) {
            return workoutEffortDescription(selectedEffort)
        }
        return "On a scale from 1 to 10, how hard was this workout?"
    }

    private func effortCard(for value: Int) -> some View {
        let isSelected = selectedEffort == value

        return Button {
            Haptics.selection()
            selectedEffort = isSelected ? 0 : value
        } label: {
            Text("\(value)")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10))
                .opacity(isSelected ? 1.0 : 0.6)
                .scaleEffect(isSelected ? 1.1 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityIdentifiers.workoutFinishEffortCard(value))
        .accessibilityLabel(AccessibilityText.workoutSummaryEffortLabel(value: value))
        .accessibilityValue(AccessibilityText.workoutSummaryEffortValue(value: value, isSelected: isSelected))
        .accessibilityHint(AccessibilityText.workoutFinishEffortCardHint)
    }
}
