import SwiftUI

struct WorkoutEffortPromptView: View {
    @Binding var selectedEffort: Int
    let onClose: () -> Void
    let onSkip: () -> Void
    let onConfirm: () -> Void
    @ScaledMetric(relativeTo: .largeTitle) private var selectedScoreFontSize: CGFloat = 64

    private var hasSelection: Bool {
        (1...10).contains(selectedEffort)
    }

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
                        if hasSelection {
                            Text("\(selectedEffort)")
                                .font(.system(size: selectedScoreFontSize, weight: .bold, design: .rounded))
                                .minimumScaleFactor(0.7)

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
                if hasSelection {
                    Button(action: onConfirm) {
                        Text("Finish")
                            .fontWeight(.semibold)
                            .font(.title3)
                            .padding(.vertical, 4)
                    }
                    .buttonSizing(.flexible)
                    .buttonStyle(.glassProminent)
                    .accessibilityIdentifier(AccessibilityIdentifiers.workoutFinishEffortConfirmButton)
                    .accessibilityHint(AccessibilityText.workoutFinishEffortConfirmHint)
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
                    if hasSelection {
                        Button("Clear") {
                            Haptics.selection()
                            selectedEffort = 0
                        }
                            .fontWeight(.semibold)
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
