import SwiftUI

struct WorkoutEffortPromptView: View {
    @Binding var selectedEffort: Int
    let onClose: () -> Void
    let onSkip: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .center, spacing: 2) {
                    Text("How hard was this workout?")
                        .font(.title2)
                        .bold()
                    Text("Drag or tap the dial to rate the overall effort.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                Spacer()
                ZStack {
                    WorkoutEffortInteractiveDial(selection: $selectedEffort, size: 280, lineWidth: 24, showsScaleLabels: true, markerAccessibilityIdentifier: AccessibilityIdentifiers.workoutFinishEffortCard, markerAccessibilityHint: AccessibilityText.workoutFinishEffortCardHint)

                    VStack(spacing: 4) {
                        if (1...10).contains(selectedEffort) {
                            Text("\(selectedEffort)")
                                .font(.system(size: 64, weight: .bold, design: .rounded))

                            Text(workoutEffortTitle(selectedEffort))
                                .font(.title3)
                                .fontWeight(.bold)

                            Text(workoutEffortDescription(selectedEffort))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        } else {
                            Text("Drag to Rate")
                                .font(.title3)
                                .fontWeight(.bold)

                            Text("Your effort score and description will appear here.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(width: 190)
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutFinishEffortSelectionSummary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
                if (1...10).contains(selectedEffort) {
                    Button{
                        Haptics.selection()
                        selectedEffort = 0
                    } label: {
                        Text("Clear")
                            .fontWeight(.semibold)
                            .font(.title3)
                            .padding(.vertical, 4)
                    }
                    .buttonSizing(.flexible)
                    .buttonStyle(.glass)
                }

            }
            .fontDesign(.rounded)
            .padding(.horizontal)
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
        .presentationDetents([.fraction(0.62)])
        .presentationBackground(Color(.systemBackground))
        .accessibilityIdentifier(AccessibilityIdentifiers.workoutFinishEffortSheet)
    }
}
