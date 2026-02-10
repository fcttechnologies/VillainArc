import SwiftUI

struct RPEPickerView: View {
    @Binding var rpe: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                HStack(spacing: 12) {
                    ForEach([6, 7, 8, 9, 10], id: \.self) { value in
                        rpeCard(for: value)
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
            VStack(spacing: 6) {
                Text("\(value)")
                    .font(.title)
                Text(rpeLabel(value))
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
            .opacity(isSelected ? 1.0 : 0.6)
            .scaleEffect(isSelected ? 1.2 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.bouncy, value: rpe)
    }

    private func rpeLabel(_ value: Int) -> String {
        switch value {
        case 6: "4+ left"
        case 7: "3 left"
        case 8: "2 left"
        case 9: "1 left"
        case 10: "Max"
        default: ""
        }
    }
}
