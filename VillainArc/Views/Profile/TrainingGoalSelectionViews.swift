import SwiftUI

struct TrainingGoalSelectionList: View {
    @Binding var selection: TrainingGoalKind?

    var body: some View {
        VStack(spacing: 12) {
            ForEach(TrainingGoalKind.allCases, id: \.self) { option in
                if selection == option {
                    Button {
                        selection = option
                        Haptics.selection()
                    } label: {
                        optionLabel(for: option)
                    }
                    .buttonSizing(.flexible)
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 16))
                    .accessibilityHint(AccessibilityText.onboardingTrainingGoalOptionHint)
                    .accessibilityValue(AccessibilityText.onboardingTrainingGoalOptionValue(isSelected: true))
                        .accessibilityAddTraits(.isSelected)
                } else {
                    Button {
                        selection = option
                        Haptics.selection()
                    } label: {
                        optionLabel(for: option)
                    }
                    .buttonSizing(.flexible)
                    .buttonStyle(.glass)
                    .buttonBorderShape(.roundedRectangle(radius: 16))
                    .accessibilityHint(AccessibilityText.onboardingTrainingGoalOptionHint)
                    .accessibilityValue(AccessibilityText.onboardingTrainingGoalOptionValue(isSelected: false))
                }
            }
        }
    }

    private func optionLabel(for option: TrainingGoalKind) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(option.title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(option.detail)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
    }
}
