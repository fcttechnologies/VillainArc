import SwiftUI

struct RestTimeEditorView<ExerciseType: RestTimeEditable>: View {
    @AppStorage("autoStartRestTimer") private var autoStartRestTimer = true
    @Environment(\.modelContext) private var context
    @Bindable var exercise: ExerciseType
    
    @State private var expandedPicker: RestTimePicker? = nil
    @State private var copiedSeconds: Int? = nil
    
    private var restTimePolicy: RestTimePolicy {
        exercise.restTimePolicy
    }
    
    var body: some View {
        Form {
            Section {
                Toggle("Auto-Start Timer", isOn: $autoStartRestTimer)
                    .accessibilityIdentifier("restTimeAutoStartToggle")
            } footer: {
                Text("Starts a rest timer after completing a set, based on the mode and times below.")
            }
            
            Section {
                Picker("Mode", selection: $exercise.restTimePolicy.activeMode) {
                    ForEach(RestTimeMode.allCases, id: \.self) { mode in
                        Text(mode.displayName)
                            .tag(mode)
                    }
                }
                .accessibilityIdentifier("restTimeModePicker")
            } footer: {
                Text(modeFooterText)
            }
            
            Section {
                switch restTimePolicy.activeMode {
                case .allSame:
                    restTimeRow(title: "Rest Time", seconds: policyBinding(\.allSameSeconds), isExpanded: expandedPicker == .allSame, toggle: { togglePicker(.allSame) })
                case .individual:
                    if exercise.sortedSets.isEmpty {
                        Text("Add sets first to change their rest times.")
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("restTimeEmptySetsMessage")
                    } else {
                        ForEach(exercise.sortedSets, id: \.index) { set in
                            restTimeRow(title: individualSetTitle(for: set), seconds: restSecondsBinding(for: set), isExpanded: expandedPicker == .individual(set.index), toggle: { togglePicker(.individual(set.index)) })
                        }
                    }
                case .byType:
                    restTimeRow(title: "Warm Up Sets", seconds: policyBinding(\.warmupSeconds), isExpanded: expandedPicker == .warmup, toggle: { togglePicker(.warmup) })
                    
                    restTimeRow(title: "Working Sets", seconds: policyBinding(\.workingSeconds), isExpanded: expandedPicker == .working, toggle: { togglePicker(.working) })
                    
                        
                    restTimeRow(title: "Drop Sets", seconds: policyBinding(\.dropSetSeconds), isExpanded: expandedPicker == .dropSet, toggle: { togglePicker(.dropSet) })
                }
            } footer: {
                Text("If you complete a set but the next set is a super or drop set, the rest time will be skipped.")
            }
            .listRowSeparator(.hidden)
        }
        .navBar(title: "Set Rest Times") {
            CloseButton()
        }
        .accessibilityIdentifier("restTimeEditorForm")
        .onChange(of: restTimePolicy.activeMode) {
            Haptics.selection()
            collapsePickers()
            saveContext(context: context)
        }
        .onDisappear {
            saveContext(context: context)
        }
    }
    
    private func policyBinding(_ keyPath: ReferenceWritableKeyPath<RestTimePolicy, Int>) -> Binding<Int> {
        Binding(get: { restTimePolicy[keyPath: keyPath] }, set: { restTimePolicy[keyPath: keyPath] = $0 })
    }
    
    private func restSecondsBinding(for set: ExerciseType.SetType) -> Binding<Int> {
        Binding(get: { set.restSeconds }, set: { set.restSeconds = $0 })
    }
    
    private var modeFooterText: String {
        switch restTimePolicy.activeMode {
        case .allSame:
            return "All sets will use the same rest time."
        case .individual:
            return "Each set keeps its own rest time."
        case .byType:
            return "Rest time for each set will be based on the set's type."
        }
    }
    
    private func collapsePickers() {
        expandedPicker = nil
    }
    
    @ViewBuilder
    private func restTimeRow(title: String, seconds: Binding<Int>, isExpanded: Bool, toggle: @escaping () -> Void) -> some View {
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
    
    private func togglePicker(_ picker: RestTimePicker) {
        Haptics.selection()
        if expandedPicker == picker {
            expandedPicker = nil
        } else {
            expandedPicker = picker
        }
    }
    
    private func isAdvancedPicker(_ picker: RestTimePicker) -> Bool {
        switch picker {
        case .dropSet:
            return true
        case .allSame, .warmup, .working, .individual:
            return false
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
    
    private func individualSetTitle(for set: ExerciseType.SetType) -> String {
        if set.type == .working {
            return "Set \(set.index + 1)"
        }
        
        return "Set \(set.index + 1) (\(set.type.displayName))"
    }

    private enum RestTimePicker: Equatable {
        case allSame
        case warmup
        case working
        case dropSet
        case individual(Int)
    }
}

#Preview {
    RestTimeEditorView(exercise: sampleIncompleteSession().sortedExercises.first!)
        .sampleDataContainerIncomplete()
}
