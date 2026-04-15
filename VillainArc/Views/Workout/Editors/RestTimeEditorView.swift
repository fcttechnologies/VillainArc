import SwiftUI
import SwiftData

struct RestTimeEditorView<ExerciseType: RestTimeEditable>: View {
    @Environment(\.modelContext) private var context
    @Bindable var exercise: ExerciseType

    @State private var expandedSetIndex: Int? = nil
    @State private var copiedSeconds: Int? = nil

    var body: some View {
        Form {
            Section {
                if exercise.sortedSets.isEmpty {
                    Text("Add sets first to change their rest times.")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier(AccessibilityIdentifiers.restTimeEmptySetsMessage)
                        .appGroupedListRow(position: .single)
                } else {
                    ForEach(exercise.sortedSets, id: \.index) { set in
                        restTimeRow(title: setTitle(for: set), seconds: restSecondsBinding(for: set), isExpanded: expandedSetIndex == set.index, toggle: { togglePicker(for: set.index) }, position: rowPosition(for: set.index))
                    }
                }
            } footer: {
                Text("If the next set is a drop set, rest time is skipped.")
            }
        }
        .listSectionSpacing(20)
        .navBar(title: "Set Rest Times") {
            CloseButton()
        }
        .scrollContentBackground(.hidden)
        .accessibilityIdentifier(AccessibilityIdentifiers.restTimeEditorForm)
        .onDisappear {
            saveContext(context: context)
        }
    }

    private func restSecondsBinding(for set: ExerciseType.SetType) -> Binding<Int> {
        Binding(
            get: { set.restSeconds },
            set: { set.restSeconds = $0 }
        )
    }

    @ViewBuilder
    private func restTimeRow(
        title: String,
        seconds: Binding<Int>,
        isExpanded: Bool,
        toggle: @escaping () -> Void,
        position: AppGroupedListRowPosition
    ) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                Spacer()
                Button {
                    toggle()
                } label: {
                    Text(secondsToTime(seconds.wrappedValue))
                        .fontWeight(.semibold)
                        .contentTransition(.numericText())
                        .sensoryFeedback(.selection, trigger: seconds.wrappedValue)
                }
                .buttonStyle(.borderless)
                .tint(.primary)
                .accessibilityIdentifier(AccessibilityIdentifiers.restTimeRowButton(title))
                .accessibilityLabel(title)
                .accessibilityValue(secondsToTime(seconds.wrappedValue))
                .accessibilityHint(AccessibilityText.restTimeRowHint)
                .contextMenu {
                    Button("Copy") {
                        copySeconds(seconds.wrappedValue)
                    }

                    if copiedSeconds != nil {
                        Button("Paste") {
                            pasteSeconds(into: seconds)
                        }
                    }
                }
                .accessibilityAction(named: AccessibilityText.copyActionLabel) {
                    copySeconds(seconds.wrappedValue)
                }
                .accessibilityAction(named: AccessibilityText.pasteActionLabel) {
                    pasteSeconds(into: seconds)
                }
            }

            if isExpanded {
                TimerDurationPicker(seconds: seconds, showZero: true)
                    .frame(height: 60)
                    .accessibilityIdentifier(AccessibilityIdentifiers.restTimeRowPicker(title))
            }
        }
        .appGroupedListRow(position: position)
        .onChange(of: seconds.wrappedValue) {
            scheduleSave(context: context)
        }
    }

    private func rowPosition(for setIndex: Int) -> AppGroupedListRowPosition {
        let indices = exercise.sortedSets.map(\.index)
        guard let first = indices.first, let last = indices.last else { return .single }
        if first == last { return .single }
        if setIndex == first { return .top }
        if setIndex == last { return .bottom }
        return .middle
    }

    private func togglePicker(for index: Int) {
        Haptics.selection()
        if expandedSetIndex == index {
            expandedSetIndex = nil
        } else {
            expandedSetIndex = index
        }
    }

    private func copySeconds(_ value: Int) {
        copiedSeconds = value
        Haptics.selection()
    }

    private func pasteSeconds(into binding: Binding<Int>) {
        guard let copiedSeconds else { return }
        binding.wrappedValue = copiedSeconds
        Haptics.selection()
    }

    private func setTitle(for set: ExerciseType.SetType) -> String {
        if set.type == .working {
            return "Set \(set.index + 1)"
        }

        return "Set \(set.index + 1) (\(set.type.displayName))"
    }
}

#Preview(traits: .sampleDataIncomplete) {
    RestTimeEditorView(exercise: sampleIncompleteSession().sortedExercises.first!)
}
