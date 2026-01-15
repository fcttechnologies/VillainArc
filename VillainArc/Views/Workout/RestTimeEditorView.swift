import SwiftUI

struct RestTimeEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("autoStartRestTimer") private var storedAutoStartRestTimer = true
    @Environment(\.modelContext) private var context
    @Bindable var exercise: WorkoutExercise
    
    @State private var mode: RestTimeMode = .allSame
    @State private var allSameSeconds: Int = RestTimePolicy.defaultAllSameSeconds
    @State private var byType: RestTimeByType = RestTimeByType.defaultValues
    @State private var showAllSamePicker = false
    @State private var showWarmupPicker = false
    @State private var showRegularPicker = false
    @State private var autoStartRestTimer = true
    @State private var individualSetSeconds: [Int: Int] = [:]
    @State private var expandedSetIndex: Int? = nil
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Auto-Start Timer", isOn: $autoStartRestTimer)
                } footer: {
                    Text("Starts a rest timer after completing a set, based on the mode and times below.")
                }
                
                Section {
                    Picker("Mode", selection: $mode) {
                        ForEach(RestTimeMode.allCases) { mode in
                            Text(mode.displayName)
                                .tag(mode)
                        }
                    }
                } footer: {
                    Text(modeFooterText)
                }
                
                Section {
                    switch mode {
                    case .allSame:
                        restTimeRow(
                            title: "Rest Time",
                            timeLabel: allSameTimeLabel,
                            isExpanded: showAllSamePicker,
                            toggle: toggleAllSamePicker,
                            minutes: allSameMinutes,
                            seconds: allSameSecondsPart
                        )
                    case .byType:
                        restTimeRow(
                            title: "Warm Up Sets",
                            timeLabel: warmupTimeLabel,
                            isExpanded: showWarmupPicker,
                            toggle: toggleWarmupPicker,
                            minutes: warmupMinutes,
                            seconds: warmupSecondsPart
                        )
                        
                        restTimeRow(
                            title: "Normal Sets",
                            timeLabel: regularTimeLabel,
                            isExpanded: showRegularPicker,
                            toggle: toggleRegularPicker,
                            minutes: regularMinutes,
                            seconds: regularSecondsPart
                        )
                    case .individual:
                        if exercise.sortedSets.isEmpty {
                            Text("Add sets first to change their rest times.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(exercise.sortedSets) { set in
                                restTimeRow(
                                    title: individualSetTitle(for: set),
                                    timeLabel: individualTimeLabel(for: set),
                                    isExpanded: expandedSetIndex == set.index,
                                    toggle: { toggleIndividualPicker(for: set.index) },
                                    minutes: individualMinutes(for: set),
                                    seconds: individualSecondsPart(for: set)
                                )
                            }
                        }
                    }
                }
                .listRowSeparator(.hidden)
            }
            .navigationTitle("Set Rest Times")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        Haptics.success()
                        applyChanges()
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadFromPolicy()
            }
            .onChange(of: mode) { _, _ in
                Haptics.selection()
                collapsePickers()
            }
            .onChange(of: autoStartRestTimer) { _, _ in
                Haptics.selection()
            }
        }
    }
    
    private func timeLabel(for totalSeconds: Int) -> String {
        let minutes = max(0, totalSeconds / 60)
        let seconds = max(0, totalSeconds % 60)
        let paddedSeconds = seconds < 10 ? "0\(seconds)" : "\(seconds)"
        return "\(minutes):\(paddedSeconds)"
    }
    
    private var allSameTimeLabel: String {
        timeLabel(for: allSameSeconds)
    }
    
    private var warmupTimeLabel: String {
        timeLabel(for: byType.warmup)
    }
    
    private var regularTimeLabel: String {
        timeLabel(for: byType.regular)
    }
    
    private var allSameMinutes: Binding<Int> {
        Binding(
            get: { min(10, max(0, allSameSeconds / 60)) },
            set: { newValue in
                let seconds = max(0, min(55, allSameSeconds % 60))
                allSameSeconds = max(0, newValue) * 60 + seconds
            }
        )
    }
    
    private var allSameSecondsPart: Binding<Int> {
        Binding(
            get: { max(0, min(55, (allSameSeconds % 60) / 5 * 5)) },
            set: { newValue in
                let minutes = max(0, min(10, allSameSeconds / 60))
                let clamped = max(0, min(55, newValue))
                allSameSeconds = minutes * 60 + clamped
            }
        )
    }
    
    private var warmupMinutes: Binding<Int> {
        Binding(
            get: { min(10, max(0, byType.warmup / 60)) },
            set: { newValue in
                let seconds = max(0, min(55, byType.warmup % 60))
                byType.warmup = max(0, newValue) * 60 + seconds
            }
        )
    }
    
    private var warmupSecondsPart: Binding<Int> {
        Binding(
            get: { max(0, min(55, (byType.warmup % 60) / 5 * 5)) },
            set: { newValue in
                let minutes = max(0, min(10, byType.warmup / 60))
                let clamped = max(0, min(55, newValue))
                byType.warmup = minutes * 60 + clamped
            }
        )
    }
    
    private var regularMinutes: Binding<Int> {
        Binding(
            get: { min(10, max(0, byType.regular / 60)) },
            set: { newValue in
                let seconds = max(0, min(55, byType.regular % 60))
                byType.regular = max(0, newValue) * 60 + seconds
            }
        )
    }
    
    private var regularSecondsPart: Binding<Int> {
        Binding(
            get: { max(0, min(55, (byType.regular % 60) / 5 * 5)) },
            set: { newValue in
                let minutes = max(0, min(10, byType.regular / 60))
                let clamped = max(0, min(55, newValue))
                byType.regular = minutes * 60 + clamped
            }
        )
    }
    
    private var currentPolicy: RestTimePolicy {
        switch mode {
        case .allSame:
            return .allSame(seconds: allSameSeconds)
        case .byType:
            return .byType(byType)
        case .individual:
            return .individual
        }
    }
    
    private var modeFooterText: String {
        switch mode {
        case .allSame:
            return "All sets will use the same rest time."
        case .byType:
            return "Rest time for each set will be based on the set's type."
        case .individual:
            return "Each set keeps its own rest time."
        }
    }
    
    private func loadFromPolicy() {
        autoStartRestTimer = storedAutoStartRestTimer
        individualSetSeconds = Dictionary(uniqueKeysWithValues: exercise.sortedSets.map { ($0.index, $0.restSeconds) })
        switch exercise.restTimePolicy {
        case .allSame(let seconds):
            mode = .allSame
            allSameSeconds = seconds
            byType = RestTimeByType.defaultValues.settingRegular(seconds)
        case .byType(let values):
            mode = .byType
            byType = values
            allSameSeconds = values.regular
        case .individual:
            mode = .individual
            allSameSeconds = RestTimePolicy.defaultAllSameSeconds
            byType = RestTimeByType.defaultValues
        }
    }
    
    private func applyChanges() {
        if mode == .individual {
            for set in exercise.sortedSets {
                if let seconds = individualSetSeconds[set.index] {
                    set.restSeconds = seconds
                }
            }
            exercise.restTimePolicy = .individual
        } else {
            exercise.setRestTimePolicy(currentPolicy)
        }
        storedAutoStartRestTimer = autoStartRestTimer
        saveContext(context: context)
    }
    
    private func collapsePickers() {
        showAllSamePicker = false
        showWarmupPicker = false
        showRegularPicker = false
        expandedSetIndex = nil
    }
    
    @ViewBuilder
    private func restTimeRow(
        title: String,
        timeLabel: String,
        isExpanded: Bool,
        toggle: @escaping () -> Void,
        minutes: Binding<Int>,
        seconds: Binding<Int>
    ) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                Spacer()
                Button {
                    toggle()
                } label: {
                    Text(timeLabel)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
                .buttonStyle(.borderless)
            }
            
            if isExpanded {
                HStack(spacing: 16) {
                    Picker("Minutes", selection: minutes) {
                        ForEach(0...10, id: \.self) { minute in
                            Text("\(minute) min")
                                .tag(minute)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    
                    Picker("Seconds", selection: seconds) {
                        ForEach(0...11, id: \.self) { step in
                            let second = step * 5
                            Text("\(second) sec")
                                .tag(second)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                }
                .frame(height: 140)
            }
        }
    }
    
    private func toggleAllSamePicker() {
        Haptics.selection()
        showAllSamePicker.toggle()
        if showAllSamePicker {
            showWarmupPicker = false
            showRegularPicker = false
        }
    }
    
    private func toggleWarmupPicker() {
        Haptics.selection()
        showWarmupPicker.toggle()
        if showWarmupPicker {
            showAllSamePicker = false
            showRegularPicker = false
        }
    }
    
    private func toggleRegularPicker() {
        Haptics.selection()
        showRegularPicker.toggle()
        if showRegularPicker {
            showAllSamePicker = false
            showWarmupPicker = false
        }
    }
    
    private func toggleIndividualPicker(for index: Int) {
        Haptics.selection()
        if expandedSetIndex == index {
            expandedSetIndex = nil
        } else {
            expandedSetIndex = index
        }
        showAllSamePicker = false
        showWarmupPicker = false
        showRegularPicker = false
    }
    
    private func individualSetTitle(for set: ExerciseSet) -> String {
        if set.type == .regular {
            return "Set \(set.index + 1)"
        }
        
        return "Set \(set.index + 1) (\(set.type.rawValue))"
    }
    
    private func individualTimeLabel(for set: ExerciseSet) -> String {
        let seconds = individualSetSeconds[set.index] ?? set.restSeconds
        return timeLabel(for: seconds)
    }
    
    private func individualMinutes(for set: ExerciseSet) -> Binding<Int> {
        Binding(
            get: {
                let seconds = individualSetSeconds[set.index] ?? set.restSeconds
                return min(10, max(0, seconds / 60))
            },
            set: { newValue in
                let current = individualSetSeconds[set.index] ?? set.restSeconds
                let secondsPart = max(0, min(55, current % 60))
                individualSetSeconds[set.index] = max(0, newValue) * 60 + secondsPart
            }
        )
    }
    
    private func individualSecondsPart(for set: ExerciseSet) -> Binding<Int> {
        Binding(
            get: {
                let seconds = individualSetSeconds[set.index] ?? set.restSeconds
                return max(0, min(55, (seconds % 60) / 5 * 5))
            },
            set: { newValue in
                let current = individualSetSeconds[set.index] ?? set.restSeconds
                let minutes = max(0, min(10, current / 60))
                let clamped = max(0, min(55, newValue))
                individualSetSeconds[set.index] = minutes * 60 + clamped
            }
        )
    }
}

private enum RestTimeMode: String, CaseIterable, Identifiable {
    case allSame
    case byType
    case individual
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .allSame:
            return "All Same"
        case .byType:
            return "By Type"
        case .individual:
            return "Individual"
        }
    }
}
