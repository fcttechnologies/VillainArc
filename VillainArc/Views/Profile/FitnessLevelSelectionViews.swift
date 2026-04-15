import SwiftUI

struct FitnessLevelSelectionList: View {
    @Binding var selection: FitnessLevel?
    var warningLevel: FitnessLevel? = nil

    var body: some View {
        VStack(spacing: 12) {
            ForEach(FitnessLevel.allCases, id: \.self) { option in
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
                    .accessibilityHint(AccessibilityText.onboardingFitnessLevelOptionHint)
                    .accessibilityValue(AccessibilityText.onboardingFitnessLevelOptionValue(isSelected: true))
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
                    .accessibilityHint(AccessibilityText.onboardingFitnessLevelOptionHint)
                    .accessibilityValue(AccessibilityText.onboardingFitnessLevelOptionValue(isSelected: false))
                }
            }
        }
    }

    private func optionLabel(for option: FitnessLevel) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                if warningLevel == option {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.yellow)
                        .accessibilityHidden(true)
                }

                Text(option.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
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
