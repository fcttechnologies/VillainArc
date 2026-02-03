import SwiftUI

struct MuscleFilterSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMuscles: Set<Muscle> = []
    @State private var showAdvanced = false
    let onConfirm: (Set<Muscle>) -> Void
    let showMinorMuscles: Bool

    init(selectedMuscles: Set<Muscle>, showMinorMuscles: Bool = false, onConfirm: @escaping (Set<Muscle>) -> Void) {
        _selectedMuscles = State(initialValue: selectedMuscles)
        self.showMinorMuscles = showMinorMuscles
        self.onConfirm = onConfirm
    }

    private var hasSelection: Bool {
        !selectedMuscles.isEmpty
    }

    private let chipSpacing: CGFloat = 6

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    FlowLayout(spacing: chipSpacing) {
                        ForEach(Muscle.allMajor, id: \.rawValue) { muscle in
                            muscleChip(for: muscle)
                        }
                    }
                    .padding()
                    .background(.ultraThickMaterial, in: .rect(cornerRadius: 20))

                    if showMinorMuscles {
                        VStack(spacing: 8) {
                            Button {
                                Haptics.selection()
                                showAdvanced.toggle()
                            } label: {
                                HStack {
                                    Text("Advanced")
                                        .font(.headline)
                                    Spacer()
                                    Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                                        .foregroundStyle(.secondary)
                                }
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)
                            .accessibilityIdentifier("muscleFilterAdvancedToggle")
                            .accessibilityLabel("Advanced muscles")
                            .accessibilityValue(showAdvanced ? "Expanded" : "Collapsed")
                            .accessibilityHint("Shows minor muscles.")

                            if showAdvanced {
                                FlowLayout(spacing: chipSpacing) {
                                    ForEach(minorMuscles, id: \.rawValue) { muscle in
                                        muscleChip(for: muscle)
                                    }
                                }
                                .padding()
                                .background(.ultraThickMaterial, in: .rect(cornerRadius: 20))
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Muscles")
            .navigationBarTitleDisplayMode(.inline)
            .animation(.bouncy, value: selectedMuscles)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if hasSelection {
                        Button("Clear") {
                            clearSelection()
                        }
                        .accessibilityIdentifier("muscleFilterClearButton")
                        .accessibilityHint("Clears all selected muscles.")
                    } else {
                        Button(role: .close) {
                            Haptics.selection()
                            dismiss()
                        }
                        .accessibilityLabel("Close")
                        .accessibilityIdentifier("muscleFilterCloseButton")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .confirm) {
                        Haptics.selection()
                        onConfirm(selectedMuscles)
                        dismiss()
                    }
                    .accessibilityLabel("Apply Filters")
                    .accessibilityIdentifier("muscleFilterConfirmButton")
                }
            }
            .accessibilityIdentifier("muscleFilterSheet")
        }
    }

    private func clearSelection() {
        selectedMuscles.removeAll()
        Haptics.selection()
    }

    private func toggleMuscle(_ muscle: Muscle) {
        if selectedMuscles.contains(muscle) {
            selectedMuscles.remove(muscle)
        } else {
            selectedMuscles.insert(muscle)
        }
        Haptics.selection()
    }

    private var minorMuscles: [Muscle] {
        Muscle.allCases.filter { !$0.isMajor }
    }

    @ViewBuilder
    private func muscleChip(for muscle: Muscle) -> some View {
        Button {
            toggleMuscle(muscle)
        } label: {
            Text(muscle.rawValue)
                .foregroundStyle(selectedMuscles.contains(muscle) ? .white : .primary)
                .lineLimit(1)
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(selectedMuscles.contains(muscle) ? Color.blue : Color(.systemGray5))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityIdentifiers.muscleFilterChip(muscle))
        .accessibilityLabel(muscle.rawValue)
        .accessibilityAddTraits(selectedMuscles.contains(muscle) ? .isSelected : [])
        .accessibilityHint("Toggles this muscle filter.")
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 12

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var maxRowWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let nextWidth = rowWidth == 0 ? size.width : rowWidth + spacing + size.width

            if nextWidth > maxWidth {
                totalHeight += rowHeight == 0 ? 0 : rowHeight + spacing
                maxRowWidth = max(maxRowWidth, rowWidth)
                rowWidth = size.width
                rowHeight = size.height
            } else {
                rowWidth = nextWidth
                rowHeight = max(rowHeight, size.height)
            }
        }

        totalHeight += rowHeight
        maxRowWidth = max(maxRowWidth, rowWidth)

        return CGSize(width: maxRowWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x != bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )

            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview("Muscle Filter Empty") {
    MuscleFilterSheetView(selectedMuscles: []) { _ in }
}

#Preview("Muscle Filter Selected") {
    MuscleFilterSheetView(selectedMuscles: [.chest, .back, .quads]) { _ in }
}

#Preview("Include minor muscles") {
    MuscleFilterSheetView(selectedMuscles: [], showMinorMuscles: true) { _ in }
}
