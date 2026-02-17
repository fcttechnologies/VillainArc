import SwiftUI
import SwiftData

struct RestTimeEditorView<ExerciseType: RestTimeEditable>: View {
    @AppStorage("autoStartRestTimer") private var autoStartRestTimer = true
    @Environment(\.modelContext) private var context
    @Bindable var exercise: ExerciseType

    @State private var expandedSetIndex: Int? = nil
    @State private var copiedSeconds: Int? = nil

    var body: some View {
        Form {
            Section {
                Toggle("Auto-Start Timer", isOn: $autoStartRestTimer)
                    .accessibilityIdentifier("restTimeAutoStartToggle")
            } footer: {
                Text("Starts a rest timer after completing a set.")
            }

            Section {
                if exercise.sortedSets.isEmpty {
                    Text("Add sets first to change their rest times.")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("restTimeEmptySetsMessage")
                } else {
                    ForEach(exercise.sortedSets, id: \.index) { set in
                        restTimeRow(
                            title: setTitle(for: set),
                            seconds: restSecondsBinding(for: set),
                            isExpanded: expandedSetIndex == set.index,
                            toggle: { togglePicker(for: set.index) }
                        )
                    }
                }
            } footer: {
                Text("If the next set is a drop set, rest time is skipped.")
            }
            .listRowSeparator(.hidden)
        }
        .listSectionSpacing(20)
        .navBar(title: "Set Rest Times") {
            CloseButton()
        }
        .accessibilityIdentifier("restTimeEditorForm")
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
        toggle: @escaping () -> Void
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
                .accessibilityHint("Shows duration picker.")
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
                .accessibilityAction(named: "Copy") {
                    copySeconds(seconds.wrappedValue)
                }
                .accessibilityAction(named: "Paste") {
                    pasteSeconds(into: seconds)
                }
            }

            if isExpanded {
                TimerDurationPicker(seconds: seconds, showZero: true)
                    .frame(height: 60)
                    .accessibilityIdentifier(AccessibilityIdentifiers.restTimeRowPicker(title))
            }
        }
        .onChange(of: seconds.wrappedValue) {
            scheduleSave(context: context)
        }
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

#Preview {
    RestTimeEditorView(exercise: sampleIncompleteSession().sortedExercises.first!)
        .sampleDataContainerIncomplete()
}
