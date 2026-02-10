import SwiftUI

struct RPEPickerView: View {
    @Binding var rpe: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text(rpeDescription(rpe))
                        .font(.headline)
                        .fontWeight(.semibold)

                    HStack(spacing: 12) {
                        ForEach([6, 7, 8, 9, 10], id: \.self) { value in
                            rpeCard(for: value)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("RPE")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if rpe > 0 {
                        Button("Clear") {
                            Haptics.selection()
                            rpe = 0
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
            }
        }
    }

    private func rpeCard(for value: Int) -> some View {
        let isSelected = rpe == value

        return Button {
            Haptics.selection()
            rpe = value
        } label: {
            Text("\(value)")
                .font(.title)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 8)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                .opacity(isSelected ? 1.0 : 0.6)
                .scaleEffect(isSelected ? 1.2 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.bouncy, value: isSelected)
    }

    private func rpeDescription(_ value: Int) -> String {
        switch value {
        case 6: "You could perform 4 or more reps."
        case 7: "You could perform 3 more reps."
        case 8: "You could perform 2 more reps."
        case 9: "You could perform 1 more rep."
        case 10: "No more reps possible."
        default: " "
        }
    }
}

#Preview {
    @Previewable @State var rpe: Int = 0
    RPEPickerView(rpe: $rpe)
}
