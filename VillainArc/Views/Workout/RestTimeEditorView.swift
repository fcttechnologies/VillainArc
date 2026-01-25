import SwiftUI

struct RestTimeEditorView<E: RestTimeEditable>: View {
    @AppStorage("autoStartRestTimer") private var autoStartRestTimer = true
    @Environment(\.modelContext) private var context
    @Bindable var exercise: E
    
    @State private var showAdvancedByType = false
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
                case .byType:
                    restTimeRow(title: "Warm Up Sets", seconds: policyBinding(\.warmupSeconds), isExpanded: expandedPicker == .warmup, toggle: { togglePicker(.warmup) })
                    
                    restTimeRow(title: "Normal Sets", seconds: policyBinding(\.regularSeconds), isExpanded: expandedPicker == .regular, toggle: { togglePicker(.regular) })
                    
                    DisclosureGroup("Advanced", isExpanded: $showAdvancedByType) {
                        restTimeRow(title: "Super Sets", seconds: policyBinding(\.superSetSeconds), isExpanded: expandedPicker == .superSet, toggle: { togglePicker(.superSet) })
                        
                        restTimeRow(title: "Drop Sets", seconds: policyBinding(\.dropSetSeconds), isExpanded: expandedPicker == .dropSet, toggle: { togglePicker(.dropSet) })
                        
                        restTimeRow(title: "Failure Sets", seconds: policyBinding(\.failureSeconds), isExpanded: expandedPicker == .failure, toggle: { togglePicker(.failure) })
                    }
                    .accessibilityIdentifier("restTimeAdvancedDisclosure")
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
        .onChange(of: showAdvancedByType) {
            Haptics.selection()
            if !showAdvancedByType {
                if let picker = expandedPicker, isAdvancedPicker(picker) {
                    expandedPicker = nil
                }
            }
        }
        .onDisappear {
            saveContext(context: context)
        }
    }
    
    private func policyBinding(_ keyPath: ReferenceWritableKeyPath<RestTimePolicy, Int>) -> Binding<Int> {
        Binding(
            get: { restTimePolicy[keyPath: keyPath] },
            set: { restTimePolicy[keyPath: keyPath] = $0 }
        )
    }
    
    private func restSecondsBinding(for set: E.SetType) -> Binding<Int> {
        Binding(
            get: { set.restSeconds },
            set: { set.restSeconds = $0 }
        )
    }
    
    private var modeFooterText: String {
        switch restTimePolicy.activeMode {
        case .allSame:
            return "All sets will use the same rest time."
        case .byType:
            return "Rest time for each set will be based on the set's type."
        case .individual:
            return "Each set keeps its own rest time."
        }
    }
    
    private func collapsePickers() {
        showAdvancedByType = false
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
        
        if isAdvancedPicker(picker) {
            showAdvancedByType = true
        }
        
        if case .individual = picker {
            showAdvancedByType = false
        }
    }
    
    private func isAdvancedPicker(_ picker: RestTimePicker) -> Bool {
        switch picker {
        case .superSet, .dropSet, .failure:
            return true
        case .allSame, .warmup, .regular, .individual:
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
    
    private func individualSetTitle(for set: E.SetType) -> String {
        if set.type == .regular {
            return "Set \(set.index + 1)"
        }
        
        return "Set \(set.index + 1) (\(set.type.rawValue))"
    }

    private enum RestTimePicker: Equatable {
        case allSame
        case warmup
        case regular
        case superSet
        case dropSet
        case failure
        case individual(Int)
    }
}

#Preview {
    RestTimeEditorView(exercise: sampleIncompleteWorkout().sortedExercises.first!)
        .sampleDataContainerIncomplete()
        .environment(RestTimerState())
}
