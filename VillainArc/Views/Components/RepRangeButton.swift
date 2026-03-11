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
        .accessibilityLabel("Rep range")
        .accessibilityValue(repRange.displayText)
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityHint("Edits the rep range.")
    }
}
