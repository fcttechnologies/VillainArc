import SwiftUI

struct RepRangeButton: View {
    @Bindable var repRange: RepRangePolicy
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            Text(repRange.displayText)
                .fontWeight(.semibold)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(AccessibilityText.repRangeButtonLabel)
        .accessibilityValue(repRange.displayText)
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityHint(AccessibilityText.repRangeButtonHint)
    }
}
